/*
  # Phase 7 - Integration Hub

  1. New Tables
    - `integration_connections` — one row per installed integration (slack, adjust, mixpanel, metabase, gcs, s3, sheets, etc.)
      Clients only ever see non-secret config here. Secrets go in pulse_secrets.
    - `pulse_secrets.integration_credentials` — encrypted payload (AES-256-GCM via HKDF key) per connection.

  2. Security
    - RLS on integration_connections: workspace_members read, admin/owner mutate.
    - pulse_secrets.integration_credentials revoked from anon/authenticated; service-role only.
*/

create table if not exists integration_connections (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  provider text not null,
  name text not null default '',
  config jsonb not null default '{}'::jsonb,
  has_credentials boolean not null default false,
  is_active boolean not null default true,
  last_synced_at timestamptz,
  last_error text default '',
  created_at timestamptz default now()
);
alter table integration_connections enable row level security;

create policy "int conn select member" on integration_connections for select to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = integration_connections.workspace_id and m.user_id = auth.uid()));
create policy "int conn insert admin" on integration_connections for insert to authenticated
  with check (exists (select 1 from workspace_members m where m.workspace_id = integration_connections.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin')));
create policy "int conn update admin" on integration_connections for update to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = integration_connections.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin')))
  with check (exists (select 1 from workspace_members m where m.workspace_id = integration_connections.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin')));
create policy "int conn delete admin" on integration_connections for delete to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = integration_connections.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin')));

create index if not exists idx_int_conn_ws_provider on integration_connections(workspace_id, provider);

do $$ begin
  create schema if not exists pulse_secrets;
end $$;

create table if not exists pulse_secrets.integration_credentials (
  connection_id uuid primary key references integration_connections(id) on delete cascade,
  payload text not null,
  updated_at timestamptz default now()
);
revoke all on pulse_secrets.integration_credentials from anon, authenticated;
grant all on pulse_secrets.integration_credentials to service_role;
