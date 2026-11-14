-- Correct the role-granting actor to use the verified Supabase auth context.
-- This is review-only and must not be applied to production without approval.

begin;

-- Drop the old four-argument overload (whose fourth UUID was caller supplied).
-- Repository inspection found no callers in tracked frontend files or other
-- migration definitions; retain the three-argument API shape for legitimate callers.
drop function if exists public.grant_user_role(uuid, public.app_role, uuid, uuid);

create function public.grant_user_role(
  p_user_id uuid,
  p_role public.app_role,
  p_department_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_id uuid;
begin
  if v_actor_id is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_super_admin(v_actor_id) then
    raise exception 'Only super administrators can grant roles';
  end if;

  if p_role = 'department_administrator' and p_department_id is null then
    raise exception 'Department administrators require a department scope';
  end if;

  if p_role in ('administrator', 'super_administrator') and p_department_id is not null then
    raise exception 'Global admin roles cannot be department-scoped';
  end if;

  insert into public.user_roles (user_id, role, department_id, granted_by, revoked_at)
  values (p_user_id, p_role, p_department_id, v_actor_id, null)
  on conflict (user_id, role, department_id) where department_id is not null
  do update
    set revoked_at = null,
        updated_at = now(),
        granted_by = excluded.granted_by,
        granted_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

-- Do not leave default PUBLIC execution or the removed caller-supplied overload.
-- Only authenticated sessions may invoke this; the function itself verifies that
-- auth.uid() is non-NULL and has the active super_administrator role.
revoke all on function public.grant_user_role(uuid, public.app_role, uuid) from public;
revoke all on function public.grant_user_role(uuid, public.app_role, uuid) from anon;
revoke all on function public.grant_user_role(uuid, public.app_role, uuid) from authenticated;
revoke all on function public.grant_user_role(uuid, public.app_role, uuid) from service_role;
grant execute on function public.grant_user_role(uuid, public.app_role, uuid) to authenticated;

commit;
