/*
  # Phase 6 - AI Studio tables

  1. New Tables
    - `ai_anomalies` — detected deltas in metrics (events, campaigns, signals) with severity + status
    - `ai_segment_suggestions` — Claude-generated segment ideas with rationale and rules
    - `ai_journey_drafts` — Claude-generated journey canvases (nodes/edges) ready to promote to a real journey
    - `ai_path_insights` — per-journey drop-off and optimisation notes

  2. Security
    - Enable RLS on all new tables
    - Workspace members read; admins/editors mutate; service-role inserts allowed for edge functions
*/

create table if not exists ai_anomalies (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  kind text not null default 'metric',
  metric text not null,
  dimension text default '',
  baseline numeric default 0,
  current numeric default 0,
  delta_pct numeric default 0,
  severity text not null default 'info',
  summary text default '',
  status text not null default 'open',
  detected_at timestamptz default now(),
  resolved_at timestamptz
);
alter table ai_anomalies enable row level security;

create policy "anomalies select member" on ai_anomalies for select to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = ai_anomalies.workspace_id and m.user_id = auth.uid()));
create policy "anomalies insert admin" on ai_anomalies for insert to authenticated
  with check (exists (select 1 from workspace_members m where m.workspace_id = ai_anomalies.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin','editor')));
create policy "anomalies update admin" on ai_anomalies for update to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = ai_anomalies.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin','editor')))
  with check (exists (select 1 from workspace_members m where m.workspace_id = ai_anomalies.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin','editor')));
create policy "anomalies delete admin" on ai_anomalies for delete to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = ai_anomalies.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin')));

create index if not exists idx_ai_anomalies_ws_time on ai_anomalies(workspace_id, detected_at desc);

create table if not exists ai_segment_suggestions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  name text not null,
  description text default '',
  rules jsonb not null default '{"conditions":[]}'::jsonb,
  expected_count integer default 0,
  rationale text default '',
  model text default 'heuristic',
  status text not null default 'pending',
  segment_id uuid references segments(id) on delete set null,
  created_at timestamptz default now()
);
alter table ai_segment_suggestions enable row level security;

create policy "seg sugg select member" on ai_segment_suggestions for select to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = ai_segment_suggestions.workspace_id and m.user_id = auth.uid()));
create policy "seg sugg insert editor" on ai_segment_suggestions for insert to authenticated
  with check (exists (select 1 from workspace_members m where m.workspace_id = ai_segment_suggestions.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin','editor')));
create policy "seg sugg update editor" on ai_segment_suggestions for update to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = ai_segment_suggestions.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin','editor')))
  with check (exists (select 1 from workspace_members m where m.workspace_id = ai_segment_suggestions.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin','editor')));
create policy "seg sugg delete admin" on ai_segment_suggestions for delete to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = ai_segment_suggestions.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin')));

create table if not exists ai_journey_drafts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  goal text not null default '',
  trigger_event text default '',
  name text not null default 'AI journey draft',
  description text default '',
  nodes jsonb not null default '[]'::jsonb,
  edges jsonb not null default '[]'::jsonb,
  rationale text default '',
  model text default 'heuristic',
  status text not null default 'pending',
  journey_id uuid references journeys(id) on delete set null,
  created_at timestamptz default now()
);
alter table ai_journey_drafts enable row level security;

create policy "jd select member" on ai_journey_drafts for select to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = ai_journey_drafts.workspace_id and m.user_id = auth.uid()));
create policy "jd insert editor" on ai_journey_drafts for insert to authenticated
  with check (exists (select 1 from workspace_members m where m.workspace_id = ai_journey_drafts.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin','editor')));
create policy "jd update editor" on ai_journey_drafts for update to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = ai_journey_drafts.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin','editor')))
  with check (exists (select 1 from workspace_members m where m.workspace_id = ai_journey_drafts.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin','editor')));
create policy "jd delete admin" on ai_journey_drafts for delete to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = ai_journey_drafts.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin')));

create table if not exists ai_path_insights (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  journey_id uuid not null references journeys(id) on delete cascade,
  node_id text default '',
  insight_kind text not null default 'drop_off',
  severity text not null default 'info',
  summary text default '',
  suggestion text default '',
  detected_at timestamptz default now()
);
alter table ai_path_insights enable row level security;

create policy "pi select member" on ai_path_insights for select to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = ai_path_insights.workspace_id and m.user_id = auth.uid()));
create policy "pi insert editor" on ai_path_insights for insert to authenticated
  with check (exists (select 1 from workspace_members m where m.workspace_id = ai_path_insights.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin','editor')));
create policy "pi update editor" on ai_path_insights for update to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = ai_path_insights.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin','editor')))
  with check (exists (select 1 from workspace_members m where m.workspace_id = ai_path_insights.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin','editor')));
create policy "pi delete admin" on ai_path_insights for delete to authenticated
  using (exists (select 1 from workspace_members m where m.workspace_id = ai_path_insights.workspace_id and m.user_id = auth.uid() and m.role in ('owner','admin')));

create index if not exists idx_ai_path_insights_journey on ai_path_insights(journey_id, detected_at desc);
