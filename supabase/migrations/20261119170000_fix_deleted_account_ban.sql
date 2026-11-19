-- Al Paso — cuenta eliminada sin "infinity" (etapa 6, corrección)
--
-- delete_my_account marcaba banned_until = 'infinity'. El servicio de
-- cuentas (GoTrue) no sabe leer ese valor y respondía con error 500 a
-- cualquier pedido de esa cuenta, por ejemplo al cerrar la sesión. Ahora se
-- usa una fecha lejana, y las cuentas ya eliminadas se corrigen.

update auth.users set banned_until = '2999-12-31 00:00:00+00'
 where banned_until = 'infinity';

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  -- Primero se resuelve lo que está en curso.
  if exists (select 1 from public.bookings
              where customer_id = v_user_id
                and status in ('pending_payment', 'confirmed', 'checked_in')) then
    raise exception 'active_bookings' using errcode = '55000';
  end if;
  if exists (select 1 from public.lodging_members
              where user_id = v_user_id and role = 'owner') then
    raise exception 'owns_lodgings' using errcode = '55000';
  end if;

  -- Deja de ser personal de cualquier hostal.
  delete from public.lodging_members where user_id = v_user_id;
  delete from public.lodging_payout_accounts where updated_by = v_user_id;

  -- El perfil queda sin datos personales y bloqueado.
  update public.profiles
     set full_name = '', is_blocked = true
   where id = v_user_id;

  -- La cuenta queda sin correo, sin contraseña y sin forma de entrar. Las
  -- reservas pagadas siguen apuntando a ella como registro de dinero.
  update auth.users
     set email = 'eliminada+' || v_user_id::text || '@cuenta.invalid',
         encrypted_password = null,
         phone = null,
         raw_user_meta_data = '{}'::jsonb,
         -- Una fecha lejana: el servicio de cuentas no sabe leer 'infinity'.
         banned_until = '2999-12-31 00:00:00+00'::timestamptz,
         updated_at = now()
   where id = v_user_id;
  delete from auth.identities where user_id = v_user_id;
  delete from auth.sessions where user_id = v_user_id;
  delete from auth.refresh_tokens where user_id = v_user_id::text;

  perform private.audit('delete_my_account', 'auth.users', v_user_id::text);
end;
$$;

