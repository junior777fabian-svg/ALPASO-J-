-- Perfiles: se crean solos, cada cuenta ve y edita solo el suyo, y nada de lo
-- que envía la app puede otorgar permisos.
begin;
select plan(20);

-- ana pide en el registro ser admin y venir bloqueada: debe ignorarse.
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.test',
   '{"full_name": "  Ana Pérez  ", "role": "admin", "is_blocked": true, "adult_confirmed_at": "2020-01-01"}'),
  ('22222222-2222-2222-2222-222222222222', 'luis@example.test', '{}'),
  ('33333333-3333-3333-3333-333333333333', 'admin@example.test',
   jsonb_build_object('full_name', repeat('x', 200)));

insert into private.admins (user_id)
values ('33333333-3333-3333-3333-333333333333');

-- ── creación automática ───────────────────────────────────────────────────

select is(
  (select count(*) from public.profiles
    where id in ('11111111-1111-1111-1111-111111111111',
                 '22222222-2222-2222-2222-222222222222',
                 '33333333-3333-3333-3333-333333333333')),
  3::bigint,
  'registrarse crea el perfil'
);

select is(
  (select full_name from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  'Ana Pérez',
  'toma el nombre del registro sin espacios sobrantes'
);

select is(
  (select char_length(full_name) from public.profiles where id = '33333333-3333-3333-3333-333333333333'),
  80,
  'recorta un nombre demasiado largo'
);

select is(
  (select full_name from public.profiles where id = '22222222-2222-2222-2222-222222222222'),
  '',
  'sin nombre en el registro, el perfil nace con nombre vacío'
);

select is(
  (select is_blocked from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  false,
  'el registro no puede decidir el bloqueo'
);

select is(
  (select adult_confirmed_at from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  null,
  'el registro no puede fijar la mayoría de edad'
);

select is(
  (select count(*) from private.admins where user_id = '11111111-1111-1111-1111-111111111111'),
  0::bigint,
  'pedir rol admin en el registro no convierte a nadie en administrador'
);

-- ── ana, con sesión ───────────────────────────────────────────────────────

select set_config('request.jwt.claims',
  '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
set local role authenticated;

select results_eq(
  'select id from public.profiles',
  array['11111111-1111-1111-1111-111111111111'::uuid],
  'una cuenta solo ve su propio perfil'
);

select lives_ok(
  $$ update public.profiles set full_name = 'Ana P.' where id = '11111111-1111-1111-1111-111111111111' $$,
  'puede cambiar su nombre'
);

select throws_ok(
  $$ update public.profiles set is_blocked = true $$,
  '42501', null,
  'no puede bloquearse ni desbloquearse'
);

select throws_ok(
  $$ update public.profiles set adult_confirmed_at = now() $$,
  '42501', null,
  'no puede fijar a mano la mayoría de edad'
);

select throws_ok(
  $$ insert into public.profiles (id) values (gen_random_uuid()) $$,
  '42501', null,
  'no puede crear perfiles'
);

select throws_ok(
  $$ delete from public.profiles $$,
  '42501', null,
  'no puede borrar perfiles'
);

-- Intenta renombrar a luis: no da error, pero no debe tocar ninguna fila.
update public.profiles set full_name = 'intruso'
 where id = '22222222-2222-2222-2222-222222222222';

select ok(
  public.confirm_adult() is not null,
  'confirm_adult registra la mayoría de edad'
);

reset role;

select is(
  (select full_name from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  'Ana P.',
  'el cambio de nombre quedó guardado'
);

select is(
  (select full_name from public.profiles where id = '22222222-2222-2222-2222-222222222222'),
  '',
  'no puede cambiar el perfil de otra cuenta'
);

-- ── confirm_adult conserva la primera fecha ───────────────────────────────

-- Se apagan los disparadores solo para fijar una fecha antigua de partida.
set local session_replication_role = replica;
update public.profiles
   set adult_confirmed_at = '2024-05-01 10:00:00+00', updated_at = '2024-05-01 10:00:00+00'
 where id = '11111111-1111-1111-1111-111111111111';
set local session_replication_role = origin;

set local role authenticated;

select is(
  public.confirm_adult(),
  '2024-05-01 10:00:00+00'::timestamptz,
  'repetir confirm_adult no cambia la fecha original'
);

reset role;

select ok(
  (select updated_at > '2025-01-01'::timestamptz from public.profiles
    where id = '11111111-1111-1111-1111-111111111111'),
  'updated_at se actualiza solo en cada cambio'
);

-- ── administrador ─────────────────────────────────────────────────────────

select set_config('request.jwt.claims',
  '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}', true);
set local role authenticated;

select is(
  (select count(*) from public.profiles
    where id in ('11111111-1111-1111-1111-111111111111',
                 '22222222-2222-2222-2222-222222222222',
                 '33333333-3333-3333-3333-333333333333')),
  3::bigint,
  'un administrador ve todos los perfiles'
);

reset role;

-- ── sin sesión ────────────────────────────────────────────────────────────

select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;

select throws_ok(
  'select * from public.profiles',
  '42501', null,
  'sin sesión no se leen perfiles'
);

reset role;

select * from finish();
rollback;
