-- Profile editing. Run after schema.sql. Safe to re-run.
alter table public.app_users add column if not exists phone text;

create or replace function public.my_profile(p_token uuid)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  return (select json_build_object('name', name, 'email', email, 'phone', phone) from app_users where id = uid);
end $$;

create or replace function public.update_my_profile(p_token uuid, p_name text, p_phone text)
returns json language plpgsql security definer set search_path = public as $$
declare uid uuid := _session_account(p_token, 'user');
begin
  if uid is null then raise exception 'Not authorised'; end if;
  if length(trim(coalesce(p_name, ''))) = 0 then raise exception 'Name is required'; end if;
  update app_users set name = trim(p_name), phone = nullif(trim(coalesce(p_phone, '')), '') where id = uid;
  return (select json_build_object('name', name, 'email', email, 'phone', phone) from app_users where id = uid);
end $$;
