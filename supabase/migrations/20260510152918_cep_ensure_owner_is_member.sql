/*
  # Ensure workspace owners are always workspace_members

  1. Problem
    - Many RLS policies across the schema gate access via `workspace_members`.
    - Workspace OWNERS were not always inserted into `workspace_members`,
      so owners hit RLS denials (e.g. logo upload, webhooks, api keys,
      commerce tables, etc.).
  2. Fix
    - Backfill: insert a `workspace_members` row (role = 'owner') for every
      workspace owner that is missing one.
    - New trigger `ensure_owner_in_members` on `workspaces`:
      after insert, ensures the owner is present in workspace_members.
  3. Security
    - No policy changes needed; the invariant now matches the assumption
      every policy makes.
*/

insert into workspace_members (workspace_id, user_id, role)
select w.id, w.owner_id, 'owner'
from workspaces w
where w.owner_id is not null
  and not exists (
    select 1 from workspace_members wm
    where wm.workspace_id = w.id and wm.user_id = w.owner_id
  )
on conflict do nothing;

create or replace function public.ensure_owner_in_members()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.owner_id is not null then
    insert into workspace_members (workspace_id, user_id, role)
    values (new.id, new.owner_id, 'owner')
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists ensure_owner_member_on_workspace on workspaces;
create trigger ensure_owner_member_on_workspace
after insert on workspaces
for each row execute function public.ensure_owner_in_members();