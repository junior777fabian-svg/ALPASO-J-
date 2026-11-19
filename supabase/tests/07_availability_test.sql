-- Disponibilidad: la búsqueda solo devuelve lo que de verdad se puede
-- reservar, con cruces, limpieza y retenciones.
begin;
select plan(28);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.test');
update public.profiles set adult_confirmed_at = now();

-- Hostal Sol en Miraflores: Simple (S/ 30 por 4 h, cuartos 101 y 102) y
-- Suite con jacuzzi (S/ 60 por 4 h, cuarto 201). Limpieza de 30 minutos.
create temp table ids (name text primary key, id uuid) on commit drop;
grant all on ids to anon, authenticated;
create temp table t0 (arrival timestamptz) on commit drop;
grant all on t0 to anon, authenticated;
-- La llegada: dentro de dos horas, en punto.
insert into t0 values (date_trunc('hour', now()) + interval '2 hours');

insert into public.lodgings (id, name, district_id, address, latitude, longitude,
                             cleaning_minutes, status, created_by, has_parking)
values ('aaaaaaaa-0000-0000-0000-000000000001', 'Hostal Sol', 21, 'Av. Larco 123',
        -12.1211, -77.0297, 30, 'published', '11111111-1111-1111-1111-111111111111', true),
       ('aaaaaaaa-0000-0000-0000-000000000002', 'Hostal Borrador', 21, 'Av. Larco 456',
        -12.1215, -77.0300, 30, 'draft', '11111111-1111-1111-1111-111111111111', false),
       ('aaaaaaaa-0000-0000-0000-000000000003', 'Hostal Callao', 44, 'Av. Sáenz Peña 1',
        -12.0566, -77.1181, 30, 'published', '11111111-1111-1111-1111-111111111111', false);

insert into public.room_types (id, lodging_id, name, has_jacuzzi) values
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Simple', false),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Suite', true),
  ('bbbbbbbb-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002', 'Borrador', false),
  ('bbbbbbbb-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000003', 'Callao', false);

insert into public.rates (room_type_id, lodging_id, block_hours, price_cents) values
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 4, 3000),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 4, 6000),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 12, 11000),
  ('bbbbbbbb-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002', 4, 1000),
  ('bbbbbbbb-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000003', 4, 2500);

insert into public.rooms (id, lodging_id, room_type_id, label) values
  ('cccccccc-0000-0000-0000-000000000101', 'aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', '101'),
  ('cccccccc-0000-0000-0000-000000000102', 'aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', '102'),
  ('cccccccc-0000-0000-0000-000000000201', 'aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', '201'),
  ('cccccccc-0000-0000-0000-000000000301', 'aaaaaaaa-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000003', '301'),
  ('cccccccc-0000-0000-0000-000000000401', 'aaaaaaaa-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000004', '401');

-- Búsqueda desde el parque Kennedy (Miraflores), 4 horas.
create function pg_temp.found(p_hours int default 4, p_jacuzzi bool default false,
                              p_parking bool default false, p_max int default null)
returns table (name text, min_price_cents int, available_room_types int)
language sql as $$
  select s.name, s.min_price_cents, s.available_room_types
    from public.search_lodgings(-12.1219, -77.0300, (select arrival from t0), p_hours,
                                3000, null, p_max, p_jacuzzi, p_parking) s
   -- Solo los hostales de esta prueba: la base puede tener otros.
   where s.lodging_id::text like 'aaaaaaaa-%';
$$;
grant execute on function pg_temp.found(int, bool, bool, int) to anon;

-- ── la restricción de exclusión ────────────────────────────────────────────
select lives_ok($$
  insert into public.room_occupancy (room_id, lodging_id, kind, period)
  values ('cccccccc-0000-0000-0000-000000000102', 'aaaaaaaa-0000-0000-0000-000000000001', 'maintenance',
          tstzrange(now() + interval '10 days', now() + interval '10 days 2 hours'))
$$, 'se registra una ocupación');
select throws_ok($$
  insert into public.room_occupancy (room_id, lodging_id, kind, period)
  values ('cccccccc-0000-0000-0000-000000000102', 'aaaaaaaa-0000-0000-0000-000000000001', 'walk_in',
          tstzrange(now() + interval '10 days 1 hour', now() + interval '10 days 3 hours'))
$$, '23P01', null, 'dos ocupaciones del mismo cuarto no se cruzan: lo impide la base');
select lives_ok($$
  insert into public.room_occupancy (room_id, lodging_id, kind, period)
  values ('cccccccc-0000-0000-0000-000000000102', 'aaaaaaaa-0000-0000-0000-000000000001', 'walk_in',
          tstzrange(now() + interval '10 days 2 hours', now() + interval '10 days 4 hours'))
$$, 'una ocupación puede empezar justo cuando termina otra');
select throws_ok($$
  insert into public.room_occupancy (room_id, lodging_id, kind, period)
  values ('cccccccc-0000-0000-0000-000000000101', 'aaaaaaaa-0000-0000-0000-000000000001', 'hold',
          tstzrange(now() + interval '1 day', now() + interval '1 day 4 hours'))
$$, '23514', null, 'una retención exige su vencimiento');

-- ── búsqueda sin ocupaciones ───────────────────────────────────────────────
set local role anon;
select results_eq($$ select * from pg_temp.found() $$,
  $$ values ('Hostal Sol', 3000, 2) $$,
  'sin sesión encuentra el hostal publicado cercano, con su precio más bajo; ni el borrador ni el lejano');
select results_eq($$ select * from pg_temp.found(12) $$,
  $$ values ('Hostal Sol', 11000, 1) $$, 'el precio depende del bloque elegido');
select is_empty($$ select * from pg_temp.found(6) $$, 'un bloque que nadie vende no encuentra nada');
select results_eq($$ select * from pg_temp.found(4, true) $$,
  $$ values ('Hostal Sol', 6000, 1) $$, 'el filtro de jacuzzi deja solo la suite');
select is_empty($$ select * from pg_temp.found(4, false, false, 2000) $$,
  'el filtro de precio máximo funciona');
select results_eq($$ select * from pg_temp.found(4, false, true) $$,
  $$ values ('Hostal Sol', 3000, 2) $$, 'el filtro de cochera funciona');
select results_eq(
  $$ select name from public.search_lodgings(-12.1219, -77.0300, (select arrival from t0), 4,
                                              3000, 44::smallint)
      where lodging_id::text like 'aaaaaaaa-%' $$,
  $$ values ('Hostal Callao') $$, 'buscar por distrito ignora la distancia');
select throws_ok($$ select 1 from public.room_occupancy $$, '42501', null,
  'sin sesión no se ve la ocupación');
reset role;

select throws_ok($$ select * from public.search_lodgings(-12.12, -77.03, now(), 5) $$,
  '22023', 'block_not_allowed', 'un bloque no permitido se rechaza');
select throws_ok($$ select * from public.search_lodgings(-12.12, -77.03, now() + interval '8 days', 4) $$,
  '22023', 'arrival_out_of_range', 'no se busca a más de 7 días');
select throws_ok($$ select * from public.search_lodgings(-12.12, -77.03, now() - interval '1 hour', 4) $$,
  '22023', 'arrival_out_of_range', 'no se busca en el pasado');

-- ── cruces ─────────────────────────────────────────────────────────────────
-- 101 ocupado justo en la estadía pedida.
insert into public.room_occupancy (room_id, lodging_id, kind, period)
select 'cccccccc-0000-0000-0000-000000000101', 'aaaaaaaa-0000-0000-0000-000000000001', 'booking',
       tstzrange(arrival + interval '1 hour', arrival + interval '3 hours') from t0;
select results_eq($$ select * from pg_temp.found() $$, $$ values ('Hostal Sol', 3000, 2) $$,
  'con un cuarto simple ocupado, el otro simple sigue libre');

-- 102 termina su ocupación (con limpieza) exactamente a la hora de llegada.
insert into public.room_occupancy (room_id, lodging_id, kind, period)
select 'cccccccc-0000-0000-0000-000000000102', 'aaaaaaaa-0000-0000-0000-000000000001', 'booking',
       tstzrange(arrival - interval '4 hours 30 minutes', arrival) from t0;
select results_eq($$ select * from pg_temp.found() $$, $$ values ('Hostal Sol', 3000, 2) $$,
  'un cuarto que se libera justo a la llegada está disponible');

-- Ahora 102 tiene otra reserva que empieza 20 minutos después de la salida
-- pedida: no alcanza la limpieza de 30 minutos.
insert into public.room_occupancy (room_id, lodging_id, kind, period)
select 'cccccccc-0000-0000-0000-000000000102', 'aaaaaaaa-0000-0000-0000-000000000001', 'booking',
       tstzrange(arrival + interval '4 hours 20 minutes', arrival + interval '9 hours') from t0;
select results_eq($$ select * from pg_temp.found() $$, $$ values ('Hostal Sol', 6000, 1) $$,
  'si no alcanza la limpieza antes de la siguiente reserva, el cuarto no está libre');

-- La suite tiene una retención vencida: no la ocupa.
insert into public.room_occupancy (room_id, lodging_id, kind, period, expires_at)
select 'cccccccc-0000-0000-0000-000000000201', 'aaaaaaaa-0000-0000-0000-000000000001', 'hold',
       tstzrange(arrival, arrival + interval '4 hours 30 minutes'), now() - interval '1 minute' from t0;
select results_eq($$ select * from pg_temp.found() $$, $$ values ('Hostal Sol', 6000, 1) $$,
  'una retención vencida no ocupa el cuarto');

-- Se vuelve vigente: ya no queda nada libre.
update public.room_occupancy set expires_at = now() + interval '10 minutes'
 where room_id = 'cccccccc-0000-0000-0000-000000000201';
select is_empty($$ select * from pg_temp.found() $$,
  'con todo ocupado, el hostal no aparece en la búsqueda');

-- Un cuarto inactivo no cuenta aunque esté libre.
update public.room_occupancy set expires_at = now() - interval '1 minute'
 where room_id = 'cccccccc-0000-0000-0000-000000000201';
update public.rooms set is_active = false where label = '201';
select is_empty($$ select * from pg_temp.found() $$, 'un cuarto fuera de servicio no cuenta como libre');
update public.rooms set is_active = true where label = '201';

-- ── oferta de un hostal ────────────────────────────────────────────────────
set local role anon;
select results_eq(
  $$ select name, price_cents, is_available
       from public.get_lodging_offer('aaaaaaaa-0000-0000-0000-000000000001', (select arrival from t0), 4) $$,
  $$ values ('Simple', 3000, false), ('Suite', 6000, true) $$,
  'la oferta muestra cada tipo de cuarto con su precio y si hay uno libre');
select is(
  (select rates from public.get_lodging_offer('aaaaaaaa-0000-0000-0000-000000000001', (select arrival from t0), 4)
    where name = 'Suite'),
  '{"4": 6000, "12": 11000}'::jsonb, 'con todas sus tarifas');
select results_eq(
  $$ select name, price_cents
       from public.get_lodging_offer('aaaaaaaa-0000-0000-0000-000000000001', (select arrival from t0), 12) $$,
  $$ values ('Suite', 11000), ('Simple', null::int) $$,
  'un tipo de cuarto sin precio para ese bloque aparece al final, sin precio');
select throws_ok(
  $$ select * from public.get_lodging_offer('aaaaaaaa-0000-0000-0000-000000000002', now() + interval '1 hour', 4) $$,
  'P0002', 'lodging_not_found', 'un hostal sin publicar no tiene oferta pública');
reset role;

-- La retención vencida se borra (lo hará la tarea automática de la etapa 4)
-- y el cuarto se puede volver a ocupar.
delete from public.room_occupancy where kind = 'hold' and expires_at < now();
select lives_ok($$
  insert into public.room_occupancy (room_id, lodging_id, kind, period)
  select 'cccccccc-0000-0000-0000-000000000201', 'aaaaaaaa-0000-0000-0000-000000000001', 'booking',
         tstzrange(arrival, arrival + interval '4 hours 30 minutes') from t0
$$, 'tras borrar la retención vencida, el cuarto se reserva');

-- Al publicar, la búsqueda devuelve la foto de portada.
insert into storage.objects (bucket_id, name)
values ('lodging-photos', 'aaaaaaaa-0000-0000-0000-000000000003/portada.jpg');
insert into public.lodging_photos (lodging_id, storage_path)
values ('aaaaaaaa-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000003/portada.jpg');
select is(
  (select cover_photo_path from public.search_lodgings(-12.0566, -77.1181, (select arrival from t0), 4)
    where lodging_id = 'aaaaaaaa-0000-0000-0000-000000000003'),
  'aaaaaaaa-0000-0000-0000-000000000003/portada.jpg', 'con su foto de portada');
select cmp_ok(
  (select distance_m from public.search_lodgings(-12.0566, -77.1181, (select arrival from t0), 4)
    where lodging_id = 'aaaaaaaa-0000-0000-0000-000000000003'),
  '<', 50, 'y su distancia en metros');

select * from finish();
rollback;
