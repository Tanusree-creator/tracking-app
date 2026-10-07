-- Profile photo + position editing, avatars for the admin app, and open task pins for the live map.
-- Run after 004_field_sync.sql. Safe to re-run.
alter table public.app_users add column if not exists avatar text; -- small JPEG, base64

drop function if exists public.my_profile(uuid);
create or replace function public.my_profile(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  return (select json_build_object('name', name, 'email', email, 'phone', phone, 'role_title', role_title, 'avatar', avatar)
          from app_users where id = uid);
end $$;

-- p_avatar: null = keep the current photo, '' = remove it, anything else = new photo (base64).
create or replace function public.update_my_profile_v2(p_token uuid, p_name text, p_phone text, p_title text, p_avatar text)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  if length(trim(coalesce(p_name, ''))) = 0 then raise exception 'Name is required'; end if;
  if length(trim(coalesce(p_title, ''))) = 0 then raise exception 'Position is required'; end if;
  if p_avatar is not null and length(p_avatar) > 400000 then raise exception 'Photo is too large'; end if;
  update app_users set
    name = trim(p_name),
    phone = nullif(trim(coalesce(p_phone, '')), ''),
    role_title = trim(p_title),
    avatar = case when p_avatar is null then avatar else nullif(p_avatar, '') end
  where id = uid;
  return public.my_profile(p_token);
end $$;

-- Admin: photos are fetched separately so the 15 s live refresh stays light.
create or replace function public.admin_avatars(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', id, 'avatar', avatar)) from app_users where avatar is not null), '[]'::json);
end $$;

-- admin_live, now with the phone number.
create or replace function public.admin_live(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(r) from (
    select u.id, u.name, u.email, u.phone, u.role_title, u.district,
      (select s.started_at from shifts s where s.user_id = u.id and s.ended_at is null order by s.started_at desc limit 1) as shift_start,
      (select jsonb_array_length(s.breaks) > 0 and (((s.breaks -> -1) ->> 'end') is null)
         from shifts s where s.user_id = u.id and s.ended_at is null order by s.started_at desc limit 1) as on_break,
      (select row_to_json(p) from (select lat, lng, accuracy as acc, recorded_at as at from location_points
         where user_id = u.id order by recorded_at desc limit 1) p) as last_point,
      (select count(*) from chat_messages c where c.user_id = u.id and not c.from_admin and c.read_at is null) as unread
    from app_users u where u.status = 'approved' order by u.name) r), '[]'::json);
end $$;

-- Task locations still to do (and today's finished ones) for every employee, shown as pins on the live map.
create or replace function public.admin_task_pins(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', v.id, 'user_id', v.user_id, 'user_name', u.name, 'title', v.title,
      'location', v.location, 'lat', v.lat, 'lng', v.lng, 'scheduled_time', v.scheduled_time, 'status', v.status))
    from visits v join app_users u on u.id = v.user_id
    where v.lat is not null and (v.status <> 'completed' or v.completed_at > now() - interval '1 day')), '[]'::json);
end $$;

-- Tasks of every employee in a date range, for the admin calendar.
create or replace function public.admin_tasks_range(p_token uuid, p_from timestamptz, p_to timestamptz)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', v.id, 'user_name', u.name, 'title', v.title, 'location', v.location,
      'scheduled_time', v.scheduled_time, 'status', v.status, 'completed_at', v.completed_at) order by v.scheduled_time)
    from visits v join app_users u on u.id = v.user_id
    where v.scheduled_time >= p_from and v.scheduled_time < p_to), '[]'::json);
end $$;
