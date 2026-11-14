-- Remove actor impersonation from role revocation.
-- Review on the hardening branch; do not apply to production without approval.

begin;

-- Repository inspection found no tracked callers of the legacy four-argument
-- signature. Drop it so the caller-supplied actor UUID cannot remain callable.
drop function if exists public.revoke_user_role(uuid, public.app_role, uuid, uuid);

create function public.revoke_user_role(
  p_user_id uuid,
  p_role public.app_role,
  p_department_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_super_admin(v_actor_id) then
    raise exception 'Only super administrators can revoke roles';
  end if;

  update public.user_roles
  set revoked_at = now(), updated_at = now()
  where user_id = p_user_id
    and role = p_role
    and department_id is not distinct from p_department_id
    and revoked_at is null;
end;
$$;

revoke all on function public.revoke_user_role(uuid, public.app_role, uuid) from public;
revoke all on function public.revoke_user_role(uuid, public.app_role, uuid) from anon;
revoke all on function public.revoke_user_role(uuid, public.app_role, uuid) from service_role;
grant execute on function public.revoke_user_role(uuid, public.app_role, uuid) to authenticated;

commit;
