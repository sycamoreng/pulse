/*
  # Phase 1 — Deliverability & Operations

  Adds three capabilities:

  1. Sending Policy (frequency caps + auto-suspend)
     - New table `sending_policies` (one row per workspace): per-contact cap,
       quiet-hours, complaint rate threshold above which sending auto-suspends.
     - Default row auto-created for every workspace.

  2. Sending Suspension Log
     - `sending_suspensions` records why/when sending was paused, so admins
       and tenants can audit it. Workspace also gets a `sending_paused_reason`.

  3. Domain health snapshot
     - `email_domains` already has SPF/DKIM/DMARC columns. We add a
       `email_domain_health_v` view that rolls up per-workspace pass/fail
       counts so the dashboard card can render without N+1 queries.

  ## Security
  All new tables have RLS. Only workspace members can read policies/suspensions
  for their workspace. Only admins/owners can update policies.
*/

-- 1. Sending policies
CREATE TABLE IF NOT EXISTS sending_policies (
  workspace_id uuid PRIMARY KEY REFERENCES workspaces(id) ON DELETE CASCADE,
  max_messages_per_contact_7d integer NOT NULL DEFAULT 5,
  max_messages_per_contact_24h integer NOT NULL DEFAULT 2,
  quiet_hours_start smallint NOT NULL DEFAULT 21,
  quiet_hours_end smallint NOT NULL DEFAULT 8,
  respect_quiet_hours boolean NOT NULL DEFAULT true,
  complaint_rate_threshold numeric(5,4) NOT NULL DEFAULT 0.001,
  bounce_rate_threshold numeric(5,4) NOT NULL DEFAULT 0.05,
  auto_suspend_on_breach boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid
);

ALTER TABLE sending_policies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members read policy" ON sending_policies;
CREATE POLICY "Members read policy" ON sending_policies FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = sending_policies.workspace_id AND wm.user_id = auth.uid()));

DROP POLICY IF EXISTS "Admins update policy" ON sending_policies;
CREATE POLICY "Admins update policy" ON sending_policies FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = sending_policies.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = sending_policies.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins insert policy" ON sending_policies;
CREATE POLICY "Admins insert policy" ON sending_policies FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = sending_policies.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

-- Seed a row for existing workspaces
INSERT INTO sending_policies (workspace_id)
SELECT id FROM workspaces WHERE id NOT IN (SELECT workspace_id FROM sending_policies);

-- 2. Workspace pause state + suspension log
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='workspaces' AND column_name='sending_paused') THEN
    ALTER TABLE workspaces ADD COLUMN sending_paused boolean NOT NULL DEFAULT false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='workspaces' AND column_name='sending_paused_reason') THEN
    ALTER TABLE workspaces ADD COLUMN sending_paused_reason text NOT NULL DEFAULT '';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS sending_suspensions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  reason text NOT NULL DEFAULT '',
  metric text NOT NULL DEFAULT '',
  metric_value numeric,
  threshold numeric,
  triggered_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolved_by uuid
);
CREATE INDEX IF NOT EXISTS idx_sending_suspensions_ws ON sending_suspensions(workspace_id, triggered_at DESC);

ALTER TABLE sending_suspensions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members read suspensions" ON sending_suspensions;
CREATE POLICY "Members read suspensions" ON sending_suspensions FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = sending_suspensions.workspace_id AND wm.user_id = auth.uid()));

DROP POLICY IF EXISTS "Admins update suspensions" ON sending_suspensions;
CREATE POLICY "Admins update suspensions" ON sending_suspensions FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = sending_suspensions.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = sending_suspensions.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

-- 3. Domain health rollup view
CREATE OR REPLACE VIEW email_domain_health_v AS
SELECT
  workspace_id,
  count(*) AS total,
  count(*) FILTER (WHERE status = 'verified') AS verified,
  count(*) FILTER (WHERE spf_status = 'pass') AS spf_pass,
  count(*) FILTER (WHERE dkim_status = 'pass') AS dkim_pass,
  count(*) FILTER (WHERE dmarc_status = 'pass') AS dmarc_pass
FROM email_domains
GROUP BY workspace_id;
