-- Etapa 6: eliminar cuenta, soporte, ingresos, liquidaciones y acciones del
-- administrador, siempre con registro.
begin;
select plan(35);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'cli@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'admin@example.test'),
  ('66666666-6666-6666-6666-666666666666', 'borrar@example.test');
insert into auth.identities (id, user_id, provider_id, identity_data, provider)
values (gen_random_uuid(), '66666666-6666-6666-6666-666666666666', '66666666-6666-6666-6666-666666666666',
        '{"email": "borrar@example.test"}', 'email');
update public.profiles set adult_confirmed_at = now();
update public.profiles set full_name = 'Beto Borrar' where id = '66666666-6666-6666-6666-666666666666';
insert into private.admins (user_id) values ('33333333-3333-3333-3333-333333333333');

insert into public.lodgings (id, name, district_id, address, latitude, longitude,
                             cleaning_minutes, status, created_by)
values ('aaaaaaaa-3000-0000-0000-000000000001', 'Hostal Dinero', 21, 'Av. Larco 30',
        -12.1211, -77.0297, 0, 'published', '11111111-1111-1111-1111-111111111111');
insert into public.lodging_members (lodging_id, user_id, role)
values ('aaaaaaaa-3000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'owner');
insert into public.room_types (id, lodging_id, name) values
  ('bbbbbbbb-3000-0000-0000-000000000001', 'aaaaaaaa-3000-0000-0000-000000000001', 'Simple');
insert into public.rates (room_type_id, lodging_id, block_hours, price_cents) values
  ('bbbbbbbb-3000-0000-0000-000000000001', 'aaaaaaaa-3000-0000-0000-000000000001', 4, 5000);
insert into public.rooms (id, lodging_id, room_type_id, label) values
  ('cccccccc-3000-0000-0000-000000000001', 'aaaaaaaa-3000-0000-0000-000000000001', 'bbbbbbbb-3000-0000-0000-000000000001', '101'),
  ('cccccccc-3000-0000-0000-000000000002', 'aaaaaaaa-3000-0000-0000-000000000001', 'bbbbbbbb-3000-0000-0000-000000000001', '102');

create temp table ids (name text primary key, id uuid) on commit drop;
grant all on ids to authenticated;

create function pg_temp.act_as(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- Dos reservas pagadas del cliente; una se usa y termina.
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
insert into ids select 'b1', (public.create_booking('bbbbbbbb-3000-0000-0000-000000000001',
  now() + interval '5 minutes', 4, '[]', gen_random_uuid()) ->> 'booking_id')::uuid;
select public.demo_gateway_complete((public.start_payment((select id from ids where name = 'b1')) ->> 'payment_id')::uuid, true);
reset role;
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select public.host_check_in('aaaaaaaa-3000-0000-0000-000000000001',
  (select code from public.bookings where id = (select id from ids where name = 'b1')));
reset role;

-- ── ingresos (N7) ──────────────────────────────────────────────────────────
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select throws_ok($$ select public.lodging_earnings('aaaaaaaa-3000-0000-0000-000000000001') $$,
  '42501', 'not_owner', 'solo la dueña ve los ingresos del hostal');
reset role;
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select is(public.lodging_earnings('aaaaaaaa-3000-0000-0000-000000000001') ->> 'pending_gross_cents', '5000',
  'una estadía en curso cuenta como venta');
select is(public.lodging_earnings('aaaaaaaa-3000-0000-0000-000000000001') ->> 'pending_commission_cents', '500',
  'con la comisión del 10 %');
select is(public.lodging_earnings('aaaaaaaa-3000-0000-0000-000000000001') ->> 'pending_net_cents', '4500',
  'y el neto para el hostal');
select throws_ok($$ select public.set_payout_account('aaaaaaaa-3000-0000-0000-000000000001', 'Ana', 'BCP', '123') $$,
  '23514', null, 'el CCI tiene 20 dígitos');
select lives_ok($$ select public.set_payout_account('aaaaaaaa-3000-0000-0000-000000000001', 'Ana Pérez', 'BCP', '002-193-001234567890-12') $$,
  'la dueña registra su cuenta de destino');
select is((select cci from public.lodging_payout_accounts where lodging_id = 'aaaaaaaa-3000-0000-0000-000000000001'),
  '00219300123456789012', 'el CCI se guarda solo con sus dígitos');
select throws_ok($$ select public.admin_create_payout('aaaaaaaa-3000-0000-0000-000000000001') $$,
  '42501', 'not_admin', 'la dueña no se liquida a sí misma');
reset role;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select is_empty($$ select 1 from public.lodging_payout_accounts $$, 'el cliente no ve cuentas bancarias');
reset role;

-- ── liquidación ────────────────────────────────────────────────────────────
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
insert into ids select 'p1', (public.admin_create_payout('aaaaaaaa-3000-0000-0000-000000000001') ->> 'payout_id')::uuid;
select is((select net_cents from public.payouts where id = (select id from ids where name = 'p1')), 4500,
  'el admin liquida el neto');
select throws_ok($$ select public.admin_create_payout('aaaaaaaa-3000-0000-0000-000000000001') $$,
  '55000', 'nothing_to_pay', 'una reserva no entra a dos liquidaciones');
select throws_ok($$ select public.admin_mark_payout_paid((select id from ids where name = 'p1'), ' ') $$,
  '23514', 'reference_required', 'registrar el pago exige la referencia de la transferencia');
select lives_ok($$ select public.admin_mark_payout_paid((select id from ids where name = 'p1'), 'OP-123456') $$,
  'el admin registra la transferencia');
select throws_ok($$ select public.admin_refund_booking((select id from ids where name = 'b1'), 1000, 'Queja') $$,
  '55000', 'already_paid_out', 'una reserva ya liquidada no se reembolsa desde el panel');
reset role;
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select is(public.lodging_earnings('aaaaaaaa-3000-0000-0000-000000000001') -> 'payouts' -> 0 ->> 'status', 'paid',
  'la dueña ve su liquidación pagada');
select is(public.lodging_earnings('aaaaaaaa-3000-0000-0000-000000000001') ->> 'pending_gross_cents', '0',
  'y nada pendiente');
reset role;

-- ── reembolso de soporte ───────────────────────────────────────────────────
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
insert into ids select 'b2', (public.create_booking('bbbbbbbb-3000-0000-0000-000000000001',
  now() + interval '3 hours', 4, '[]', gen_random_uuid()) ->> 'booking_id')::uuid;
select public.demo_gateway_complete((public.start_payment((select id from ids where name = 'b2')) ->> 'payment_id')::uuid, true);
reset role;
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select throws_ok($$ select public.admin_refund_booking((select id from ids where name = 'b2'), 1000, '') $$,
  '23514', 'reason_required', 'un reembolso de soporte exige el motivo');
select is(public.admin_refund_booking((select id from ids where name = 'b2'), 1000, 'Ducha sin agua caliente'), 1000,
  'el admin reembolsa una parte');
select is(public.admin_refund_booking((select id from ids where name = 'b2'), 99999, 'Todo'), 4000,
  'y nunca más que lo que queda del cobro');
select throws_ok($$ select public.admin_refund_booking((select id from ids where name = 'b2'), 100, 'Más') $$,
  '55000', 'nothing_to_refund', 'ya no queda nada que reembolsar');
reset role;

-- ── suspender y bloquear ───────────────────────────────────────────────────
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select is(public.admin_set_lodging_suspended('aaaaaaaa-3000-0000-0000-000000000001', true, 'Denuncia por ruido'),
  'suspended', 'el admin suspende un hostal');
reset role;
select is_empty($$ select 1 from public.search_lodgings(-12.1211, -77.0297, now() + interval '1 hour', 4)
                   where lodging_id = 'aaaaaaaa-3000-0000-0000-000000000001' $$,
  'un hostal suspendido sale de la búsqueda');
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select is(public.admin_set_lodging_suspended('aaaaaaaa-3000-0000-0000-000000000001', false, 'Resuelto'),
  'published', 'y lo vuelve a publicar');
select throws_ok($$ select public.admin_set_blocked('33333333-3333-3333-3333-333333333333', true, 'prueba') $$,
  '42501', 'cannot_block_admin', 'un admin no se bloquea');
select lives_ok($$ select public.admin_set_blocked('22222222-2222-2222-2222-222222222222', true, 'Fraude') $$,
  'el admin bloquea una cuenta');
reset role;
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select throws_ok($$ select public.create_booking('bbbbbbbb-3000-0000-0000-000000000001', now() + interval '2 hours', 4, '[]', gen_random_uuid()) $$,
  '42501', 'account_blocked', 'una cuenta bloqueada no reserva');
reset role;
select is((select count(*)::int from private.audit_log where actor_id = '33333333-3333-3333-3333-333333333333'),
  7, 'cada acción del admin quedó registrada: liquidar, pagar, 2 reembolsos, suspender, publicar y bloquear');

-- ── soporte ────────────────────────────────────────────────────────────────
select pg_temp.act_as('66666666-6666-6666-6666-666666666666');
set local role authenticated;
insert into ids select 'case', public.create_support_case('No puedo entrar', 'El código no funciona en recepción.');
select is((select status from public.support_cases where id = (select id from ids where name = 'case')), 'open',
  'una cuenta abre una incidencia');
reset role;
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select is_empty($$ select 1 from public.support_cases $$, 'otra cuenta no la ve');
reset role;
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select lives_ok($$ select public.admin_resolve_support_case((select id from ids where name = 'case'), 'Se validó el código a mano.') $$,
  'el admin la resuelve');
reset role;

-- ── eliminar la cuenta ─────────────────────────────────────────────────────
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select throws_ok($$ select public.delete_my_account() $$, '55000', 'owns_lodgings',
  'la dueña de un hostal primero lo resuelve con soporte');
reset role;
select pg_temp.act_as('66666666-6666-6666-6666-666666666666');
set local role authenticated;
select lives_ok($$ select public.delete_my_account() $$, 'una cuenta se elimina');
reset role;
select is((select full_name from public.profiles where id = '66666666-6666-6666-6666-666666666666'), '',
  'su nombre se borra');
select ok((select email like 'eliminada+%@cuenta.invalid' and encrypted_password is null
                  and banned_until > now() + interval '100 years' from auth.users
            where id = '66666666-6666-6666-6666-666666666666'),
  'su correo se reemplaza y ya no puede entrar');
select is_empty($$ select 1 from auth.identities where user_id = '66666666-6666-6666-6666-666666666666' $$,
  'y su identidad de acceso se borra');

select * from finish();
rollback;
