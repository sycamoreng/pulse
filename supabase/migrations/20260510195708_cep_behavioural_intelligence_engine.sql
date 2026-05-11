/*
  # Behavioural intelligence engine

  1. New Tables
    - `signal_definitions`
      - Rule definitions that turn raw events into behavioural signals.
      - `key` (text) stable identifier, `rule_type` (text, sql_rule|event_count|event_sequence|absence),
        `rule jsonb` (parameters), `window_minutes int`, `priority int`,
        `description text`, `enabled bool`.
      - Workspace-scoped, seeded with a default library per workspace.
    - `customer_signals`
      - One row per (customer, signal_key) active at a time.
      - `confidence numeric(4,3)` 0..1, `context jsonb` (why it fired),
        `detected_at timestamptz`, `expires_at timestamptz`,
        `consumed_at timestamptz` (set when an action was taken).
    - `ai_recommendations`
      - One row per AI-suggested next-best-action.
      - `customer_id`, `signal_id` (nullable), `kind text` (message|product|journey_branch),
        `channel text`, `headline text`, `body text`, `cta text`,
        `products jsonb`, `payload jsonb`, `model text`, `confidence numeric(4,3)`,
        `status text` (pending|delivered|dismissed|converted), `used_in text`,
        `created_at timestamptz`, `delivered_at`, `converted_at`.
    - `intelligence_runs`
      - Audit table for each detection/AI pass (ops + cost observability).
      - `workspace_id`, `kind text`, `started_at`, `finished_at`,
        `events_scanned int`, `signals_created int`, `recommendations_created int`,
        `error text`.

  2. Security
    - RLS enabled on every new table, policies scoped to workspace membership.
    - Recommendations readable by members, writable by service role.
    - Signal definitions editable by owners/admins.

  3. Performance
    - Index `customer_signals (workspace_id, detected_at desc)` and `(customer_id, signal_key)`.
    - Unique `(workspace_id, customer_id, signal_key)` where consumed_at is null -> at most one open signal of a kind per customer.
    - Index `ai_recommendations (workspace_id, customer_id, created_at desc)`.

  4. Seeding
    - A trigger adds a default library of signal definitions to every new workspace
      (cart_abandoned, onboarding_stalled, power_user, churn_risk, price_hesitation,
       content_deep_dive, reengagement_window, feature_discovery_stalled).
    - Backfill existing workspaces.
*/

create table if not exists signal_definitions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  key text not null,
  label text not null default '',
  description text not null default '',
  rule_type text not null default 'event_count',
  rule jsonb not null default '{}'::jsonb,
  window_minutes integer not null default 1440,
  priority integer not null default 50,
  category text not null default 'engagement',
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (workspace_id, key)
);

create table if not exists customer_signals (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  signal_key text not null,
  signal_label text not null default '',
  category text not null default 'engagement',
  confidence numeric(4,3) not null default 0.5,
  context jsonb not null default '{}'::jsonb,
  detected_at timestamptz not null default now(),
  expires_at timestamptz,
  consumed_at timestamptz,
  consumed_by text,
  created_at timestamptz not null default now()
);

create unique index if not exists uq_customer_signals_open
  on customer_signals (workspace_id, customer_id, signal_key)
  where consumed_at is null;

create index if not exists idx_customer_signals_ws_time
  on customer_signals (workspace_id, detected_at desc);

create index if not exists idx_customer_signals_customer
  on customer_signals (customer_id, detected_at desc);

create table if not exists ai_recommendations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  signal_id uuid references customer_signals(id) on delete set null,
  signal_key text,
  kind text not null default 'message',
  channel text not null default 'email',
  headline text not null default '',
  body text not null default '',
  cta text not null default '',
  products jsonb not null default '[]'::jsonb,
  payload jsonb not null default '{}'::jsonb,
  reasoning text not null default '',
  model text not null default 'claude',
  confidence numeric(4,3) not null default 0.5,
  status text not null default 'pending',
  used_in text,
  created_at timestamptz not null default now(),
  delivered_at timestamptz,
  converted_at timestamptz,
  dismissed_at timestamptz
);

create index if not exists idx_ai_reco_ws_customer_time
  on ai_recommendations (workspace_id, customer_id, created_at desc);

create index if not exists idx_ai_reco_ws_status_time
  on ai_recommendations (workspace_id, status, created_at desc);

create table if not exists intelligence_runs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  kind text not null default 'detect',
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  events_scanned integer not null default 0,
  signals_created integer not null default 0,
  recommendations_created integer not null default 0,
  customers_touched integer not null default 0,
  error text
);

create index if not exists idx_intel_runs_ws_time
  on intelligence_runs (workspace_id, started_at desc);

alter table signal_definitions enable row level security;
alter table customer_signals enable row level security;
alter table ai_recommendations enable row level security;
alter table intelligence_runs enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='signal_definitions' and policyname='Members read signal defs') then
    create policy "Members read signal defs" on signal_definitions for select to authenticated
      using (exists (select 1 from workspace_members wm where wm.workspace_id = signal_definitions.workspace_id and wm.user_id = auth.uid()));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='signal_definitions' and policyname='Admins insert signal defs') then
    create policy "Admins insert signal defs" on signal_definitions for insert to authenticated
      with check (exists (select 1 from workspace_members wm where wm.workspace_id = signal_definitions.workspace_id and wm.user_id = auth.uid() and wm.role in ('owner','admin','editor')));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='signal_definitions' and policyname='Admins update signal defs') then
    create policy "Admins update signal defs" on signal_definitions for update to authenticated
      using (exists (select 1 from workspace_members wm where wm.workspace_id = signal_definitions.workspace_id and wm.user_id = auth.uid() and wm.role in ('owner','admin','editor')))
      with check (exists (select 1 from workspace_members wm where wm.workspace_id = signal_definitions.workspace_id and wm.user_id = auth.uid() and wm.role in ('owner','admin','editor')));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='signal_definitions' and policyname='Admins delete signal defs') then
    create policy "Admins delete signal defs" on signal_definitions for delete to authenticated
      using (exists (select 1 from workspace_members wm where wm.workspace_id = signal_definitions.workspace_id and wm.user_id = auth.uid() and wm.role in ('owner','admin')));
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='customer_signals' and policyname='Members read customer signals') then
    create policy "Members read customer signals" on customer_signals for select to authenticated
      using (exists (select 1 from workspace_members wm where wm.workspace_id = customer_signals.workspace_id and wm.user_id = auth.uid()));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='customer_signals' and policyname='Editors update customer signals') then
    create policy "Editors update customer signals" on customer_signals for update to authenticated
      using (exists (select 1 from workspace_members wm where wm.workspace_id = customer_signals.workspace_id and wm.user_id = auth.uid() and wm.role in ('owner','admin','editor')))
      with check (exists (select 1 from workspace_members wm where wm.workspace_id = customer_signals.workspace_id and wm.user_id = auth.uid() and wm.role in ('owner','admin','editor')));
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ai_recommendations' and policyname='Members read recos') then
    create policy "Members read recos" on ai_recommendations for select to authenticated
      using (exists (select 1 from workspace_members wm where wm.workspace_id = ai_recommendations.workspace_id and wm.user_id = auth.uid()));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ai_recommendations' and policyname='Editors update recos') then
    create policy "Editors update recos" on ai_recommendations for update to authenticated
      using (exists (select 1 from workspace_members wm where wm.workspace_id = ai_recommendations.workspace_id and wm.user_id = auth.uid() and wm.role in ('owner','admin','editor')))
      with check (exists (select 1 from workspace_members wm where wm.workspace_id = ai_recommendations.workspace_id and wm.user_id = auth.uid() and wm.role in ('owner','admin','editor')));
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='intelligence_runs' and policyname='Members read intel runs') then
    create policy "Members read intel runs" on intelligence_runs for select to authenticated
      using (exists (select 1 from workspace_members wm where wm.workspace_id = intelligence_runs.workspace_id and wm.user_id = auth.uid()));
  end if;
end $$;

create or replace function public.seed_signal_definitions(p_workspace_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into signal_definitions (workspace_id, key, label, description, rule_type, rule, window_minutes, priority, category, enabled) values
    (p_workspace_id, 'cart_abandoned', 'Cart abandoned',
     'Added to cart but did not purchase within 60 minutes.',
     'event_sequence',
     jsonb_build_object('trigger_event','add_to_cart','absent_event','purchase','within_minutes',60),
     120, 90, 'commerce', true),
    (p_workspace_id, 'price_hesitation', 'Price hesitation',
     'Repeatedly viewed a product or pricing page without purchasing.',
     'event_count',
     jsonb_build_object('event_name','product_viewed','min_count',3),
     1440, 70, 'commerce', true),
    (p_workspace_id, 'onboarding_stalled', 'Onboarding stalled',
     'Signed up but has not completed a key activation event.',
     'absence',
     jsonb_build_object('require_event','signup','absent_event','activated','since_hours',24),
     4320, 85, 'lifecycle', true),
    (p_workspace_id, 'power_user', 'Power user',
     'Highly active in the last week — great candidate for referrals or upsell.',
     'event_count',
     jsonb_build_object('min_count',20),
     10080, 40, 'engagement', true),
    (p_workspace_id, 'churn_risk', 'Churn risk',
     'Previously active, now quiet for 14+ days.',
     'absence',
     jsonb_build_object('require_prior_days',30,'quiet_days',14),
     43200, 80, 'retention', true),
    (p_workspace_id, 'content_deep_dive', 'Content deep dive',
     'Viewed 5+ pieces of content in a single session.',
     'event_count',
     jsonb_build_object('event_name','content_viewed','min_count',5),
     120, 50, 'engagement', true),
    (p_workspace_id, 'reengagement_window', 'Re-engagement window',
     'Back after a long absence — greet them now.',
     'event_sequence',
     jsonb_build_object('returned_after_days',14),
     1440, 75, 'retention', true),
    (p_workspace_id, 'feature_discovery_stalled', 'Feature discovery stalled',
     'Active but not exploring a core feature yet.',
     'absence',
     jsonb_build_object('require_event','session_start','absent_event','feature_used','since_days',7),
     20160, 55, 'product', true)
  on conflict (workspace_id, key) do nothing;
end;
$$;

grant execute on function public.seed_signal_definitions(uuid) to authenticated, service_role;

create or replace function public.seed_signal_definitions_on_workspace()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.seed_signal_definitions(new.id);
  return new;
end $$;

drop trigger if exists seed_signal_defs_on_ws on workspaces;
create trigger seed_signal_defs_on_ws
after insert on workspaces for each row execute function public.seed_signal_definitions_on_workspace();

do $$
declare w record;
begin
  for w in select id from workspaces loop
    perform public.seed_signal_definitions(w.id);
  end loop;
end $$;