-- Configuración y administradores: la app solo conoce lo marcado como público
-- y nadie puede nombrarse administrador desde la API.
begin;
select plan(13);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'ana@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'admin@example.test');

insert into private.admins (user_id)
values ('33333333-3333-3333-3333-333333333333');

insert into private.app_settings (key, value, is_public)
values ('dato_interno', '"no debe salir"', false);

select throws_ok(
  $$ insert into private.app_settings (key, value) values ('Clave Mala', '1') $$,
  '23514', null,
  'las claves de configuración van en minúsculas y sin espacios'
);

-- ── sin sesión ────────────────────────────────────────────────────────────

select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;

select is(
  public.get_public_settings() ->> 'payments_provider',
  'demo',
  'los pagos arrancan en demo'
);

select is(
  public.get_public_settings() ->> 'otp_provider',
  'demo',
  'la verificación de celular arranca en demo'
);

select ok(
  not (public.get_public_settings() ? 'dato_interno'),
  'la configuración privada no sale por get_public_settings'
);

select throws_ok(
  'select * from private.app_settings',
  '42501', null,
  'sin sesión no se lee la tabla de configuración'
);

select throws_ok(
  'select private.is_admin()',
  '42501', null,
  'sin sesión no se puede preguntar quién es administrador'
);

select throws_ok(
  'select public.confirm_adult()',
  '42501', null,
  'sin sesión no se puede confirmar la mayoría de edad'
);

reset role;

-- ── cuenta común ──────────────────────────────────────────────────────────

select set_config('request.jwt.claims',
  '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
set local role authenticated;

select is(private.is_admin(), false, 'una cuenta común no es administradora');

select throws_ok(
  $$ insert into private.admins (user_id) values ('11111111-1111-1111-1111-111111111111') $$,
  '42501', null,
  'nadie se nombra administrador desde la API'
);

select throws_ok(
  'select * from private.admins',
  '42501', null,
  'una cuenta no puede listar a los administradores'
);

select throws_ok(
  $$ update private.app_settings set value = '"culqi"' where key = 'payments_provider' $$,
  '42501', null,
  'una cuenta no puede cambiar la configuración'
);

select is(
  public.get_public_settings() ->> 'payments_provider',
  'demo',
  'una cuenta con sesión también lee la configuración pública'
);

reset role;

-- ── administrador ─────────────────────────────────────────────────────────

select set_config('request.jwt.claims',
  '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}', true);
set local role authenticated;

select is(private.is_admin(), true, 'quien está en private.admins es administrador');

reset role;

select * from finish();
rollback;
