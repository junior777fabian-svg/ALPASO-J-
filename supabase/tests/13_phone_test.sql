-- Verificación de celular antes de la primera reserva, con el conector demo.
begin;
select plan(13);

insert into auth.users (id, email) values
  ('22222222-2222-2222-2222-222222222222', 'cli@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'otro@example.test');
update public.profiles set adult_confirmed_at = now();

insert into public.lodgings (id, name, district_id, address, latitude, longitude,
                             cleaning_minutes, status, created_by)
values ('aaaaaaaa-4000-0000-0000-000000000001', 'Hostal Celular', 21, 'Av. Larco 40',
        -12.1211, -77.0297, 0, 'published', '22222222-2222-2222-2222-222222222222');
insert into public.room_types (id, lodging_id, name) values
  ('bbbbbbbb-4000-0000-0000-000000000001', 'aaaaaaaa-4000-0000-0000-000000000001', 'Simple');
insert into public.rates (room_type_id, lodging_id, block_hours, price_cents) values
  ('bbbbbbbb-4000-0000-0000-000000000001', 'aaaaaaaa-4000-0000-0000-000000000001', 4, 3000);
insert into public.rooms (lodging_id, room_type_id, label) values
  ('aaaaaaaa-4000-0000-0000-000000000001', 'bbbbbbbb-4000-0000-0000-000000000001', '101');

create function pg_temp.act_as(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

select pg_temp.act_as('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select throws_ok($$ select public.create_booking('bbbbbbbb-4000-0000-0000-000000000001', now() + interval '1 hour', 4, '[]', gen_random_uuid()) $$,
  '42501', 'phone_not_verified', 'sin celular verificado no se reserva');
select throws_ok($$ select public.request_phone_code('12345') $$, '22023', 'invalid_phone',
  'solo celulares peruanos');
select is(public.request_phone_code('987 654 321') ->> 'phone', '+51987654321',
  'el número se guarda en un solo formato');
select throws_ok($$ select public.request_phone_code('987654321') $$, '54000', 'too_many_requests',
  'no se pide otro código antes de un minuto');
select throws_ok($$ select public.verify_phone_code('000000') $$, '22023', 'wrong_code',
  'un código equivocado se rechaza');
select throws_ok($$ update public.profiles set phone_verified_at = now() where id = '22222222-2222-2222-2222-222222222222' $$,
  '42501', null, 'la app no puede marcarse verificada a mano');
select is(public.verify_phone_code(' 123456 '), '+51987654321', 'el código demo verifica el celular');
select lives_ok($$ select public.create_booking('bbbbbbbb-4000-0000-0000-000000000001', now() + interval '1 hour', 4, '[]', gen_random_uuid()) $$,
  'con el celular verificado, reserva');
reset role;

select is((select count(*)::int from private.phone_codes), 0, 'el código usado se borra');

select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select throws_ok($$ select public.request_phone_code('987654321') $$, '23505', 'phone_in_use',
  'un celular verificado no se usa en otra cuenta');
reset role;

-- Cinco intentos fallidos agotan el código.
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select public.request_phone_code('912345678');
reset role;
update private.phone_codes set attempts = 5 where user_id = '33333333-3333-3333-3333-333333333333';
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select throws_ok($$ select public.verify_phone_code('123456') $$, '54000', 'too_many_attempts',
  'tras 5 intentos fallidos hay que pedir otro código');
reset role;

-- Una cuenta bloqueada sin celular recibe "bloqueada", no "verifica tu celular".
update public.profiles set is_blocked = true where id = '33333333-3333-3333-3333-333333333333';
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select throws_ok($$ select public.create_booking('bbbbbbbb-4000-0000-0000-000000000001', now() + interval '2 hours', 4, '[]', gen_random_uuid()) $$,
  '42501', 'account_blocked', 'el bloqueo responde antes que el celular');
reset role;

-- Con un proveedor real todavía no conectado, no se finge el envío.
update private.app_settings set value = '"twilio"' where key = 'otp_provider';
delete from private.phone_codes;
select pg_temp.act_as('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select throws_ok($$ select public.request_phone_code('912345678') $$, '55000', 'otp_provider_not_ready',
  'sin conector real de SMS, pedir un código falla en vez de fingir');
reset role;

select * from finish();
rollback;
