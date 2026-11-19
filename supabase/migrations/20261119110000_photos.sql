-- Al Paso — fotos del hostal y de cada tipo de cuarto (etapa 2, parte 2D)
--
-- Qué crea:
--   · almacenamiento "lodging-photos"   los archivos, en carpetas por hostal
--   · public.lodging_photos             fotos del hostal (fachada, recepción…)
--   · public.room_type_photos           fotos de cada tipo de cuarto, con su
--                                        etiqueta: habitación, baño o jacuzzi
--   · private.lodging_missing()         ahora exige fotos para publicar
--
-- Reglas que este archivo deja fijas:
--   · Solo el dueño sube o borra fotos, y solo en la carpeta de su hostal.
--   · Una fila de foto solo puede apuntar a un archivo que ya existe en la
--     carpeta de su hostal.
--   · Para enviar a revisión: al menos una foto del hostal y, en cada tipo de
--     cuarto listo, una de la habitación, una del baño y una del jacuzzi si
--     lo tiene (docs/ESTRUCTURA.md, sección 7).

-- ──────────────────────────────────────────────────────────── almacenamiento
-- Lectura pública: las fotos de un hostal publicado las ve cualquiera, y las
-- direcciones llevan identificadores imposibles de adivinar. 5 MB por foto;
-- la app las reduce antes de subirlas.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('lodging-photos', 'lodging-photos', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp']);

-- Convierte texto en uuid sin fallar. Nulo si no es un uuid.
create function private.try_uuid(p_value text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  return p_value::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;
revoke all on function private.try_uuid(text) from public, anon;
grant execute on function private.try_uuid(text) to authenticated;

-- Carpeta = id del hostal: "<lodging_id>/<archivo>".
create policy lodging_photos_insert_owner
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'lodging-photos'
    and (select private.is_lodging_owner(private.try_uuid((storage.foldername(name))[1])))
  );

-- El almacenamiento necesita ver el archivo para borrarlo.
create policy lodging_photos_select_owner
  on storage.objects for select to authenticated
  using (
    bucket_id = 'lodging-photos'
    and (select private.is_lodging_owner(private.try_uuid((storage.foldername(name))[1])))
  );

create policy lodging_photos_delete_owner
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'lodging-photos'
    and (select private.is_lodging_owner(private.try_uuid((storage.foldername(name))[1])))
  );

-- ─────────────────────────────────────────────────────────────────── tablas
create table public.lodging_photos (
  id uuid primary key default gen_random_uuid(),
  lodging_id uuid not null references public.lodgings (id) on delete cascade,
  storage_path text not null unique,
  sort_order smallint not null default 0,
  created_at timestamptz not null default now(),
  check (storage_path like lodging_id::text || '/%')
);

comment on table public.lodging_photos is
  'Fotos del hostal. El archivo vive en el almacenamiento lodging-photos.';

create index lodging_photos_lodging_idx on public.lodging_photos (lodging_id);

create table public.room_type_photos (
  id uuid primary key default gen_random_uuid(),
  room_type_id uuid not null,
  lodging_id uuid not null,
  kind text not null check (kind in ('room', 'bathroom', 'jacuzzi', 'other')),
  storage_path text not null unique,
  sort_order smallint not null default 0,
  created_at timestamptz not null default now(),
  foreign key (room_type_id, lodging_id)
    references public.room_types (id, lodging_id) on delete cascade,
  check (storage_path like lodging_id::text || '/%')
);

comment on table public.room_type_photos is
  'Fotos etiquetadas de cada tipo de cuarto: habitación, baño, jacuzzi u otra.';

create index room_type_photos_type_idx on public.room_type_photos (room_type_id);

-- El archivo debe existir antes que la fila: así una foto publicada nunca
-- apunta a la nada.
create function private.check_photo_object()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from storage.objects o
     where o.bucket_id = 'lodging-photos' and o.name = new.storage_path
  ) then
    raise exception 'photo_not_uploaded' using errcode = '23503';
  end if;
  return new;
end;
$$;
revoke all on function private.check_photo_object() from public, anon, authenticated;

create trigger lodging_photos_check_object
  before insert on public.lodging_photos
  for each row execute function private.check_photo_object();

create trigger room_type_photos_check_object
  before insert on public.room_type_photos
  for each row execute function private.check_photo_object();

-- ────────────────────────────────────────────────────────────────── permisos
alter table public.lodging_photos enable row level security;
revoke all on table public.lodging_photos from public, anon, authenticated;
grant select on table public.lodging_photos to anon, authenticated;
grant insert (lodging_id, storage_path, sort_order) on table public.lodging_photos to authenticated;
grant update (sort_order) on table public.lodging_photos to authenticated;
grant delete on table public.lodging_photos to authenticated;

create policy lodging_photos_select_public
  on public.lodging_photos for select to anon, authenticated
  using ((select private.is_lodging_published(lodging_id)));
create policy lodging_photos_select_staff
  on public.lodging_photos for select to authenticated
  using ((select private.is_lodging_member(lodging_id)) or (select private.is_admin()));
create policy lodging_photos_insert_owner
  on public.lodging_photos for insert to authenticated
  with check ((select private.is_lodging_owner(lodging_id)));
create policy lodging_photos_update_owner
  on public.lodging_photos for update to authenticated
  using ((select private.is_lodging_owner(lodging_id)))
  with check ((select private.is_lodging_owner(lodging_id)));
create policy lodging_photos_delete_owner
  on public.lodging_photos for delete to authenticated
  using ((select private.is_lodging_owner(lodging_id)));

alter table public.room_type_photos enable row level security;
revoke all on table public.room_type_photos from public, anon, authenticated;
grant select on table public.room_type_photos to anon, authenticated;
grant insert (room_type_id, lodging_id, kind, storage_path, sort_order)
  on table public.room_type_photos to authenticated;
grant update (kind, sort_order) on table public.room_type_photos to authenticated;
grant delete on table public.room_type_photos to authenticated;

create policy room_type_photos_select_public
  on public.room_type_photos for select to anon, authenticated
  using ((select private.is_lodging_published(lodging_id)));
create policy room_type_photos_select_staff
  on public.room_type_photos for select to authenticated
  using ((select private.is_lodging_member(lodging_id)) or (select private.is_admin()));
create policy room_type_photos_insert_owner
  on public.room_type_photos for insert to authenticated
  with check ((select private.is_lodging_owner(lodging_id)));
create policy room_type_photos_update_owner
  on public.room_type_photos for update to authenticated
  using ((select private.is_lodging_owner(lodging_id)))
  with check ((select private.is_lodging_owner(lodging_id)));
create policy room_type_photos_delete_owner
  on public.room_type_photos for delete to authenticated
  using ((select private.is_lodging_owner(lodging_id)));

-- ───────────────────────────────────────────── qué falta para publicar
-- Se reemplaza la versión de 2A: ahora también exige fotos.
create or replace function private.lodging_missing(p_lodging_id uuid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select array_remove(array[
    case when not exists (
      select 1 from public.lodging_photos f where f.lodging_id = p_lodging_id
    ) then 'lodging_photo' end,
    case when not exists (
      select 1 from public.room_types t
       where t.lodging_id = p_lodging_id and t.is_active
         and exists (select 1 from public.rates r where r.room_type_id = t.id)
         and exists (select 1 from public.rooms u where u.room_type_id = t.id and u.is_active)
    ) then 'room_type_ready' end,
    -- Todo tipo de cuarto activo con precio debe tener sus fotos.
    case when exists (
      select 1 from public.room_types t
       where t.lodging_id = p_lodging_id and t.is_active
         and exists (select 1 from public.rates r where r.room_type_id = t.id)
         and (
           not exists (select 1 from public.room_type_photos f
                        where f.room_type_id = t.id and f.kind = 'room')
           or not exists (select 1 from public.room_type_photos f
                           where f.room_type_id = t.id and f.kind = 'bathroom')
           or (t.has_jacuzzi and not exists (
                 select 1 from public.room_type_photos f
                  where f.room_type_id = t.id and f.kind = 'jacuzzi'))
         )
    ) then 'room_type_photos' end
  ], null);
$$;
