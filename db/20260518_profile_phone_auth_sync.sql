update public.profiles
   set phone =
       case
         when phone ~ '^\+[1-9][0-9]{7,14}$' then phone
         when regexp_replace(phone, '\D', '', 'g') ~ '^[0-9]{10}$' then '+91' || regexp_replace(phone, '\D', '', 'g')
         when regexp_replace(phone, '\D', '', 'g') ~ '^91[0-9]{10}$' then '+' || regexp_replace(phone, '\D', '', 'g')
         else phone
       end
 where phone is not null
   and btrim(phone) <> '';

create unique index if not exists profiles_phone_unique_idx
on public.profiles (phone)
where phone is not null and btrim(phone) <> '';

create schema if not exists private;

create or replace function private.sync_profile_phone_to_auth_user()
returns trigger
language plpgsql
security definer
set search_path = auth, public, pg_temp
as $$
declare
  normalized_phone text := nullif(btrim(new.phone), '');
begin
  if normalized_phone is not null and normalized_phone !~ '^\+[1-9][0-9]{7,14}$' then
    raise exception 'Phone number must be in E.164 format';
  end if;

  update auth.users
     set phone = normalized_phone,
         updated_at = now()
   where id = new.id
     and phone is distinct from normalized_phone;

  return new;
end;
$$;

drop trigger if exists sync_profile_phone_to_auth_user on public.profiles;

create trigger sync_profile_phone_to_auth_user
after insert or update of phone on public.profiles
for each row
execute function private.sync_profile_phone_to_auth_user();

update public.profiles
   set phone = phone
 where phone is not null
   and btrim(phone) <> '';
