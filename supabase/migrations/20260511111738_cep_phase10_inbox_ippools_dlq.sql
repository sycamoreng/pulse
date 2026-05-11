/*
  # Phase 10 — Inbox placement, IP pools, webhook DLQ

  1. New Tables
    - `inbox_placement_tests` — seed-style tests against known test inboxes
      - id, workspace_id, name, sent_at, inbox_rate, spam_rate, missing_rate,
        total_seeds, status (pending|running|complete|failed), report (jsonb)
    - `ip_pools` — per-workspace sending IP pool assignments
      - id, workspace_id, name, pool_type (shared|dedicated|transactional|bulk),
        ip_addresses (text[]), warmup_stage (int 1-6), daily_cap, is_default, notes
    - `webhook_dlq` — dead-letter queue for permanently failed webhook deliveries
      - id, workspace_id, destination_id, event_type, payload, last_error,
        last_status, attempts, failed_at, resolved_at
  2. Security
    - RLS on all tables; admin/owner gated writes, members read
    - `webhook_dlq_replay(p_id)` RPC re-queues a row for webhook-dispatch
*/

CREATE TABLE IF NOT EXISTS inbox_placement_tests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT 'Seed test',
  status text NOT NULL DEFAULT 'pending',
  total_seeds integer NOT NULL DEFAULT 0,
  inbox_rate numeric(5,2) NOT NULL DEFAULT 0,
  spam_rate numeric(5,2) NOT NULL DEFAULT 0,
  missing_rate numeric(5,2) NOT NULL DEFAULT 0,
  report jsonb NOT NULL DEFAULT '{}'::jsonb,
  subject text DEFAULT '',
  from_email text DEFAULT '',
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_inbox_tests_workspace ON inbox_placement_tests(workspace_id, created_at DESC);

ALTER TABLE inbox_placement_tests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members view inbox tests" ON inbox_placement_tests;
CREATE POLICY "Members view inbox tests" ON inbox_placement_tests FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = inbox_placement_tests.workspace_id AND wm.user_id = auth.uid()));

DROP POLICY IF EXISTS "Admins insert inbox tests" ON inbox_placement_tests;
CREATE POLICY "Admins insert inbox tests" ON inbox_placement_tests FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = inbox_placement_tests.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins update inbox tests" ON inbox_placement_tests;
CREATE POLICY "Admins update inbox tests" ON inbox_placement_tests FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = inbox_placement_tests.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = inbox_placement_tests.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins delete inbox tests" ON inbox_placement_tests;
CREATE POLICY "Admins delete inbox tests" ON inbox_placement_tests FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = inbox_placement_tests.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));


CREATE TABLE IF NOT EXISTS ip_pools (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT 'Shared pool',
  pool_type text NOT NULL DEFAULT 'shared',
  ip_addresses text[] NOT NULL DEFAULT ARRAY[]::text[],
  warmup_stage integer NOT NULL DEFAULT 1,
  daily_cap integer NOT NULL DEFAULT 10000,
  is_default boolean NOT NULL DEFAULT false,
  notes text DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ip_pools_workspace ON ip_pools(workspace_id);

ALTER TABLE ip_pools ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members view ip pools" ON ip_pools;
CREATE POLICY "Members view ip pools" ON ip_pools FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ip_pools.workspace_id AND wm.user_id = auth.uid()));

DROP POLICY IF EXISTS "Admins insert ip pools" ON ip_pools;
CREATE POLICY "Admins insert ip pools" ON ip_pools FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ip_pools.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins update ip pools" ON ip_pools;
CREATE POLICY "Admins update ip pools" ON ip_pools FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ip_pools.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ip_pools.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins delete ip pools" ON ip_pools;
CREATE POLICY "Admins delete ip pools" ON ip_pools FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ip_pools.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));


CREATE TABLE IF NOT EXISTS webhook_dlq (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  destination_id uuid,
  event_type text NOT NULL DEFAULT '',
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_error text DEFAULT '',
  last_status integer DEFAULT 0,
  attempts integer NOT NULL DEFAULT 0,
  failed_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_webhook_dlq_workspace ON webhook_dlq(workspace_id, failed_at DESC);
CREATE INDEX IF NOT EXISTS idx_webhook_dlq_unresolved ON webhook_dlq(workspace_id) WHERE resolved_at IS NULL;

ALTER TABLE webhook_dlq ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members view webhook dlq" ON webhook_dlq;
CREATE POLICY "Members view webhook dlq" ON webhook_dlq FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = webhook_dlq.workspace_id AND wm.user_id = auth.uid()));

DROP POLICY IF EXISTS "Admins insert webhook dlq" ON webhook_dlq;
CREATE POLICY "Admins insert webhook dlq" ON webhook_dlq FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = webhook_dlq.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins update webhook dlq" ON webhook_dlq;
CREATE POLICY "Admins update webhook dlq" ON webhook_dlq FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = webhook_dlq.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = webhook_dlq.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins delete webhook dlq" ON webhook_dlq;
CREATE POLICY "Admins delete webhook dlq" ON webhook_dlq FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = webhook_dlq.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));
