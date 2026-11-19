-- Al Paso — administración, dinero y soporte (etapa 6, parte 6A)
--
-- Qué crea:
--   · public.delete_my_account()        elimina la cuenta y sus datos personales
--   · public.support_cases + create_support_case()   incidencias de soporte
--   · private.audit_log                 registro de acciones sensibles del admin
--   · public.lodging_earnings()         ventas, comisión y neto de un hostal (N7)
--   · public.lodging_payout_accounts    cuenta de destino de las liquidaciones
--   · public.payouts + admin_create_payout() + admin_mark_payout_paid()
--   · public.admin_set_blocked(), admin_refund_booking(), admin_set_lodging_suspended(),
--     admin_resolve_support_case()
--
-- Reglas que este archivo deja fijas (docs/ESTRUCTURA.md, secciones 4, 6.6 y 8):
--   · Eliminar la cuenta borra los datos personales de verdad. Las reservas
--     pagadas se conservan como registro de dinero, sin datos personales.
--   · El administrador no actúa sin dejar registro: cada acción va a
--     private.audit_log.
--   · Una reserva entra a una sola liquidación.

insert into private.app_settings (key, value, is_public, description) values
  ('commission_percent', '10', false,
   'Porcentaje que cobra la plataforma sobre cada reserva, descontado en la liquidación. Decisión abierta (sección 17).');

-- ──────────────────────────────────────────────────────────── auditoría
create table private.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid,
  action text not null,
  target_table text not null,
  target_id text not null,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);

comment on table private.audit_log is 'Acciones sensibles del administrador. Nunca se borra.';
alter table private.audit_log enable row level security;
revoke all on table private.audit_log from public, anon, authenticated;

create function private.audit(p_action text, p_table text, p_id text, p_details jsonb default '{}')
returns void
language sql
security definer
set search_path = ''
as $$
  insert into private.audit_log (actor_id, action, target_table, target_id, details)
  values ((select auth.uid()), p_action, p_table, p_id, coalesce(p_details, '{}'));
$$;
revoke all on function private.audit(text, text, text, jsonb) from public, anon, authenticated;

create function private.require_admin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (private.is_admin() or (select auth.role()) = 'service_role') then
    raise exception 'not_admin' using errcode = '42501';
  end if;
end;
$$;
revoke all on function private.require_admin() from public, anon, authenticated;

-- ─────────────────────────────────────────────────────── eliminar la cuenta
create function public.delete_my_account()
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
         banned_until = 'infinity'::timestamptz,
         updated_at = now()
   where id = v_user_id;
  delete from auth.identities where user_id = v_user_id;
  delete from auth.sessions where user_id = v_user_id;
  delete from auth.refresh_tokens where user_id = v_user_id::text;

  perform private.audit('delete_my_account', 'auth.users', v_user_id::text);
end;
$$;

comment on function public.delete_my_account() is
  'Elimina la cuenta en sesión y sus datos personales. Las reservas pagadas quedan como registro, sin datos personales.';
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ────────────────────────────────────────────────────────────────── soporte
create table public.support_cases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  booking_id uuid references public.bookings (id),
  subject text not null check (char_length(btrim(subject)) between 3 and 120),
  message text not null check (char_length(btrim(message)) between 10 and 2000),
  status text not null default 'open' check (status in ('open', 'resolved')),
  resolution text not null default '' check (char_length(resolution) <= 2000),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

comment on table public.support_cases is 'Incidencias de soporte. Las crea cualquier cuenta; las resuelve el admin.';
create index support_cases_status_idx on public.support_cases (status, created_at);

alter table public.support_cases enable row level security;
revoke all on table public.support_cases from public, anon, authenticated;
grant select on table public.support_cases to authenticated;
create policy support_cases_select on public.support_cases for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()));

create function public.create_support_case(p_subject text, p_message text, p_booking_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_booking_id is not null and not exists (
       select 1 from public.bookings where id = p_booking_id and customer_id = v_user_id) then
    raise exception 'booking_not_found' using errcode = 'P0002';
  end if;
  if (select count(*) from public.support_cases
       where user_id = v_user_id and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'too_many_cases' using errcode = '54000';
  end if;
  insert into public.support_cases (user_id, booking_id, subject, message)
  values (v_user_id, p_booking_id, btrim(p_subject), btrim(p_message))
  returning id into v_id;
  return v_id;
end;
$$;

comment on function public.create_support_case(text, text, uuid) is 'Una cuenta abre una incidencia de soporte, opcionalmente sobre una reserva suya.';
revoke all on function public.create_support_case(text, text, uuid) from public, anon;
grant execute on function public.create_support_case(text, text, uuid) to authenticated;

-- ───────────────────────────────────────────────────── ingresos del hostal
-- Una reserva cuenta para el hostal cuando ya no se puede cancelar con
-- reembolso: terminada, en curso o "no llegó". Lo cobrado menos lo
-- reembolsado es la venta; la comisión se descuenta en la liquidación.
create function private.booking_net_sales(p_booking_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select sum(p.amount_cents) from public.payments p
                    where p.booking_id = p_booking_id and p.status in ('paid', 'refunded')), 0)
       - coalesce((select sum(r.amount_cents) from public.refunds r
                    where r.booking_id = p_booking_id), 0);
$$;
revoke all on function private.booking_net_sales(uuid) from public, anon, authenticated;

create table public.payouts (
  id uuid primary key default gen_random_uuid(),
  lodging_id uuid not null references public.lodgings (id),
  period_end timestamptz not null,
  gross_cents integer not null check (gross_cents >= 0),
  commission_cents integer not null check (commission_cents >= 0),
  net_cents integer not null check (net_cents = gross_cents - commission_cents),
  bookings_count integer not null,
  status text not null default 'pending' check (status in ('pending', 'paid')),
  transfer_reference text not null default '',
  created_by uuid,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);

comment on table public.payouts is 'Liquidaciones a hostales. Las calcula y registra el admin.';

alter table public.bookings add column payout_id uuid references public.payouts (id);
create index bookings_payout_idx on public.bookings (lodging_id) where payout_id is null;

alter table public.payouts enable row level security;
revoke all on table public.payouts from public, anon, authenticated;
grant select on table public.payouts to authenticated;
create policy payouts_select on public.payouts for select to authenticated
  using ((select private.is_lodging_owner(lodging_id)) or (select private.is_admin()));

create function public.lodging_earnings(p_lodging_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_percent numeric := coalesce((private.setting('commission_percent'))::numeric, 10);
  v_gross integer;
  v_count integer;
begin
  if not (private.is_lodging_owner(p_lodging_id) or private.is_admin()) then
    raise exception 'not_owner' using errcode = '42501';
  end if;
  select coalesce(sum(private.booking_net_sales(b.id)), 0), count(*)
    into v_gross, v_count
    from public.bookings b
   where b.lodging_id = p_lodging_id and b.payout_id is null
     and b.status in ('checked_in', 'completed', 'no_show');
  return jsonb_build_object(
    'pending_gross_cents', v_gross,
    'pending_commission_cents', round(v_gross * v_percent / 100)::integer,
    'pending_net_cents', v_gross - round(v_gross * v_percent / 100)::integer,
    'pending_bookings', v_count,
    'commission_percent', v_percent,
    'payouts', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', p.id, 'period_end', p.period_end, 'gross_cents', p.gross_cents,
               'commission_cents', p.commission_cents, 'net_cents', p.net_cents,
               'bookings_count', p.bookings_count, 'status', p.status,
               'paid_at', p.paid_at, 'transfer_reference', p.transfer_reference)
             order by p.created_at desc)
        from public.payouts p where p.lodging_id = p_lodging_id), '[]'));
end;
$$;

comment on function public.lodging_earnings(uuid) is 'Ventas pendientes de liquidar, comisión, neto y liquidaciones de un hostal.';
revoke all on function public.lodging_earnings(uuid) from public, anon;
grant execute on function public.lodging_earnings(uuid) to authenticated;

-- Cuenta de destino. Datos sensibles: solo el dueño y el admin la ven.
create table public.lodging_payout_accounts (
  lodging_id uuid primary key references public.lodgings (id) on delete cascade,
  holder_name text not null check (char_length(btrim(holder_name)) between 3 and 120),
  bank_name text not null check (char_length(btrim(bank_name)) between 2 and 60),
  -- Código de cuenta interbancario: 20 dígitos.
  cci text not null check (cci ~ '^[0-9]{20}$'),
  updated_by uuid not null references auth.users (id),
  updated_at timestamptz not null default now()
);

comment on table public.lodging_payout_accounts is 'Cuenta bancaria de destino de las liquidaciones de cada hostal.';

alter table public.lodging_payout_accounts enable row level security;
revoke all on table public.lodging_payout_accounts from public, anon, authenticated;
grant select on table public.lodging_payout_accounts to authenticated;
create policy payout_accounts_select on public.lodging_payout_accounts for select to authenticated
  using ((select private.is_lodging_owner(lodging_id)) or (select private.is_admin()));

create function public.set_payout_account(p_lodging_id uuid, p_holder text, p_bank text, p_cci text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_lodging_owner(p_lodging_id) then
    raise exception 'not_owner' using errcode = '42501';
  end if;
  insert into public.lodging_payout_accounts (lodging_id, holder_name, bank_name, cci, updated_by)
  values (p_lodging_id, btrim(p_holder), btrim(p_bank), regexp_replace(coalesce(p_cci, ''), '[^0-9]', '', 'g'),
          (select auth.uid()))
  on conflict (lodging_id) do update
     set holder_name = excluded.holder_name, bank_name = excluded.bank_name,
         cci = excluded.cci, updated_by = excluded.updated_by, updated_at = now();
end;
$$;
revoke all on function public.set_payout_account(uuid, text, text, text) from public, anon;
grant execute on function public.set_payout_account(uuid, text, text, text) to authenticated;

create function public.admin_create_payout(p_lodging_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_percent numeric := coalesce((private.setting('commission_percent'))::numeric, 10);
  v_gross integer;
  v_count integer;
  v_commission integer;
  v_payout public.payouts;
begin
  perform private.require_admin();
  -- Bloquea las reservas que entran, para que ninguna entre dos veces.
  perform 1 from public.bookings b
   where b.lodging_id = p_lodging_id and b.payout_id is null
     and b.status in ('checked_in', 'completed', 'no_show')
   for update;
  select coalesce(sum(private.booking_net_sales(b.id)), 0), count(*)
    into v_gross, v_count
    from public.bookings b
   where b.lodging_id = p_lodging_id and b.payout_id is null
     and b.status in ('checked_in', 'completed', 'no_show');
  if v_count = 0 then
    raise exception 'nothing_to_pay' using errcode = '55000';
  end if;
  v_commission := round(v_gross * v_percent / 100)::integer;
  insert into public.payouts (lodging_id, period_end, gross_cents, commission_cents, net_cents,
                              bookings_count, created_by)
  values (p_lodging_id, now(), v_gross, v_commission, v_gross - v_commission, v_count,
          (select auth.uid()))
  returning * into v_payout;
  update public.bookings set payout_id = v_payout.id
   where lodging_id = p_lodging_id and payout_id is null
     and status in ('checked_in', 'completed', 'no_show');
  perform private.audit('admin_create_payout', 'payouts', v_payout.id::text,
                        jsonb_build_object('lodging_id', p_lodging_id, 'net_cents', v_payout.net_cents));
  return jsonb_build_object('payout_id', v_payout.id, 'gross_cents', v_gross,
                            'commission_cents', v_commission, 'net_cents', v_gross - v_commission,
                            'bookings_count', v_count);
end;
$$;

comment on function public.admin_create_payout(uuid) is 'El admin calcula la liquidación de un hostal: ventas sin liquidar menos la comisión.';
revoke all on function public.admin_create_payout(uuid) from public, anon;
grant execute on function public.admin_create_payout(uuid) to authenticated, service_role;

create function public.admin_mark_payout_paid(p_payout_id uuid, p_reference text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  if btrim(coalesce(p_reference, '')) = '' then
    raise exception 'reference_required' using errcode = '23514';
  end if;
  update public.payouts
     set status = 'paid', paid_at = now(), transfer_reference = left(btrim(p_reference), 120)
   where id = p_payout_id and status = 'pending';
  if not found then
    raise exception 'invalid_status' using errcode = '55000';
  end if;
  perform private.audit('admin_mark_payout_paid', 'payouts', p_payout_id::text,
                        jsonb_build_object('reference', p_reference));
end;
$$;

comment on function public.admin_mark_payout_paid(uuid, text) is 'El admin registra la transferencia de una liquidación.';
revoke all on function public.admin_mark_payout_paid(uuid, text) from public, anon;
grant execute on function public.admin_mark_payout_paid(uuid, text) to authenticated, service_role;

-- ─────────────────────────────────────────────────────── acciones del admin
create function public.admin_set_blocked(p_user_id uuid, p_blocked boolean, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception 'reason_required' using errcode = '23514';
  end if;
  if exists (select 1 from private.admins where user_id = p_user_id) then
    raise exception 'cannot_block_admin' using errcode = '42501';
  end if;
  update public.profiles set is_blocked = p_blocked where id = p_user_id;
  if not found then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;
  perform private.audit(case when p_blocked then 'block_user' else 'unblock_user' end,
                        'profiles', p_user_id::text, jsonb_build_object('reason', p_reason));
end;
$$;
revoke all on function public.admin_set_blocked(uuid, boolean, text) from public, anon;
grant execute on function public.admin_set_blocked(uuid, boolean, text) to authenticated, service_role;

-- Reembolso decidido por soporte, fuera de las reglas de la app.
create function public.admin_refund_booking(p_booking_id uuid, p_amount_cents integer, p_reason text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_refund integer;
begin
  perform private.require_admin();
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception 'reason_required' using errcode = '23514';
  end if;
  if p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'invalid_amount' using errcode = '22023';
  end if;
  if exists (select 1 from public.bookings where id = p_booking_id and payout_id is not null) then
    -- Ya se le pagó al hostal: se resuelve fuera de la app.
    raise exception 'already_paid_out' using errcode = '55000';
  end if;
  v_refund := private.add_refund(p_booking_id, p_amount_cents, 'soporte: ' || p_reason);
  if v_refund = 0 then
    raise exception 'nothing_to_refund' using errcode = '55000';
  end if;
  perform private.audit('admin_refund_booking', 'bookings', p_booking_id::text,
                        jsonb_build_object('amount_cents', v_refund, 'reason', p_reason));
  return v_refund;
end;
$$;
revoke all on function public.admin_refund_booking(uuid, integer, text) from public, anon;
grant execute on function public.admin_refund_booking(uuid, integer, text) to authenticated, service_role;

create function public.admin_set_lodging_suspended(p_lodging_id uuid, p_suspended boolean, p_reason text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  perform private.require_admin();
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception 'reason_required' using errcode = '23514';
  end if;
  select status into v_status from public.lodgings where id = p_lodging_id for update;
  if p_suspended and v_status = 'published' then
    update public.lodgings set status = 'suspended', review_note = left(p_reason, 500) where id = p_lodging_id;
  elsif not p_suspended and v_status = 'suspended' then
    update public.lodgings set status = 'published', review_note = '' where id = p_lodging_id;
  else
    raise exception 'invalid_status' using errcode = '55000';
  end if;
  perform private.audit(case when p_suspended then 'suspend_lodging' else 'restore_lodging' end,
                        'lodgings', p_lodging_id::text, jsonb_build_object('reason', p_reason));
  return case when p_suspended then 'suspended' else 'published' end;
end;
$$;
revoke all on function public.admin_set_lodging_suspended(uuid, boolean, text) from public, anon;
grant execute on function public.admin_set_lodging_suspended(uuid, boolean, text) to authenticated, service_role;

create function public.admin_resolve_support_case(p_case_id uuid, p_resolution text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  if btrim(coalesce(p_resolution, '')) = '' then
    raise exception 'reason_required' using errcode = '23514';
  end if;
  update public.support_cases
     set status = 'resolved', resolution = left(btrim(p_resolution), 2000), resolved_at = now()
   where id = p_case_id and status = 'open';
  if not found then
    raise exception 'invalid_status' using errcode = '55000';
  end if;
  perform private.audit('resolve_support_case', 'support_cases', p_case_id::text);
end;
$$;
revoke all on function public.admin_resolve_support_case(uuid, text) from public, anon;
grant execute on function public.admin_resolve_support_case(uuid, text) to authenticated, service_role;

-- La revisión de hostales también deja registro.
create or replace function public.admin_review_lodging(
  p_lodging_id uuid,
  p_approve boolean,
  p_note text default ''
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_note text := btrim(coalesce(p_note, ''));
begin
  if not (private.is_admin() or (select auth.role()) = 'service_role') then
    raise exception 'not_admin' using errcode = '42501';
  end if;

  select status into v_status from public.lodgings where id = p_lodging_id for update;
  if v_status is distinct from 'pending_review' then
    raise exception 'invalid_status' using errcode = '55000';
  end if;

  if p_approve then
    if cardinality(private.lodging_missing(p_lodging_id)) > 0 then
      raise exception 'lodging_incomplete' using errcode = '23514';
    end if;
    update public.lodgings
       set status = 'published', published_at = now(), review_note = v_note
     where id = p_lodging_id;
    perform private.audit('approve_lodging', 'lodgings', p_lodging_id::text);
    return 'published';
  end if;

  if v_note = '' then
    raise exception 'review_note_required' using errcode = '23514';
  end if;
  update public.lodgings
     set status = 'rejected', review_note = left(v_note, 500)
   where id = p_lodging_id;
  perform private.audit('reject_lodging', 'lodgings', p_lodging_id::text, jsonb_build_object('note', v_note));
  return 'rejected';
end;
$$;
