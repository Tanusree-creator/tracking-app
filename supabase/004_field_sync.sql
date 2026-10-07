-- Field data sync, chat, face checks, notifications. Run after schema.sql, 002 and 003. Safe to re-run.
-- Same pattern as schema.sql: tables are locked, the app only calls the functions below (token = uuid).

-- Replace the old, empty shifts/visits tables (employee_id layout) with the new layout.
-- Only runs if the old layout is still there and the table has no rows, so re-runs never delete data.
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'visits' and column_name = 'employee_id')
     and not exists (select 1 from public.visits) then
    drop table public.visits cascade;
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'shifts' and column_name = 'employee_id')
     and not exists (select 1 from public.shifts) then
    drop table public.shifts cascade;
  end if;
end $$;

create table if not exists public.shifts (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz,
  breaks jsonb not null default '[]'::jsonb
);
create index if not exists shifts_user_idx on public.shifts(user_id, started_at desc);

create table if not exists public.visits (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  title text not null,
  location text not null default '',
  lat double precision,
  lng double precision,
  scheduled_time timestamptz not null,
  status text not null default 'pending' check (status in ('pending','inProgress','completed')),
  started_at timestamptz,
  completed_at timestamptz,
  proof_photo text,                       -- base64 JPEG taken at the site
  created_by_admin uuid references public.admins(id),
  created_at timestamptz not null default now()
);
create index if not exists visits_user_idx on public.visits(user_id, scheduled_time desc);

create table if not exists public.location_points (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  accuracy real, speed real, heading real,
  recorded_at timestamptz not null,
  unique (user_id, recorded_at)
);
create index if not exists points_user_idx on public.location_points(user_id, recorded_at);

create table if not exists public.face_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_users(id) on delete cascade,
  kind text not null check (kind in ('enroll','sign_in','clock_in','break_end')),
  photo text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_users(id) on delete cascade,  -- the employee side of the thread
  from_admin boolean not null,
  admin_id uuid references public.admins(id),
  body text not null,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists chat_user_idx on public.chat_messages(user_id, created_at);

create table if not exists public.admin_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.app_users(id) on delete cascade,
  title text not null,
  body text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists events_idx on public.admin_events(created_at desc);

alter table public.shifts enable row level security;
alter table public.visits enable row level security;
alter table public.location_points enable row level security;
alter table public.face_checks enable row level security;
alter table public.chat_messages enable row level security;
alter table public.admin_events enable row level security;

-- Session check used for "stay signed in".
create or replace function public.session_info(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare s app_sessions; u app_users; a admins;
begin
  select * into s from app_sessions where token = p_token and expires_at > now();
  if s.token is null then raise exception 'Session expired'; end if;
  if s.role = 'admin' then
    select * into a from admins where id = s.account_id;
    return json_build_object('role', 'admin', 'email', a.email);
  end if;
  select * into u from app_users where id = s.account_id;
  if u.status <> 'approved' then raise exception 'Account not approved'; end if;
  return json_build_object('role', 'user', 'id', u.id, 'email', u.email, 'name', u.name,
    'role_title', u.role_title, 'district', u.district,
    'has_face', exists (select 1 from face_checks f where f.user_id = u.id and f.kind = 'enroll'));
end $$;

create or replace function public.sign_out(p_token uuid)
returns void language sql security definer set search_path = public as $$
  delete from app_sessions where token = p_token;
$$;

-- ── employee side ───────────────────────────────────────────────────────────
create or replace function public.log_face_check(p_token uuid, p_kind text, p_photo text)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user'); nm text; enrolled boolean;
begin
  if uid is null then raise exception 'Not authorised'; end if;
  select name into nm from app_users where id = uid;
  select exists (select 1 from face_checks where user_id = uid and kind = 'enroll') into enrolled;
  if p_kind <> 'enroll' and not enrolled then p_kind := 'enroll'; end if;
  insert into face_checks(user_id, kind, photo) values (uid, p_kind, p_photo);
  if p_kind in ('clock_in','break_end') then
    insert into admin_events(user_id, title, body) values (uid, nm || ' verified face',
      case p_kind when 'clock_in' then 'Face verified at clock-in' else 'Face verified after break' end);
  end if;
  return json_build_object('enrolled', true);
end $$;

create or replace function public.sync_shift(p_token uuid, p_id uuid, p_start timestamptz, p_end timestamptz, p_breaks jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user'); nm text; existed boolean; was_ended boolean;
begin
  if uid is null then raise exception 'Not authorised'; end if;
  select name into nm from app_users where id = uid;
  select true, ended_at is not null into existed, was_ended from shifts where id = p_id and user_id = uid;
  insert into shifts(id, user_id, started_at, ended_at, breaks) values (p_id, uid, p_start, p_end, coalesce(p_breaks, '[]'))
  on conflict (id) do update set ended_at = excluded.ended_at, breaks = excluded.breaks
    where shifts.user_id = uid;
  if existed is null then
    insert into admin_events(user_id, title, body) values (uid, nm || ' started shift', 'Clocked in');
  elsif p_end is not null and coalesce(was_ended, false) = false then
    insert into admin_events(user_id, title, body) values (uid, nm || ' ended shift', 'Clocked out');
  end if;
end $$;

create or replace function public.sync_visit(
  p_token uuid, p_id uuid, p_title text, p_location text, p_lat double precision, p_lng double precision,
  p_scheduled timestamptz, p_status text, p_started timestamptz, p_completed timestamptz, p_photo text default null)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user'); nm text; old_status text;
begin
  if uid is null then raise exception 'Not authorised'; end if;
  select name into nm from app_users where id = uid;
  select status into old_status from visits where id = p_id and user_id = uid;
  if p_status = 'completed' and (p_photo is null) and coalesce(old_status, '') <> 'completed'
     and not exists (select 1 from visits where id = p_id and proof_photo is not null) then
    raise exception 'A photo of the visited place is required to complete a visit';
  end if;
  insert into visits(id, user_id, title, location, lat, lng, scheduled_time, status, started_at, completed_at, proof_photo)
  values (p_id, uid, p_title, p_location, p_lat, p_lng, p_scheduled, p_status, p_started, p_completed, p_photo)
  on conflict (id) do update set title = excluded.title, location = excluded.location, lat = excluded.lat, lng = excluded.lng,
    scheduled_time = excluded.scheduled_time, status = excluded.status, started_at = excluded.started_at,
    completed_at = excluded.completed_at, proof_photo = coalesce(excluded.proof_photo, visits.proof_photo)
    where visits.user_id = uid;
  if old_status is null then
    insert into admin_events(user_id, title, body) values (uid, 'Task created by ' || nm, p_title || ' · ' || p_location);
    insert into chat_messages(user_id, from_admin, body, is_system) values (uid, false, 'Task created: ' || p_title, true);
  elsif old_status <> p_status and p_status = 'inProgress' then
    insert into admin_events(user_id, title, body) values (uid, nm || ' started a task', p_title);
  elsif old_status <> p_status and p_status = 'completed' then
    insert into admin_events(user_id, title, body) values (uid, nm || ' closed a task', p_title || ' · ' || p_location);
    insert into chat_messages(user_id, from_admin, body, is_system) values (uid, false, 'Task closed: ' || p_title, true);
  end if;
end $$;

create or replace function public.my_visits(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', id, 'title', title, 'location', location, 'lat', lat, 'lng', lng,
      'scheduled_time', scheduled_time, 'status', status, 'started_at', started_at, 'completed_at', completed_at,
      'by_admin', created_by_admin is not null) order by scheduled_time)
    from visits where user_id = uid and scheduled_time > now() - interval '60 days'), '[]'::json);
end $$;

create or replace function public.my_shifts(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', id, 'start', started_at, 'end', ended_at, 'breaks', breaks)
      order by started_at) from shifts where user_id = uid and started_at > now() - interval '120 days'), '[]'::json);
end $$;

create or replace function public.add_location_points(p_token uuid, p_points jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  insert into location_points(user_id, lat, lng, accuracy, speed, heading, recorded_at)
  select uid, (x->>'lat')::float8, (x->>'lng')::float8, (x->>'acc')::real, (x->>'speed')::real,
         (x->>'heading')::real, (x->>'at')::timestamptz
  from jsonb_array_elements(p_points) x
  on conflict do nothing;
end $$;

create or replace function public.my_route(p_token uuid, p_from timestamptz, p_to timestamptz)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('lat', lat, 'lng', lng, 'acc', accuracy, 'at', recorded_at) order by recorded_at)
    from location_points where user_id = uid and recorded_at between p_from and p_to), '[]'::json);
end $$;

-- chat (employee side)
create or replace function public.my_chat(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  update chat_messages set read_at = now() where user_id = uid and from_admin and read_at is null;
  return coalesce((select json_agg(json_build_object('id', id, 'from_admin', from_admin, 'body', body,
      'is_system', is_system, 'created_at', created_at) order by created_at)
    from chat_messages where user_id = uid), '[]'::json);
end $$;

create or replace function public.my_unread_chat(p_token uuid)
returns int language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  return (select count(*) from chat_messages where user_id = uid and from_admin and read_at is null);
end $$;

create or replace function public.send_chat(p_token uuid, p_body text)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user'); nm text;
begin
  if uid is null then raise exception 'Not authorised'; end if;
  if length(trim(coalesce(p_body, ''))) = 0 then return; end if;
  select name into nm from app_users where id = uid;
  insert into chat_messages(user_id, from_admin, body) values (uid, false, trim(p_body));
  insert into admin_events(user_id, title, body) values (uid, 'Message from ' || nm, left(trim(p_body), 140));
end $$;

-- ── admin side ──────────────────────────────────────────────────────────────
create or replace function public.admin_live(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(r) from (
    select u.id, u.name, u.email, u.role_title, u.district,
      (select s.started_at from shifts s where s.user_id = u.id and s.ended_at is null order by s.started_at desc limit 1) as shift_start,
      (select jsonb_array_length(s.breaks) > 0 and (((s.breaks -> -1) ->> 'end') is null)
         from shifts s where s.user_id = u.id and s.ended_at is null order by s.started_at desc limit 1) as on_break,
      (select row_to_json(p) from (select lat, lng, accuracy as acc, recorded_at as at from location_points
         where user_id = u.id order by recorded_at desc limit 1) p) as last_point,
      (select count(*) from chat_messages c where c.user_id = u.id and not c.from_admin and c.read_at is null) as unread
    from app_users u where u.status = 'approved' order by u.name) r), '[]'::json);
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
        'has_photo', proof_photo is not null) order by scheduled_time desc) from visits where user_id = p_user), '[]'::json),
    'faces', coalesce((select json_agg(json_build_object('id', id, 'kind', kind, 'at', created_at) order by created_at desc)
        from (select * from face_checks where user_id = p_user order by created_at desc limit 20) f), '[]'::json));
end $$;

create or replace function public.admin_report_data(p_token uuid, p_from timestamptz, p_to timestamptz)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return json_build_object(
    'shifts', coalesce((select json_agg(json_build_object('user_id', user_id, 'start', started_at, 'end', ended_at, 'breaks', breaks))
        from shifts where started_at between p_from and p_to), '[]'::json),
    'visits', coalesce((select json_agg(json_build_object('user_id', user_id, 'status', status, 'scheduled_time', scheduled_time))
        from visits where scheduled_time between p_from and p_to), '[]'::json));
end $$;

create or replace function public.admin_route(p_token uuid, p_user uuid, p_from timestamptz, p_to timestamptz)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('lat', lat, 'lng', lng, 'acc', accuracy, 'at', recorded_at) order by recorded_at)
    from location_points where user_id = p_user and recorded_at between p_from and p_to), '[]'::json);
end $$;

create or replace function public.admin_visit_photo(p_token uuid, p_visit uuid)
returns text language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return (select proof_photo from visits where id = p_visit);
end $$;

create or replace function public.admin_face_photo(p_token uuid, p_check uuid)
returns text language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return (select photo from face_checks where id = p_check);
end $$;

create or replace function public.admin_create_task(
  p_token uuid, p_user uuid, p_title text, p_location text, p_lat double precision, p_lng double precision, p_when timestamptz)
returns uuid language plpgsql security definer set search_path = public as $$
declare adm uuid := _session_account(p_token, 'admin'); vid uuid := gen_random_uuid();
begin
  if adm is null then raise exception 'Not authorised'; end if;
  if length(trim(coalesce(p_title, ''))) = 0 then raise exception 'Task title is required'; end if;
  if length(trim(coalesce(p_location, ''))) = 0 or p_lat is null or p_lng is null then
    raise exception 'Choose the visit location';
  end if;
  insert into visits(id, user_id, title, location, lat, lng, scheduled_time, created_by_admin)
    values (vid, p_user, trim(p_title), trim(p_location), p_lat, p_lng, p_when, adm);
  insert into chat_messages(user_id, from_admin, admin_id, body, is_system)
    values (p_user, true, adm, 'New task assigned: ' || trim(p_title) || ' at ' || trim(p_location), true);
  return vid;
end $$;

create or replace function public.admin_chat_threads(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(r order by r.last_at desc nulls last, r.name) from (
    select u.id, u.name, u.role_title,
      (select body from chat_messages c where c.user_id = u.id order by created_at desc limit 1) as last_body,
      (select created_at from chat_messages c where c.user_id = u.id order by created_at desc limit 1) as last_at,
      (select count(*) from chat_messages c where c.user_id = u.id and not c.from_admin and c.read_at is null) as unread
    from app_users u where u.status = 'approved') r), '[]'::json);
end $$;

create or replace function public.admin_chat(p_token uuid, p_user uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  update chat_messages set read_at = now() where user_id = p_user and not from_admin and read_at is null;
  return coalesce((select json_agg(json_build_object('id', id, 'from_admin', from_admin, 'body', body,
      'is_system', is_system, 'created_at', created_at) order by created_at)
    from chat_messages where user_id = p_user), '[]'::json);
end $$;

create or replace function public.admin_send_chat(p_token uuid, p_user uuid, p_body text)
returns void language plpgsql security definer set search_path = public as $$
declare adm uuid := _session_account(p_token, 'admin');
begin
  if adm is null then raise exception 'Not authorised'; end if;
  if length(trim(coalesce(p_body, ''))) = 0 then return; end if;
  insert into chat_messages(user_id, from_admin, admin_id, body) values (p_user, true, adm, trim(p_body));
end $$;

create or replace function public.admin_events_since(p_token uuid, p_since timestamptz)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', id, 'user_id', user_id, 'title', title, 'body', body,
      'created_at', created_at) order by created_at desc)
    from (select * from admin_events where created_at > p_since order by created_at desc limit 50) e), '[]'::json);
end $$;

grant execute on function
  public.session_info(uuid), public.sign_out(uuid), public.log_face_check(uuid, text, text),
  public.sync_shift(uuid, uuid, timestamptz, timestamptz, jsonb),
  public.sync_visit(uuid, uuid, text, text, double precision, double precision, timestamptz, text, timestamptz, timestamptz, text),
  public.my_visits(uuid), public.my_shifts(uuid), public.add_location_points(uuid, jsonb),
  public.my_route(uuid, timestamptz, timestamptz), public.my_chat(uuid), public.my_unread_chat(uuid),
  public.send_chat(uuid, text), public.admin_live(uuid), public.admin_employee_data(uuid, uuid),
  public.admin_report_data(uuid, timestamptz, timestamptz), public.admin_route(uuid, uuid, timestamptz, timestamptz),
  public.admin_visit_photo(uuid, uuid), public.admin_face_photo(uuid, uuid),
  public.admin_create_task(uuid, uuid, text, text, double precision, double precision, timestamptz),
  public.admin_chat_threads(uuid), public.admin_chat(uuid, uuid), public.admin_send_chat(uuid, uuid, text),
  public.admin_events_since(uuid, timestamptz)
to anon, authenticated;

notify pgrst, 'reload schema';
