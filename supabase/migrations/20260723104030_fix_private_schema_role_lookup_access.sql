grant usage on schema private to authenticated, service_role;

revoke execute on all functions in schema private
  from public, anon, authenticated, service_role;

grant execute on function private.current_role()
  to authenticated, service_role;

grant execute on function private.dispatch_manager_can_read_profile(uuid)
  to authenticated, service_role;
