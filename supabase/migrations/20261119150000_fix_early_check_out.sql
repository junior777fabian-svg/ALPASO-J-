-- Al Paso — salida antes de la hora reservada (etapa 5, corrección)
--
-- Se puede ingresar desde 15 minutos antes de la hora reservada. Si el
-- cliente sale también antes de esa hora, host_check_out dejaba la limpieza
-- empezando a la hora reservada, y el cuarto aparecía "libre" mientras
-- seguía sucio. Ahora la limpieza empieza siempre en el momento de la salida.

create or replace function public.host_check_out(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_cleaning smallint;
  v_start timestamptz;
begin
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'booking_not_found' using errcode = 'P0002';
  end if;
  perform private.require_staff(v_booking.lodging_id);
  if v_booking.status <> 'checked_in' then
    raise exception 'invalid_status' using errcode = '55000';
  end if;
  select cleaning_minutes into v_cleaning from public.lodgings where id = v_booking.lodging_id;

  update public.bookings set status = 'completed', checked_out_at = now() where id = p_booking_id;

  -- La estadía termina ahora. Si ni siquiera llegó la hora reservada, su
  -- ocupación se quita entera; la reserva queda en el historial.
  select lower(period) into v_start from public.room_occupancy where booking_id = p_booking_id;
  if now() > v_start then
    update public.room_occupancy set period = tstzrange(v_start, now(), '[)')
     where booking_id = p_booking_id;
  else
    delete from public.room_occupancy where booking_id = p_booking_id;
  end if;

  -- La limpieza empieza en el momento de la salida.
  if v_cleaning > 0 then
    insert into public.room_occupancy (room_id, lodging_id, kind, period)
    values (v_booking.room_id, v_booking.lodging_id, 'cleaning',
            tstzrange(now(), now() + make_interval(mins => v_cleaning), '[)'));
  end if;
  perform private.log_booking(p_booking_id, 'checked_in', 'completed', 'salida registrada por recepción');
end;
$$;
