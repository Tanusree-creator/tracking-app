-- Run once against the Supabase Postgres DB. Safe to re-run.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.admins (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  password_hash text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.app_users (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text unique not null,
  password_hash text not null,
  created_by uuid references public.admins(id),
  role_title text not null default 'Field Technician',
  district text not null default 'East District',
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_users(id) on delete cascade,
  sender_admin_id uuid not null references public.admins(id),
  title text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.app_sessions (
  token uuid primary key default gen_random_uuid(),
  role text not null check (role in ('admin','user')),
  account_id uuid not null,
  expires_at timestamptz not null default now() + interval '30 days'
);

-- Lock tables down: the app only reaches data through the functions below.
alter table public.admins enable row level security;
alter table public.app_users enable row level security;
alter table public.messages enable row level security;
alter table public.app_sessions enable row level security;

create or replace function public._session_account(p_token uuid, p_role text)
returns uuid language sql security definer set search_path = public as $$
  select account_id from app_sessions
  where token = p_token and role = p_role and expires_at > now()
$$;

create or replace function public.admin_login(p_email text, p_password text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare a admins; t uuid;
begin
  select * into a from admins where email = lower(p_email);
  if a.id is null or a.password_hash <> crypt(p_password, a.password_hash) then
    raise exception 'Incorrect email or password';
  end if;
  insert into app_sessions(role, account_id) values ('admin', a.id) returning token into t;
  return json_build_object('token', t, 'role', 'admin', 'email', a.email);
end $$;

create or replace function public.user_login(p_email text, p_password text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare u app_users; t uuid;
begin
  select * into u from app_users where email = lower(p_email);
  if u.id is null or u.password_hash <> crypt(p_password, u.password_hash) then
    raise exception 'Incorrect email or password';
  end if;
  if u.status = 'pending' then raise exception 'Your account is awaiting admin approval'; end if;
  if u.status = 'rejected' then raise exception 'Your access request was rejected'; end if;
  insert into app_sessions(role, account_id) values ('user', u.id) returning token into t;
  return json_build_object('token', t, 'role', 'user', 'id', u.id, 'email', u.email, 'name', u.name, 'role_title', u.role_title, 'district', u.district);
end $$;

-- Admin creates a user; the credentials are delivered as an in-app message.
create or replace function public.admin_create_user(
  p_token uuid, p_name text, p_email text, p_password text default null)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare adm uuid; pw text; uid uuid; em text := lower(trim(p_email));
begin
  adm := _session_account(p_token, 'admin');
  if adm is null then raise exception 'Not authorised'; end if;
  if exists (select 1 from app_users where email = em) then
    raise exception 'A user with this email already exists';
  end if;
  pw := coalesce(nullif(p_password, ''),
                 substr(translate(encode(gen_random_bytes(12), 'base64'), '+/=', 'xyz'), 1, 12));
  if length(pw) < 8 then raise exception 'Password must be at least 8 characters'; end if;
  insert into app_users(name, email, password_hash, created_by, status)
    values (trim(p_name), em, crypt(pw, gen_salt('bf')), adm, 'approved') returning id into uid;
  insert into messages(user_id, sender_admin_id, title, body) values (uid, adm,
    'Your account has been created',
    format(E'Hello %s,\n\nYour login details:\nEmail: %s\nPassword: %s\n\nPlease keep these safe.', trim(p_name), em, pw));
  return json_build_object('id', uid, 'email', em, 'password', pw);
end $$;

create or replace function public.admin_list_users(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', id, 'name', name, 'email', email, 'status', status, 'role_title', role_title, 'district', district, 'created_at', created_at)
                   order by created_at desc) from app_users), '[]'::json);
end $$;

create or replace function public.my_messages(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', id, 'title', title, 'body', body,
                   'is_read', is_read, 'created_at', created_at) order by created_at desc)
                   from messages where user_id = uid), '[]'::json);
end $$;

-- Employee self-registration: lands as 'pending' until an admin approves.
create or replace function public.register_employee(p_name text, p_email text, p_password text)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare em text := lower(trim(p_email));
begin
  if length(trim(coalesce(p_name,''))) = 0 then raise exception 'Name is required'; end if;
  if length(coalesce(p_password,'')) < 8 then raise exception 'Password must be at least 8 characters'; end if;
  if exists (select 1 from app_users where email = em) then
    raise exception 'An account with this email already exists';
  end if;
  insert into app_users(name, email, password_hash, status)
    values (trim(p_name), em, crypt(p_password, gen_salt('bf')), 'pending');
end $$;

create or replace function public.admin_set_user_status(p_token uuid, p_user uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  if p_status not in ('approved','rejected') then raise exception 'Invalid status'; end if;
  update app_users set status = p_status where id = p_user;
end $$;

revoke all on function public._session_account(uuid, text) from public, anon, authenticated;
