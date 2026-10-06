-- Contact edits must never change an Auth login identity. Existing users link
-- their phone through Auth updateUser + verifyOTP(phone_change), proving
-- ownership before Supabase changes the login phone.
drop trigger if exists sync_profile_phone_to_auth_user on public.profiles;
