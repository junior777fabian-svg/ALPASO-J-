-- Al Paso — verificación de celular antes de la primera reserva (módulo C1)
--
-- Qué crea:
--   · profiles.phone, profiles.phone_verified_at
--   · private.phone_codes            códigos pendientes, guardados como hash
--   · public.request_phone_code()    pide un código para un celular peruano
--   · public.verify_phone_code()     lo comprueba y deja el celular verificado
--   · create_booking exige el celular verificado
--
-- Conector (docs/ESTRUCTURA.md, sección 9): con otp_provider = 'demo' el
-- código es siempre 123456 y la respuesta lo dice, para que la app lo
-- muestre con el rótulo DEMO. Con un proveedor real, el envío lo hará una
-- función del servidor (etapa 8); mientras no exista, pedir un código falla
-- en vez de fingir que se envió.

insert into private.app_settings (key, value, is_public, description) values
  ('require_phone_verification', 'true', true,
   'Si hay que verificar el celular antes de la primera reserva.');

alter table public.profiles add column phone text check (phone ~ '^\+519[0-9]{8}$');
alter table public.profiles add column phone_verified_at timestamptz;
create unique index profiles_phone_idx on public.profiles (phone) where phone is not null;

create table private.phone_codes (
  user_id uuid primary key references auth.users (id) on delete cascade,
  phone text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  attempts smallint not null default 0,
  sent_at timestamptz not null default now()
);
alter table private.phone_codes enable row level security;
revoke all on table private.phone_codes from public, anon, authenticated;

-- +51 9XX XXX XXX en cualquier formato → +519XXXXXXXX. Nulo si no es un
-- celular peruano.
create function private.normalize_pe_mobile(p_phone text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when d ~ '^9[0-9]{8}$' then '+51' || d
    when d ~ '^519[0-9]{8}$' then '+' || d
    else null end
    from (select regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g') as d) x;
$$;
revoke all on function private.normalize_pe_mobile(text) from public, anon, authenticated;

create function public.request_phone_code(p_phone text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_phone text := private.normalize_pe_mobile(p_phone);
  v_provider text := coalesce(private.setting('otp_provider') #>> '{}', 'demo');
  v_code text;
  v_last timestamptz;
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if v_phone is null then
    raise exception 'invalid_phone' using errcode = '22023';
  end if;
  if exists (select 1 from public.profiles
              where phone = v_phone and id <> v_user_id and phone_verified_at is not null) then
    raise exception 'phone_in_use' using errcode = '23505';
  end if;
  select sent_at into v_last from private.phone_codes where user_id = v_user_id;
  if v_last > now() - interval '60 seconds' then
    raise exception 'too_many_requests' using errcode = '54000';
  end if;

  if v_provider <> 'demo' then
    -- El envío real llega con el conector de SMS (etapa 8).
    raise exception 'otp_provider_not_ready' using errcode = '55000';
  end if;
  v_code := '123456';

  insert into private.phone_codes (user_id, phone, code_hash, expires_at)
  values (v_user_id, v_phone, extensions.crypt(v_code, extensions.gen_salt('bf')),
          now() + interval '10 minutes')
  on conflict (user_id) do update
     set phone = excluded.phone, code_hash = excluded.code_hash,
         expires_at = excluded.expires_at, attempts = 0, sent_at = now();

  return jsonb_build_object('phone', v_phone, 'provider', v_provider,
                            -- Solo en demo: la app lo muestra rotulado.
                            'demo_code', v_code);
end;
$$;

comment on function public.request_phone_code(text) is
  'Pide un código para verificar un celular peruano. En demo el código es 123456.';
revoke all on function public.request_phone_code(text) from public, anon;
grant execute on function public.request_phone_code(text) to authenticated;

create function public.verify_phone_code(p_code text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_row private.phone_codes;
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  select * into v_row from private.phone_codes where user_id = v_user_id for update;
  if not found or v_row.expires_at < now() then
    raise exception 'code_expired' using errcode = 'P0002';
  end if;
  if v_row.attempts >= 5 then
    raise exception 'too_many_attempts' using errcode = '54000';
  end if;
  if v_row.code_hash <> extensions.crypt(btrim(coalesce(p_code, '')), v_row.code_hash) then
    update private.phone_codes set attempts = attempts + 1 where user_id = v_user_id;
    raise exception 'wrong_code' using errcode = '22023';
  end if;

  update public.profiles set phone = v_row.phone, phone_verified_at = now() where id = v_user_id;
  delete from private.phone_codes where user_id = v_user_id;
  return v_row.phone;
exception
  when unique_violation then
    raise exception 'phone_in_use' using errcode = '23505';
end;
$$;

comment on function public.verify_phone_code(text) is 'Comprueba el código y deja el celular verificado.';
revoke all on function public.verify_phone_code(text) from public, anon;
grant execute on function public.verify_phone_code(text) to authenticated;

-- create_booking: además de la mayoría de edad, el celular verificado.
-- Se envuelve la función existente para no repetir su lógica.
alter function public.create_booking(uuid, timestamptz, integer, jsonb, uuid)
  rename to create_booking_checked;
revoke all on function public.create_booking_checked(uuid, timestamptz, integer, jsonb, uuid)
  from public, anon, authenticated;
alter function public.create_booking_checked(uuid, timestamptz, integer, jsonb, uuid)
  set schema private;

create function public.create_booking(
  p_room_type_id uuid,
  p_arrival timestamptz,
  p_block_hours integer,
  p_items jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Primero la mayoría de edad (la revisa la función de adentro), después
  -- el celular.
  if (select auth.uid()) is not null
     -- El bloqueo y la mayoría de edad responden primero.
     and exists (select 1 from public.profiles
                  where id = (select auth.uid()) and adult_confirmed_at is not null
                    and not is_blocked)
     and coalesce((private.setting('require_phone_verification'))::boolean, true)
     and not exists (select 1 from public.profiles
                      where id = (select auth.uid()) and phone_verified_at is not null)
     -- Un reintento de una reserva ya creada no se bloquea.
     and not exists (select 1 from public.bookings
                      where customer_id = (select auth.uid()) and idempotency_key = p_idempotency_key) then
    raise exception 'phone_not_verified' using errcode = '42501';
  end if;
  return private.create_booking_checked(p_room_type_id, p_arrival, p_block_hours, p_items, p_idempotency_key);
end;
$$;

comment on function public.create_booking(uuid, timestamptz, integer, jsonb, uuid) is
  'Reserva en una transacción. Exige mayoría de edad y celular verificado.';
revoke all on function public.create_booking(uuid, timestamptz, integer, jsonb, uuid) from public, anon;
grant execute on function public.create_booking(uuid, timestamptz, integer, jsonb, uuid) to authenticated;
