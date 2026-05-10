/*
  # Workspace logos storage bucket

  1. Storage
    - Creates a public `workspace-logos` bucket for workspace logo uploads.
  2. Security
    - Public read (logos need to render in emails / client apps).
    - Authenticated members of a workspace can upload / update / delete files
      under a path prefix that matches a workspace they belong to.
  3. Notes
    1. Files are expected to be stored at path `{workspace_id}/{filename}`.
    2. Write access is gated through workspace_members, not USING (true).
*/

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('workspace-logos', 'workspace-logos', true, 2097152, array['image/png','image/jpeg','image/webp','image/svg+xml','image/gif'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'workspace_logos_public_read') then
    create policy "workspace_logos_public_read"
      on storage.objects for select
      to public
      using (bucket_id = 'workspace-logos');
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'workspace_logos_member_insert') then
    create policy "workspace_logos_member_insert"
      on storage.objects for insert
      to authenticated
      with check (
        bucket_id = 'workspace-logos'
        and exists (
          select 1 from workspace_members wm
          where wm.workspace_id::text = split_part(name, '/', 1)
            and wm.user_id = auth.uid()
        )
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'workspace_logos_member_update') then
    create policy "workspace_logos_member_update"
      on storage.objects for update
      to authenticated
      using (
        bucket_id = 'workspace-logos'
        and exists (
          select 1 from workspace_members wm
          where wm.workspace_id::text = split_part(name, '/', 1)
            and wm.user_id = auth.uid()
        )
      )
      with check (
        bucket_id = 'workspace-logos'
        and exists (
          select 1 from workspace_members wm
          where wm.workspace_id::text = split_part(name, '/', 1)
            and wm.user_id = auth.uid()
        )
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'workspace_logos_member_delete') then
    create policy "workspace_logos_member_delete"
      on storage.objects for delete
      to authenticated
      using (
        bucket_id = 'workspace-logos'
        and exists (
          select 1 from workspace_members wm
          where wm.workspace_id::text = split_part(name, '/', 1)
            and wm.user_id = auth.uid()
        )
      );
  end if;
end $$;