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

select results_eq(
  $$ select (table_schema || '.' || table_name || ':' || privilege_type)::text collate "default"
       from information_schema.role_table_grants
      where grantee in ('anon', 'PUBLIC')
        and table_schema in ('public', 'private')
      order by 1 $$,
  $$ values ('public.districts:SELECT'), ('public.lodgings:SELECT'),
            ('public.products:SELECT'), ('public.rates:SELECT'),
            ('public.room_types:SELECT') $$,
  'sin sesión solo se lee la oferta (y RLS deja ver solo lo publicado)'
);

select results_eq(
  $$ select (table_schema || '.' || table_name || ':' || privilege_type)::text collate "default"
       from information_schema.role_table_grants
      where grantee = 'authenticated'
        and table_schema in ('public', 'private')
      order by 1 $$,
  $$ values ('public.districts:SELECT'),
            ('public.lodging_members:SELECT'), ('public.lodgings:SELECT'),
            ('public.products:DELETE'), ('public.products:SELECT'),
            ('public.profiles:SELECT'),
            ('public.rates:DELETE'), ('public.rates:SELECT'),
            ('public.room_types:DELETE'), ('public.room_types:SELECT'),
            ('public.rooms:DELETE'), ('public.rooms:SELECT') $$,
  'una cuenta solo tiene los permisos de tabla previstos'
);

select results_eq(
  $$ select (table_name || '.' || column_name)::text collate "default"
       from information_schema.role_column_grants
      where grantee = 'authenticated'
        and table_schema in ('public', 'private')
        and privilege_type in ('UPDATE', 'INSERT')
      order by 1 $$,
  $$ values
    ('lodgings.address'), ('lodgings.address_reference'),
    ('lodgings.cleaning_minutes'), ('lodgings.description'),
    ('lodgings.district_id'), ('lodgings.has_parking'), ('lodgings.has_wifi'),
    ('lodgings.latitude'), ('lodgings.longitude'), ('lodgings.name'),
    ('products.category'), ('products.category'),
    ('products.description'), ('products.description'),
    ('products.is_available'), ('products.is_available'),
    ('products.lodging_id'),
    ('products.name'), ('products.name'),
    ('products.price_cents'), ('products.price_cents'),
    ('profiles.full_name'),
    ('rates.block_hours'), ('rates.lodging_id'),
    ('rates.price_cents'), ('rates.price_cents'), ('rates.room_type_id'),
    ('room_types.description'), ('room_types.description'),
    ('room_types.has_air_conditioning'), ('room_types.has_air_conditioning'),
    ('room_types.has_jacuzzi'), ('room_types.has_jacuzzi'),
    ('room_types.has_tv'), ('room_types.has_tv'),
    ('room_types.is_active'), ('room_types.is_active'),
    ('room_types.lodging_id'),
    ('room_types.max_guests'), ('room_types.max_guests'),
    ('room_types.name'), ('room_types.name'),
    ('rooms.is_active'), ('rooms.is_active'), ('rooms.label'), ('rooms.label'),
    ('rooms.lodging_id'), ('rooms.room_type_id'), ('rooms.room_type_id')
  $$,
  'las columnas que una cuenta puede escribir son solo las previstas (nunca estados, dueños ni hostal de una fila)'
);

select results_eq(
  $$ select p.proname::text collate "default"
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'private')
        and has_function_privilege('anon', p.oid, 'execute')
      order by 1 $$,
  $$ values ('get_public_settings'), ('is_lodging_published') $$,
  'sin sesión solo se ejecutan get_public_settings e is_lodging_published'
);

select results_eq(
  $$ select (n.nspname || '.' || p.proname)::text collate "default"
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'private')
        and has_function_privilege('authenticated', p.oid, 'execute')
      order by 1 $$,
  $$ values ('private.is_admin'), ('private.is_lodging_member'),
            ('private.is_lodging_owner'), ('private.is_lodging_published'),
            ('private.lodging_role'),
            ('public.admin_review_lodging'), ('public.confirm_adult'),
            ('public.create_lodging'), ('public.get_public_settings'),
            ('public.save_room_type'), ('public.submit_lodging') $$,
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
