-- Reservas y pago demo: precio del servidor, retención, sin doble reserva,
-- un solo cobro, vencimiento, cancelación y permisos.
begin;
select plan(52);

-- ana: dueña. cli: cliente. otro: otro cliente. menor: sin mayoría de edad.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'cli@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'otro@example.test'),
  ('55555555-5555-5555-5555-555555555555', 'menor@example.test');
update public.profiles set adult_confirmed_at = now()
 where id <> '55555555-5555-5555-5555-555555555555';

insert into public.lodgings (id, name, district_id, address, latitude, longitude,
                             cleaning_minutes, status, created_by)
values ('aaaaaaaa-1000-0000-0000-000000000001', 'Hostal Reserva', 21, 'Av. Larco 1',
        -12.1211, -77.0297, 30, 'published', '11111111-1111-1111-1111-111111111111'),
       ('aaaaaaaa-1000-0000-0000-000000000002', 'Hostal Otro', 21, 'Av. Larco 2',
        -12.1212, -77.0298, 30, 'published', '11111111-1111-1111-1111-111111111111');
insert into public.lodging_members (lodging_id, user_id, role)
values ('aaaaaaaa-1000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'owner');

-- Un solo cuarto de tipo Suite: S/ 50 por 4 h.
insert into public.room_types (id, lodging_id, name) values
  ('bbbbbbbb-1000-0000-0000-000000000001', 'aaaaaaaa-1000-0000-0000-000000000001', 'Suite');
insert into public.rates (room_type_id, lodging_id, block_hours, price_cents) values
  ('bbbbbbbb-1000-0000-0000-000000000001', 'aaaaaaaa-1000-0000-0000-000000000001', 4, 5000);
insert into public.rooms (id, lodging_id, room_type_id, label) values
  ('cccccccc-1000-0000-0000-000000000001', 'aaaaaaaa-1000-0000-0000-000000000001',
   'bbbbbbbb-1000-0000-0000-000000000001', '201');
insert into public.products (id, lodging_id, name, category, price_cents, is_available) values
  ('dddddddd-1000-0000-0000-000000000001', 'aaaaaaaa-1000-0000-0000-000000000001', 'Gaseosa', 'drinks', 400, true),
  ('dddddddd-1000-0000-0000-000000000002', 'aaaaaaaa-1000-0000-0000-000000000001', 'Agua', 'drinks', 300, false),
  ('dddddddd-1000-0000-0000-000000000003', 'aaaaaaaa-1000-0000-0000-000000000002', 'Ajena', 'drinks', 100, true);

create temp table t0 (arrival timestamptz) on commit drop;
insert into t0 values (date_trunc('hour', now()) + interval '3 hours');
grant all on t0 to anon, authenticated;
create temp table ids (name text primary key, id uuid) on commit drop;
grant all on ids to authenticated;

create function pg_temp.act_as(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- ── cotización ─────────────────────────────────────────────────────────────
set local role anon;
select is(
  public.get_quote('bbbbbbbb-1000-0000-0000-000000000001', (select arrival from t0), 4,
                   '[{"product_id": "dddddddd-1000-0000-0000-000000000001", "quantity": 2}]') ->> 'total_cents',
  '5800', 'sin sesión se cotiza: S/ 50 del cuarto + 2 gaseosas de S/ 4');
select throws_ok(
  $$ select public.get_quote('bbbbbbbb-1000-0000-0000-000000000001', (select arrival from t0), 4,
       '[{"product_id": "dddddddd-1000-0000-0000-000000000003", "quantity": 1}]') $$,
  'P0002', 'product_not_available', 'un extra de otro hostal no se acepta');
select throws_ok(
  $$ select public.get_quote('bbbbbbbb-1000-0000-0000-000000000001', (select arrival from t0), 4,
       '[{"product_id": "dddddddd-1000-0000-0000-000000000002", "quantity": 1}]') $$,
  'P0002', 'product_not_available', 'un extra agotado no se acepta');
select throws_ok(
  $$ select public.get_quote('bbbbbbbb-1000-0000-0000-000000000001', (select arrival from t0), 4,
       '[{"product_id": "dddddddd-1000-0000-0000-000000000001", "quantity": 11}]') $$,
  '22023', 'invalid_quantity', 'hasta 10 unidades de un extra');
select throws_ok(
  $$ select public.get_quote('bbbbbbbb-1000-0000-0000-000000000001', (select arrival from t0), 4,
       '[{"product_id": "dddddddd-1000-0000-0000-000000000001", "quantity": 1},
         {"product_id": "dddddddd-1000-0000-0000-000000000001", "quantity": 1}]') $$,
  '22023', 'duplicate_items', 'un extra no se repite');
select throws_ok(
  $$ select public.get_quote('bbbbbbbb-1000-0000-0000-000000000001', (select arrival from t0), 12, '[]') $$,
  'P0002', 'room_type_not_bookable', 'un bloque que el cuarto no vende no se cotiza');
select throws_ok(
  $$ select public.create_booking('bbbbbbbb-1000-0000-0000-000000000001', (select arrival from t0), 4, '[]', gen_random_uuid()) $$,
  '42501', null, 'sin sesión no se reserva');
reset role;

-- ── reservar ───────────────────────────────────────────────────────────────
select pg_temp.act_as('55555555-5555-5555-5555-555555555555');
set local role authenticated;
select throws_ok(
  $$ select public.create_booking('bbbbbbbb-1000-0000-0000-000000000001', (select arrival from t0), 4, '[]', gen_random_uuid()) $$,
  '42501', 'adult_not_confirmed', 'sin mayoría de edad confirmada no se reserva');
reset role;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
insert into ids values ('key', 'eeeeeeee-0000-0000-0000-000000000001');
insert into ids
select 'b1', (public.create_booking('bbbbbbbb-1000-0000-0000-000000000001', (select arrival from t0), 4,
  '[{"product_id": "dddddddd-1000-0000-0000-000000000001", "quantity": 2}]',
  (select id from ids where name = 'key')) ->> 'booking_id')::uuid;

select is((select status from public.bookings where id = (select id from ids where name = 'b1')),
  'pending_payment', 'la reserva nace pendiente de pago');
select is((select total_cents from public.bookings where id = (select id from ids where name = 'b1')),
  5800, 'con el total calculado por el servidor');
select ok((select code ~ '^[A-Z0-9]{6}$' from public.bookings where id = (select id from ids where name = 'b1')),
  'y un código de 6 caracteres');
select is((select count(*)::int from public.booking_items where booking_id = (select id from ids where name = 'b1')),
  1, 'guarda el extra con su precio del momento');
select is(
  (public.create_booking('bbbbbbbb-1000-0000-0000-000000000001', (select arrival from t0), 4, '[]',
                          (select id from ids where name = 'key')) ->> 'booking_id')::uuid,
  (select id from ids where name = 'b1'),
  'reintentar con la misma clave devuelve la misma reserva, sin crear otra');
select throws_ok(
  $$ select public.create_booking('bbbbbbbb-1000-0000-0000-000000000001', (select arrival from t0), 4, '[]', gen_random_uuid()) $$,
  '55000', 'pending_booking_exists', 'una cuenta no acumula reservas sin pagar');
select throws_ok(
  $$ insert into public.bookings (code, customer_id, lodging_id, room_type_id, room_id, block_hours,
       arrival_at, departure_at, room_price_cents, total_cents, idempotency_key)
     values ('AAAAAA', '22222222-2222-2222-2222-222222222222', 'aaaaaaaa-1000-0000-0000-000000000001',
       'bbbbbbbb-1000-0000-0000-000000000001', 'cccccccc-1000-0000-0000-000000000001', 4,
       now(), now() + interval '4 hours', 100, 100, gen_random_uuid()) $$,
  '42501', null, 'nadie crea reservas escribiendo la tabla: solo por la función');
reset role;

select is((select kind from public.room_occupancy where booking_id = (select id from ids where name = 'b1')),
  'hold', 'el cuarto queda retenido');
select ok((select expires_at between now() + interval '9 minutes' and now() + interval '11 minutes'
             from public.room_occupancy where booking_id = (select id from ids where name = 'b1')),
  'por 10 minutos');
select is_empty(
  $$ select 1 from public.search_lodgings(-12.1211, -77.0297, (select arrival from t0), 4)
      where lodging_id = 'aaaaaaaa-1000-0000-0000-000000000001' $$,
  'retenido su único cuarto, el hostal sale de la búsqueda');

select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select throws_ok(
  $$ select public.create_booking('bbbbbbbb-1000-0000-0000-000000000001', (select arrival from t0), 4, '[]', gen_random_uuid()) $$,
  '55000', 'no_room_available', 'otra persona no se lleva el mismo cuarto');
select is_empty($$ select 1 from public.bookings where id = (select id from ids where name = 'b1') $$,
  'otra cuenta no ve la reserva ajena');
select throws_ok(
  $$ select public.start_payment((select id from ids where name = 'b1')) $$,
  'P0002', 'booking_not_found', 'ni puede pagarla');
reset role;

-- ── pago demo ──────────────────────────────────────────────────────────────
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
insert into ids select 'p1', (public.start_payment((select id from ids where name = 'b1')) ->> 'payment_id')::uuid;
select is((public.start_payment((select id from ids where name = 'b1')) ->> 'payment_id')::uuid,
  (select id from ids where name = 'p1'), 'abrir el cobro dos veces devuelve el mismo cobro');
select is(public.demo_gateway_complete((select id from ids where name = 'p1'), false), 'failed',
  'la pasarela demo rechaza el pago');
select is((select status from public.bookings where id = (select id from ids where name = 'b1')),
  'pending_payment', 'un pago rechazado no confirma nada');
insert into ids select 'p2', (public.start_payment((select id from ids where name = 'b1')) ->> 'payment_id')::uuid;
select isnt((select id from ids where name = 'p2'), (select id from ids where name = 'p1'),
  'tras un rechazo se abre un cobro nuevo');
select is(public.demo_gateway_complete((select id from ids where name = 'p2'), true), 'paid',
  'la pasarela demo aprueba el pago');
select is((select status from public.bookings where id = (select id from ids where name = 'b1')),
  'confirmed', 'solo entonces la reserva queda confirmada');
select is(public.demo_gateway_complete((select id from ids where name = 'p2'), true), 'paid',
  'el mismo aviso otra vez no cambia nada');
reset role;

select is((select count(*)::int from public.payment_events where payment_id = (select id from ids where name = 'p2')),
  1, 'el aviso repetido se registró una sola vez');
select is(private.apply_payment_event((select id from ids where name = 'p2'), 'otro-aviso', true), 'paid',
  'un segundo aviso de pago del mismo cobro no cobra dos veces');
select is((select count(*)::int from public.payments where booking_id = (select id from ids where name = 'b1') and status = 'paid'),
  1, 'hay un solo cobro pagado');
select is((select kind from public.room_occupancy where booking_id = (select id from ids where name = 'b1')),
  'booking', 'la retención pasa a ser la ocupación de la reserva');
select is((select array_agg(to_status order by id) from public.booking_events where booking_id = (select id from ids where name = 'b1')),
  array['pending_payment', 'confirmed'], 'el historial guarda cada cambio de estado');

-- ── quién ve qué ───────────────────────────────────────────────────────────
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select is((select count(*)::int from public.bookings where lodging_id = 'aaaaaaaa-1000-0000-0000-000000000001'),
  1, 'la dueña ve las reservas de su hostal');
select is_empty($$ select 1 from public.payments where booking_id = (select id from ids where name = 'b1') $$,
  'pero no los cobros');
reset role;

-- ── cancelar ───────────────────────────────────────────────────────────────
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select is(public.cancel_booking((select id from ids where name = 'b1'), 'cambio de planes') ->> 'refund_cents',
  '5800', 'cancelar con más de 1 hora de anticipación reembolsa todo');
select is((select status from public.bookings where id = (select id from ids where name = 'b1')),
  'cancelled', 'la reserva queda cancelada, no se borra');
select throws_ok($$ select public.cancel_booking((select id from ids where name = 'b1')) $$,
  '55000', 'invalid_status', 'no se cancela dos veces');
reset role;
select is((select status from public.refunds where booking_id = (select id from ids where name = 'b1')),
  'processed', 'el reembolso demo queda procesado');
select isnt_empty(
  $$ select 1 from public.search_lodgings(-12.1211, -77.0297, (select arrival from t0), 4)
      where lodging_id = 'aaaaaaaa-1000-0000-0000-000000000001' $$,
  'el cuarto vuelve a estar libre');

-- Reserva para dentro de 30 minutos, pagada hace 10: fuera de plazo.
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
insert into ids
select 'b2', (public.create_booking('bbbbbbbb-1000-0000-0000-000000000001',
  date_trunc('minute', now()) + interval '30 minutes', 4, '[]', gen_random_uuid()) ->> 'booking_id')::uuid;
insert into ids select 'p3', (public.start_payment((select id from ids where name = 'b2')) ->> 'payment_id')::uuid;
select is(public.demo_gateway_complete((select id from ids where name = 'p3'), true), 'paid',
  'una reserva inmediata se paga');
reset role;
update public.bookings set paid_at = now() - interval '10 minutes' where id = (select id from ids where name = 'b2');
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select throws_ok($$ select public.cancel_booking((select id from ids where name = 'b2')) $$,
  '55000', 'cancel_window_closed', 'pasados los 5 minutos de gracia no se cancela desde la app');
reset role;
update public.bookings set paid_at = now() - interval '2 minutes' where id = (select id from ids where name = 'b2');
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select is(public.cancel_booking((select id from ids where name = 'b2')) ->> 'refund_cents', '5000',
  'dentro de los 5 minutos de gracia sí, con reembolso');
reset role;

-- ── vencimiento y pago tardío ──────────────────────────────────────────────
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
insert into ids
select 'b3', (public.create_booking('bbbbbbbb-1000-0000-0000-000000000001', (select arrival from t0), 4, '[]',
  gen_random_uuid()) ->> 'booking_id')::uuid;
insert into ids select 'p4', (public.start_payment((select id from ids where name = 'b3')) ->> 'payment_id')::uuid;
reset role;
update public.bookings set hold_expires_at = now() - interval '1 second' where id = (select id from ids where name = 'b3');
select is(private.expire_pending_bookings(), 1, 'la tarea automática vence la reserva sin pagar');
select is((select status from public.bookings where id = (select id from ids where name = 'b3')),
  'expired', 'queda vencida');
select is_empty($$ select 1 from public.room_occupancy where booking_id = (select id from ids where name = 'b3') $$,
  'y libera el cuarto');
select is(private.apply_payment_event((select id from ids where name = 'p4'), 'tarde-1', true), 'refunded',
  'un pago que llega cuando la reserva ya venció no la confirma: se devuelve');
select is((select status from public.bookings where id = (select id from ids where name = 'b3')),
  'expired', 'la reserva sigue vencida');
select is((select amount_cents from public.refunds where payment_id = (select id from ids where name = 'p4')),
  5000, 'y el reembolso es completo');
select is(private.apply_payment_event((select id from ids where name = 'p4'), 'tarde-2', true), 'refunded',
  'un segundo aviso no reembolsa dos veces');
select ok(exists (select 1 from cron.job where jobname = 'expire-pending-bookings'),
  'la tarea corre cada minuto');

-- ── la pasarela demo solo existe en demo ───────────────────────────────────
update private.app_settings set value = '"culqi"' where key = 'payments_provider';
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select throws_ok($$ select public.demo_gateway_complete((select id from ids where name = 'p4'), true) $$,
  '42501', 'demo_gateway_disabled', 'con un conector real, la pasarela demo no funciona');
reset role;

select * from finish();
rollback;
