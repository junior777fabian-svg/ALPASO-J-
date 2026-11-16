-- Al Paso — base de identidad
--
-- Qué crea:
--   · private            esquema para lo que la API nunca debe exponer
--   · public.profiles    un perfil por cuenta, creado solo al registrarse
--   · private.admins     quién es administrador
--   · private.app_settings   configuración de la plataforma
--   · public.confirm_adult()         la cuenta declara ser mayor de edad
--   · public.get_public_settings()   lo que la app puede saber de la configuración
--
-- Reglas que este archivo deja fijas:
--   · Toda tabla tiene seguridad por fila (RLS) activa.
--   · Los permisos se otorgan uno por uno; nada queda abierto por omisión.
--   · Nadie puede darse a sí mismo el rol de administrador ni desbloquearse.

-- ───────────────────────────────────────────────────────────── esquema privado

create schema if not exists private;

revoke all on schema private from public;
-- Las políticas de `public` llaman funciones de `private` cuando consulta una
-- cuenta con sesión, así que ese rol necesita poder nombrar el esquema. No
-- puede leer sus tablas: la API no lo expone y cada tabla revoca sus permisos
-- más abajo. Sin sesión no hay acceso al esquema.
grant usage on schema private to authenticated;

-- Postgres deja ejecutar a cualquiera toda función nueva. Ese permiso no se
-- puede quitar por esquema, así que cada función de este archivo lo revoca
-- una por una. La prueba 01_security_baseline lo vigila.

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function private.set_updated_at() from public, anon, authenticated;

-- ──────────────────────────────────────────────────────────── administradores

create table private.admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

comment on table private.admins is
  'Cuentas con rol de administrador. Solo se modifica desde el servidor.';

alter table private.admins enable row level security;
revoke all on table private.admins from public, anon, authenticated;

-- `security definer` porque quien pregunta no puede leer private.admins.
create function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from private.admins a where a.user_id = (select auth.uid())
  );
$$;

revoke all on function private.is_admin() from public, anon;
grant execute on function private.is_admin() to authenticated;

-- ──────────────────────────────────────────────────────────────────── perfiles

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '' check (char_length(full_name) <= 80),
  -- Momento en que la cuenta declaró ser mayor de 18. Nulo = aún no lo hizo.
  adult_confirmed_at timestamptz,
  is_blocked boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Un perfil por cuenta. Se crea solo al registrarse.';

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function private.set_updated_at();

alter table public.profiles enable row level security;

-- Permisos columna por columna: la cuenta puede leer su perfil y cambiar su
-- nombre. `is_blocked` y `adult_confirmed_at` solo cambian por funciones del
-- servidor.
revoke all on table public.profiles from public, anon, authenticated;
grant select on table public.profiles to authenticated;
grant update (full_name) on table public.profiles to authenticated;

create policy profiles_select_own_or_admin
  on public.profiles
  for select
  to authenticated
  using (id = (select auth.uid()) or (select private.is_admin()));

create policy profiles_update_own
  on public.profiles
  for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Crea el perfil cuando nace la cuenta. Del registro solo se toma el nombre:
-- nada de lo que envía la app puede decidir roles o permisos.
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    left(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), 80)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function private.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- La cuenta declara ser mayor de edad. Guarda el primer momento en que lo
-- hizo; repetir la llamada no lo cambia.
create function public.confirm_adult()
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_confirmed_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  update public.profiles
     set adult_confirmed_at = coalesce(adult_confirmed_at, now())
   where id = v_user_id
  returning adult_confirmed_at into v_confirmed_at;

  if not found then
    raise exception 'profile_not_found' using errcode = 'P0002';
  end if;

  return v_confirmed_at;
end;
$$;

comment on function public.confirm_adult() is
  'La cuenta en sesión declara ser mayor de 18 años.';

revoke all on function public.confirm_adult() from public, anon;
grant execute on function public.confirm_adult() to authenticated;

-- ───────────────────────────────────────────────────────────── configuración

create table private.app_settings (
  key text primary key check (key ~ '^[a-z][a-z0-9_]*$'),
  value jsonb not null,
  -- Verdadero si la app puede conocer este valor sin iniciar sesión.
  is_public boolean not null default false,
  description text not null default '',
  updated_at timestamptz not null default now()
);

comment on table private.app_settings is
  'Configuración de la plataforma. Solo se modifica desde el servidor.';

create trigger app_settings_set_updated_at
  before update on private.app_settings
  for each row execute function private.set_updated_at();

alter table private.app_settings enable row level security;
revoke all on table private.app_settings from public, anon, authenticated;

-- Los conectores arrancan en demo en cualquier entorno. Producción tiene que
-- cambiarlos a propósito; mientras no lo haga, la app de tiendas no arranca.
insert into private.app_settings (key, value, is_public, description) values
  ('payments_provider', '"demo"', true,
   'Conector de pagos activo: demo, culqi, izipay o mercadopago.'),
  ('otp_provider', '"demo"', true,
   'Conector de verificación de celular activo: demo o el proveedor real.');

create function public.get_public_settings()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(s.key, s.value), '{}'::jsonb)
    from private.app_settings s
   where s.is_public;
$$;

comment on function public.get_public_settings() is
  'Configuración que la app puede leer sin sesión, por ejemplo qué conectores están en demo.';

revoke all on function public.get_public_settings() from public;
grant execute on function public.get_public_settings() to anon, authenticated, service_role;
