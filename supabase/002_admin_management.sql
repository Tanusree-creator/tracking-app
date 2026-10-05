-- Admin management. Run after schema.sql. Safe to re-run.
create or replace function public.admin_create_admin(p_token uuid, p_email text, p_password text default null)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare pw text; aid uuid; em text := lower(trim(p_email));
begin
  if _session_account(p_token, 'admin') is null then raise exception 'Not authorised'; end if;
  if em !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Enter a valid email'; end if;
  if exists (select 1 from admins where email = em) then
    raise exception 'An admin with this email already exists';
  end if;
  pw := coalesce(nullif(p_password, ''),
                 substr(translate(encode(gen_random_bytes(12), 'base64'), '+/=', 'xyz'), 1, 12));
  if length(pw) < 8 then raise exception 'Password must be at least 8 characters'; end if;
  insert into admins(email, password_hash) values (em, crypt(pw, gen_salt('bf'))) returning id into aid;
  return json_build_object('id', aid, 'email', em, 'password', pw);
end $$;

create or replace function public.admin_list_admins(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare me uuid := _session_account(p_token, 'admin');
begin
  if me is null then raise exception 'Not authorised'; end if;
  return coalesce((select json_agg(json_build_object('id', id, 'email', email,
                   'created_at', created_at, 'is_me', id = me) order by created_at)
                   from admins), '[]'::json);
end $$;

create or replace function public.admin_delete_admin(p_token uuid, p_admin uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid := _session_account(p_token, 'admin');
begin
  if me is null then raise exception 'Not authorised'; end if;
  if p_admin = me then raise exception 'You cannot remove your own admin account'; end if;
  if (select count(*) from admins) <= 1 then raise exception 'At least one admin must remain'; end if;
  if exists (select 1 from app_users where created_by = p_admin) or exists (select 1 from messages where sender_admin_id = p_admin) then
    raise exception 'This admin has created users and cannot be removed';
  end if;
  delete from app_sessions where role = 'admin' and account_id = p_admin;
  delete from admins where id = p_admin;
end $$;
