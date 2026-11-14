-- Replace change_request_status with authenticated-actor authorization.
-- Review-only migration: do not apply to production without approval.

begin;

-- Remove the insecure signature that accepted a caller-supplied actor UUID.
-- No callers are present in the tracked migrations or application files on this branch.
drop function if exists public.change_request_status(uuid, public.request_status, uuid);

drop function if exists public.change_request_status(uuid, public.request_status);

create function public.change_request_status(
  p_request_id uuid,
  p_new_status public.request_status
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_department_id uuid;
  v_current_status public.request_status;
begin
  if v_actor_id is null then
    raise exception 'Authentication required';
  end if;

  select sr.department_id, sr.status
    into v_department_id, v_current_status
  from public.service_requests sr
  where sr.id = p_request_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;

  if not (
    public.is_super_admin(v_actor_id)
    or public.is_administrator(v_actor_id)
    or public.has_role_in_department(v_actor_id, 'department_administrator', v_department_id)
    or public.has_role_in_department(v_actor_id, 'support_agent', v_department_id)
  ) then
    raise exception 'User is not authorized to change this request status';
  end if;

  -- Preserve the existing lifecycle behavior: accept any value in the existing
  -- request_status enum; a business-approved transition matrix is not yet available.
  update public.service_requests
  set status = p_new_status,
      updated_at = now(),
      closed_at = case
        when p_new_status in ('closed'::public.request_status, 'cancelled'::public.request_status) then now()
        else null
      end
  where id = p_request_id;

  insert into public.service_request_events (
    service_request_id,
    actor_user_id,
    event_type,
    old_status,
    new_status,
    customer_visible,
    message
  ) values (
    p_request_id,
    v_actor_id,
    'status_changed',
    v_current_status,
    p_new_status,
    true,
    'Request status updated by staff.'
  );
end;
$$;

revoke all on function public.change_request_status(uuid, public.request_status) from public;
revoke all on function public.change_request_status(uuid, public.request_status) from anon;
revoke all on function public.change_request_status(uuid, public.request_status) from service_role;
grant execute on function public.change_request_status(uuid, public.request_status) to authenticated;

commit;
