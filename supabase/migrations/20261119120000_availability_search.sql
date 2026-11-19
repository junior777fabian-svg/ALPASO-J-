-- Al Paso — disponibilidad y búsqueda (etapa 3, parte 3A)
--
-- Qué crea:
--   · public.room_occupancy        la única fuente de verdad de la disponibilidad
--   · public.search_lodgings()     hostales cercanos con cuarto libre, su precio
--                                  y su distancia
--   · public.get_lodging_offer()   tipos de cuarto de un hostal con su precio y
--                                  si hay uno libre, para la hora y duración pedidas
--
-- Reglas que este archivo deja fijas (docs/ESTRUCTURA.md, secciones 6.2 y 7):
--   · Dos ocupaciones del mismo cuarto nunca se cruzan en el tiempo: lo impide
--     una restricción de exclusión de la base, no la app.
--   · Un cuarto está libre si nada lo ocupa desde la llegada hasta la salida
--     más el tiempo de limpieza del hostal.
--   · Una retención vencida (reserva sin pagar) ya no ocupa el cuarto.
--   · Nadie escribe ocupaciones desde la app: lo harán las funciones de
--     reservas (etapa 4) y de recepción (etapa 5).

create extension if not exists btree_gist with schema extensions;

insert into private.app_settings (key, value, is_public, description) values
  ('max_advance_days', '7', true,
   'Con cuántos días de anticipación se puede reservar.'),
  ('max_search_radius_m', '30000', false,
   'Radio máximo de búsqueda, en metros.');

-- ─────────────────────────────────────────────────────────────── ocupación
create table public.room_occupancy (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms (id) on delete cascade,
  lodging_id uuid not null references public.lodgings (id) on delete cascade,
  -- booking: reserva pagada. hold: retención mientras se paga. walk_in:
  -- cliente directo. cleaning: limpieza. maintenance: fuera de servicio.
  kind text not null
    check (kind in ('booking', 'hold', 'walk_in', 'cleaning', 'maintenance')),
  -- [desde, hasta): incluye el inicio, no el fin. Una reserva cubre la
  -- estadía más la limpieza.
  period tstzrange not null
    check (not isempty(period) and lower_inc(period) and not upper_inc(period)
           and lower(period) is not null and upper(period) is not null),
  -- Solo las retenciones vencen.
  expires_at timestamptz check ((kind = 'hold') = (expires_at is not null)),
  created_at timestamptz not null default now(),
  constraint room_occupancy_no_overlap
    exclude using gist (room_id with =, period with &&)
);

comment on table public.room_occupancy is
  'Ocupación de cada cuarto. Una restricción de exclusión impide cruces. Solo la escriben funciones del servidor.';

create index room_occupancy_lodging_idx on public.room_occupancy (lodging_id);

alter table public.room_occupancy enable row level security;
revoke all on table public.room_occupancy from public, anon, authenticated;
grant select on table public.room_occupancy to authenticated;

create policy room_occupancy_select_staff
  on public.room_occupancy for select to authenticated
  using ((select private.is_lodging_member(lodging_id)) or (select private.is_admin()));

-- ¿Este cuarto está libre en este rango? Las retenciones vencidas no cuentan.
create function private.room_is_free(p_room_id uuid, p_range tstzrange)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.room_occupancy o
     where o.room_id = p_room_id
       and o.period && p_range
       and (o.kind <> 'hold' or o.expires_at > now())
  );
$$;
revoke all on function private.room_is_free(uuid, tstzrange) from public, anon, authenticated;

-- Valida llegada y duración pedidas. Devuelve el bloque como smallint.
create function private.check_search_window(p_arrival timestamptz, p_block_hours integer)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_arrival is null or p_block_hours is null then
    raise exception 'invalid_search' using errcode = '22023';
  end if;
  if not (private.setting('booking_blocks_hours') @> to_jsonb(p_block_hours)) then
    raise exception 'block_not_allowed' using errcode = '22023';
  end if;
  -- Unos minutos de tolerancia hacia atrás: "ahora" en el teléfono puede
  -- ir un poco adelantado.
  if p_arrival < now() - interval '10 minutes'
     or p_arrival > now() + make_interval(
       days => coalesce((private.setting('max_advance_days'))::integer, 7)) then
    raise exception 'arrival_out_of_range' using errcode = '22023';
  end if;
end;
$$;
revoke all on function private.check_search_window(timestamptz, integer) from public, anon, authenticated;

-- ──────────────────────────────────────────────────────────────── búsqueda
create function public.search_lodgings(
  p_latitude double precision,
  p_longitude double precision,
  p_arrival timestamptz,
  p_block_hours integer,
  p_radius_m integer default 5000,
  p_district_id smallint default null,
  p_max_price_cents integer default null,
  p_needs_jacuzzi boolean default false,
  p_needs_parking boolean default false
)
returns table (
  lodging_id uuid,
  name text,
  district_name text,
  address text,
  address_reference text,
  latitude double precision,
  longitude double precision,
  distance_m integer,
  min_price_cents integer,
  available_room_types integer,
  has_parking boolean,
  has_wifi boolean,
  has_jacuzzi boolean,
  cover_photo_path text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_origin extensions.geography;
  v_radius integer;
begin
  perform private.check_search_window(p_arrival, p_block_hours);
  v_origin := extensions.st_setsrid(
    extensions.st_makepoint(p_longitude, p_latitude), 4326)::extensions.geography;
  v_radius := least(
    greatest(coalesce(p_radius_m, 5000), 100),
    coalesce((private.setting('max_search_radius_m'))::integer, 30000));

  return query
  with candidates as (
    select l.*, extensions.st_distance(l.location, v_origin) as distance
      from public.lodgings l
     where l.status = 'published'
       and (p_district_id is null or l.district_id = p_district_id)
       and (p_district_id is not null
            or extensions.st_dwithin(l.location, v_origin, v_radius))
       and (not p_needs_parking or l.has_parking)
  ),
  offer as (
    -- Tipos de cuarto vendibles con al menos un cuarto libre durante la
    -- estadía más la limpieza.
    select t.lodging_id, t.id as room_type_id, t.has_jacuzzi, r.price_cents
      from candidates c
      join public.room_types t on t.lodging_id = c.id and t.is_active
      join public.rates r on r.room_type_id = t.id and r.block_hours = p_block_hours
     where (not p_needs_jacuzzi or t.has_jacuzzi)
       and (p_max_price_cents is null or r.price_cents <= p_max_price_cents)
       and exists (
         select 1 from public.rooms u
          where u.room_type_id = t.id and u.is_active
            and private.room_is_free(
              u.id,
              tstzrange(
                p_arrival,
                p_arrival + make_interval(hours => p_block_hours,
                                          mins => c.cleaning_minutes),
                '[)'))
       )
  )
  select c.id, c.name, d.name, c.address, c.address_reference,
         c.latitude, c.longitude, round(c.distance)::integer,
         min(o.price_cents)::integer, count(*)::integer,
         c.has_parking, c.has_wifi, bool_or(o.has_jacuzzi),
         (select f.storage_path from public.lodging_photos f
           where f.lodging_id = c.id order by f.sort_order, f.created_at limit 1)
    from candidates c
    join offer o on o.lodging_id = c.id
    join public.districts d on d.id = c.district_id
   group by c.id, c.name, d.name, c.address, c.address_reference, c.latitude,
            c.longitude, c.distance, c.has_parking, c.has_wifi
   order by c.distance, min(o.price_cents)
   limit 100;
end;
$$;

comment on function public.search_lodgings(double precision, double precision, timestamptz, integer, integer, smallint, integer, boolean, boolean) is
  'Hostales publicados cercanos con al menos un cuarto libre para la llegada y el bloque pedidos.';
revoke all on function public.search_lodgings(double precision, double precision, timestamptz, integer, integer, smallint, integer, boolean, boolean) from public;
grant execute on function public.search_lodgings(double precision, double precision, timestamptz, integer, integer, smallint, integer, boolean, boolean) to anon, authenticated;

-- ────────────────────────────────────────────────────── oferta de un hostal
create function public.get_lodging_offer(
  p_lodging_id uuid,
  p_arrival timestamptz,
  p_block_hours integer
)
returns table (
  room_type_id uuid,
  name text,
  description text,
  max_guests smallint,
  has_jacuzzi boolean,
  has_tv boolean,
  has_air_conditioning boolean,
  price_cents integer,
  is_available boolean,
  -- Todas las tarifas del tipo de cuarto: {"4": 4500, "12": 9000}.
  rates jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_cleaning smallint;
begin
  perform private.check_search_window(p_arrival, p_block_hours);
  select l.cleaning_minutes into v_cleaning
    from public.lodgings l
   where l.id = p_lodging_id and l.status = 'published';
  if not found then
    raise exception 'lodging_not_found' using errcode = 'P0002';
  end if;

  return query
  select t.id, t.name, t.description, t.max_guests, t.has_jacuzzi, t.has_tv,
         t.has_air_conditioning, r.price_cents,
         exists (
           select 1 from public.rooms u
            where u.room_type_id = t.id and u.is_active
              and private.room_is_free(
                u.id,
                tstzrange(p_arrival,
                          p_arrival + make_interval(hours => p_block_hours, mins => v_cleaning),
                          '[)'))
         ),
         (select jsonb_object_agg(x.block_hours::text, x.price_cents)
            from public.rates x where x.room_type_id = t.id)
    from public.room_types t
    left join public.rates r on r.room_type_id = t.id and r.block_hours = p_block_hours
   where t.lodging_id = p_lodging_id and t.is_active
   order by r.price_cents nulls last, t.name;
end;
$$;

comment on function public.get_lodging_offer(uuid, timestamptz, integer) is
  'Tipos de cuarto de un hostal publicado, con el precio del bloque pedido y si hay uno libre.';
revoke all on function public.get_lodging_offer(uuid, timestamptz, integer) from public;
grant execute on function public.get_lodging_offer(uuid, timestamptz, integer) to anon, authenticated;
