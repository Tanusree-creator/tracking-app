-- Office staff, follow-ups, leave requests, announcements, chat photos + voice notes.
-- Run after 006_outcomes_targets_leaderboard.sql. Safe to re-run.

-- ── staff type: 'field' = marketing (GPS tracked), 'office' = in-house (no tracking) ─────────────
alter table public.app_users add column if not exists staff_type text not null default 'field';
do $$ begin
  alter table public.app_users add constraint app_users_staff_type_chk check (staff_type in ('field', 'office'));
exception when duplicate_object then null; end $$;

create or replace function public.user_login(p_email text, p_password text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare u app_users; t uuid;
begin
  select * into u from app_users where email = lower(trim(p_email));
  if u.id is null or u.password_hash <> crypt(p_password, u.password_hash) then
    raise exception 'Incorrect email or password';
  end if;
  if u.status = 'pending' then raise exception 'Your account is awaiting admin approval'; end if;
  if u.status = 'rejected' then raise exception 'Your access request was rejected'; end if;
  insert into app_sessions(role, account_id) values ('user', u.id) returning token into t;
  return json_build_object('token', t, 'role', 'user', 'id', u.id, 'email', u.email, 'name', u.name,
    'role_title', u.role_title, 'district', u.district, 'staff_type', u.staff_type);
end $$;

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
    'role_title', u.role_title, 'district', u.district, 'staff_type', u.staff_type,
    'has_face', exists (select 1 from face_checks f where f.user_id = u.id and f.kind = 'enroll'));
end $$;

create or replace function public.admin_create_user_v2(
  p_token uuid, p_name text, p_email text, p_password text default null, p_staff_type text default 'field')
returns json language plpgsql security definer set search_path = public, extensions as $$
declare adm uuid; pw text; uid uuid; em text := lower(trim(p_email));
begin
  adm := _session_account(p_token, 'admin');
  if adm is null then raise exception 'Not authorised'; end if;
  if p_staff_type not in ('field', 'office') then raise exception 'Invalid staff type'; end if;
  if exists (select 1 from app_users where email = em) then
    raise exception 'A user with this email already exists';
  end if;
  pw := coalesce(nullif(p_password, ''),
                 substr(translate(encode(gen_random_bytes(12), 'base64'), '+/=', 'xyz'), 1, 12));
  if length(pw) < 8 then raise exception 'Password must be at least 8 characters'; end if;
  insert into app_users(name, email, password_hash, created_by, status, staff_type, role_title)
    values (trim(p_name), em, crypt(pw, gen_salt('bf')), adm, 'approved', p_staff_type,
            case when p_staff_type = 'office' then 'Office Staff' else 'Field Technician' end)
    returning id into uid;
  insert into messages(user_id, sender_admin_id, title, body) values (uid, adm,
    'Your account has been created',
    format(E'Hello %s,\n\nYour login details:\nEmail: %s\nPassword: %s\n\nPlease keep these safe.', trim(p_name), em, pw));
  return json_build_object('id', uid, 'email', em, 'password', pw, 'staff_type', p_staff_type);
end $$;

create or replace function public.admin_set_staff_type(p_token uuid, p_user uuid, p_staff_type text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  if p_staff_type not in ('field', 'office') then raise exception 'Invalid staff type'; end if;
  update app_users set staff_type = p_staff_type where id = p_user;
end $$;

create or replace function public.admin_list_users(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', id, 'name', name, 'email', email, 'status', status,
                   'role_title', role_title, 'district', district, 'staff_type', staff_type, 'created_at', created_at)
                   order by created_at desc) from app_users), '[]'::json);
end $$;

create or replace function public.admin_live(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(r) from (
    select u.id, u.name, u.email, u.phone, u.role_title, u.district, u.staff_type,
      (select s.started_at from shifts s where s.user_id = u.id and s.ended_at is null order by s.started_at desc limit 1) as shift_start,
      (select jsonb_array_length(s.breaks) > 0 and (((s.breaks -> -1) ->> 'end') is null)
         from shifts s where s.user_id = u.id and s.ended_at is null order by s.started_at desc limit 1) as on_break,
      (select row_to_json(p) from (select lat, lng, accuracy as acc, recorded_at as at from location_points
         where user_id = u.id order by recorded_at desc limit 1) p) as last_point,
      (select count(*) from chat_messages c where c.user_id = u.id and not c.from_admin and c.read_at is null) as unread
    from app_users u where u.status = 'approved' order by u.name) r), '[]'::json);
end $$;

-- ── office tasks (no location) ──────────────────────────────────────────────────────────────────
create table if not exists public.office_tasks (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  title text not null,
  note text not null default '',
  due_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending', 'inProgress', 'completed')),
  completed_at timestamptz,
  created_by_admin uuid references public.admins(id),
  created_at timestamptz not null default now()
);
create index if not exists office_tasks_user_idx on public.office_tasks(user_id, due_at desc);

-- ── follow-ups: people / schools to call (or visit later), with a date and time ─────────────────
create table if not exists public.follow_ups (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  contact_name text not null,
  organization text not null default '',
  phone text not null default '',
  purpose text not null default '',
  kind text not null default 'call' check (kind in ('call', 'visit')),
  remind_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending', 'done')),
  result_note text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists follow_ups_user_idx on public.follow_ups(user_id, remind_at);

-- ── leave requests ──────────────────────────────────────────────────────────────────────────────
create table if not exists public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_users(id) on delete cascade,
  from_date date not null,
  to_date date not null,
  reason text not null default '',
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  decided_by uuid references public.admins(id),
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  check (to_date >= from_date)
);
create index if not exists leave_user_idx on public.leave_requests(user_id, from_date);

-- ── announcements ───────────────────────────────────────────────────────────────────────────────
create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.admins(id),
  title text not null,
  body text not null default '',
  image text,                                    -- optional base64 JPEG
  audience text not null default 'all' check (audience in ('all', 'field', 'office')),
  created_at timestamptz not null default now()
);

-- ── chat: photos + voice notes ──────────────────────────────────────────────────────────────────
alter table public.chat_messages add column if not exists kind text not null default 'text';
alter table public.chat_messages add column if not exists media text;       -- base64 JPEG / m4a
do $$ begin
  alter table public.chat_messages add constraint chat_kind_chk check (kind in ('text', 'image', 'voice'));
exception when duplicate_object then null; end $$;

alter table public.office_tasks enable row level security;
alter table public.follow_ups enable row level security;
alter table public.leave_requests enable row level security;
alter table public.announcements enable row level security;

-- ── office tasks: employee side ─────────────────────────────────────────────────────────────────
create or replace function public.sync_office_task(
  p_token uuid, p_id uuid, p_title text, p_note text, p_due timestamptz, p_status text)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user'); nm text; old_status text;
begin
  if uid is null then raise exception 'Not authorised'; end if;
  if length(trim(coalesce(p_title, ''))) = 0 then raise exception 'Task title is required'; end if;
  select name into nm from app_users where id = uid;
  select status into old_status from office_tasks where id = p_id and user_id = uid;
  insert into office_tasks(id, user_id, title, note, due_at, status, completed_at)
    values (p_id, uid, trim(p_title), coalesce(p_note, ''), p_due, p_status,
            case when p_status = 'completed' then now() end)
  on conflict (id) do update set title = excluded.title, note = excluded.note, due_at = excluded.due_at,
    status = excluded.status,
    completed_at = case when excluded.status = 'completed' then coalesce(office_tasks.completed_at, now()) end
    where office_tasks.user_id = uid;
  if old_status is null then
    insert into admin_events(user_id, title, body) values (uid, 'Task created by ' || nm, trim(p_title));
  elsif old_status <> p_status and p_status = 'completed' then
    insert into admin_events(user_id, title, body) values (uid, nm || ' closed a task', trim(p_title));
  end if;
end $$;

create or replace function public.delete_office_task(p_token uuid, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  delete from office_tasks where id = p_id and user_id = uid and created_by_admin is null;
end $$;

create or replace function public.my_office_tasks(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', id, 'title', title, 'note', note, 'due_at', due_at,
      'status', status, 'completed_at', completed_at, 'by_admin', created_by_admin is not null) order by due_at desc)
    from office_tasks where user_id = uid), '[]'::json);
end $$;

-- ── follow-ups: employee side ───────────────────────────────────────────────────────────────────
create or replace function public.sync_follow_up(
  p_token uuid, p_id uuid, p_name text, p_org text, p_phone text, p_purpose text, p_kind text,
  p_remind timestamptz, p_status text, p_result text)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user'); nm text; old_status text;
begin
  if uid is null then raise exception 'Not authorised'; end if;
  if length(trim(coalesce(p_name, ''))) = 0 then raise exception 'Enter who to contact'; end if;
  select name into nm from app_users where id = uid;
  select status into old_status from follow_ups where id = p_id and user_id = uid;
  insert into follow_ups(id, user_id, contact_name, organization, phone, purpose, kind, remind_at, status, result_note)
    values (p_id, uid, trim(p_name), coalesce(trim(p_org), ''), coalesce(trim(p_phone), ''), coalesce(trim(p_purpose), ''),
            p_kind, p_remind, p_status, coalesce(p_result, ''))
  on conflict (id) do update set contact_name = excluded.contact_name, organization = excluded.organization,
    phone = excluded.phone, purpose = excluded.purpose, kind = excluded.kind, remind_at = excluded.remind_at,
    status = excluded.status, result_note = excluded.result_note
    where follow_ups.user_id = uid;
  if old_status is null then
    insert into admin_events(user_id, title, body) values (uid,
      nm || ' scheduled a ' || p_kind,
      trim(p_name) || case when length(trim(coalesce(p_org, ''))) > 0 then ' · ' || trim(p_org) else '' end
        || ' · ' || to_char(p_remind at time zone 'Asia/Kolkata', 'DD Mon, HH12:MI AM'));
  elsif old_status <> p_status and p_status = 'done' then
    insert into admin_events(user_id, title, body) values (uid, nm || ' finished a ' || p_kind, trim(p_name));
  end if;
end $$;

create or replace function public.delete_follow_up(p_token uuid, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  delete from follow_ups where id = p_id and user_id = uid;
end $$;

create or replace function public.my_follow_ups(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', id, 'name', contact_name, 'org', organization, 'phone', phone,
      'purpose', purpose, 'kind', kind, 'remind_at', remind_at, 'status', status, 'result', result_note) order by remind_at)
    from follow_ups where user_id = uid), '[]'::json);
end $$;

-- ── leave: employee side ────────────────────────────────────────────────────────────────────────
create or replace function public.request_leave(p_token uuid, p_from date, p_to date, p_reason text)
returns uuid language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user'); nm text; lid uuid;
begin
  if uid is null then raise exception 'Not authorised'; end if;
  if p_from is null or p_to is null or p_to < p_from then raise exception 'Choose valid leave dates'; end if;
  if exists (select 1 from leave_requests where user_id = uid and status in ('pending', 'approved')
             and from_date <= p_to and to_date >= p_from) then
    raise exception 'You already have a leave request on these dates';
  end if;
  select name into nm from app_users where id = uid;
  insert into leave_requests(user_id, from_date, to_date, reason) values (uid, p_from, p_to, coalesce(trim(p_reason), ''))
    returning id into lid;
  insert into admin_events(user_id, title, body) values (uid, nm || ' requested leave',
    to_char(p_from, 'DD Mon') || case when p_to <> p_from then ' – ' || to_char(p_to, 'DD Mon') else '' end
    || case when length(trim(coalesce(p_reason, ''))) > 0 then ' · ' || left(trim(p_reason), 100) else '' end);
  return lid;
end $$;

create or replace function public.cancel_leave(p_token uuid, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  update leave_requests set status = 'cancelled' where id = p_id and user_id = uid and status = 'pending';
end $$;

create or replace function public.my_leaves(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', id, 'from', from_date, 'to', to_date, 'reason', reason,
      'status', status, 'decided_at', decided_at, 'created_at', created_at) order by from_date desc)
    from leave_requests where user_id = uid and status <> 'cancelled'), '[]'::json);
end $$;

-- ── announcements: employee side ────────────────────────────────────────────────────────────────
create or replace function public.my_announcements(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user'); st text;
begin
  if uid is null then raise exception 'Not authorised'; end if;
  select staff_type into st from app_users where id = uid;
  return coalesce((select json_agg(json_build_object('id', id, 'title', title, 'body', body, 'image', image,
      'created_at', created_at) order by created_at desc)
    from (select * from announcements where audience in ('all', st) order by created_at desc limit 50) a), '[]'::json);
end $$;

-- ── chat with photos / voice ────────────────────────────────────────────────────────────────────
create or replace function public.my_chat(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  update chat_messages set read_at = now() where user_id = uid and from_admin and read_at is null;
  return coalesce((select json_agg(json_build_object('id', id, 'from_admin', from_admin, 'body', body,
      'is_system', is_system, 'kind', kind, 'created_at', created_at) order by created_at)
    from chat_messages where user_id = uid), '[]'::json);
end $$;

create or replace function public.admin_chat(p_token uuid, p_user uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  update chat_messages set read_at = now() where user_id = p_user and not from_admin and read_at is null;
  return coalesce((select json_agg(json_build_object('id', id, 'from_admin', from_admin, 'body', body,
      'is_system', is_system, 'kind', kind, 'created_at', created_at) order by created_at)
    from chat_messages where user_id = p_user), '[]'::json);
end $$;

-- The (large) photo / audio is fetched on demand, one message at a time.
create or replace function public.my_chat_media(p_token uuid, p_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  return (select media from chat_messages where id = p_id and user_id = uid);
end $$;

create or replace function public.admin_chat_media(p_token uuid, p_id uuid)
returns text language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return (select media from chat_messages where id = p_id);
end $$;

create or replace function public.send_chat_media(p_token uuid, p_kind text, p_media text, p_body text default '')
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user'); nm text;
begin
  if uid is null then raise exception 'Not authorised'; end if;
  if p_kind not in ('image', 'voice') then raise exception 'Invalid message type'; end if;
  if p_media is null or length(p_media) = 0 then raise exception 'Nothing to send'; end if;
  if length(p_media) > 3000000 then raise exception 'File is too large'; end if;
  select name into nm from app_users where id = uid;
  insert into chat_messages(user_id, from_admin, body, kind, media) values (uid, false, coalesce(trim(p_body), ''), p_kind, p_media);
  insert into admin_events(user_id, title, body) values (uid, 'Message from ' || nm,
    case when p_kind = 'image' then 'Sent a photo' else 'Sent a voice message' end);
end $$;

create or replace function public.admin_send_chat_media(p_token uuid, p_user uuid, p_kind text, p_media text, p_body text default '')
returns void language plpgsql security definer set search_path = public as $$
declare adm uuid := _session_account(p_token, 'admin');
begin
  if adm is null then raise exception 'Not authorised'; end if;
  if p_kind not in ('image', 'voice') then raise exception 'Invalid message type'; end if;
  if p_media is null or length(p_media) = 0 then raise exception 'Nothing to send'; end if;
  if length(p_media) > 3000000 then raise exception 'File is too large'; end if;
  insert into chat_messages(user_id, from_admin, admin_id, body, kind, media)
    values (p_user, true, adm, coalesce(trim(p_body), ''), p_kind, p_media);
end $$;

create or replace function public.admin_chat_threads(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(r order by r.last_at desc nulls last, r.name) from (
    select u.id, u.name, u.role_title, u.staff_type,
      (select case c.kind when 'image' then 'Photo' when 'voice' then 'Voice message' else c.body end
         from chat_messages c where c.user_id = u.id order by created_at desc limit 1) as last_body,
      (select created_at from chat_messages c where c.user_id = u.id order by created_at desc limit 1) as last_at,
      (select count(*) from chat_messages c where c.user_id = u.id and not c.from_admin and c.read_at is null) as unread
    from app_users u where u.status = 'approved') r), '[]'::json);
end $$;

-- ── admin side ──────────────────────────────────────────────────────────────────────────────────
create or replace function public.admin_create_office_task(p_token uuid, p_user uuid, p_title text, p_note text, p_due timestamptz)
returns uuid language plpgsql security definer set search_path = public as $$
declare adm uuid := _session_account(p_token, 'admin'); tid uuid := gen_random_uuid();
begin
  if adm is null then raise exception 'Not authorised'; end if;
  if length(trim(coalesce(p_title, ''))) = 0 then raise exception 'Task title is required'; end if;
  insert into office_tasks(id, user_id, title, note, due_at, created_by_admin)
    values (tid, p_user, trim(p_title), coalesce(trim(p_note), ''), p_due, adm);
  insert into chat_messages(user_id, from_admin, admin_id, body, is_system)
    values (p_user, true, adm, 'New task assigned: ' || trim(p_title), true);
  return tid;
end $$;

-- Everything dated, for the admin calendar and the employee detail page.
create or replace function public.admin_calendar(p_token uuid, p_from timestamptz, p_to timestamptz, p_user uuid default null)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return json_build_object(
    'leaves', coalesce((select json_agg(json_build_object('id', l.id, 'user_id', l.user_id, 'user_name', u.name,
        'from', l.from_date, 'to', l.to_date, 'reason', l.reason, 'status', l.status) order by l.from_date)
      from leave_requests l join app_users u on u.id = l.user_id
      where l.status in ('pending', 'approved') and l.to_date >= p_from::date and l.from_date <= p_to::date
        and (p_user is null or l.user_id = p_user)), '[]'::json),
    'follow_ups', coalesce((select json_agg(json_build_object('id', f.id, 'user_id', f.user_id, 'user_name', u.name,
        'name', f.contact_name, 'org', f.organization, 'phone', f.phone, 'purpose', f.purpose, 'kind', f.kind,
        'remind_at', f.remind_at, 'status', f.status) order by f.remind_at)
      from follow_ups f join app_users u on u.id = f.user_id
      where f.remind_at >= p_from and f.remind_at < p_to and (p_user is null or f.user_id = p_user)), '[]'::json),
    'office_tasks', coalesce((select json_agg(json_build_object('id', t.id, 'user_id', t.user_id, 'user_name', u.name,
        'title', t.title, 'note', t.note, 'due_at', t.due_at, 'status', t.status) order by t.due_at)
      from office_tasks t join app_users u on u.id = t.user_id
      where t.due_at >= p_from and t.due_at < p_to and (p_user is null or t.user_id = p_user)), '[]'::json));
end $$;

create or replace function public.admin_office_tasks(p_token uuid, p_user uuid default null)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', t.id, 'user_id', t.user_id, 'user_name', u.name, 'title', t.title,
      'note', t.note, 'due_at', t.due_at, 'status', t.status, 'completed_at', t.completed_at) order by t.due_at desc)
    from office_tasks t join app_users u on u.id = t.user_id where p_user is null or t.user_id = p_user), '[]'::json);
end $$;

create or replace function public.admin_follow_ups(p_token uuid, p_user uuid default null)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', f.id, 'user_id', f.user_id, 'user_name', u.name, 'name', f.contact_name,
      'org', f.organization, 'phone', f.phone, 'purpose', f.purpose, 'kind', f.kind, 'remind_at', f.remind_at,
      'status', f.status, 'result', f.result_note) order by f.remind_at desc)
    from follow_ups f join app_users u on u.id = f.user_id where p_user is null or f.user_id = p_user), '[]'::json);
end $$;

create or replace function public.admin_leaves(p_token uuid, p_user uuid default null)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', l.id, 'user_id', l.user_id, 'user_name', u.name, 'staff_type', u.staff_type,
      'from', l.from_date, 'to', l.to_date, 'reason', l.reason, 'status', l.status, 'decided_at', l.decided_at,
      'created_at', l.created_at) order by (l.status = 'pending') desc, l.from_date desc)
    from leave_requests l join app_users u on u.id = l.user_id
    where l.status <> 'cancelled' and (p_user is null or l.user_id = p_user)), '[]'::json);
end $$;

create or replace function public.admin_decide_leave(p_token uuid, p_id uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
declare adm uuid := _session_account(p_token, 'admin'); l leave_requests;
begin
  if adm is null then raise exception 'Not authorised'; end if;
  select * into l from leave_requests where id = p_id;
  if l.id is null then raise exception 'Leave request not found'; end if;
  update leave_requests set status = case when p_approve then 'approved' else 'rejected' end,
    decided_by = adm, decided_at = now() where id = p_id;
  insert into chat_messages(user_id, from_admin, admin_id, body, is_system)
    values (l.user_id, true, adm,
      'Leave ' || to_char(l.from_date, 'DD Mon') || case when l.to_date <> l.from_date then ' – ' || to_char(l.to_date, 'DD Mon') else '' end
      || (case when p_approve then ' approved' else ' rejected' end), true);
end $$;

create or replace function public.admin_create_announcement(p_token uuid, p_title text, p_body text, p_image text, p_audience text)
returns uuid language plpgsql security definer set search_path = public as $$
declare adm uuid := _session_account(p_token, 'admin'); aid uuid;
begin
  if adm is null then raise exception 'Not authorised'; end if;
  if length(trim(coalesce(p_title, ''))) = 0 then raise exception 'Title is required'; end if;
  if p_image is not null and length(p_image) > 1500000 then raise exception 'Image is too large'; end if;
  insert into announcements(admin_id, title, body, image, audience)
    values (adm, trim(p_title), coalesce(trim(p_body), ''), nullif(p_image, ''), coalesce(p_audience, 'all'))
    returning id into aid;
  return aid;
end $$;

create or replace function public.admin_list_announcements(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', id, 'title', title, 'body', body, 'image', image,
      'audience', audience, 'created_at', created_at) order by created_at desc)
    from (select * from announcements order by created_at desc limit 50) a), '[]'::json);
end $$;

create or replace function public.admin_delete_announcement(p_token uuid, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  delete from announcements where id = p_id;
end $$;

grant execute on function
  public.user_login(text, text), public.session_info(uuid),
  public.admin_create_user_v2(uuid, text, text, text, text), public.admin_set_staff_type(uuid, uuid, text),
  public.admin_list_users(uuid), public.admin_live(uuid),
  public.sync_office_task(uuid, uuid, text, text, timestamptz, text), public.delete_office_task(uuid, uuid),
  public.my_office_tasks(uuid),
  public.sync_follow_up(uuid, uuid, text, text, text, text, text, timestamptz, text, text),
  public.delete_follow_up(uuid, uuid), public.my_follow_ups(uuid),
  public.request_leave(uuid, date, date, text), public.cancel_leave(uuid, uuid), public.my_leaves(uuid),
  public.my_announcements(uuid),
  public.my_chat(uuid), public.admin_chat(uuid, uuid), public.my_chat_media(uuid, uuid), public.admin_chat_media(uuid, uuid),
  public.send_chat_media(uuid, text, text, text), public.admin_send_chat_media(uuid, uuid, text, text, text),
  public.admin_chat_threads(uuid),
  public.admin_create_office_task(uuid, uuid, text, text, timestamptz),
  public.admin_calendar(uuid, timestamptz, timestamptz, uuid),
  public.admin_office_tasks(uuid, uuid), public.admin_follow_ups(uuid, uuid), public.admin_leaves(uuid, uuid),
  public.admin_decide_leave(uuid, uuid, boolean),
  public.admin_create_announcement(uuid, text, text, text, text), public.admin_list_announcements(uuid),
  public.admin_delete_announcement(uuid, uuid)
to anon, authenticated;

notify pgrst, 'reload schema';
