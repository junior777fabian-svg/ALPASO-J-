-- Al Paso — recepción y personal (etapa 5, parte 5A)
--
-- Qué crea:
--   · public.host_today()           tablero del día: llegadas, en curso, cuartos y extras por preparar
--   · public.host_check_in()        ingreso con el código, una sola vez
--   · public.host_check_out()       salida: el cuarto pasa a limpieza
--   · public.host_mark_clean()      el cuarto vuelve a estar libre
--   · public.host_block_room()      cliente directo o fuera de servicio
--   · public.host_release_block()   termina un bloqueo antes de tiempo
--   · public.host_set_item_status() extra listo en el cuarto o no disponible (se reembolsa)
--   · public.host_cancel_booking()  el dueño cancela con motivo: reembolso total
--   · public.lodging_invites, invite_staff(), accept_invite(), revoke_staff()
--   · tareas automáticas: "no llegó" y salida automática al terminar el tiempo
--
-- Reglas que este archivo deja fijas (docs/ESTRUCTURA.md, secciones 4, 6.5 y 6.7):
--   · Un código sirve una sola vez, solo en su hostal y en su horario: desde
--     15 minutos antes de la llegada hasta la hora de salida.
--   · El recepcionista ve del cliente solo el nombre y el código.
--   · El recepcionista atiende el día; cancelar reservas e invitar personal
--     es del dueño.
--   · Un extra que falta se reembolsa; los reembolsos de un cobro nunca
--     suman más que el cobro.

insert into private.app_settings (key, value, is_public, description) values
  ('check_in_early_minutes', '15', true,
   'Minutos antes de la hora reservada desde los que se puede ingresar.'),
  ('no_show_minutes', '30', true,
   'Minutos de espera después de la hora reservada antes de marcar "no llegó".'),
  ('invite_valid_hours', '48', false,
   'Horas que vale un código de invitación de personal.');

alter table public.bookings add column checked_in_at timestamptz;
alter table public.bookings add column checked_out_at timestamptz;

-- ───────────────────────────────────────────── reembolsos parciales
-- Un cobro puede tener varios reembolsos (por ejemplo, un extra que faltó y
-- después la cancelación), pero nunca suman más que lo cobrado.
alter table public.refunds drop constraint refunds_payment_id_key;
alter table public.refunds add column booking_item_id uuid references public.booking_items (id);
create unique index refunds_item_idx on public.refunds (booking_item_id)
  where booking_item_id is not null;

create function private.check_refund_total()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select coalesce(sum(r.amount_cents), 0) from public.refunds r
       where r.payment_id = new.payment_id)
     > (select p.amount_cents from public.payments p where p.id = new.payment_id) then
    raise exception 'refund_exceeds_payment' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function private.check_refund_total() from public, anon, authenticated;

create constraint trigger refunds_total_check
  after insert or update on public.refunds
  deferrable initially immediate
  for each row execute function private.check_refund_total();

-- Lo que falta devolver de un cobro.
create function private.refundable_cents(p_payment_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select p.amount_cents - coalesce((select sum(r.amount_cents) from public.refunds r
                                     where r.payment_id = p.id), 0)
    from public.payments p where p.id = p_payment_id;
$$;
revoke all on function private.refundable_cents(uuid) from public, anon, authenticated;

-- Registra un reembolso. En demo se procesa al instante. Marca el cobro
-- como reembolsado cuando ya se devolvió todo.
create function private.add_refund(
  p_booking_id uuid, p_amount integer, p_reason text, p_item_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payment public.payments;
  v_amount integer;
begin
  select * into v_payment from public.payments
   where booking_id = p_booking_id and status in ('paid', 'refunded')
   order by created_at desc limit 1
   for update;
  if not found then
    return 0;
  end if;
  v_amount := least(p_amount, private.refundable_cents(v_payment.id));
  if v_amount <= 0 then
    return 0;
  end if;
  insert into public.refunds (booking_id, payment_id, amount_cents, status, reason,
                              processed_at, booking_item_id)
  values (p_booking_id, v_payment.id, v_amount,
          case when v_payment.provider = 'demo' then 'processed' else 'pending' end,
          coalesce(p_reason, ''),
          case when v_payment.provider = 'demo' then now() end, p_item_id);
  if private.refundable_cents(v_payment.id) = 0 then
    update public.payments set status = 'refunded' where id = v_payment.id;
  end if;
  return v_amount;
end;
$$;
revoke all on function private.add_refund(uuid, integer, text, uuid) from public, anon, authenticated;

-- La cancelación del cliente ahora devuelve solo lo que falta devolver.
create or replace function public.cancel_booking(p_booking_id uuid, p_reason text default '')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_hours integer := coalesce((private.setting('refund_full_hours_before'))::integer, 1);
  v_grace integer := coalesce((private.setting('refund_grace_minutes'))::integer, 5);
  v_refund integer;
begin
  select * into v_booking from public.bookings
   where id = p_booking_id and customer_id = (select auth.uid())
   for update;
  if not found then
    raise exception 'booking_not_found' using errcode = 'P0002';
  end if;

  if v_booking.status = 'pending_payment' then
    update public.bookings
       set status = 'cancelled', cancelled_at = now(), cancel_reason = left(coalesce(p_reason, ''), 300)
     where id = p_booking_id;
    delete from public.room_occupancy where booking_id = p_booking_id;
    update public.payments set status = 'failed'
     where booking_id = p_booking_id and status = 'pending';
    perform private.log_booking(p_booking_id, 'pending_payment', 'cancelled', 'cancelada antes de pagar');
    return jsonb_build_object('status', 'cancelled', 'refund_cents', 0);
  end if;

  if v_booking.status <> 'confirmed' then
    raise exception 'invalid_status' using errcode = '55000';
  end if;

  if not (now() <= v_booking.arrival_at - make_interval(hours => v_hours)
          or (v_booking.paid_at > v_booking.arrival_at - make_interval(hours => v_hours)
              and now() <= v_booking.paid_at + make_interval(mins => v_grace))) then
    raise exception 'cancel_window_closed' using errcode = '55000';
  end if;

  update public.bookings
     set status = 'cancelled', cancelled_at = now(), cancel_reason = left(coalesce(p_reason, ''), 300)
   where id = p_booking_id;
  delete from public.room_occupancy where booking_id = p_booking_id;
  v_refund := private.add_refund(p_booking_id, v_booking.total_cents, 'cancelada por el cliente');
  perform private.log_booking(p_booking_id, 'confirmed', 'cancelled', 'cancelada por el cliente, con reembolso');
  return jsonb_build_object('status', 'cancelled', 'refund_cents', v_refund);
end;
$$;

-- ─────────────────────────────────────────────────────── auxiliares de rol
-- Devuelve el hostal de una reserva si quien llama es su personal (dueño o
-- recepcionista). Si no, falla.
create function private.require_staff(p_lodging_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not private.is_lodging_member(p_lodging_id) then
    raise exception 'not_staff' using errcode = '42501';
  end if;
end;
$$;
revoke all on function private.require_staff(uuid) from public, anon, authenticated;

-- ────────────────────────────────────────────────────────────────── tablero
create function public.host_today(p_lodging_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_early integer := coalesce((private.setting('check_in_early_minutes'))::integer, 15);
begin
  perform private.require_staff(p_lodging_id);
  return jsonb_build_object(
    -- Llegadas confirmadas de las próximas 24 horas y de las últimas 2 que
    -- todavía no ingresan.
    'arrivals', coalesce((
      select jsonb_agg(jsonb_build_object(
               'booking_id', b.id, 'code', b.code,
               -- Del cliente, solo el nombre (sección 7).
               'customer_name', coalesce(nullif(p.full_name, ''), 'Cliente'),
               'room_label', u.label, 'room_type', t.name,
               'arrival_at', b.arrival_at, 'departure_at', b.departure_at,
               'block_hours', b.block_hours,
               'can_check_in', now() >= b.arrival_at - make_interval(mins => v_early),
               'items', coalesce((select jsonb_agg(jsonb_build_object(
                          'id', i.id, 'name', i.name, 'quantity', i.quantity, 'status', i.status)
                          order by i.name)
                        from public.booking_items i where i.booking_id = b.id), '[]'))
             order by b.arrival_at)
        from public.bookings b
        join public.profiles p on p.id = b.customer_id
        join public.rooms u on u.id = b.room_id
        join public.room_types t on t.id = b.room_type_id
       where b.lodging_id = p_lodging_id and b.status = 'confirmed'
         and b.arrival_at between now() - interval '2 hours' and now() + interval '24 hours'
    ), '[]'),
    'in_house', coalesce((
      select jsonb_agg(jsonb_build_object(
               'booking_id', b.id, 'code', b.code,
               'customer_name', coalesce(nullif(p.full_name, ''), 'Cliente'),
               'room_label', u.label, 'departure_at', b.departure_at,
               'items', coalesce((select jsonb_agg(jsonb_build_object(
                          'id', i.id, 'name', i.name, 'quantity', i.quantity, 'status', i.status)
                          order by i.name)
                        from public.booking_items i where i.booking_id = b.id), '[]'))
             order by b.departure_at)
        from public.bookings b
        join public.profiles p on p.id = b.customer_id
        join public.rooms u on u.id = b.room_id
       where b.lodging_id = p_lodging_id and b.status = 'checked_in'
    ), '[]'),
    -- Estado actual de cada cuarto.
    'rooms', coalesce((
      select jsonb_agg(jsonb_build_object(
               'room_id', u.id, 'label', u.label, 'room_type', t.name,
               'is_active', u.is_active,
               'state', case
                 when not u.is_active then 'inactive'
                 when o.id is null then 'free'
                 when o.kind = 'booking' and b.status = 'checked_in' then 'occupied'
                 when o.kind = 'booking' and now() >= b.departure_at then 'cleaning'
                 when o.kind in ('booking', 'hold') then 'reserved'
                 else o.kind end,
               'occupancy_id', o.id,
               'until', upper(o.period))
             order by u.label)
        from public.rooms u
        join public.room_types t on t.id = u.room_type_id
        left join lateral (
          select x.* from public.room_occupancy x
           where x.room_id = u.id and x.period @> now()
             and (x.kind <> 'hold' or x.expires_at > now())
           limit 1) o on true
        left join public.bookings b on b.id = o.booking_id
       where u.lodging_id = p_lodging_id
    ), '[]'));
end;
$$;

comment on function public.host_today(uuid) is
  'Tablero de recepción: llegadas, estadías en curso, estado de cada cuarto y extras.';
revoke all on function public.host_today(uuid) from public, anon;
grant execute on function public.host_today(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────── ingreso
create function public.host_check_in(p_lodging_id uuid, p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  -- Acepta el código solo o el contenido del QR (ALPASO:<código>), en
  -- mayúsculas o minúsculas y con espacios.
  v_code text := btrim(replace(upper(coalesce(p_code, '')), 'ALPASO:', ''));
  v_early integer := coalesce((private.setting('check_in_early_minutes'))::integer, 15);
begin
  perform private.require_staff(p_lodging_id);

  select * into v_booking from public.bookings
   where code = v_code and lodging_id = p_lodging_id
   for update;
  if not found then
    -- Mismo mensaje si el código no existe o es de otro hostal.
    raise exception 'code_not_found' using errcode = 'P0002';
  end if;
  if v_booking.status = 'checked_in' or v_booking.status = 'completed' then
    raise exception 'code_already_used' using errcode = '55000';
  end if;
  if v_booking.status <> 'confirmed' then
    raise exception 'booking_not_confirmed' using errcode = '55000';
  end if;
  if now() < v_booking.arrival_at - make_interval(mins => v_early) then
    raise exception 'too_early' using errcode = '55000';
  end if;
  if now() >= v_booking.departure_at then
    raise exception 'too_late' using errcode = '55000';
  end if;

  update public.bookings set status = 'checked_in', checked_in_at = now()
   where id = v_booking.id;
  perform private.log_booking(v_booking.id, 'confirmed', 'checked_in', 'ingreso con código');

  return jsonb_build_object(
    'booking_id', v_booking.id, 'code', v_booking.code,
    'customer_name', (select coalesce(nullif(p.full_name, ''), 'Cliente')
                        from public.profiles p where p.id = v_booking.customer_id),
    'room_label', (select u.label from public.rooms u where u.id = v_booking.room_id),
    'departure_at', v_booking.departure_at);
end;
$$;

comment on function public.host_check_in(uuid, text) is
  'Recepción registra el ingreso con el código: solo en su hostal, en horario y una sola vez.';
revoke all on function public.host_check_in(uuid, text) from public, anon;
grant execute on function public.host_check_in(uuid, text) to authenticated;

-- ──────────────────────────────────────────────────────────────────── salida
create function public.host_check_out(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_cleaning smallint;
  v_end timestamptz;
begin
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'booking_not_found' using errcode = 'P0002';
  end if;
  perform private.require_staff(v_booking.lodging_id);
  if v_booking.status <> 'checked_in' then
    raise exception 'invalid_status' using errcode = '55000';
  end if;
  select cleaning_minutes into v_cleaning from public.lodgings where id = v_booking.lodging_id;

  update public.bookings set status = 'completed', checked_out_at = now() where id = p_booking_id;
  -- La estadía termina ahora y el cuarto pasa a limpieza desde ya.
  select greatest(now(), lower(period) + interval '1 second') into v_end
    from public.room_occupancy where booking_id = p_booking_id;
  update public.room_occupancy set period = tstzrange(lower(period), v_end, '[)')
   where booking_id = p_booking_id;
  if v_cleaning > 0 and v_end < now() + make_interval(mins => v_cleaning) then
    insert into public.room_occupancy (room_id, lodging_id, kind, period)
    values (v_booking.room_id, v_booking.lodging_id, 'cleaning',
            tstzrange(v_end, now() + make_interval(mins => v_cleaning), '[)'));
  end if;
  perform private.log_booking(p_booking_id, 'checked_in', 'completed', 'salida registrada por recepción');
end;
$$;

comment on function public.host_check_out(uuid) is 'Recepción registra la salida: la estadía se cierra y el cuarto pasa a limpieza.';
revoke all on function public.host_check_out(uuid) from public, anon;
grant execute on function public.host_check_out(uuid) to authenticated;

-- El cuarto queda libre desde ya: termina su limpieza (o la limpieza que
-- queda de una reserva terminada).
create function public.host_mark_clean(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lodging_id uuid;
begin
  select lodging_id into v_lodging_id from public.rooms where id = p_room_id;
  if not found then
    raise exception 'room_not_found' using errcode = 'P0002';
  end if;
  perform private.require_staff(v_lodging_id);

  delete from public.room_occupancy
   where room_id = p_room_id and kind = 'cleaning' and lower(period) >= now();
  update public.room_occupancy
     set period = tstzrange(lower(period), now(), '[)')
   where room_id = p_room_id and kind = 'cleaning' and period @> now();
  -- Una reserva que ya terminó pero cuyo periodo incluía la limpieza.
  update public.room_occupancy o
     set period = tstzrange(lower(o.period), now(), '[)')
    from public.bookings b
   where o.booking_id = b.id and o.room_id = p_room_id
     and o.period @> now() and now() >= b.departure_at
     and b.status in ('completed', 'checked_in');
end;
$$;

comment on function public.host_mark_clean(uuid) is 'Recepción marca un cuarto limpio: queda libre desde ya.';
revoke all on function public.host_mark_clean(uuid) from public, anon;
grant execute on function public.host_mark_clean(uuid) to authenticated;

-- Cliente directo (con su limpieza al final) o fuera de servicio.
create function public.host_block_room(p_room_id uuid, p_kind text, p_minutes integer)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms;
  v_cleaning smallint;
  v_id uuid;
begin
  select * into v_room from public.rooms where id = p_room_id;
  if not found then
    raise exception 'room_not_found' using errcode = 'P0002';
  end if;
  perform private.require_staff(v_room.lodging_id);
  if p_kind not in ('walk_in', 'maintenance') then
    raise exception 'invalid_kind' using errcode = '22023';
  end if;
  if p_minutes is null or p_minutes < 15 or p_minutes > 24 * 60 then
    raise exception 'invalid_duration' using errcode = '22023';
  end if;
  select cleaning_minutes into v_cleaning from public.lodgings where id = v_room.lodging_id;

  insert into public.room_occupancy (room_id, lodging_id, kind, period)
  values (p_room_id, v_room.lodging_id, p_kind,
          tstzrange(now(), now() + make_interval(mins => p_minutes
            + case when p_kind = 'walk_in' then v_cleaning else 0 end), '[)'))
  returning id into v_id;
  return v_id;
exception
  when exclusion_violation then
    -- Una reserva de la app ya tiene el cuarto en ese rango.
    raise exception 'room_not_free' using errcode = '55000';
end;
$$;

comment on function public.host_block_room(uuid, text, integer) is
  'Recepción ocupa un cuarto para un cliente directo o lo saca de servicio. No pisa reservas de la app.';
revoke all on function public.host_block_room(uuid, text, integer) from public, anon;
grant execute on function public.host_block_room(uuid, text, integer) to authenticated;

create function public.host_release_block(p_occupancy_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_occ public.room_occupancy;
begin
  select * into v_occ from public.room_occupancy where id = p_occupancy_id for update;
  if not found or v_occ.kind not in ('walk_in', 'maintenance', 'cleaning') then
    raise exception 'block_not_found' using errcode = 'P0002';
  end if;
  perform private.require_staff(v_occ.lodging_id);
  if lower(v_occ.period) >= now() then
    delete from public.room_occupancy where id = p_occupancy_id;
  else
    update public.room_occupancy set period = tstzrange(lower(period), now(), '[)')
     where id = p_occupancy_id;
  end if;
end;
$$;

comment on function public.host_release_block(uuid) is 'Recepción libera un cuarto ocupado por un cliente directo, mantenimiento o limpieza.';
revoke all on function public.host_release_block(uuid) from public, anon;
grant execute on function public.host_release_block(uuid) to authenticated;

-- ───────────────────────────────────────────────────────────────── extras
create function public.host_set_item_status(p_item_id uuid, p_status text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.booking_items;
  v_booking public.bookings;
  v_refund integer := 0;
begin
  select * into v_item from public.booking_items where id = p_item_id for update;
  if not found then
    raise exception 'item_not_found' using errcode = 'P0002';
  end if;
  select * into v_booking from public.bookings where id = v_item.booking_id;
  perform private.require_staff(v_booking.lodging_id);
  if p_status not in ('ready', 'unavailable') then
    raise exception 'invalid_status' using errcode = '22023';
  end if;
  if v_item.status <> 'pending' then
    raise exception 'item_already_set' using errcode = '55000';
  end if;
  if v_booking.status not in ('confirmed', 'checked_in') then
    raise exception 'invalid_status' using errcode = '55000';
  end if;

  update public.booking_items set status = p_status where id = p_item_id;
  if p_status = 'unavailable' then
    v_refund := private.add_refund(v_booking.id, v_item.unit_price_cents * v_item.quantity,
                                   'extra no disponible: ' || v_item.name, v_item.id);
  end if;
  return jsonb_build_object('status', p_status, 'refund_cents', v_refund);
end;
$$;

comment on function public.host_set_item_status(uuid, text) is
  'Recepción marca un extra listo en el cuarto o no disponible; si no está, se reembolsa.';
revoke all on function public.host_set_item_status(uuid, text) from public, anon;
grant execute on function public.host_set_item_status(uuid, text) to authenticated;

-- ───────────────────────────────────────────── cancelación del hostal
create function public.host_cancel_booking(p_booking_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_refund integer;
begin
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'booking_not_found' using errcode = 'P0002';
  end if;
  if not (private.is_lodging_owner(v_booking.lodging_id) or private.is_admin()) then
    raise exception 'not_owner' using errcode = '42501';
  end if;
  if v_reason = '' then
    raise exception 'reason_required' using errcode = '23514';
  end if;
  if v_booking.status <> 'confirmed' then
    raise exception 'invalid_status' using errcode = '55000';
  end if;

  update public.bookings
     set status = 'cancelled', cancelled_at = now(), cancel_reason = left(v_reason, 300)
   where id = p_booking_id;
  delete from public.room_occupancy where booking_id = p_booking_id;
  -- Si cancela el hostal, el reembolso es total (sección 6.6).
  v_refund := private.add_refund(p_booking_id, v_booking.total_cents, 'cancelada por el hostal: ' || v_reason);
  perform private.log_booking(p_booking_id, 'confirmed', 'cancelled', 'cancelada por el hostal: ' || v_reason);
  return jsonb_build_object('status', 'cancelled', 'refund_cents', v_refund);
end;
$$;

comment on function public.host_cancel_booking(uuid, text) is
  'El dueño (o un administrador) cancela una reserva confirmada con motivo; el reembolso es total.';
revoke all on function public.host_cancel_booking(uuid, text) from public, anon;
grant execute on function public.host_cancel_booking(uuid, text) to authenticated;

-- ──────────────────────────────────────────────────────────────── personal
create table public.lodging_invites (
  id uuid primary key default gen_random_uuid(),
  lodging_id uuid not null references public.lodgings (id) on delete cascade,
  -- Código que el dueño comparte con su recepcionista.
  code text not null unique check (code ~ '^[A-Z0-9]{8}$'),
  created_by uuid not null references auth.users (id),
  expires_at timestamptz not null,
  accepted_by uuid references auth.users (id),
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.lodging_invites is
  'Invitaciones de personal. Solo se modifican por funciones del servidor.';

alter table public.lodging_invites enable row level security;
revoke all on table public.lodging_invites from public, anon, authenticated;
grant select on table public.lodging_invites to authenticated;
create policy lodging_invites_select_owner on public.lodging_invites for select to authenticated
  using ((select private.is_lodging_owner(lodging_id)) or (select private.is_admin()));

create function public.invite_staff(p_lodging_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_alphabet constant text := 'ACDEFGHJKMNPQRTUVWXY34679';
  v_code text;
  v_bytes bytea;
  v_invite public.lodging_invites;
begin
  if not private.is_lodging_owner(p_lodging_id) then
    raise exception 'not_owner' using errcode = '42501';
  end if;
  if (select count(*) from public.lodging_invites
       where lodging_id = p_lodging_id and accepted_at is null and revoked_at is null
         and expires_at > now()) >= 5 then
    raise exception 'too_many_invites' using errcode = '54000';
  end if;
  loop
    v_bytes := extensions.gen_random_bytes(8);
    v_code := '';
    for i in 0..7 loop
      v_code := v_code || substr(v_alphabet, 1 + get_byte(v_bytes, i) % length(v_alphabet), 1);
    end loop;
    exit when not exists (select 1 from public.lodging_invites where code = v_code);
  end loop;
  insert into public.lodging_invites (lodging_id, code, created_by, expires_at)
  values (p_lodging_id, v_code, (select auth.uid()),
          now() + make_interval(hours => coalesce((private.setting('invite_valid_hours'))::integer, 48)))
  returning * into v_invite;
  return jsonb_build_object('invite_id', v_invite.id, 'code', v_invite.code,
                            'expires_at', v_invite.expires_at);
end;
$$;

comment on function public.invite_staff(uuid) is 'El dueño crea un código para que alguien se una como recepcionista.';
revoke all on function public.invite_staff(uuid) from public, anon;
grant execute on function public.invite_staff(uuid) to authenticated;

create function public.accept_invite(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_invite public.lodging_invites;
  v_profile public.profiles;
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

  select * into v_invite from public.lodging_invites
   where code = upper(btrim(coalesce(p_code, ''))) for update;
  if not found or v_invite.revoked_at is not null or v_invite.accepted_at is not null
     or v_invite.expires_at <= now() then
    raise exception 'invite_not_valid' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.lodging_members
              where lodging_id = v_invite.lodging_id and user_id = v_user_id) then
    raise exception 'already_member' using errcode = '55000';
  end if;

  insert into public.lodging_members (lodging_id, user_id, role)
  values (v_invite.lodging_id, v_user_id, 'receptionist');
  update public.lodging_invites set accepted_by = v_user_id, accepted_at = now()
   where id = v_invite.id;
  return jsonb_build_object('lodging_id', v_invite.lodging_id,
                            'lodging_name', (select name from public.lodgings where id = v_invite.lodging_id));
end;
$$;

comment on function public.accept_invite(text) is 'Una cuenta se une como recepcionista con el código que le dio el dueño.';
revoke all on function public.accept_invite(text) from public, anon;
grant execute on function public.accept_invite(text) to authenticated;

create function public.revoke_staff(p_lodging_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_lodging_owner(p_lodging_id) then
    raise exception 'not_owner' using errcode = '42501';
  end if;
  delete from public.lodging_members
   where lodging_id = p_lodging_id and user_id = p_user_id and role = 'receptionist';
  if not found then
    raise exception 'member_not_found' using errcode = 'P0002';
  end if;
end;
$$;

comment on function public.revoke_staff(uuid, uuid) is 'El dueño retira a un recepcionista. Al dueño no se le puede retirar.';
revoke all on function public.revoke_staff(uuid, uuid) from public, anon;
grant execute on function public.revoke_staff(uuid, uuid) to authenticated;

-- Personal de un hostal con su nombre, para el dueño.
create function public.lodging_staff(p_lodging_id uuid)
returns table (user_id uuid, full_name text, role text, since timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_lodging_owner(p_lodging_id) then
    raise exception 'not_owner' using errcode = '42501';
  end if;
  return query
  select m.user_id, coalesce(nullif(p.full_name, ''), 'Sin nombre'), m.role, m.created_at
    from public.lodging_members m
    join public.profiles p on p.id = m.user_id
   where m.lodging_id = p_lodging_id
   order by m.role, m.created_at;
end;
$$;
revoke all on function public.lodging_staff(uuid) from public, anon;
grant execute on function public.lodging_staff(uuid) to authenticated;

-- ───────────────────────────────────────────── tareas automáticas
-- "No llegó" a los 30 minutos y salida automática al terminar el tiempo.
create function private.run_stay_transitions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
  v_booking record;
  v_wait integer := coalesce((private.setting('no_show_minutes'))::integer, 30);
begin
  for v_booking in
    select b.id from public.bookings b
     where b.status = 'confirmed'
       and now() > b.arrival_at + make_interval(mins => v_wait)
     for update skip locked
  loop
    update public.bookings set status = 'no_show' where id = v_booking.id;
    -- El cuarto se libera desde ya.
    update public.room_occupancy set period = tstzrange(lower(period), greatest(now(), lower(period) + interval '1 second'), '[)')
     where booking_id = v_booking.id;
    perform private.log_booking(v_booking.id, 'confirmed', 'no_show', 'no llegó a tiempo');
    v_count := v_count + 1;
  end loop;

  for v_booking in
    select b.id from public.bookings b
     where b.status = 'checked_in' and now() >= b.departure_at
     for update skip locked
  loop
    -- La ocupación ya incluye la limpieza: queda como estaba.
    update public.bookings set status = 'completed', checked_out_at = now() where id = v_booking.id;
    perform private.log_booking(v_booking.id, 'checked_in', 'completed', 'salida automática');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke all on function private.run_stay_transitions() from public, anon, authenticated;

select cron.schedule('stay-transitions', '* * * * *', $$select private.run_stay_transitions()$$);
