-- Libro de Reclamaciones: cualquiera registra, con número correlativo; solo
-- el administrador lee y responde.
begin;
select plan(9);

insert into auth.users (id, email) values
  ('33333333-3333-3333-3333-333333333333', 'admin@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'cli@example.test');
insert into private.admins (user_id) values ('33333333-3333-3333-3333-333333333333');

create function pg_temp.act_as(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;
create temp table nums (n text) on commit drop;
grant all on nums to anon, authenticated;

set local role anon;
insert into nums select public.submit_complaint('{
  "kind": "reclamo", "consumer_name": "Carla Pérez", "consumer_document": "45678912",
  "consumer_email": "Carla@Example.test", "booking_code": "k7x9qa", "amount_cents": "4500",
  "detail": "El cuarto no tenía agua caliente.", "consumer_request": "Devolución parcial."}');
select ok((select n ~ '^[0-9]{4}-[0-9]{6}$' from nums), 'sin cuenta se registra un reclamo y recibe su número');
insert into nums select public.submit_complaint('{
  "kind": "queja", "consumer_name": "Luis", "consumer_document": "12345678",
  "consumer_email": "luis@example.test",
  "detail": "Me atendieron de mala manera.", "consumer_request": "Que se revise."}');
select is((select count(distinct n)::int from nums), 2, 'cada registro tiene su propio número');
select ok((select max(n) > min(n) from nums), 'y los números son correlativos');
select throws_ok($$ select public.submit_complaint('{"kind": "reclamo", "consumer_name": "X"}') $$,
  '22023', 'invalid_data', 'un registro incompleto se rechaza');
select throws_ok($$ select public.submit_complaint('{"kind": "sugerencia", "consumer_name": "Ana Ruiz",
  "consumer_document": "12345678", "consumer_email": "a@b.pe", "detail": "Algo largo de detalle.",
  "consumer_request": "Nada."}') $$, '22023', 'invalid_data', 'solo reclamo o queja');
select throws_ok($$ select * from public.admin_list_complaints() $$, '42501', null,
  'sin sesión no se leen los reclamos');
reset role;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select throws_ok($$ select * from public.admin_list_complaints() $$, '42501', 'not_admin',
  'otra cuenta no los lee');
reset role;

select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select is((select consumer_email from public.admin_list_complaints() where kind = 'reclamo'),
  'carla@example.test', 'el admin los lee, con el correo normalizado');
select lives_ok($$ select public.admin_answer_complaint((select min(n) from nums), 'Se devolvieron S/ 10 al cliente.') $$,
  'y responde, con registro');
reset role;

select * from finish();
rollback;
