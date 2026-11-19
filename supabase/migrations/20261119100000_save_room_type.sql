-- Al Paso — guardar un tipo de cuarto completo (etapa 2, parte 2C)
--
-- Qué crea:
--   · public.save_room_type()   crea o edita un tipo de cuarto con sus tarifas
--                               y sus cuartos, todo o nada
--
-- Por qué una función y no escrituras sueltas: las tarifas y los cuartos se
-- reemplazan juntos. Si la app los escribiera uno por uno, una falla a medias
-- dejaría un tipo de cuarto sin precio o con cuartos de más.

create function public.save_room_type(
  p_lodging_id uuid,
  p_room_type_id uuid,
  p_name text,
  p_description text,
  p_max_guests smallint,
  p_has_jacuzzi boolean,
  p_has_tv boolean,
  p_has_air_conditioning boolean,
  p_is_active boolean,
  -- {"4": 4500, "12": 9000}: horas → céntimos. Los bloques que no vienen se
  -- dejan de vender.
  p_rates jsonb,
  -- Números de cuarto de este tipo. Los que no vienen se quitan.
  p_rooms text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_room_type_id;
  v_labels text[];
  v_taken text;
begin
  if (select auth.uid()) is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not private.is_lodging_owner(p_lodging_id) then
    raise exception 'not_owner' using errcode = '42501';
  end if;
  if jsonb_typeof(coalesce(p_rates, '{}'::jsonb)) <> 'object' then
    raise exception 'invalid_rates' using errcode = '22023';
  end if;

  -- Números de cuarto limpios, en mayúsculas y sin repetir.
  select coalesce(array_agg(distinct upper(btrim(l))), '{}')
    into v_labels
    from unnest(coalesce(p_rooms, '{}')) l
   where btrim(l) <> '';
  if cardinality(v_labels) > 200 then
    raise exception 'too_many_rooms' using errcode = '54000';
  end if;

  -- Un número no puede estar en otro tipo de cuarto del mismo hostal.
  select r.label into v_taken
    from public.rooms r
   where r.lodging_id = p_lodging_id
     and r.label = any (v_labels)
     and (v_id is null or r.room_type_id <> v_id)
   limit 1;
  if v_taken is not null then
    raise exception 'room_label_taken' using errcode = '23505', detail = v_taken;
  end if;

  if v_id is null then
    insert into public.room_types (
      lodging_id, name, description, max_guests, has_jacuzzi, has_tv,
      has_air_conditioning, is_active
    ) values (
      p_lodging_id, btrim(p_name), btrim(coalesce(p_description, '')),
      p_max_guests, p_has_jacuzzi, p_has_tv, p_has_air_conditioning, p_is_active
    )
    returning id into v_id;
  else
    update public.room_types
       set name = btrim(p_name),
           description = btrim(coalesce(p_description, '')),
           max_guests = p_max_guests,
           has_jacuzzi = p_has_jacuzzi,
           has_tv = p_has_tv,
           has_air_conditioning = p_has_air_conditioning,
           is_active = p_is_active
     where id = v_id and lodging_id = p_lodging_id;
    if not found then
      raise exception 'room_type_not_found' using errcode = 'P0002';
    end if;
  end if;

  -- Tarifas: se quitan las que no vienen y se crean o cambian las demás. El
  -- disparador de rates valida que cada bloque esté permitido.
  delete from public.rates r
   where r.room_type_id = v_id
     and not (coalesce(p_rates, '{}'::jsonb) ? r.block_hours::text);

  insert into public.rates (room_type_id, lodging_id, block_hours, price_cents)
  select v_id, p_lodging_id, e.key::smallint, (e.value #>> '{}')::integer
    from jsonb_each(coalesce(p_rates, '{}'::jsonb)) e
  on conflict (room_type_id, block_hours)
  do update set price_cents = excluded.price_cents;

  -- Cuartos: se quitan los que no vienen y se agregan los nuevos.
  delete from public.rooms r
   where r.room_type_id = v_id and not (r.label = any (v_labels));

  insert into public.rooms (lodging_id, room_type_id, label)
  select p_lodging_id, v_id, l
    from unnest(v_labels) l
  on conflict (lodging_id, label) do nothing;

  return v_id;
end;
$$;

comment on function public.save_room_type(uuid, uuid, text, text, smallint, boolean, boolean, boolean, boolean, jsonb, text[]) is
  'El dueño crea o edita un tipo de cuarto con sus tarifas y sus cuartos, todo o nada.';
revoke all on function public.save_room_type(uuid, uuid, text, text, smallint, boolean, boolean, boolean, boolean, jsonb, text[]) from public, anon;
grant execute on function public.save_room_type(uuid, uuid, text, text, smallint, boolean, boolean, boolean, boolean, jsonb, text[]) to authenticated;
