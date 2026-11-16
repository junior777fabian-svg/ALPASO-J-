-- Vigilancia general: reglas que deben cumplirse para TODA tabla y función,
-- también las que se agreguen en etapas futuras.
--
-- Los nombres del catálogo de Postgres usan otra colación que los textos
-- comunes; por eso cada consulta los convierte con collate "default" antes de
-- compararlos.
begin;
select plan(8);

select is_empty(
  $$ select n.nspname || '.' || c.relname
       from pg_class c
       join pg_namespace n on n.oid = c.relnamespace
      where n.nspname in ('public', 'private')
        and c.relkind in ('r', 'p')
        and not c.relrowsecurity $$,
  'toda tabla de public y private tiene RLS activo'
);

select is_empty(
  $$ select p.oid::regprocedure::text
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'private')
        and p.prosecdef
        and not exists (
          select 1 from unnest(coalesce(p.proconfig, '{}')) c
           where c like 'search_path=%'
        ) $$,
  'toda función security definer fija su search_path'
);

select is_empty(
  $$ select table_schema || '.' || table_name || ':' || privilege_type
       from information_schema.role_table_grants
      where grantee in ('anon', 'PUBLIC')
        and table_schema in ('public', 'private') $$,
  'sin sesión no hay permisos sobre ninguna tabla'
);

select results_eq(
  $$ select (table_schema || '.' || table_name || ':' || privilege_type)::text collate "default"
       from information_schema.role_table_grants
      where grantee = 'authenticated'
        and table_schema in ('public', 'private')
      order by 1 $$,
  $$ values ('public.profiles:SELECT') $$,
  'una cuenta solo tiene permiso de lectura sobre profiles'
);

select results_eq(
  $$ select (table_name || '.' || column_name)::text collate "default"
       from information_schema.role_column_grants
      where grantee = 'authenticated'
        and table_schema in ('public', 'private')
        and privilege_type in ('UPDATE', 'INSERT')
      order by 1 $$,
  $$ values ('profiles.full_name') $$,
  'la única columna que una cuenta puede escribir es su nombre'
);

select results_eq(
  $$ select p.proname::text collate "default"
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'private')
        and has_function_privilege('anon', p.oid, 'execute')
      order by 1 $$,
  $$ values ('get_public_settings') $$,
  'sin sesión solo se puede ejecutar get_public_settings'
);

select results_eq(
  $$ select (n.nspname || '.' || p.proname)::text collate "default"
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'private')
        and has_function_privilege('authenticated', p.oid, 'execute')
      order by 1 $$,
  $$ values ('private.is_admin'), ('public.confirm_adult'), ('public.get_public_settings') $$,
  'una cuenta solo puede ejecutar las funciones previstas'
);

select is_empty(
  $$ select n.nspname
       from pg_namespace n
      where n.nspname = 'private'
        and has_schema_privilege('anon', n.oid, 'create') $$,
  'nadie externo puede crear objetos en private'
);

select * from finish();
rollback;
