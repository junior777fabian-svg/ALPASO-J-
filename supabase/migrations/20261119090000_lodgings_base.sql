-- Al Paso — oferta del hostal (etapa 2, parte 2A)
--
-- Qué crea:
--   · public.districts        distritos de Lima Metropolitana y Callao
--   · public.lodgings         el hostal, con su ubicación y su estado de revisión
--   · public.lodging_members  quién es dueño o recepcionista de cada hostal
--   · public.room_types       lo que el cliente ve y elige
--   · public.rooms            las unidades físicas (201, 202…)
--   · public.rates            precio por bloque de horas de cada tipo de cuarto
--   · public.products         la carta de extras del hostal
--   · public.create_lodging()         registra un hostal y nombra dueño a quien lo crea
--   · public.submit_lodging()         el dueño lo envía a revisión
--   · public.admin_review_lodging()   un administrador lo publica o lo rechaza
--
-- Reglas que este archivo deja fijas:
--   · El estado del hostal solo cambia por estas funciones, nunca desde la app.
--   · Solo el dueño edita el contenido de su hostal. Los recepcionistas no
--     cambian precios (docs/ESTRUCTURA.md, sección 4).
--   · Sin sesión solo se ve lo publicado.
--   · Las duraciones permitidas y la venta de licores son configuración de la
--     plataforma, no código.

-- ─────────────────────────────────────────────────────────────── extensiones
create extension if not exists postgis with schema extensions;

-- ────────────────────────────────────────────────────────────── configuración
insert into private.app_settings (key, value, is_public, description) values
  ('booking_blocks_hours', '[4, 6, 8, 12, 24]', true,
   'Bloques de horas que se pueden vender. Cada hostal elige cuáles ofrece.'),
  ('alcohol_enabled', 'false', true,
   'Si los hostales pueden vender licores como extra.'),
  ('max_open_lodgings_per_account', '3', false,
   'Cuántos hostales sin publicar puede tener una cuenta a la vez.');

-- Lee un valor de configuración. Para uso interno de otras funciones.
create function private.setting(p_key text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select s.value from private.app_settings s where s.key = p_key;
$$;
revoke all on function private.setting(text) from public, anon, authenticated;

-- ───────────────────────────────────────────────────────────────── distritos
create table public.districts (
  id smallint primary key,
  name text not null unique,
  province text not null check (province in ('Lima', 'Callao'))
);

comment on table public.districts is
  'Distritos de la zona de servicio: Lima Metropolitana y Callao.';

alter table public.districts enable row level security;
revoke all on table public.districts from public, anon, authenticated;
grant select on table public.districts to anon, authenticated;

create policy districts_select_all
  on public.districts for select to anon, authenticated using (true);

insert into public.districts (id, name, province) values
  (1, 'Ancón', 'Lima'), (2, 'Ate', 'Lima'), (3, 'Barranco', 'Lima'),
  (4, 'Breña', 'Lima'), (5, 'Carabayllo', 'Lima'), (6, 'Chaclacayo', 'Lima'),
  (7, 'Chorrillos', 'Lima'), (8, 'Cieneguilla', 'Lima'), (9, 'Comas', 'Lima'),
  (10, 'El Agustino', 'Lima'), (11, 'Independencia', 'Lima'),
  (12, 'Jesús María', 'Lima'), (13, 'La Molina', 'Lima'),
  (14, 'La Victoria', 'Lima'), (15, 'Lima', 'Lima'), (16, 'Lince', 'Lima'),
  (17, 'Los Olivos', 'Lima'), (18, 'Lurigancho', 'Lima'), (19, 'Lurín', 'Lima'),
  (20, 'Magdalena del Mar', 'Lima'), (21, 'Miraflores', 'Lima'),
  (22, 'Pachacámac', 'Lima'), (23, 'Pucusana', 'Lima'),
  (24, 'Pueblo Libre', 'Lima'), (25, 'Puente Piedra', 'Lima'),
  (26, 'Punta Hermosa', 'Lima'), (27, 'Punta Negra', 'Lima'),
  (28, 'Rímac', 'Lima'), (29, 'San Bartolo', 'Lima'), (30, 'San Borja', 'Lima'),
  (31, 'San Isidro', 'Lima'), (32, 'San Juan de Lurigancho', 'Lima'),
  (33, 'San Juan de Miraflores', 'Lima'), (34, 'San Luis', 'Lima'),
  (35, 'San Martín de Porres', 'Lima'), (36, 'San Miguel', 'Lima'),
  (37, 'Santa Anita', 'Lima'), (38, 'Santa María del Mar', 'Lima'),
  (39, 'Santa Rosa', 'Lima'), (40, 'Santiago de Surco', 'Lima'),
  (41, 'Surquillo', 'Lima'), (42, 'Villa El Salvador', 'Lima'),
  (43, 'Villa María del Triunfo', 'Lima'),
  (44, 'Callao', 'Callao'), (45, 'Bellavista', 'Callao'),
  (46, 'Carmen de la Legua Reynoso', 'Callao'), (47, 'La Perla', 'Callao'),
  (48, 'La Punta', 'Callao'), (49, 'Ventanilla', 'Callao'),
  (50, 'Mi Perú', 'Callao');

-- ─────────────────────────────────────────────────────────────────── hostales
create table public.lodgings (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 3 and 80),
  description text not null default '' check (char_length(description) <= 1000),
  district_id smallint not null references public.districts (id),
  address text not null check (char_length(btrim(address)) between 5 and 200),
  address_reference text not null default ''
    check (char_length(address_reference) <= 200),
  -- Dentro de Lima Metropolitana y Callao, con margen.
  latitude double precision not null check (latitude between -12.60 and -11.50),
  longitude double precision not null check (longitude between -77.30 and -76.50),
  location extensions.geography(point, 4326) generated always as (
    extensions.st_setsrid(extensions.st_makepoint(longitude, latitude), 4326)::extensions.geography
  ) stored,
  has_parking boolean not null default false,
  has_wifi boolean not null default false,
  -- Minutos que el cuarto queda bloqueado después de cada salida.
  cleaning_minutes smallint not null default 30 check (cleaning_minutes between 0 and 180),
  status text not null default 'draft'
    check (status in ('draft', 'pending_review', 'published', 'rejected', 'suspended')),
  review_note text not null default '' check (char_length(review_note) <= 500),
  submitted_at timestamptz,
  published_at timestamptz,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.lodgings is
  'Hostales. El estado solo cambia por submit_lodging y admin_review_lodging.';

create index lodgings_location_idx on public.lodgings using gist (location);
create index lodgings_status_idx on public.lodgings (status);

create trigger lodgings_set_updated_at
  before update on public.lodgings
  for each row execute function private.set_updated_at();

-- ──────────────────────────────────────────────────────── personal del hostal
create table public.lodging_members (
  lodging_id uuid not null references public.lodgings (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('owner', 'receptionist')),
  created_at timestamptz not null default now(),
  primary key (lodging_id, user_id)
);

comment on table public.lodging_members is
  'Dueños y recepcionistas. Solo se modifica por funciones del servidor.';

create index lodging_members_user_idx on public.lodging_members (user_id);

-- `security definer` porque las políticas de lodging_members y de las tablas
-- del hostal consultan lodging_members, y no deben depender de sus propias
-- políticas.
create function private.lodging_role(p_lodging_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select m.role
    from public.lodging_members m
    join public.profiles p on p.id = m.user_id
   where m.lodging_id = p_lodging_id
     and m.user_id = (select auth.uid())
     and not p.is_blocked;
$$;
revoke all on function private.lodging_role(uuid) from public, anon;
grant execute on function private.lodging_role(uuid) to authenticated;

create function private.is_lodging_owner(p_lodging_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(private.lodging_role(p_lodging_id) = 'owner', false);
$$;
revoke all on function private.is_lodging_owner(uuid) from public, anon;
grant execute on function private.is_lodging_owner(uuid) to authenticated;

create function private.is_lodging_member(p_lodging_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.lodging_role(p_lodging_id) is not null;
$$;
revoke all on function private.is_lodging_member(uuid) from public, anon;
grant execute on function private.is_lodging_member(uuid) to authenticated;

create function private.is_lodging_published(p_lodging_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.lodgings l
     where l.id = p_lodging_id and l.status = 'published'
  );
$$;
revoke all on function private.is_lodging_published(uuid) from public;
grant execute on function private.is_lodging_published(uuid) to anon, authenticated;

-- Las políticas de `public` llaman a funciones de `private` también sin
-- sesión, para ver lo publicado. anon puede nombrar el esquema, pero solo
-- ejecuta is_lodging_published y no lee ninguna tabla de private.
grant usage on schema private to anon;

-- Permisos de hostales
alter table public.lodgings enable row level security;
revoke all on table public.lodgings from public, anon, authenticated;
grant select on table public.lodgings to anon, authenticated;
grant update (
  name, description, district_id, address, address_reference,
  latitude, longitude, has_parking, has_wifi, cleaning_minutes
) on table public.lodgings to authenticated;

create policy lodgings_select_published
  on public.lodgings for select to anon, authenticated
  using (status = 'published');

create policy lodgings_select_member_or_admin
  on public.lodgings for select to authenticated
  using ((select private.is_lodging_member(id)) or (select private.is_admin()));

create policy lodgings_update_owner
  on public.lodgings for update to authenticated
  using ((select private.is_lodging_owner(id)))
  with check ((select private.is_lodging_owner(id)));

alter table public.lodging_members enable row level security;
revoke all on table public.lodging_members from public, anon, authenticated;
grant select on table public.lodging_members to authenticated;

-- Cada cuenta ve sus pertenencias; el dueño ve todo el personal de su hostal.
create policy lodging_members_select
  on public.lodging_members for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.is_lodging_owner(lodging_id))
    or (select private.is_admin())
  );

-- ───────────────────────────────────────────────────────────── tipos de cuarto
create table public.room_types (
  id uuid primary key default gen_random_uuid(),
  lodging_id uuid not null references public.lodgings (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 2 and 60),
  description text not null default '' check (char_length(description) <= 500),
  max_guests smallint not null default 2 check (max_guests between 1 and 6),
  has_jacuzzi boolean not null default false,
  has_tv boolean not null default false,
  has_air_conditioning boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Permite que cuartos y tarifas exijan pertenecer al mismo hostal.
  unique (id, lodging_id)
);

comment on table public.room_types is
  'Tipos de cuarto: lo que el cliente ve y elige.';

create index room_types_lodging_idx on public.room_types (lodging_id);

create trigger room_types_set_updated_at
  before update on public.room_types
  for each row execute function private.set_updated_at();

-- ──────────────────────────────────────────────────────────────────── cuartos
create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  lodging_id uuid not null,
  room_type_id uuid not null,
  label text not null check (label ~ '^[A-Za-z0-9-]{1,10}$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  foreign key (room_type_id, lodging_id)
    references public.room_types (id, lodging_id) on delete cascade,
  unique (lodging_id, label)
);

comment on table public.rooms is
  'Unidades físicas. El cliente no las ve: el servidor asigna una al reservar.';

create index rooms_room_type_idx on public.rooms (room_type_id);

-- ─────────────────────────────────────────────────────────────────── tarifas
create table public.rates (
  room_type_id uuid not null,
  lodging_id uuid not null,
  block_hours smallint not null,
  -- Céntimos de sol. De S/ 1.00 a S/ 5,000.00.
  price_cents integer not null check (price_cents between 100 and 500000),
  updated_at timestamptz not null default now(),
  primary key (room_type_id, block_hours),
  foreign key (room_type_id, lodging_id)
    references public.room_types (id, lodging_id) on delete cascade
);

comment on table public.rates is
  'Precio de cada bloque de horas por tipo de cuarto. En céntimos.';

create index rates_lodging_idx on public.rates (lodging_id);

create trigger rates_set_updated_at
  before update on public.rates
  for each row execute function private.set_updated_at();

-- El bloque debe estar entre los que la plataforma permite vender.
-- `security definer` porque lee la configuración privada, que quien escribe
-- no puede leer.
create function private.check_rate_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (private.setting('booking_blocks_hours') @> to_jsonb(new.block_hours)) then
    raise exception 'block_not_allowed' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function private.check_rate_block() from public, anon, authenticated;

create trigger rates_check_block
  before insert or update of block_hours on public.rates
  for each row execute function private.check_rate_block();

-- ──────────────────────────────────────────────────────────── carta de extras
create table public.products (
  id uuid primary key default gen_random_uuid(),
  lodging_id uuid not null references public.lodgings (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 2 and 60),
  description text not null default '' check (char_length(description) <= 200),
  category text not null
    check (category in ('drinks', 'snacks', 'personal_care', 'alcohol', 'other')),
  -- Céntimos de sol. De S/ 0.50 a S/ 1,000.00.
  price_cents integer not null check (price_cents between 50 and 100000),
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.products is
  'Carta de extras de cada hostal, con sus precios en céntimos.';

create index products_lodging_idx on public.products (lodging_id);

create trigger products_set_updated_at
  before update on public.products
  for each row execute function private.set_updated_at();

-- `security definer` porque lee la configuración privada, que quien escribe
-- no puede leer.
create function private.check_product_category()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.category = 'alcohol'
     and not coalesce((private.setting('alcohol_enabled'))::boolean, false) then
    raise exception 'alcohol_disabled' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function private.check_product_category() from public, anon, authenticated;

create trigger products_check_category
  before insert or update of category on public.products
  for each row execute function private.check_product_category();

-- ──────────────────────────────────── permisos del contenido del hostal
-- Lectura: lo publicado, para todos; lo demás, para el personal y el admin.
-- Escritura: solo el dueño. Nunca se cambia de hostal una fila existente.

alter table public.room_types enable row level security;
revoke all on table public.room_types from public, anon, authenticated;
grant select on table public.room_types to anon, authenticated;
grant insert (
  lodging_id, name, description, max_guests, has_jacuzzi, has_tv,
  has_air_conditioning, is_active
) on table public.room_types to authenticated;
grant update (
  name, description, max_guests, has_jacuzzi, has_tv, has_air_conditioning,
  is_active
) on table public.room_types to authenticated;
grant delete on table public.room_types to authenticated;

create policy room_types_select_public
  on public.room_types for select to anon, authenticated
  using (is_active and (select private.is_lodging_published(lodging_id)));
create policy room_types_select_staff
  on public.room_types for select to authenticated
  using ((select private.is_lodging_member(lodging_id)) or (select private.is_admin()));
create policy room_types_insert_owner
  on public.room_types for insert to authenticated
  with check ((select private.is_lodging_owner(lodging_id)));
create policy room_types_update_owner
  on public.room_types for update to authenticated
  using ((select private.is_lodging_owner(lodging_id)))
  with check ((select private.is_lodging_owner(lodging_id)));
create policy room_types_delete_owner
  on public.room_types for delete to authenticated
  using ((select private.is_lodging_owner(lodging_id)));

alter table public.rooms enable row level security;
revoke all on table public.rooms from public, anon, authenticated;
grant select on table public.rooms to authenticated;
grant insert (lodging_id, room_type_id, label, is_active)
  on table public.rooms to authenticated;
grant update (room_type_id, label, is_active) on table public.rooms to authenticated;
grant delete on table public.rooms to authenticated;

create policy rooms_select_staff
  on public.rooms for select to authenticated
  using ((select private.is_lodging_member(lodging_id)) or (select private.is_admin()));
create policy rooms_insert_owner
  on public.rooms for insert to authenticated
  with check ((select private.is_lodging_owner(lodging_id)));
create policy rooms_update_owner
  on public.rooms for update to authenticated
  using ((select private.is_lodging_owner(lodging_id)))
  with check ((select private.is_lodging_owner(lodging_id)));
create policy rooms_delete_owner
  on public.rooms for delete to authenticated
  using ((select private.is_lodging_owner(lodging_id)));

alter table public.rates enable row level security;
revoke all on table public.rates from public, anon, authenticated;
grant select on table public.rates to anon, authenticated;
grant insert (room_type_id, lodging_id, block_hours, price_cents)
  on table public.rates to authenticated;
grant update (price_cents) on table public.rates to authenticated;
grant delete on table public.rates to authenticated;

create policy rates_select_public
  on public.rates for select to anon, authenticated
  using ((select private.is_lodging_published(lodging_id)));
create policy rates_select_staff
  on public.rates for select to authenticated
  using ((select private.is_lodging_member(lodging_id)) or (select private.is_admin()));
create policy rates_insert_owner
  on public.rates for insert to authenticated
  with check ((select private.is_lodging_owner(lodging_id)));
create policy rates_update_owner
  on public.rates for update to authenticated
  using ((select private.is_lodging_owner(lodging_id)))
  with check ((select private.is_lodging_owner(lodging_id)));
create policy rates_delete_owner
  on public.rates for delete to authenticated
  using ((select private.is_lodging_owner(lodging_id)));

alter table public.products enable row level security;
revoke all on table public.products from public, anon, authenticated;
grant select on table public.products to anon, authenticated;
grant insert (lodging_id, name, description, category, price_cents, is_available)
  on table public.products to authenticated;
grant update (name, description, category, price_cents, is_available)
  on table public.products to authenticated;
grant delete on table public.products to authenticated;

create policy products_select_public
  on public.products for select to anon, authenticated
  using (is_available and (select private.is_lodging_published(lodging_id)));
create policy products_select_staff
  on public.products for select to authenticated
  using ((select private.is_lodging_member(lodging_id)) or (select private.is_admin()));
create policy products_insert_owner
  on public.products for insert to authenticated
  with check ((select private.is_lodging_owner(lodging_id)));
create policy products_update_owner
  on public.products for update to authenticated
  using ((select private.is_lodging_owner(lodging_id)))
  with check ((select private.is_lodging_owner(lodging_id)));
create policy products_delete_owner
  on public.products for delete to authenticated
  using ((select private.is_lodging_owner(lodging_id)));

-- ───────────────────────────────────────────────────────────────── funciones

-- Registra un hostal en borrador y nombra dueño a la cuenta en sesión.
create function public.create_lodging(
  p_name text,
  p_district_id smallint,
  p_address text,
  p_address_reference text,
  p_latitude double precision,
  p_longitude double precision
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_profile public.profiles;
  v_open integer;
  v_lodging_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select * into v_profile from public.profiles where id = v_user_id;
  if v_profile.is_blocked then
    raise exception 'account_blocked' using errcode = '42501';
  end if;
  if v_profile.adult_confirmed_at is null then
    raise exception 'adult_not_confirmed' using errcode = '42501';
  end if;

  select count(*) into v_open
    from public.lodgings l
    join public.lodging_members m on m.lodging_id = l.id
   where m.user_id = v_user_id
     and m.role = 'owner'
     and l.status in ('draft', 'pending_review', 'rejected');
  if v_open >= coalesce((private.setting('max_open_lodgings_per_account'))::integer, 3) then
    raise exception 'too_many_open_lodgings' using errcode = '54000';
  end if;

  insert into public.lodgings (
    name, district_id, address, address_reference, latitude, longitude, created_by
  ) values (
    btrim(p_name), p_district_id, btrim(p_address),
    btrim(coalesce(p_address_reference, '')), p_latitude, p_longitude, v_user_id
  )
  returning id into v_lodging_id;

  insert into public.lodging_members (lodging_id, user_id, role)
  values (v_lodging_id, v_user_id, 'owner');

  return v_lodging_id;
end;
$$;

comment on function public.create_lodging(text, smallint, text, text, double precision, double precision) is
  'Registra un hostal en borrador. Quien lo crea queda como dueño.';
revoke all on function public.create_lodging(text, smallint, text, text, double precision, double precision) from public, anon;
grant execute on function public.create_lodging(text, smallint, text, text, double precision, double precision) to authenticated;

-- Qué le falta a un hostal para poder enviarse a revisión. Vacío = completo.
-- Las fotos se exigirán cuando existan (parte 2D).
create function private.lodging_missing(p_lodging_id uuid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select array_remove(array[
    case when not exists (
      select 1 from public.room_types t
       where t.lodging_id = p_lodging_id and t.is_active
         and exists (select 1 from public.rates r where r.room_type_id = t.id)
         and exists (select 1 from public.rooms u where u.room_type_id = t.id and u.is_active)
    ) then 'room_type_ready' end
  ], null);
$$;
revoke all on function private.lodging_missing(uuid) from public, anon, authenticated;

-- El dueño envía su hostal a revisión.
create function public.submit_lodging(p_lodging_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_missing text[];
begin
  if (select auth.uid()) is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not private.is_lodging_owner(p_lodging_id) then
    raise exception 'not_owner' using errcode = '42501';
  end if;

  select status into v_status from public.lodgings where id = p_lodging_id for update;
  if v_status not in ('draft', 'rejected') then
    raise exception 'invalid_status' using errcode = '55000';
  end if;

  v_missing := private.lodging_missing(p_lodging_id);
  if cardinality(v_missing) > 0 then
    raise exception 'lodging_incomplete'
      using errcode = '23514', detail = array_to_string(v_missing, ',');
  end if;

  update public.lodgings
     set status = 'pending_review', submitted_at = now(), review_note = ''
   where id = p_lodging_id;

  return 'pending_review';
end;
$$;

comment on function public.submit_lodging(uuid) is
  'El dueño envía su hostal a revisión. Exige al menos un tipo de cuarto con tarifa y cuarto activo.';
revoke all on function public.submit_lodging(uuid) from public, anon;
grant execute on function public.submit_lodging(uuid) to authenticated;

-- Un administrador publica o rechaza un hostal en revisión.
create function public.admin_review_lodging(
  p_lodging_id uuid,
  p_approve boolean,
  p_note text default ''
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_note text := btrim(coalesce(p_note, ''));
begin
  -- Un administrador con sesión, o la llave de servidor (tools/admin-review.cjs
  -- mientras no exista el panel de administración de la etapa 6).
  if not (private.is_admin() or (select auth.role()) = 'service_role') then
    raise exception 'not_admin' using errcode = '42501';
  end if;

  select status into v_status from public.lodgings where id = p_lodging_id for update;
  if v_status is distinct from 'pending_review' then
    raise exception 'invalid_status' using errcode = '55000';
  end if;

  if p_approve then
    -- Pudo cambiar entre el envío y la revisión.
    if cardinality(private.lodging_missing(p_lodging_id)) > 0 then
      raise exception 'lodging_incomplete' using errcode = '23514';
    end if;
    update public.lodgings
       set status = 'published', published_at = now(), review_note = v_note
     where id = p_lodging_id;
    return 'published';
  end if;

  if v_note = '' then
    raise exception 'review_note_required' using errcode = '23514';
  end if;
  update public.lodgings
     set status = 'rejected', review_note = left(v_note, 500)
   where id = p_lodging_id;
  return 'rejected';
end;
$$;

comment on function public.admin_review_lodging(uuid, boolean, text) is
  'Un administrador publica o rechaza un hostal en revisión. Rechazar exige un motivo.';
revoke all on function public.admin_review_lodging(uuid, boolean, text) from public, anon;
grant execute on function public.admin_review_lodging(uuid, boolean, text) to authenticated, service_role;
