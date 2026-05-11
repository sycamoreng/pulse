/*
  # Online workspace members RPC

  1. New function
    - `workspace_online_members(workspace_id uuid, minutes integer default 10)`
    - Returns the count of members of the given workspace whose
      `auth.users.last_sign_in_at` is within the last N minutes.
  2. Security
    - SECURITY DEFINER so it can read auth.users while still enforcing
      that the caller is a member of the workspace they're asking about.
    - Returns 0 if caller isn't a member — never leaks counts cross-workspace.
  3. Notes
    1. The owner is always treated as a member.
    2. Minutes is capped at 1440 (24h) to avoid accidental long windows.
*/

create or replace function public.workspace_online_members(p_workspace_id uuid, p_minutes integer default 10)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cutoff timestamptz;
  v_is_member boolean;
  v_count integer;
begin
  if p_workspace_id is null then
    return 0;
  end if;
  if p_minutes is null or p_minutes < 1 then
    p_minutes := 10;
  end if;
  if p_minutes > 1440 then
    p_minutes := 1440;
  end if;
  v_cutoff := now() - make_interval(mins => p_minutes);

  select exists(
    select 1 from workspaces w where w.id = p_workspace_id and w.owner_id = auth.uid()
    union all
    select 1 from workspace_members wm where wm.workspace_id = p_workspace_id and wm.user_id = auth.uid()
  ) into v_is_member;

  if not coalesce(v_is_member, false) then
    return 0;
  end if;

  select count(*)::int
  into v_count
  from (
    select u.id
    from auth.users u
    where u.last_sign_in_at >= v_cutoff
      and (
        exists (select 1 from workspaces w where w.id = p_workspace_id and w.owner_id = u.id)
        or exists (select 1 from workspace_members wm where wm.workspace_id = p_workspace_id and wm.user_id = u.id)
      )
  ) q;

  return coalesce(v_count, 0);
end;
$$;

grant execute on function public.workspace_online_members(uuid, integer) to authenticated;