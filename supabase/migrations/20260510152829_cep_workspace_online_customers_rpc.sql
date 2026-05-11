/*
  # Online customers RPC (distinct count)

  1. New function
    - `workspace_online_customers(p_workspace_id uuid, p_minutes integer default 10)`
    - Returns `integer`: count of DISTINCT `customer_id` on `events`
      in the given workspace within the last N minutes.
  2. Security
    - SECURITY DEFINER, but explicitly checks that `auth.uid()` is either
      the workspace owner or a member before returning a number.
    - Returns 0 for non-members, never leaks cross-workspace counts.
  3. Performance
    - Uses the existing `(workspace_id, occurred_at desc)` index on events.
    - p_minutes clamped to [1, 1440].
    - Returns a single integer to the client (tiny payload).
*/

create or replace function public.workspace_online_customers(p_workspace_id uuid, p_minutes integer default 10)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_cutoff timestamptz;
  v_ok boolean;
  v_count integer;
begin
  if p_workspace_id is null then
    return 0;
  end if;
  if p_minutes is null or p_minutes < 1 then p_minutes := 10; end if;
  if p_minutes > 1440 then p_minutes := 1440; end if;

  select exists(
    select 1 from workspaces w where w.id = p_workspace_id and w.owner_id = auth.uid()
    union all
    select 1 from workspace_members wm where wm.workspace_id = p_workspace_id and wm.user_id = auth.uid()
  ) into v_ok;

  if not coalesce(v_ok, false) then
    return 0;
  end if;

  v_cutoff := now() - make_interval(mins => p_minutes);

  select count(distinct customer_id)::int
  into v_count
  from events
  where workspace_id = p_workspace_id
    and occurred_at >= v_cutoff
    and customer_id is not null;

  return coalesce(v_count, 0);
end;
$$;

grant execute on function public.workspace_online_customers(uuid, integer) to authenticated;