-- Recepción: ingreso con código una sola vez, salida, limpieza, cliente
-- directo, extras, cancelación del hostal, personal y tareas automáticas.
begin;
select plan(46);

-- ana: dueña. rosa: será recepcionista. cli: cliente. luis: otra cuenta.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.test'),
  ('44444444-4444-4444-4444-444444444444', 'rosa@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'cli@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'luis@example.test');
update public.profiles set adult_confirmed_at = now();
update public.profiles set full_name = 'Carla Cliente' where id = '22222222-2222-2222-2222-222222222222';

insert into public.lodgings (id, name, district_id, address, latitude, longitude,
                             cleaning_minutes, status, created_by)
values ('aaaaaaaa-2000-0000-0000-000000000001', 'Hostal Recepción', 21, 'Av. Larco 9',
        -12.1211, -77.0297, 20, 'published', '11111111-1111-1111-1111-111111111111'),
       ('aaaaaaaa-2000-0000-0000-000000000002', 'Hostal Ajeno', 21, 'Av. Larco 10',
        -12.1212, -77.0298, 20, 'published', '33333333-3333-3333-3333-333333333333');
insert into public.lodging_members (lodging_id, user_id, role) values
  ('aaaaaaaa-2000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-2000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'owner');
insert into public.room_types (id, lodging_id, name) values
  ('bbbbbbbb-2000-0000-0000-000000000001', 'aaaaaaaa-2000-0000-0000-000000000001', 'Simple');
insert into public.rates (room_type_id, lodging_id, block_hours, price_cents) values
  ('bbbbbbbb-2000-0000-0000-000000000001', 'aaaaaaaa-2000-0000-0000-000000000001', 4, 4000);
insert into public.rooms (id, lodging_id, room_type_id, label) values
  ('cccccccc-2000-0000-0000-000000000101', 'aaaaaaaa-2000-0000-0000-000000000001', 'bbbbbbbb-2000-0000-0000-000000000001', '101'),
  ('cccccccc-2000-0000-0000-000000000102', 'aaaaaaaa-2000-0000-0000-000000000001', 'bbbbbbbb-2000-0000-0000-000000000001', '102');
insert into public.products (id, lodging_id, name, category, price_cents) values
  ('dddddddd-2000-0000-0000-000000000001', 'aaaaaaaa-2000-0000-0000-000000000001', 'Gaseosa', 'drinks', 500),
  ('dddddddd-2000-0000-0000-000000000002', 'aaaaaaaa-2000-0000-0000-000000000001', 'Agua', 'drinks', 300);

create temp table ids (name text primary key, id uuid, code text) on commit drop;
grant all on ids to authenticated;

create function pg_temp.act_as(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- Carla reserva para dentro de 10 minutos, con gaseosa y agua, y paga.
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
insert into ids (name, id, code)
select 'b1', (r ->> 'booking_id')::uuid, r ->> 'code'
  from public.create_booking('bbbbbbbb-2000-0000-0000-000000000001',
    now() + interval '10 minutes', 4,
    '[{"product_id": "dddddddd-2000-0000-0000-000000000001", "quantity": 1},
      {"product_id": "dddddddd-2000-0000-0000-000000000002", "quantity": 2}]',
    gen_random_uuid()) r;
select public.demo_gateway_complete((public.start_payment((select id from ids where name = 'b1')) ->> 'payment_id')::uuid, true);
reset role;

-- ── personal ───────────────────────────────────────────────────────────────
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
set local role authenticated;
select throws_ok($$ select public.invite_staff('aaaaaaaa-2000-0000-0000-000000000001') $$,
  '42501', 'not_owner', 'solo el dueño invita personal');
select throws_ok($$ select public.host_today('aaaaaaaa-2000-0000-0000-000000000001') $$,
  '42501', 'not_staff', 'sin ser personal no se ve el tablero');
reset role;

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
insert into ids (name, code)
select 'invite', public.invite_staff('aaaaaaaa-2000-0000-0000-000000000001') ->> 'code';
select ok((select code ~ '^[A-Z0-9]{8}$' from ids where name = 'invite'),
  'la dueña obtiene un código de invitación');
reset role;

select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
set local role authenticated;
select is(public.accept_invite(lower((select code from ids where name = 'invite'))) ->> 'lodging_name',
  'Hostal Recepción', 'Rosa se une con el código');
select throws_ok($$ select public.accept_invite((select code from ids where name = 'invite')) $$,
  'P0002', 'invite_not_valid', 'un código de invitación sirve una sola vez');
reset role;
select is((select role from public.lodging_members
            where user_id = '44444444-4444-4444-4444-444444444444'
              and lodging_id = 'aaaaaaaa-2000-0000-0000-000000000001'),
  'receptionist', 'como recepcionista');

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select results_eq(
  $$ select full_name, role from public.lodging_staff('aaaaaaaa-2000-0000-0000-000000000001') $$,
  $$ values ('Sin nombre', 'owner'), ('Sin nombre', 'receptionist') $$,
  'la dueña ve a su personal');
reset role;

-- ── tablero ────────────────────────────────────────────────────────────────
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
set local role authenticated;
select is(public.host_today('aaaaaaaa-2000-0000-0000-000000000001') -> 'arrivals' -> 0 ->> 'customer_name',
  'Carla Cliente', 'la recepcionista ve la llegada con el nombre del cliente');
select is(public.host_today('aaaaaaaa-2000-0000-0000-000000000001') -> 'arrivals' -> 0 ->> 'code',
  (select code from ids where name = 'b1'), 'y su código');
select ok(not (public.host_today('aaaaaaaa-2000-0000-0000-000000000001') -> 'arrivals' -> 0 ? 'customer_id'),
  'pero no otros datos del cliente');
select is(jsonb_array_length(public.host_today('aaaaaaaa-2000-0000-0000-000000000001') -> 'arrivals' -> 0 -> 'items'),
  2, 'con los extras por preparar');
select is(public.host_today('aaaaaaaa-2000-0000-0000-000000000001') -> 'rooms' -> 0 ->> 'state',
  'free', 'el cuarto 101 todavía está libre: la reserva empieza en 10 minutos');
select is_empty($$ select 1 from public.profiles where id = '22222222-2222-2222-2222-222222222222' $$,
  'la recepcionista no lee el perfil del cliente');

-- ── ingreso ────────────────────────────────────────────────────────────────
select throws_ok($$ select public.host_check_in('aaaaaaaa-2000-0000-0000-000000000001', 'ZZZZZZ') $$,
  'P0002', 'code_not_found', 'un código que no existe se rechaza');
reset role;
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select throws_ok($$ select public.host_check_in('aaaaaaaa-2000-0000-0000-000000000002', (select code from ids where name = 'b1')) $$,
  'P0002', 'code_not_found', 'un código no sirve en otro hostal');
reset role;
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
set local role authenticated;
select is(public.host_check_in('aaaaaaaa-2000-0000-0000-000000000001',
            ' alpaso:' || lower((select code from ids where name = 'b1')) || ' ') ->> 'room_label',
  '101', 'el código del QR (ALPASO:…) registra el ingreso, desde 15 minutos antes');
select throws_ok($$ select public.host_check_in('aaaaaaaa-2000-0000-0000-000000000001', (select code from ids where name = 'b1')) $$,
  '55000', 'code_already_used', 'un código sirve una sola vez');
reset role;
select is((select status from public.bookings where id = (select id from ids where name = 'b1')),
  'checked_in', 'la reserva queda en curso');

-- ── extras ─────────────────────────────────────────────────────────────────
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
set local role authenticated;
select is(public.host_set_item_status(
  (select id from public.booking_items where booking_id = (select id from ids where name = 'b1') and name = 'Gaseosa'),
  'ready') ->> 'refund_cents', '0', 'la gaseosa queda lista en el cuarto');
select is(public.host_set_item_status(
  (select id from public.booking_items where booking_id = (select id from ids where name = 'b1') and name = 'Agua'),
  'unavailable') ->> 'refund_cents', '600', 'el agua no está: se reembolsan sus S/ 6');
select throws_ok($$ select public.host_set_item_status(
  (select id from public.booking_items where booking_id = (select id from ids where name = 'b1') and name = 'Agua'),
  'unavailable') $$, '55000', 'item_already_set', 'un extra no se reembolsa dos veces');
reset role;

-- ── salida y limpieza ──────────────────────────────────────────────────────
-- Para la salida, la estadía empezó hace un rato.
update public.room_occupancy set period = tstzrange(now() - interval '2 hours', upper(period), '[)')
 where booking_id = (select id from ids where name = 'b1');
update public.bookings set arrival_at = now() - interval '2 hours' where id = (select id from ids where name = 'b1');
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
set local role authenticated;
select lives_ok($$ select public.host_check_out((select id from ids where name = 'b1')) $$,
  'la recepcionista registra la salida');
select is(public.host_today('aaaaaaaa-2000-0000-0000-000000000001') -> 'rooms' -> 0 ->> 'state',
  'cleaning', 'el cuarto pasa a limpieza');
reset role;
select is((select status from public.bookings where id = (select id from ids where name = 'b1')),
  'completed', 'la reserva termina');
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
set local role authenticated;
select lives_ok($$ select public.host_mark_clean('cccccccc-2000-0000-0000-000000000101') $$,
  'marca el cuarto limpio');
select is(public.host_today('aaaaaaaa-2000-0000-0000-000000000001') -> 'rooms' -> 0 ->> 'state',
  'free', 'y queda libre');

-- ── cliente directo ────────────────────────────────────────────────────────
insert into ids (name, id)
select 'walkin', public.host_block_room('cccccccc-2000-0000-0000-000000000102', 'walk_in', 180);
select is(public.host_today('aaaaaaaa-2000-0000-0000-000000000001') -> 'rooms' -> 1 ->> 'state',
  'walk_in', 'un cliente directo ocupa el 102');
reset role;
select is(
  (select is_available from public.get_lodging_offer('aaaaaaaa-2000-0000-0000-000000000001', now() + interval '30 minutes', 4)),
  true, 'con el 101 libre, el tipo de cuarto sigue disponible');
select ok(not private.room_is_free('cccccccc-2000-0000-0000-000000000102',
            tstzrange(now() + interval '30 minutes', now() + interval '4 hours 50 minutes')),
  'la app se entera: el 102 cuenta como ocupado');
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
-- El 101 está libre, así que una reserva para ahora toma el 101, no el 102.
insert into ids (name, id)
select 'b2', (public.create_booking('bbbbbbbb-2000-0000-0000-000000000001', now() + interval '5 minutes', 4, '[]',
  gen_random_uuid()) ->> 'booking_id')::uuid;
reset role;
select is((select u.label from public.bookings b join public.rooms u on u.id = b.room_id
            where b.id = (select id from ids where name = 'b2')),
  '101', 'una reserva de la app nunca recibe el cuarto del cliente directo');
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
set local role authenticated;
select throws_ok($$ select public.host_block_room('cccccccc-2000-0000-0000-000000000101', 'walk_in', 60) $$,
  '55000', 'room_not_free', 'un cliente directo no pisa una reserva de la app');
select throws_ok($$ select public.host_block_room('cccccccc-2000-0000-0000-000000000102', 'fiesta', 60) $$,
  '22023', 'invalid_kind', 'solo cliente directo o fuera de servicio');
select lives_ok($$ select public.host_release_block((select id from ids where name = 'walkin')) $$,
  'se libera el cuarto del cliente directo');
reset role;

-- ── cancelación del hostal ─────────────────────────────────────────────────
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select public.demo_gateway_complete((public.start_payment((select id from ids where name = 'b2')) ->> 'payment_id')::uuid, true);
reset role;
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
set local role authenticated;
select throws_ok($$ select public.host_cancel_booking((select id from ids where name = 'b2'), 'Inundación') $$,
  '42501', 'not_owner', 'la recepcionista no cancela reservas');
reset role;
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select throws_ok($$ select public.host_cancel_booking((select id from ids where name = 'b2'), '  ') $$,
  '23514', 'reason_required', 'cancelar exige un motivo');
select is(public.host_cancel_booking((select id from ids where name = 'b2'), 'Inundación en el piso') ->> 'refund_cents',
  '4000', 'si cancela el hostal, el reembolso es total');
reset role;
select is((select sum(amount_cents)::int from public.refunds where booking_id = (select id from ids where name = 'b1')),
  600, 'los reembolsos de la primera reserva suman solo el extra que faltó');

-- ── retirar personal ───────────────────────────────────────────────────────
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select throws_ok($$ select public.revoke_staff('aaaaaaaa-2000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111') $$,
  'P0002', 'member_not_found', 'a la dueña no se la puede retirar');
select lives_ok($$ select public.revoke_staff('aaaaaaaa-2000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444') $$,
  'la dueña retira a Rosa');
reset role;
select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
set local role authenticated;
select throws_ok($$ select public.host_today('aaaaaaaa-2000-0000-0000-000000000001') $$,
  '42501', 'not_staff', 'Rosa ya no ve el tablero');
reset role;

-- ── tareas automáticas ─────────────────────────────────────────────────────
-- Una reserva confirmada cuya hora pasó hace 31 minutos: no llegó.
insert into public.bookings (id, code, customer_id, lodging_id, room_type_id, room_id, block_hours,
  arrival_at, departure_at, status, room_price_cents, total_cents, idempotency_key, paid_at)
values ('eeeeeeee-2000-0000-0000-000000000001', 'NNNNNN', '22222222-2222-2222-2222-222222222222',
  'aaaaaaaa-2000-0000-0000-000000000001', 'bbbbbbbb-2000-0000-0000-000000000001',
  'cccccccc-2000-0000-0000-000000000102', 4, now() - interval '31 minutes',
  now() + interval '209 minutes', 'confirmed', 4000, 4000, gen_random_uuid(), now() - interval '1 day');
insert into public.room_occupancy (room_id, lodging_id, kind, period, booking_id)
values ('cccccccc-2000-0000-0000-000000000102', 'aaaaaaaa-2000-0000-0000-000000000001', 'booking',
  tstzrange(now() - interval '31 minutes', now() + interval '229 minutes'), 'eeeeeeee-2000-0000-0000-000000000001');
-- Y una en curso cuya hora de salida ya pasó.
update public.bookings set status = 'checked_in', departure_at = now() - interval '1 minute'
 where id = (select id from ids where name = 'b1');

select is(private.run_stay_transitions(), 2, 'la tarea automática procesa las dos');
select is((select status from public.bookings where id = 'eeeeeeee-2000-0000-0000-000000000001'),
  'no_show', 'quien no llegó en 30 minutos queda como "no llegó"');
select ok((select upper(period) <= now() + interval '1 second' from public.room_occupancy
            where booking_id = 'eeeeeeee-2000-0000-0000-000000000001'),
  'y su cuarto se libera');
select is((select status from public.bookings where id = (select id from ids where name = 'b1')),
  'completed', 'una estadía terminada se cierra sola');
select ok(exists (select 1 from cron.job where jobname = 'stay-transitions'),
  'la tarea corre cada minuto');
select throws_ok($$
  insert into public.refunds (booking_id, payment_id, amount_cents, reason)
  select (select id from ids where name = 'b1'), p.id, 999999, 'demasiado'
    from public.payments p where p.booking_id = (select id from ids where name = 'b1') and p.status = 'paid' $$,
  '23514', 'refund_exceeds_payment', 'los reembolsos nunca suman más que el cobro');

select * from finish();
rollback;
