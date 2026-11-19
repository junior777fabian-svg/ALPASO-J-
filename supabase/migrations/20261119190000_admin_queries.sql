-- Al Paso — consultas del panel de administración (etapa 6, parte 6C)
--
-- Qué crea, todo solo para administradores:
--   · public.admin_overview()          cuántos hostales por revisar, incidencias, reclamos y liquidaciones
--   · public.admin_find_users()        cuentas por correo o nombre
--   · public.admin_pending_payouts()   hostales con ventas sin liquidar
--   · public.admin_find_booking()      una reserva por su código, con cobros y reembolsos
--
-- Las acciones (aprobar, bloquear, reembolsar, liquidar…) ya existen y
-- dejan registro; esto solo lee.

create function public.admin_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  return jsonb_build_object(
    'lodgings_pending_review', (select count(*) from public.lodgings where status = 'pending_review'),
    'lodgings_published', (select count(*) from public.lodgings where status = 'published'),
    'support_open', (select count(*) from public.support_cases where status = 'open'),
    'complaints_open', (select count(*) from private.complaints where status = 'open'),
    'payouts_pending', (select count(*) from public.payouts where status = 'pending'),
    'bookings_today', (select count(*) from public.bookings
                        where status in ('confirmed', 'checked_in', 'completed')
                          and arrival_at >= date_trunc('day', now() at time zone 'America/Lima') at time zone 'America/Lima'));
end;
$$;
revoke all on function public.admin_overview() from public, anon;
grant execute on function public.admin_overview() to authenticated, service_role;

create function public.admin_find_users(p_query text)
returns table (user_id uuid, email text, full_name text, is_blocked boolean,
               is_admin boolean, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := btrim(coalesce(p_query, ''));
begin
  perform private.require_admin();
  if char_length(v_query) < 3 then
    raise exception 'query_too_short' using errcode = '22023';
  end if;
  return query
  select u.id, u.email::text, p.full_name, p.is_blocked,
         exists (select 1 from private.admins a where a.user_id = u.id), u.created_at
    from auth.users u
    join public.profiles p on p.id = u.id
   where u.email ilike '%' || v_query || '%' or p.full_name ilike '%' || v_query || '%'
   order by u.created_at desc
   limit 50;
end;
$$;
revoke all on function public.admin_find_users(text) from public, anon;
grant execute on function public.admin_find_users(text) to authenticated, service_role;

create function public.admin_pending_payouts()
returns table (lodging_id uuid, lodging_name text, bookings_count integer,
               gross_cents integer, has_payout_account boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  return query
  select l.id, l.name, count(*)::integer, sum(private.booking_net_sales(b.id))::integer,
         exists (select 1 from public.lodging_payout_accounts a where a.lodging_id = l.id)
    from public.bookings b
    join public.lodgings l on l.id = b.lodging_id
   where b.payout_id is null and b.status in ('checked_in', 'completed', 'no_show')
   group by l.id, l.name
   order by l.name;
end;
$$;
revoke all on function public.admin_pending_payouts() from public, anon;
grant execute on function public.admin_pending_payouts() to authenticated, service_role;

create function public.admin_find_booking(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
begin
  perform private.require_admin();
  select * into v_booking from public.bookings
   where code = btrim(replace(upper(coalesce(p_code, '')), 'ALPASO:', ''));
  if not found then
    raise exception 'booking_not_found' using errcode = 'P0002';
  end if;
  return jsonb_build_object(
    'booking_id', v_booking.id, 'code', v_booking.code, 'status', v_booking.status,
    'lodging_name', (select name from public.lodgings where id = v_booking.lodging_id),
    'customer_email', (select email from auth.users where id = v_booking.customer_id),
    'customer_name', (select full_name from public.profiles where id = v_booking.customer_id),
    'arrival_at', v_booking.arrival_at, 'total_cents', v_booking.total_cents,
    'paid_out', v_booking.payout_id is not null,
    'refunded_cents', coalesce((select sum(amount_cents) from public.refunds where booking_id = v_booking.id), 0),
    'events', coalesce((select jsonb_agg(jsonb_build_object('to', e.to_status, 'note', e.note, 'at', e.created_at) order by e.id)
                          from public.booking_events e where e.booking_id = v_booking.id), '[]'));
end;
$$;
revoke all on function public.admin_find_booking(text) from public, anon;
grant execute on function public.admin_find_booking(text) to authenticated, service_role;
