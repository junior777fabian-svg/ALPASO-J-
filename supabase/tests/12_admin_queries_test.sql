-- Consultas del panel: solo para administradores.
begin;
select plan(8);

insert into auth.users (id, email) values
  ('33333333-3333-3333-3333-333333333333', 'admin@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'carla.panel@example.test');
update public.profiles set full_name = 'Carla Panel' where id = '22222222-2222-2222-2222-222222222222';
insert into private.admins (user_id) values ('33333333-3333-3333-3333-333333333333');

create function pg_temp.act_as(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select throws_ok($$ select public.admin_overview() $$, '42501', 'not_admin', 'una cuenta común no ve el resumen');
select throws_ok($$ select * from public.admin_find_users('carla') $$, '42501', 'not_admin', 'ni busca cuentas');
select throws_ok($$ select * from public.admin_pending_payouts() $$, '42501', 'not_admin', 'ni ve liquidaciones');
select throws_ok($$ select public.admin_find_booking('AAAAAA') $$, '42501', 'not_admin', 'ni busca reservas');
reset role;

select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select ok(public.admin_overview() ? 'lodgings_pending_review', 'el admin ve el resumen');
select is((select full_name from public.admin_find_users('carla.panel')), 'Carla Panel',
  'busca cuentas por correo');
select throws_ok($$ select * from public.admin_find_users('ab') $$, '22023', 'query_too_short',
  'con al menos 3 letras');
select throws_ok($$ select public.admin_find_booking('ZZZZZZ') $$, 'P0002', 'booking_not_found',
  'una reserva que no existe lo dice');
reset role;

select * from finish();
rollback;
