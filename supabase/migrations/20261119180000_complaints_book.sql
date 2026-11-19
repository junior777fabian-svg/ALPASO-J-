-- Al Paso — Libro de Reclamaciones virtual (etapa 6, parte 6D)
--
-- Qué crea:
--   · private.complaints          reclamos y quejas, con número correlativo por año
--   · public.submit_complaint()   cualquiera registra un reclamo, con o sin cuenta
--   · public.admin_list_complaints(), admin_answer_complaint()
--
-- Por qué: el Código de Protección y Defensa del Consumidor exige un Libro de
-- Reclamaciones, también virtual (docs/ESTRUCTURA.md, sección 18). Los datos
-- personales del consumidor van en el esquema private: la API no los expone
-- y solo el administrador los lee.

create table private.complaints (
  id uuid primary key default gen_random_uuid(),
  -- 2026-000001: correlativo por año.
  number text not null unique,
  kind text not null check (kind in ('reclamo', 'queja')),
  consumer_name text not null check (char_length(btrim(consumer_name)) between 3 and 120),
  consumer_document text not null check (char_length(btrim(consumer_document)) between 6 and 20),
  consumer_email text not null check (consumer_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  consumer_phone text not null default '' check (char_length(consumer_phone) <= 20),
  consumer_address text not null default '' check (char_length(consumer_address) <= 200),
  guardian_name text not null default '' check (char_length(guardian_name) <= 120),
  booking_code text not null default '' check (booking_code ~ '^([A-Z0-9]{6})?$'),
  amount_cents integer check (amount_cents is null or amount_cents >= 0),
  detail text not null check (char_length(btrim(detail)) between 10 and 3000),
  consumer_request text not null check (char_length(btrim(consumer_request)) between 5 and 2000),
  status text not null default 'open' check (status in ('open', 'answered')),
  answer text not null default '',
  answered_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table private.complaints is
  'Libro de Reclamaciones virtual. Datos personales: solo el administrador los lee.';

alter table private.complaints enable row level security;
revoke all on table private.complaints from public, anon, authenticated;

create table private.complaint_counters (
  year integer primary key,
  last_number integer not null default 0
);
alter table private.complaint_counters enable row level security;
revoke all on table private.complaint_counters from public, anon, authenticated;

create function public.submit_complaint(p_data jsonb)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_year integer := extract(year from now() at time zone 'America/Lima')::integer;
  v_next integer;
  v_number text;
begin
  if jsonb_typeof(p_data) <> 'object' then
    raise exception 'invalid_data' using errcode = '22023';
  end if;
  -- Un freno básico contra el abuso: hasta 20 registros por minuto en total.
  if (select count(*) from private.complaints where created_at > now() - interval '1 minute') >= 20 then
    raise exception 'too_many_requests' using errcode = '54000';
  end if;

  insert into private.complaint_counters (year, last_number) values (v_year, 1)
  on conflict (year) do update set last_number = private.complaint_counters.last_number + 1
  returning last_number into v_next;
  v_number := v_year::text || '-' || lpad(v_next::text, 6, '0');

  insert into private.complaints (
    number, kind, consumer_name, consumer_document, consumer_email, consumer_phone,
    consumer_address, guardian_name, booking_code, amount_cents, detail, consumer_request
  ) values (
    v_number,
    p_data ->> 'kind',
    btrim(coalesce(p_data ->> 'consumer_name', '')),
    btrim(coalesce(p_data ->> 'consumer_document', '')),
    lower(btrim(coalesce(p_data ->> 'consumer_email', ''))),
    btrim(coalesce(p_data ->> 'consumer_phone', '')),
    btrim(coalesce(p_data ->> 'consumer_address', '')),
    btrim(coalesce(p_data ->> 'guardian_name', '')),
    upper(btrim(coalesce(p_data ->> 'booking_code', ''))),
    nullif(p_data ->> 'amount_cents', '')::integer,
    btrim(coalesce(p_data ->> 'detail', '')),
    btrim(coalesce(p_data ->> 'consumer_request', ''))
  );
  return v_number;
exception
  when check_violation or not_null_violation or invalid_text_representation then
    raise exception 'invalid_data' using errcode = '22023';
end;
$$;

comment on function public.submit_complaint(jsonb) is
  'Registra un reclamo o queja en el Libro de Reclamaciones y devuelve su número.';
revoke all on function public.submit_complaint(jsonb) from public;
grant execute on function public.submit_complaint(jsonb) to anon, authenticated;

create function public.admin_list_complaints(p_only_open boolean default true)
returns setof private.complaints
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  return query select * from private.complaints c
   where not p_only_open or c.status = 'open'
   order by c.created_at;
end;
$$;
revoke all on function public.admin_list_complaints(boolean) from public, anon;
grant execute on function public.admin_list_complaints(boolean) to authenticated, service_role;

create function public.admin_answer_complaint(p_number text, p_answer text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  if char_length(btrim(coalesce(p_answer, ''))) < 10 then
    raise exception 'reason_required' using errcode = '23514';
  end if;
  update private.complaints
     set status = 'answered', answer = btrim(p_answer), answered_at = now()
   where number = p_number and status = 'open';
  if not found then
    raise exception 'invalid_status' using errcode = '55000';
  end if;
  perform private.audit('answer_complaint', 'complaints', p_number);
end;
$$;
revoke all on function public.admin_answer_complaint(text, text) from public, anon;
grant execute on function public.admin_answer_complaint(text, text) to authenticated, service_role;
