-- Al Paso — reservas y pago demo (etapa 4, parte 4A)
--
-- Qué crea:
--   · public.bookings, booking_items, booking_events   la reserva, sus extras y su historial
--   · public.payments, payment_events, refunds         cobros, avisos del conector y reembolsos
--   · public.get_quote()            precio de cuarto + extras, calculado por el servidor
--   · public.create_booking()       reserva con retención de 10 minutos, todo o nada
--   · public.start_payment()        abre el cobro en el conector activo
--   · public.demo_gateway_complete()  la pasarela demo: aprueba o rechaza (solo en demo)
--   · public.cancel_booking()       el cliente cancela según las reglas de reembolso
--   · tarea automática: vence cada minuto las retenciones sin pagar
--
-- Reglas que este archivo deja fijas (docs/ESTRUCTURA.md, secciones 6.3 a 6.8):
--   · La app nunca envía precios: el servidor los calcula y la reserva guarda
--     una copia de lo cobrado.
--   · Solo el aviso del conector confirma una reserva. Un aviso repetido no
--     cobra ni confirma dos veces.
--   · Una reserva nunca se borra: cambia de estado y queda su historial.
--   · El conector demo solo funciona con payments_provider = 'demo'.

create extension if not exists pgcrypto with schema extensions;

insert into private.app_settings (key, value, is_public, description) values
  ('hold_minutes', '10', true,
   'Minutos que se retiene el cuarto mientras se paga.'),
  ('max_pending_bookings', '1', false,
   'Reservas sin pagar que puede tener una cuenta a la vez.'),
  ('refund_full_hours_before', '1', true,
   'Hasta cuántas horas antes de la llegada se reembolsa todo al cancelar.'),
  ('refund_grace_minutes', '5', true,
   'Minutos de gracia para cancelar con reembolso una reserva para dentro de menos de esas horas.'),
  ('max_items_per_booking', '20', false,
   'Unidades de extras como máximo por reserva.');

-- ───────────────────────────────────────────────────────────────── reservas
create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  -- Código corto que el cliente muestra en recepción.
  code text not null unique check (code ~ '^[A-Z0-9]{6}$'),
  customer_id uuid not null references auth.users (id),
  lodging_id uuid not null references public.lodgings (id),
  room_type_id uuid not null references public.room_types (id),
  room_id uuid not null references public.rooms (id),
  block_hours smallint not null,
  arrival_at timestamptz not null,
  departure_at timestamptz not null,
  status text not null default 'pending_payment' check (status in (
    'pending_payment', 'confirmed', 'checked_in', 'completed',
    'cancelled', 'expired', 'no_show')),
  -- Copia de lo cobrado, en céntimos. No cambia si el hostal cambia precios.
  room_price_cents integer not null check (room_price_cents > 0),
  extras_cents integer not null default 0 check (extras_cents >= 0),
  total_cents integer not null check (total_cents = room_price_cents + extras_cents),
  hold_expires_at timestamptz,
  paid_at timestamptz,
  cancelled_at timestamptz,
  cancel_reason text not null default '' check (char_length(cancel_reason) <= 300),
  -- Para que reintentar no cree dos reservas.
  idempotency_key uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (departure_at > arrival_at),
  unique (customer_id, idempotency_key)
);

comment on table public.bookings is
  'Reservas. Solo cambian por funciones del servidor; nunca se borran.';

create index bookings_customer_idx on public.bookings (customer_id, arrival_at desc);
create index bookings_lodging_idx on public.bookings (lodging_id, arrival_at);
create index bookings_pending_idx on public.bookings (hold_expires_at)
  where status = 'pending_payment';

create trigger bookings_set_updated_at
  before update on public.bookings
  for each row execute function private.set_updated_at();

-- La ocupación de una reserva apunta a ella, para liberarla al cancelar.
alter table public.room_occupancy
  add column booking_id uuid references public.bookings (id);
create unique index room_occupancy_booking_idx on public.room_occupancy (booking_id)
  where booking_id is not null;

create table public.booking_items (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id),
  product_id uuid not null references public.products (id),
  -- Copia del nombre y del precio del momento.
  name text not null,
  unit_price_cents integer not null check (unit_price_cents > 0),
  quantity smallint not null check (quantity between 1 and 10),
  status text not null default 'pending'
    check (status in ('pending', 'ready', 'unavailable')),
  unique (booking_id, product_id)
);

comment on table public.booking_items is 'Extras pedidos, con el precio del momento.';

create table public.booking_events (
  id bigint generated always as identity primary key,
  booking_id uuid not null references public.bookings (id),
  from_status text,
  to_status text not null,
  actor_id uuid,
  note text not null default '',
  created_at timestamptz not null default now()
);

comment on table public.booking_events is 'Historial de cambios de estado de cada reserva.';
create index booking_events_booking_idx on public.booking_events (booking_id, id);

-- ──────────────────────────────────────────────────────────────────── dinero
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id),
  provider text not null,
  status text not null default 'pending'
    check (status in ('created', 'pending', 'paid', 'failed', 'refunded')),
  amount_cents integer not null check (amount_cents > 0),
  provider_ref text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.payments is 'Cobros. Solo los cambia el aviso del conector.';
create index payments_booking_idx on public.payments (booking_id);
-- Un solo cobro abierto o pagado por reserva.
create unique index payments_one_active_idx on public.payments (booking_id)
  where status in ('pending', 'paid');

create trigger payments_set_updated_at
  before update on public.payments
  for each row execute function private.set_updated_at();

create table public.payment_events (
  id bigint generated always as identity primary key,
  payment_id uuid not null references public.payments (id),
  -- Identificador del aviso según el conector: el mismo aviso dos veces se
  -- aplica una sola vez.
  provider_event_id text not null unique,
  result text not null check (result in ('paid', 'failed')),
  payload jsonb not null default '{}',
  received_at timestamptz not null default now()
);

comment on table public.payment_events is 'Avisos del conector de pagos, cada uno aplicado una sola vez.';

create table public.refunds (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id),
  payment_id uuid not null references public.payments (id),
  amount_cents integer not null check (amount_cents > 0),
  status text not null default 'pending' check (status in ('pending', 'processed')),
  reason text not null default '',
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (payment_id)
);

comment on table public.refunds is 'Reembolsos. Un cobro se reembolsa una sola vez, completo.';

-- ────────────────────────────────────────────────────────────────── permisos
alter table public.bookings enable row level security;
alter table public.booking_items enable row level security;
alter table public.booking_events enable row level security;
alter table public.payments enable row level security;
alter table public.payment_events enable row level security;
alter table public.refunds enable row level security;

revoke all on table public.bookings, public.booking_items, public.booking_events,
  public.payments, public.payment_events, public.refunds
  from public, anon, authenticated;

grant select on table public.bookings, public.booking_items, public.booking_events,
  public.payments, public.refunds to authenticated;

-- El cliente ve lo suyo; el personal, las reservas de su hostal; el admin, todo.
create policy bookings_select
  on public.bookings for select to authenticated
  using (customer_id = (select auth.uid())
         or (select private.is_lodging_member(lodging_id))
         or (select private.is_admin()));

create function private.can_see_booking(p_booking_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.bookings b
     where b.id = p_booking_id
       and (b.customer_id = (select auth.uid())
            or private.is_lodging_member(b.lodging_id)
            or private.is_admin())
  );
$$;
revoke all on function private.can_see_booking(uuid) from public, anon;
grant execute on function private.can_see_booking(uuid) to authenticated;

create function private.is_booking_customer(p_booking_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.bookings b
     where b.id = p_booking_id and b.customer_id = (select auth.uid())
  ) or private.is_admin();
$$;
revoke all on function private.is_booking_customer(uuid) from public, anon;
grant execute on function private.is_booking_customer(uuid) to authenticated;

create policy booking_items_select on public.booking_items for select to authenticated
  using ((select private.can_see_booking(booking_id)));
create policy booking_events_select on public.booking_events for select to authenticated
  using ((select private.can_see_booking(booking_id)));
-- El dinero lo ven el cliente y el admin, no el personal del hostal.
create policy payments_select on public.payments for select to authenticated
  using ((select private.is_booking_customer(booking_id)));
create policy refunds_select on public.refunds for select to authenticated
  using ((select private.is_booking_customer(booking_id)));

-- ───────────────────────────────────────────────────────────── auxiliares
create function private.log_booking(
  p_booking_id uuid, p_from text, p_to text, p_note text default ''
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.booking_events (booking_id, from_status, to_status, actor_id, note)
  values (p_booking_id, p_from, p_to, (select auth.uid()), coalesce(p_note, ''));
$$;
revoke all on function private.log_booking(uuid, text, text, text) from public, anon, authenticated;

-- Código de 6 caracteres sin letras que se confundan (O/0, I/1, S/5…).
create function private.new_booking_code()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_alphabet constant text := 'ACDEFGHJKMNPQRTUVWXY34679';
  v_code text;
  v_bytes bytea;
begin
  loop
    v_bytes := extensions.gen_random_bytes(6);
    v_code := '';
    for i in 0..5 loop
      v_code := v_code || substr(v_alphabet, 1 + get_byte(v_bytes, i) % length(v_alphabet), 1);
    end loop;
    exit when not exists (select 1 from public.bookings b where b.code = v_code);
  end loop;
  return v_code;
end;
$$;
revoke all on function private.new_booking_code() from public, anon, authenticated;

-- Vence las reservas sin pagar cuya retención pasó y libera sus cuartos.
create function private.expire_pending_bookings()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
  v_booking record;
begin
  for v_booking in
    select b.id from public.bookings b
     where b.status = 'pending_payment' and b.hold_expires_at < now()
     for update skip locked
  loop
    update public.bookings set status = 'expired' where id = v_booking.id;
    delete from public.room_occupancy where booking_id = v_booking.id;
    update public.payments set status = 'failed'
     where booking_id = v_booking.id and status = 'pending';
    perform private.log_booking(v_booking.id, 'pending_payment', 'expired', 'retención vencida');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke all on function private.expire_pending_bookings() from public, anon, authenticated;

-- ─────────────────────────────────────────────────────────────── cotización
-- Precio de cuarto y extras con las tarifas vigentes. La app lo muestra; al
-- reservar, el servidor lo vuelve a calcular.
create function private.compute_quote(
  p_room_type_id uuid,
  p_block_hours integer,
  p_items jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_lodging_id uuid;
  v_room_price integer;
  v_extras jsonb := '[]'::jsonb;
  v_extras_cents integer := 0;
  v_units integer := 0;
  v_item record;
begin
  select t.lodging_id, r.price_cents into v_lodging_id, v_room_price
    from public.room_types t
    join public.lodgings l on l.id = t.lodging_id and l.status = 'published'
    join public.rates r on r.room_type_id = t.id and r.block_hours = p_block_hours
   where t.id = p_room_type_id and t.is_active;
  if not found then
    raise exception 'room_type_not_bookable' using errcode = 'P0002';
  end if;

  if jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' then
    raise exception 'invalid_items' using errcode = '22023';
  end if;

  for v_item in
    select p.id, p.name, p.price_cents, x.quantity
      from jsonb_to_recordset(coalesce(p_items, '[]'::jsonb))
           as x(product_id uuid, quantity integer)
      left join public.products p
        on p.id = x.product_id and p.lodging_id = v_lodging_id and p.is_available
  loop
    if v_item.id is null then
      raise exception 'product_not_available' using errcode = 'P0002';
    end if;
    if v_item.quantity is null or v_item.quantity < 1 or v_item.quantity > 10 then
      raise exception 'invalid_quantity' using errcode = '22023';
    end if;
    v_units := v_units + v_item.quantity;
    v_extras_cents := v_extras_cents + v_item.price_cents * v_item.quantity;
    v_extras := v_extras || jsonb_build_object(
      'product_id', v_item.id, 'name', v_item.name,
      'unit_price_cents', v_item.price_cents, 'quantity', v_item.quantity,
      'subtotal_cents', v_item.price_cents * v_item.quantity);
  end loop;

  if v_units > coalesce((private.setting('max_items_per_booking'))::integer, 20) then
    raise exception 'too_many_items' using errcode = '22023';
  end if;
  if (select count(*) from jsonb_array_elements(coalesce(p_items, '[]'::jsonb))) <>
     (select count(distinct e ->> 'product_id') from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e) then
    raise exception 'duplicate_items' using errcode = '22023';
  end if;

  return jsonb_build_object(
    'lodging_id', v_lodging_id,
    'room_price_cents', v_room_price,
    'extras', v_extras,
    'extras_cents', v_extras_cents,
    'total_cents', v_room_price + v_extras_cents);
end;
$$;
revoke all on function private.compute_quote(uuid, integer, jsonb) from public, anon, authenticated;

create function public.get_quote(
  p_room_type_id uuid,
  p_arrival timestamptz,
  p_block_hours integer,
  p_items jsonb default '[]'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.check_search_window(p_arrival, p_block_hours);
  return private.compute_quote(p_room_type_id, p_block_hours, p_items);
end;
$$;

comment on function public.get_quote(uuid, timestamptz, integer, jsonb) is
  'Total de cuarto más extras con las tarifas vigentes. Lo calcula el servidor.';
revoke all on function public.get_quote(uuid, timestamptz, integer, jsonb) from public;
grant execute on function public.get_quote(uuid, timestamptz, integer, jsonb) to anon, authenticated;

-- ────────────────────────────────────────────────────────────────── reservar
create function public.create_booking(
  p_room_type_id uuid,
  p_arrival timestamptz,
  p_block_hours integer,
  p_items jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_profile public.profiles;
  v_existing public.bookings;
  v_quote jsonb;
  v_lodging public.lodgings;
  v_period tstzrange;
  v_room_id uuid;
  v_booking public.bookings;
  v_hold_minutes integer := coalesce((private.setting('hold_minutes'))::integer, 10);
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_idempotency_key is null then
    raise exception 'idempotency_key_required' using errcode = '22023';
  end if;

  -- Reintento: la misma reserva, sin crear otra.
  select * into v_existing from public.bookings
   where customer_id = v_user_id and idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object('booking_id', v_existing.id, 'code', v_existing.code,
                              'status', v_existing.status, 'total_cents', v_existing.total_cents,
                              'hold_expires_at', v_existing.hold_expires_at);
  end if;

  select * into v_profile from public.profiles where id = v_user_id;
  if v_profile.is_blocked then
    raise exception 'account_blocked' using errcode = '42501';
  end if;
  if v_profile.adult_confirmed_at is null then
    raise exception 'adult_not_confirmed' using errcode = '42501';
  end if;

  perform private.check_search_window(p_arrival, p_block_hours);
  perform private.expire_pending_bookings();

  if (select count(*) from public.bookings
       where customer_id = v_user_id and status = 'pending_payment')
     >= coalesce((private.setting('max_pending_bookings'))::integer, 1) then
    raise exception 'pending_booking_exists' using errcode = '55000';
  end if;

  v_quote := private.compute_quote(p_room_type_id, p_block_hours, p_items);
  select * into v_lodging from public.lodgings where id = (v_quote ->> 'lodging_id')::uuid;

  -- Una reserva a la vez por tipo de cuarto: dos personas no se llevan el
  -- mismo cuarto aunque lleguen en el mismo instante.
  perform 1 from public.room_types where id = p_room_type_id for update;

  v_period := tstzrange(
    p_arrival,
    p_arrival + make_interval(hours => p_block_hours, mins => v_lodging.cleaning_minutes),
    '[)');

  select u.id into v_room_id
    from public.rooms u
   where u.room_type_id = p_room_type_id and u.is_active
     and private.room_is_free(u.id, v_period)
   order by u.label
   limit 1;
  if v_room_id is null then
    raise exception 'no_room_available' using errcode = '55000';
  end if;

  -- Retenciones vencidas de otros que todavía estén en ese cuarto.
  delete from public.room_occupancy o
   where o.room_id = v_room_id and o.kind = 'hold' and o.expires_at <= now()
     and o.period && v_period;

  insert into public.bookings (
    code, customer_id, lodging_id, room_type_id, room_id, block_hours,
    arrival_at, departure_at, room_price_cents, extras_cents, total_cents,
    hold_expires_at, idempotency_key
  ) values (
    private.new_booking_code(), v_user_id, v_lodging.id, p_room_type_id, v_room_id,
    p_block_hours, p_arrival, p_arrival + make_interval(hours => p_block_hours),
    (v_quote ->> 'room_price_cents')::integer, (v_quote ->> 'extras_cents')::integer,
    (v_quote ->> 'total_cents')::integer,
    now() + make_interval(mins => v_hold_minutes), p_idempotency_key
  )
  returning * into v_booking;

  insert into public.booking_items (booking_id, product_id, name, unit_price_cents, quantity)
  select v_booking.id, (e ->> 'product_id')::uuid, e ->> 'name',
         (e ->> 'unit_price_cents')::integer, (e ->> 'quantity')::smallint
    from jsonb_array_elements(v_quote -> 'extras') e;

  -- La restricción de exclusión es la última garantía contra cruces.
  insert into public.room_occupancy (room_id, lodging_id, kind, period, expires_at, booking_id)
  values (v_room_id, v_lodging.id, 'hold', v_period, v_booking.hold_expires_at, v_booking.id);

  perform private.log_booking(v_booking.id, null, 'pending_payment', '');

  return jsonb_build_object('booking_id', v_booking.id, 'code', v_booking.code,
                            'status', v_booking.status, 'total_cents', v_booking.total_cents,
                            'hold_expires_at', v_booking.hold_expires_at);
exception
  when exclusion_violation then
    raise exception 'no_room_available' using errcode = '55000';
end;
$$;

comment on function public.create_booking(uuid, timestamptz, integer, jsonb, uuid) is
  'Reserva en una transacción: revalida, asigna cuarto, calcula precio y retiene el cuarto mientras se paga.';
revoke all on function public.create_booking(uuid, timestamptz, integer, jsonb, uuid) from public, anon;
grant execute on function public.create_booking(uuid, timestamptz, integer, jsonb, uuid) to authenticated;

-- ──────────────────────────────────────────────────────────────────── pagos
create function public.start_payment(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_payment public.payments;
  v_provider text := coalesce(private.setting('payments_provider') #>> '{}', 'demo');
begin
  perform private.expire_pending_bookings();
  select * into v_booking from public.bookings
   where id = p_booking_id and customer_id = (select auth.uid())
   for update;
  if not found then
    raise exception 'booking_not_found' using errcode = 'P0002';
  end if;
  if v_booking.status <> 'pending_payment' then
    raise exception 'invalid_status' using errcode = '55000';
  end if;

  select * into v_payment from public.payments
   where booking_id = p_booking_id and status = 'pending';
  if not found then
    insert into public.payments (booking_id, provider, status, amount_cents)
    values (p_booking_id, v_provider, 'pending', v_booking.total_cents)
    returning * into v_payment;
  end if;

  return jsonb_build_object('payment_id', v_payment.id, 'provider', v_payment.provider,
                            'amount_cents', v_payment.amount_cents,
                            'hold_expires_at', v_booking.hold_expires_at);
end;
$$;

comment on function public.start_payment(uuid) is
  'Abre (o reanuda) el cobro de una reserva sin pagar en el conector activo.';
revoke all on function public.start_payment(uuid) from public, anon;
grant execute on function public.start_payment(uuid) to authenticated;

-- Aplica un aviso del conector. Es lo único que confirma una reserva. El
-- mismo aviso dos veces se aplica una sola vez. Lo usan la pasarela demo y,
-- en la etapa 8, el webhook de la pasarela real.
create function private.apply_payment_event(
  p_payment_id uuid,
  p_provider_event_id text,
  p_paid boolean,
  p_payload jsonb default '{}'
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payment public.payments;
  v_booking public.bookings;
begin
  insert into public.payment_events (payment_id, provider_event_id, result, payload)
  values (p_payment_id, p_provider_event_id, case when p_paid then 'paid' else 'failed' end,
          coalesce(p_payload, '{}'))
  on conflict (provider_event_id) do nothing;
  if not found then
    -- Aviso repetido: no se vuelve a aplicar.
    select status into v_payment.status from public.payments where id = p_payment_id;
    return v_payment.status;
  end if;

  select * into v_payment from public.payments where id = p_payment_id for update;

  if not p_paid then
    if v_payment.status = 'pending' then
      update public.payments set status = 'failed' where id = p_payment_id;
    end if;
    return (select status from public.payments where id = p_payment_id);
  end if;

  -- Ya contado: no se cobra dos veces.
  if v_payment.status in ('paid', 'refunded') then
    return v_payment.status;
  end if;

  -- Desde aquí el dinero llegó. Si el cobro ya se había cerrado (la reserva
  -- venció o se canceló mientras se pagaba), se devuelve más abajo.
  select * into v_booking from public.bookings where id = v_payment.booking_id for update;

  update public.payments set status = 'paid' where id = p_payment_id;

  if v_payment.status = 'pending' and v_booking.status = 'pending_payment' and exists (
       select 1 from public.room_occupancy o where o.booking_id = v_booking.id) then
    update public.bookings
       set status = 'confirmed', paid_at = now(), hold_expires_at = null
     where id = v_booking.id;
    update public.room_occupancy set kind = 'booking', expires_at = null
     where booking_id = v_booking.id;
    perform private.log_booking(v_booking.id, 'pending_payment', 'confirmed', 'pago aprobado');
    return 'paid';
  end if;

  -- Llegó el pago de una reserva que ya venció o se canceló: se devuelve.
  insert into public.refunds (booking_id, payment_id, amount_cents, status, reason, processed_at)
  values (v_booking.id, p_payment_id, v_payment.amount_cents,
          case when v_payment.provider = 'demo' then 'processed' else 'pending' end,
          'pago tardío de una reserva ' || v_booking.status,
          case when v_payment.provider = 'demo' then now() end);
  update public.payments set status = 'refunded' where id = p_payment_id;
  return 'refunded';
end;
$$;
revoke all on function private.apply_payment_event(uuid, text, boolean, jsonb) from public, anon, authenticated;

-- La pasarela demo. Simula el aviso de la pasarela real. Solo existe cuando
-- el conector de pagos es demo; la app la muestra con el rótulo DEMO.
create function public.demo_gateway_complete(p_payment_id uuid, p_approved boolean)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(private.setting('payments_provider') #>> '{}', '') <> 'demo' then
    raise exception 'demo_gateway_disabled' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.payments p
      join public.bookings b on b.id = p.booking_id
     where p.id = p_payment_id and p.provider = 'demo'
       and b.customer_id = (select auth.uid())) then
    raise exception 'payment_not_found' using errcode = 'P0002';
  end if;
  return private.apply_payment_event(
    p_payment_id, 'demo:' || p_payment_id::text, p_approved,
    jsonb_build_object('approved', p_approved));
end;
$$;

comment on function public.demo_gateway_complete(uuid, boolean) is
  'Pasarela demo: aprueba o rechaza un cobro. Solo funciona con el conector de pagos en demo.';
revoke all on function public.demo_gateway_complete(uuid, boolean) from public, anon;
grant execute on function public.demo_gateway_complete(uuid, boolean) to authenticated;

-- ──────────────────────────────────────────────────────────────── cancelar
create function public.cancel_booking(p_booking_id uuid, p_reason text default '')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_payment public.payments;
  v_hours integer := coalesce((private.setting('refund_full_hours_before'))::integer, 1);
  v_grace integer := coalesce((private.setting('refund_grace_minutes'))::integer, 5);
  v_refund boolean;
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

  -- Reembolso total hasta 1 hora antes de la llegada. Si se reservó para
  -- dentro de menos de 1 hora, 5 minutos de gracia desde el pago.
  v_refund := now() <= v_booking.arrival_at - make_interval(hours => v_hours)
    or (v_booking.paid_at > v_booking.arrival_at - make_interval(hours => v_hours)
        and now() <= v_booking.paid_at + make_interval(mins => v_grace));
  if not v_refund then
    -- Fuera de plazo no se cancela desde la app: queda la vía de soporte.
    raise exception 'cancel_window_closed' using errcode = '55000';
  end if;

  select * into v_payment from public.payments
   where booking_id = p_booking_id and status = 'paid' for update;

  update public.bookings
     set status = 'cancelled', cancelled_at = now(), cancel_reason = left(coalesce(p_reason, ''), 300)
   where id = p_booking_id;
  delete from public.room_occupancy where booking_id = p_booking_id;

  insert into public.refunds (booking_id, payment_id, amount_cents, status, reason, processed_at)
  values (p_booking_id, v_payment.id, v_payment.amount_cents,
          case when v_payment.provider = 'demo' then 'processed' else 'pending' end,
          'cancelada por el cliente',
          case when v_payment.provider = 'demo' then now() end);
  update public.payments set status = 'refunded' where id = v_payment.id;
  perform private.log_booking(p_booking_id, 'confirmed', 'cancelled', 'cancelada por el cliente, con reembolso');

  return jsonb_build_object('status', 'cancelled', 'refund_cents', v_payment.amount_cents);
end;
$$;

comment on function public.cancel_booking(uuid, text) is
  'El cliente cancela su reserva. Reembolso total dentro del plazo; fuera de plazo no se cancela desde la app.';
revoke all on function public.cancel_booking(uuid, text) from public, anon;
grant execute on function public.cancel_booking(uuid, text) to authenticated;

-- ───────────────────────────────────────────────────── tarea automática
-- Cada minuto vence las retenciones sin pagar. Las funciones de reservar y
-- pagar también lo hacen, así que nada depende de que corra a tiempo.
create extension if not exists pg_cron;
select cron.schedule('expire-pending-bookings', '* * * * *',
                     $$select private.expire_pending_bookings()$$);
