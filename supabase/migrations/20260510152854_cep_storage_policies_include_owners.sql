/*
  # Fix workspace-logos storage policies to include owners

  1. Problem
    - Existing policies only check `workspace_members`, so workspace OWNERS
      (who may not have a `workspace_members` row) got RLS errors on upload.
  2. Fix
    - Replace insert/update/delete policies so they allow either:
      a) the workspace owner (workspaces.owner_id = auth.uid()), OR
      b) a workspace_members row for the caller.
  3. Security
    - Public read unchanged (logos need to render in emails / apps).
    - Writes still gated to workspace owners + members only.
*/

drop policy if exists "workspace_logos_member_insert" on storage.objects;
drop policy if exists "workspace_logos_member_update" on storage.objects;
drop policy if exists "workspace_logos_member_delete" on storage.objects;

create policy "workspace_logos_write_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'workspace-logos'
    and (
      exists (
        select 1 from workspaces w
        where w.id::text = split_part(name, '/', 1)
          and w.owner_id = auth.uid()
      )
      or exists (
        select 1 from workspace_members wm
        where wm.workspace_id::text = split_part(name, '/', 1)
          and wm.user_id = auth.uid()
      )
    )
  );

create policy "workspace_logos_write_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'workspace-logos'
    and (
      exists (
        select 1 from workspaces w
        where w.id::text = split_part(name, '/', 1)
          and w.owner_id = auth.uid()
      )
      or exists (
        select 1 from workspace_members wm
        where wm.workspace_id::text = split_part(name, '/', 1)
          and wm.user_id = auth.uid()
      )
    )
  )
  with check (
    bucket_id = 'workspace-logos'
    and (
      exists (
        select 1 from workspaces w
        where w.id::text = split_part(name, '/', 1)
          and w.owner_id = auth.uid()
      )
      or exists (
        select 1 from workspace_members wm
        where wm.workspace_id::text = split_part(name, '/', 1)
          and wm.user_id = auth.uid()
      )
    )
  );

create policy "workspace_logos_write_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'workspace-logos'
    and (
      exists (
        select 1 from workspaces w
        where w.id::text = split_part(name, '/', 1)
          and w.owner_id = auth.uid()
      )
      or exists (
        select 1 from workspace_members wm
        where wm.workspace_id::text = split_part(name, '/', 1)
          and wm.user_id = auth.uid()
      )
    )
  );