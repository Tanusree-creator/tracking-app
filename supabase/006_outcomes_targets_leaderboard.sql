-- Visit outcomes, daily target and weekly leaderboard. Run after 005. Safe to re-run.
alter table public.visits add column if not exists outcome text check (outcome in ('ordered', 'sampleGiven', 'followUp', 'notInterested'));
alter table public.visits add column if not exists outcome_note text;
alter table public.visits add column if not exists copies int;

create table if not exists public.app_settings (key text primary key, value int not null);
alter table public.app_settings enable row level security;
insert into public.app_settings(key, value) values ('daily_visit_target', 3) on conflict do nothing;

-- Same as sync_visit, plus the result of the visit.
create or replace function public.sync_visit_v2(
  p_token uuid, p_id uuid, p_title text, p_location text, p_lat double precision, p_lng double precision,
  p_scheduled timestamptz, p_status text, p_started timestamptz, p_completed timestamptz, p_photo text,
  p_outcome text, p_note text, p_copies int)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  perform public.sync_visit(p_token, p_id, p_title, p_location, p_lat, p_lng, p_scheduled, p_status, p_started, p_completed, p_photo);
  if p_outcome is not null then
    update visits set outcome = p_outcome, outcome_note = nullif(trim(coalesce(p_note, '')), ''), copies = p_copies
    where id = p_id and user_id = uid;
    -- the "closed a task" notification the admin just received now says how it went
    update admin_events set body = body || E'\n' ||
        (case p_outcome when 'ordered' then 'Books ordered' when 'sampleGiven' then 'Samples given'
           when 'followUp' then 'Follow up later' else 'Not interested' end)
        || (case when p_copies is not null then ' · ' || p_copies || ' copies' else '' end)
    where id = (select id from admin_events where user_id = uid and title like '% closed a task'
                  and created_at > now() - interval '2 minutes' order by created_at desc limit 1);
  end if;
end $$;

create or replace function public.my_visits(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', id, 'title', title, 'location', location, 'lat', lat, 'lng', lng,
      'scheduled_time', scheduled_time, 'status', status, 'started_at', started_at, 'completed_at', completed_at,
      'by_admin', created_by_admin is not null, 'outcome', outcome, 'outcome_note', outcome_note, 'copies', copies)
      order by scheduled_time)
    from visits where user_id = uid and scheduled_time > now() - interval '60 days'), '[]'::json);
end $$;

create or replace function public.admin_employee_data(p_token uuid, p_user uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return json_build_object(
    'shifts', coalesce((select json_agg(json_build_object('id', id, 'start', started_at, 'end', ended_at, 'breaks', breaks)
        order by started_at desc) from shifts where user_id = p_user), '[]'::json),
    'visits', coalesce((select json_agg(json_build_object('id', id, 'title', title, 'location', location, 'lat', lat, 'lng', lng,
        'scheduled_time', scheduled_time, 'status', status, 'started_at', started_at, 'completed_at', completed_at,
        'has_photo', proof_photo is not null, 'outcome', outcome, 'outcome_note', outcome_note, 'copies', copies)
        order by scheduled_time desc) from visits where user_id = p_user), '[]'::json),
    'faces', coalesce((select json_agg(json_build_object('id', id, 'kind', kind, 'at', created_at) order by created_at desc)
        from (select * from face_checks where user_id = p_user order by created_at desc limit 20) f), '[]'::json));
end $$;

create or replace function public.get_daily_target(p_token uuid)
returns int language plpgsql security definer set search_path = public as $$
begin
  if coalesce(_session_account(p_token, 'user'), _session_account(p_token, 'admin')) is null then raise exception 'Not authorised'; end if;
  return coalesce((select value from app_settings where key = 'daily_visit_target'), 3);
end $$;

create or replace function public.admin_set_daily_target(p_token uuid, p_target int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  if p_target < 1 or p_target > 50 then raise exception 'Target must be between 1 and 50'; end if;
  insert into app_settings(key, value) values ('daily_visit_target', p_target)
    on conflict (key) do update set value = excluded.value;
end $$;

-- This week (Mon-Sun, India time): completed visits, visits started within 15 min of schedule, and the
-- days with a completed visit in the last 30 days (the app works out streaks from them).
create or replace function public.weekly_leaderboard(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare wk timestamptz := date_trunc('week', now() at time zone 'Asia/Kolkata') at time zone 'Asia/Kolkata';
begin
  if coalesce(_session_account(p_token, 'user'), _session_account(p_token, 'admin')) is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(r order by r.done desc, r.on_time desc, r.name) from (
    select u.id, u.name, u.role_title, u.avatar,
      (select count(*) from visits v where v.user_id = u.id and v.status = 'completed' and v.completed_at >= wk) as done,
      (select count(*) from visits v where v.user_id = u.id and v.status = 'completed' and v.completed_at >= wk
         and v.started_at is not null and v.started_at <= v.scheduled_time + interval '15 minutes') as on_time,
      (select coalesce(sum(v.copies), 0) from visits v where v.user_id = u.id and v.completed_at >= wk and v.outcome = 'ordered') as copies_ordered,
      (select coalesce(json_agg(distinct (v.completed_at at time zone 'Asia/Kolkata')::date), '[]'::json)
         from visits v where v.user_id = u.id and v.status = 'completed' and v.completed_at > now() - interval '30 days') as days
    from app_users u where u.status = 'approved') r), '[]'::json);
end $$;
