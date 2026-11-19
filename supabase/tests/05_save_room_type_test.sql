-- save_room_type: el dueño guarda tipo de cuarto, tarifas y cuartos juntos.
begin;
select plan(14);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'luis@example.test');
update public.profiles set adult_confirmed_at = now();

create function pg_temp.act_as(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

create temp table ids (name text primary key, id uuid) on commit drop;
grant all on ids to authenticated;

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;

insert into ids values ('sol', public.create_lodging(
  'Hostal Sol', 21::smallint, 'Av. Larco 123', '', -12.12, -77.03));

insert into ids values ('suite', public.save_room_type(
  (select id from ids where name = 'sol'), null, ' Suite ', 'Con jacuzzi', 2::smallint,
  true, true, false, true, '{"4": 4500, "12": 9000}', array['201', ' 202 ', '201', '']));

select is((select name from public.room_types where id = (select id from ids where name = 'suite')),
  'Suite', 'crea el tipo de cuarto con el nombre limpio');
select results_eq(
  $$ select block_hours::int, price_cents from public.rates
      where room_type_id = (select id from ids where name = 'suite') order by 1 $$,
  $$ values (4, 4500), (12, 9000) $$, 'con sus tarifas');
select results_eq(
  $$ select label from public.rooms
      where room_type_id = (select id from ids where name = 'suite') order by 1 $$,
  $$ values ('201'), ('202') $$, 'y sus cuartos, sin repetir ni vacíos');

select lives_ok($$
  select public.save_room_type(
    (select id from ids where name = 'sol'), (select id from ids where name = 'suite'),
    'Suite VIP', '', 2::smallint, true, true, true, true,
    '{"6": 6000, "12": 9500}', array['202', '203b'])
$$, 'edita el tipo de cuarto');
select results_eq(
  $$ select block_hours::int, price_cents from public.rates
      where room_type_id = (select id from ids where name = 'suite') order by 1 $$,
  $$ values (6, 6000), (12, 9500) $$, 'reemplaza las tarifas: quita la de 4 h, cambia la de 12 h, agrega la de 6 h');
select results_eq(
  $$ select label from public.rooms
      where room_type_id = (select id from ids where name = 'suite') order by 1 $$,
  $$ values ('202'), ('203B') $$, 'reemplaza los cuartos y los pasa a mayúsculas');

select throws_ok($$
  select public.save_room_type(
    (select id from ids where name = 'sol'), null, 'Simple', '', 2::smallint,
    false, false, false, true, '{"4": 3000}', array['202'])
$$, '23505', 'room_label_taken', 'un número de cuarto no se repite entre tipos del mismo hostal');
select is((select count(*)::int from public.room_types
            where lodging_id = (select id from ids where name = 'sol')),
  1, 'y si falla no queda nada a medias');

select throws_ok($$
  select public.save_room_type(
    (select id from ids where name = 'sol'), (select id from ids where name = 'suite'),
    'Suite VIP', '', 2::smallint, true, true, true, true, '{"5": 6000}', array['202'])
$$, '23514', 'block_not_allowed', 'un bloque no permitido se rechaza');
select results_eq(
  $$ select block_hours::int from public.rates
      where room_type_id = (select id from ids where name = 'suite') order by 1 $$,
  $$ values (6), (12) $$, 'y las tarifas anteriores siguen intactas');

select throws_ok($$
  select public.save_room_type(
    (select id from ids where name = 'sol'), null, 'Barata', '', 2::smallint,
    false, false, false, true, '{"4": 10}', array['301'])
$$, '23514', null, 'un precio menor a S/ 1.00 se rechaza');

select is(public.submit_lodging((select id from ids where name = 'sol')), 'pending_review',
  'con un tipo de cuarto guardado así, el hostal se puede enviar a revisión');
reset role;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select throws_ok($$
  select public.save_room_type(
    (select id from ids where name = 'sol'), null, 'Intruso', '', 2::smallint,
    false, false, false, true, '{}', array['999'])
$$, '42501', 'not_owner', 'otra cuenta no guarda tipos de cuarto en un hostal ajeno');
select throws_ok($$
  select public.save_room_type(
    (select id from ids where name = 'sol'), (select id from ids where name = 'suite'),
    'Hackeado', '', 2::smallint, false, false, false, true, '{}', array[]::text[])
$$, '42501', 'not_owner', 'ni edita los ajenos');
reset role;

select * from finish();
rollback;
