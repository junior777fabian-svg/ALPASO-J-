-- Fotos: solo el dueño sube, en la carpeta de su hostal, y publicar las exige.
begin;
select plan(16);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'luis@example.test');
update public.profiles set adult_confirmed_at = now();

create function pg_temp.act_as(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

create temp table ids (name text primary key, id uuid) on commit drop;
grant all on ids to authenticated, anon;

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
insert into ids values ('sol', public.create_lodging(
  'Hostal Sol', 21::smallint, 'Av. Larco 123', '', -12.12, -77.03));
insert into ids values ('suite', public.save_room_type(
  (select id from ids where name = 'sol'), null, 'Suite', '', 2::smallint,
  true, false, false, true, '{"4": 4500}', array['201']));
reset role;

-- ── almacenamiento ─────────────────────────────────────────────────────────
select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('lodging-photos', (select id from ids where name = 'sol')::text || '/fachada.jpg') $$,
  'la dueña sube un archivo a la carpeta de su hostal');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('lodging-photos', 'otra-carpeta/foto.jpg') $$,
  '42501', null, 'no puede subir fuera de la carpeta de un hostal suyo');
reset role;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('lodging-photos', (select id from ids where name = 'sol')::text || '/intruso.jpg') $$,
  '42501', null, 'otra cuenta no sube fotos a un hostal ajeno');
reset role;

-- ── filas de foto ──────────────────────────────────────────────────────────
-- Un archivo que existe, pero en la carpeta de otro hostal.
insert into storage.objects (bucket_id, name) values ('lodging-photos', 'otro-hostal/fachada.jpg');

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select throws_ok(
  $$ insert into public.lodging_photos (lodging_id, storage_path)
     values ((select id from ids where name = 'sol'),
             (select id from ids where name = 'sol')::text || '/no-existe.jpg') $$,
  '23503', 'photo_not_uploaded', 'una foto solo apunta a un archivo ya subido');
select throws_ok(
  $$ insert into public.lodging_photos (lodging_id, storage_path)
     values ((select id from ids where name = 'sol'), 'otro-hostal/fachada.jpg') $$,
  '23514', null, 'el archivo debe estar en la carpeta del mismo hostal');
select lives_ok(
  $$ insert into public.lodging_photos (lodging_id, storage_path)
     values ((select id from ids where name = 'sol'),
             (select id from ids where name = 'sol')::text || '/fachada.jpg') $$,
  'la dueña registra la foto del hostal');

select throws_ok(
  $$ select public.submit_lodging((select id from ids where name = 'sol')) $$,
  '23514', 'lodging_incomplete', 'sin fotos del cuarto no se envía a revisión');
reset role;

insert into storage.objects (bucket_id, name)
select 'lodging-photos', (select id from ids where name = 'sol')::text || '/' || f
  from unnest(array['cuarto.jpg', 'bano.jpg', 'jacuzzi.jpg']) f;

select pg_temp.act_as('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select throws_ok(
  $$ insert into public.room_type_photos (room_type_id, lodging_id, kind, storage_path)
     values ((select id from ids where name = 'suite'), (select id from ids where name = 'sol'),
             'cocina', (select id from ids where name = 'sol')::text || '/cuarto.jpg') $$,
  '23514', null, 'la etiqueta de una foto es habitación, baño, jacuzzi u otra');
insert into public.room_type_photos (room_type_id, lodging_id, kind, storage_path)
select (select id from ids where name = 'suite'), (select id from ids where name = 'sol'), k,
       (select id from ids where name = 'sol')::text || '/' || f
  from (values ('room', 'cuarto.jpg'), ('bathroom', 'bano.jpg')) v(k, f);
select throws_ok(
  $$ select public.submit_lodging((select id from ids where name = 'sol')) $$,
  '23514', 'lodging_incomplete', 'un cuarto con jacuzzi exige una foto del jacuzzi');
insert into public.room_type_photos (room_type_id, lodging_id, kind, storage_path)
values ((select id from ids where name = 'suite'), (select id from ids where name = 'sol'),
        'jacuzzi', (select id from ids where name = 'sol')::text || '/jacuzzi.jpg');
select is(public.submit_lodging((select id from ids where name = 'sol')), 'pending_review',
  'con la foto del hostal y las del cuarto, se envía a revisión');
reset role;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select is_empty($$ select 1 from public.lodging_photos $$, 'otra cuenta no ve las fotos de un borrador');
delete from public.room_type_photos;
reset role;
select is((select count(*)::int from public.room_type_photos), 3, 'ni las borra');

set local role anon;
select is_empty($$ select 1 from public.room_type_photos $$, 'sin sesión no se ven fotos sin publicar');
reset role;

insert into private.admins (user_id) values ('22222222-2222-2222-2222-222222222222');
select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select is(public.admin_review_lodging((select id from ids where name = 'sol'), true), 'published',
  'el administrador publica');
reset role;

set local role anon;
select is((select count(*)::int from public.room_type_photos), 3, 'publicado, sin sesión se ven sus fotos');
select is((select count(*)::int from public.lodging_photos), 1, 'y la del hostal');
reset role;

select * from finish();
rollback;
