-- Hostales: quién los crea, quién los ve, quién los edita y cómo se publican.
begin;
select plan(50);

-- ana: dueña. luis: otra cuenta. rosa: recepcionista de ana. admin. menor:
-- cuenta sin mayoría de edad confirmada. bloq: cuenta bloqueada.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'luis@example.test'),
  ('44444444-4444-4444-4444-444444444444', 'rosa@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'admin@example.test'),
  ('55555555-5555-5555-5555-555555555555', 'menor@example.test'),
  ('66666666-6666-6666-6666-666666666666', 'bloq@example.test');

update public.profiles set adult_confirmed_at = now()
 where id <> '55555555-5555-5555-5555-555555555555';
update public.profiles set is_blocked = true
 where id = '66666666-6666-6666-6666-666666666666';
insert into private.admins (user_id) values ('33333333-3333-3333-3333-333333333333');

create function pg_temp.act_as(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- ── distritos ──────────────────────────────────────────────────────────────
set local role anon;
select is((select count(*)::int from public.districts), 50,
  'sin sesión se leen los 50 distritos de Lima y Callao');
reset role;

-- ── crear hostal ───────────────────────────────────────────────────────────
set local role anon;
select throws_ok(
  $$ select public.create_lodging('Hostal Sol', 21::smallint, 'Av. Larco 123', '', -12.12, -77.03) $$,
  '42501', null, 'sin sesión no se puede crear un hostal');
reset role;

select pg_temp.act_as('55555555-5555-5555-5555-555555555555');
set local role authenticated;
select throws_ok(
  $$ select public.create_lodging('Hostal Sol', 21::smallint, 'Av. Larco 123', '', -12.12, -77.03) $$,
  '42501', 'adult_not_confirmed', 'sin mayoría de edad confirmada no se crea un hostal');
reset role;

select pg_temp.act_as('66666666-6666-6666-6666-666666666666');
set local role authenticated;
select throws_ok(
  $$ select public.create_lodging('Hostal Sol', 21::smallint, 'Av. Larco 123', '', -12.12, -77.03) $$,
  '42501', 'account_blocked', 'una cuenta bloqueada no crea hostales');
reset role;

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select throws_ok(
  $$ select public.create_lodging('Hostal Lejos', 1::smallint, 'Av. Siempre Viva 1', '', -16.40, -71.53) $$,
  '23514', null, 'la ubicación debe estar en Lima o Callao');

create temp table ids (name text primary key, id uuid) on commit drop;
grant all on ids to authenticated, anon, service_role;
insert into ids values ('sol', public.create_lodging(
  '  Hostal Sol  ', 21::smallint, 'Av. Larco 123', 'Frente al parque', -12.12, -77.03));

select is((select name from public.lodgings where id = (select id from ids where name = 'sol')),
  'Hostal Sol', 'el hostal se crea con el nombre limpio');
select is((select status from public.lodgings where id = (select id from ids where name = 'sol')),
  'draft', 'nace en borrador');
select is((select role from public.lodging_members
            where lodging_id = (select id from ids where name = 'sol')
              and user_id = '11111111-1111-1111-1111-111111111111'),
  'owner', 'quien lo crea queda como dueña');

select lives_ok($$ select public.create_lodging('Hostal Dos', 21::smallint, 'Calle Dos 222', '', -12.12, -77.03) $$,
  'se puede tener un segundo hostal sin publicar');
select lives_ok($$ select public.create_lodging('Hostal Tres', 21::smallint, 'Calle Tres 333', '', -12.12, -77.03) $$,
  'y un tercero');
select throws_ok(
  $$ select public.create_lodging('Hostal Cuatro', 21::smallint, 'Calle Cuatro 4', '', -12.12, -77.03) $$,
  '54000', 'too_many_open_lodgings', 'el cuarto hostal sin publicar se rechaza');
reset role;

-- rosa pasa a ser recepcionista de Hostal Sol (lo hará invite_staff en la etapa 5).
insert into public.lodging_members (lodging_id, user_id, role)
values ((select id from ids where name = 'sol'), '44444444-4444-4444-4444-444444444444', 'receptionist');

-- ── visibilidad del borrador ───────────────────────────────────────────────
set local role anon;
select is_empty($$ select 1 from public.lodgings $$, 'sin sesión no se ven borradores');
reset role;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select is_empty($$ select 1 from public.lodgings $$, 'otra cuenta no ve el borrador ajeno');
select is_empty($$ select 1 from public.lodging_members $$, 'ni su personal');
select throws_ok(
  $$ insert into public.lodging_members (lodging_id, user_id, role)
     select id, '22222222-2222-2222-2222-222222222222', 'owner' from ids where name = 'sol' $$,
  '42501', null, 'nadie se nombra dueño de un hostal ajeno desde la API');
reset role;

-- ── edición del hostal ─────────────────────────────────────────────────────
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select lives_ok(
  $$ update public.lodgings set has_parking = true, cleaning_minutes = 20
      where id = (select id from ids where name = 'sol') $$,
  'la dueña edita los datos de su hostal');
select throws_ok(
  $$ update public.lodgings set status = 'published' where id = (select id from ids where name = 'sol') $$,
  '42501', null, 'la dueña no puede publicarse a sí misma');
select is((select count(*)::int from public.lodging_members
            where lodging_id = (select id from ids where name = 'sol')),
  2, 'la dueña ve a todo su personal');
reset role;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
update public.lodgings set name = 'Hackeado' where id = (select id from ids where name = 'sol');
reset role;
select is((select name from public.lodgings where id = (select id from ids where name = 'sol')),
  'Hostal Sol', 'otra cuenta no puede editar el hostal');

-- ── tipos de cuarto, cuartos, tarifas y extras ─────────────────────────────
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
with t as (
  insert into public.room_types (lodging_id, name, has_jacuzzi)
  values ((select id from ids where name = 'sol'), 'Suite con jacuzzi', true)
  returning id)
insert into ids select 'suite', id from t;
with t as (
  insert into public.room_types (lodging_id, name)
  values ((select id from ids where name = 'sol'), 'Simple')
  returning id)
insert into ids select 'simple', id from t;
select is((select count(*)::int from public.room_types
            where lodging_id = (select id from ids where name = 'sol')),
  2, 'la dueña crea tipos de cuarto');

select throws_ok(
  $$ insert into public.rates (room_type_id, lodging_id, block_hours, price_cents)
     values ((select id from ids where name = 'suite'), (select id from ids where name = 'sol'), 5, 3000) $$,
  '23514', 'block_not_allowed', 'un bloque que la plataforma no vende se rechaza');
select throws_ok(
  $$ insert into public.rates (room_type_id, lodging_id, block_hours, price_cents)
     values ((select id from ids where name = 'suite'), (select id from ids where name = 'sol'), 4, 50) $$,
  '23514', null, 'un precio menor a S/ 1.00 se rechaza');
select lives_ok(
  $$ insert into public.rates (room_type_id, lodging_id, block_hours, price_cents)
     values ((select id from ids where name = 'suite'), (select id from ids where name = 'sol'), 4, 4500),
            ((select id from ids where name = 'suite'), (select id from ids where name = 'sol'), 12, 9000) $$,
  'la dueña pone precio a los bloques de 4 y 12 horas');

select throws_ok(
  $$ insert into public.products (lodging_id, name, category, price_cents)
     values ((select id from ids where name = 'sol'), 'Cerveza', 'alcohol', 800) $$,
  '23514', 'alcohol_disabled', 'los licores están apagados en la plataforma');
select lives_ok(
  $$ insert into public.products (lodging_id, name, category, price_cents)
     values ((select id from ids where name = 'sol'), 'Gaseosa', 'drinks', 400) $$,
  'la dueña agrega extras a su carta');
reset role;

-- Un tipo de cuarto de Hostal Dos, para probar que no se mezclan.
with t as (
  insert into public.room_types (lodging_id, name)
  select l.id, 'Ajeno' from public.lodgings l where l.name = 'Hostal Dos'
  returning id)
insert into ids select 'ajeno', id from t;

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select throws_ok(
  $$ insert into public.rooms (lodging_id, room_type_id, label)
     values ((select id from ids where name = 'sol'), (select id from ids where name = 'ajeno'), '101') $$,
  '23503', null, 'un cuarto no puede usar un tipo de cuarto de otro hostal');
select throws_ok(
  $$ insert into public.rooms (lodging_id, room_type_id, label)
     values ((select id from ids where name = 'sol'), (select id from ids where name = 'suite'), '2 01') $$,
  '23514', null, 'el número de cuarto no admite espacios');
reset role;

select pg_temp.act_as('44444444-4444-4444-4444-444444444444');
set local role authenticated;
select is((select count(*)::int from public.room_types
            where lodging_id = (select id from ids where name = 'sol')),
  2, 'la recepcionista ve los tipos de cuarto de su hostal');
select throws_ok(
  $$ insert into public.room_types (lodging_id, name)
     values ((select id from ids where name = 'sol'), 'De la recepcionista') $$,
  '42501', null, 'la recepcionista no crea tipos de cuarto');
update public.rates set price_cents = 100 where room_type_id = (select id from ids where name = 'suite');
reset role;
select is((select price_cents from public.rates
            where room_type_id = (select id from ids where name = 'suite') and block_hours = 4),
  4500, 'la recepcionista no cambia precios');

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select throws_ok(
  $$ insert into public.room_types (lodging_id, name)
     values ((select id from ids where name = 'sol'), 'Intruso') $$,
  '42501', null, 'otra cuenta no crea tipos de cuarto en un hostal ajeno');
select throws_ok(
  $$ select public.submit_lodging((select id from ids where name = 'sol')) $$,
  '42501', 'not_owner', 'otra cuenta no envía a revisión un hostal ajeno');
reset role;

-- ── envío a revisión ───────────────────────────────────────────────────────
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select throws_ok(
  $$ select public.submit_lodging((select id from ids where name = 'sol')) $$,
  '23514', 'lodging_incomplete', 'sin ningún cuarto activo no se envía a revisión');
insert into public.rooms (lodging_id, room_type_id, label)
values ((select id from ids where name = 'sol'), (select id from ids where name = 'suite'), '201'),
       ((select id from ids where name = 'sol'), (select id from ids where name = 'simple'), '101');
select is(public.submit_lodging((select id from ids where name = 'sol')), 'pending_review',
  'con un tipo de cuarto con tarifa y cuarto, se envía a revisión');
select throws_ok(
  $$ select public.submit_lodging((select id from ids where name = 'sol')) $$,
  '55000', 'invalid_status', 'no se envía dos veces');
select throws_ok(
  $$ select public.admin_review_lodging((select id from ids where name = 'sol'), true) $$,
  '42501', 'not_admin', 'la dueña no puede aprobar su propio hostal');
reset role;

-- ── revisión del administrador ─────────────────────────────────────────────
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select is((select count(*)::int from public.lodgings), 3, 'el administrador ve todos los hostales');
select throws_ok(
  $$ select public.admin_review_lodging((select id from ids where name = 'sol'), false, '  ') $$,
  '23514', 'review_note_required', 'rechazar exige un motivo');
select is(public.admin_review_lodging((select id from ids where name = 'sol'), false, 'Faltan fotos del baño'),
  'rejected', 'el administrador rechaza con motivo');
reset role;

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select is((select review_note from public.lodgings where id = (select id from ids where name = 'sol')),
  'Faltan fotos del baño', 'la dueña ve el motivo del rechazo');
select is(public.submit_lodging((select id from ids where name = 'sol')), 'pending_review',
  'un hostal rechazado se puede volver a enviar');
reset role;

select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select is(public.admin_review_lodging((select id from ids where name = 'sol'), true), 'published',
  'el administrador publica el hostal');
select throws_ok(
  $$ select public.admin_review_lodging((select id from ids where name = 'sol'), true) $$,
  '55000', 'invalid_status', 'no se publica dos veces');
reset role;

-- La llave de servidor también puede revisar (tools/admin-review.cjs).
select set_config('request.jwt.claims', '{"role": "service_role"}', true);
set local role service_role;
select throws_ok(
  $$ select public.admin_review_lodging((select id from ids where name = 'sol'), true) $$,
  '55000', 'invalid_status', 'la llave de servidor puede revisar, con las mismas reglas');
reset role;

-- El tipo de cuarto "Simple" se desactiva: no debe verse en público.
update public.room_types set is_active = false where id = (select id from ids where name = 'simple');

-- ── lo publicado, sin sesión ───────────────────────────────────────────────
set local role anon;
select results_eq($$ select name from public.lodgings $$, $$ values ('Hostal Sol') $$,
  'sin sesión se ve solo el hostal publicado');
select results_eq($$ select name from public.room_types $$, $$ values ('Suite con jacuzzi') $$,
  'y solo sus tipos de cuarto activos');
select is((select count(*)::int from public.rates), 2, 'y sus tarifas');
select results_eq($$ select name from public.products $$, $$ values ('Gaseosa') $$, 'y su carta de extras');
select throws_ok($$ select 1 from public.rooms $$, '42501', null,
  'sin sesión no se ven los números de cuarto');
select throws_ok($$ select 1 from public.lodging_members $$, '42501', null,
  'ni quién trabaja en el hostal');
reset role;

select * from finish();
rollback;
