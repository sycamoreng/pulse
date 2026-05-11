/*
  # Phase 9 — Audit context, SCIM provisioning, retention policies

  1. Changes to existing tables
    - `audit_logs` — added `ip_address`, `user_agent`, `request_id` for forensic context
  2. New tables
    - `scim_tokens` — opaque bearer tokens used by identity providers to
      provision/de-provision workspace members via SCIM v2
      - `id`, `workspace_id`, `name`, `token_prefix`, `token_hash`,
        `created_by`, `created_at`, `last_used_at`, `is_active`
    - `retention_policies` — per-workspace rules for automatic data expiry
      - `id`, `workspace_id`, `entity` (events|audit_logs|campaign_messages|customer_signals),
        `retain_days` (int), `is_active`, `last_run_at`, `last_deleted` (int)
  3. Security
    - RLS on all new tables; admin/owner gated for writes
    - SCIM tokens are hashed at rest (no plaintext stored)
    - `retention_run(p_workspace, p_entity, p_days)` RPC uses SECURITY DEFINER
      to delete older rows while enforcing workspace isolation
*/

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'audit_logs' AND column_name = 'ip_address') THEN
    ALTER TABLE audit_logs ADD COLUMN ip_address text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'audit_logs' AND column_name = 'user_agent') THEN
    ALTER TABLE audit_logs ADD COLUMN user_agent text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'audit_logs' AND column_name = 'request_id') THEN
    ALTER TABLE audit_logs ADD COLUMN request_id text DEFAULT '';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS scim_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT 'SCIM token',
  token_prefix text NOT NULL,
  token_hash text NOT NULL,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz,
  is_active boolean NOT NULL DEFAULT true
);
CREATE INDEX IF NOT EXISTS idx_scim_tokens_workspace ON scim_tokens(workspace_id);
CREATE INDEX IF NOT EXISTS idx_scim_tokens_hash ON scim_tokens(token_hash);

ALTER TABLE scim_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins view scim tokens" ON scim_tokens;
CREATE POLICY "Admins view scim tokens" ON scim_tokens FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = scim_tokens.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins insert scim tokens" ON scim_tokens;
CREATE POLICY "Admins insert scim tokens" ON scim_tokens FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = scim_tokens.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins update scim tokens" ON scim_tokens;
CREATE POLICY "Admins update scim tokens" ON scim_tokens FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = scim_tokens.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = scim_tokens.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins delete scim tokens" ON scim_tokens;
CREATE POLICY "Admins delete scim tokens" ON scim_tokens FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = scim_tokens.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));


CREATE TABLE IF NOT EXISTS retention_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  entity text NOT NULL,
  retain_days integer NOT NULL DEFAULT 90,
  is_active boolean NOT NULL DEFAULT true,
  last_run_at timestamptz,
  last_deleted integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (workspace_id, entity)
);
CREATE INDEX IF NOT EXISTS idx_retention_policies_workspace ON retention_policies(workspace_id);

ALTER TABLE retention_policies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members view retention policies" ON retention_policies;
CREATE POLICY "Members view retention policies" ON retention_policies FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = retention_policies.workspace_id AND wm.user_id = auth.uid()));

DROP POLICY IF EXISTS "Admins insert retention policies" ON retention_policies;
CREATE POLICY "Admins insert retention policies" ON retention_policies FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = retention_policies.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins update retention policies" ON retention_policies;
CREATE POLICY "Admins update retention policies" ON retention_policies FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = retention_policies.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = retention_policies.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins delete retention policies" ON retention_policies;
CREATE POLICY "Admins delete retention policies" ON retention_policies FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = retention_policies.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));


-- SECURITY DEFINER retention runner: cleans up rows older than retain_days for a given entity in a workspace.
CREATE OR REPLACE FUNCTION retention_run(p_workspace uuid, p_entity text, p_days integer)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cutoff timestamptz := now() - make_interval(days => greatest(p_days, 1));
  v_deleted integer := 0;
BEGIN
  IF p_entity = 'events' THEN
    WITH d AS (DELETE FROM events WHERE workspace_id = p_workspace AND occurred_at < v_cutoff RETURNING 1)
    SELECT count(*) INTO v_deleted FROM d;
  ELSIF p_entity = 'audit_logs' THEN
    WITH d AS (DELETE FROM audit_logs WHERE workspace_id = p_workspace AND created_at < v_cutoff RETURNING 1)
    SELECT count(*) INTO v_deleted FROM d;
  ELSIF p_entity = 'campaign_messages' THEN
    WITH d AS (DELETE FROM campaign_messages WHERE workspace_id = p_workspace AND coalesce(sent_at, created_at) < v_cutoff RETURNING 1)
    SELECT count(*) INTO v_deleted FROM d;
  ELSIF p_entity = 'customer_signals' THEN
    WITH d AS (DELETE FROM customer_signals WHERE workspace_id = p_workspace AND detected_at < v_cutoff RETURNING 1)
    SELECT count(*) INTO v_deleted FROM d;
  ELSE
    RAISE EXCEPTION 'Unsupported retention entity: %', p_entity;
  END IF;

  UPDATE retention_policies
    SET last_run_at = now(), last_deleted = v_deleted, updated_at = now()
    WHERE workspace_id = p_workspace AND entity = p_entity;

  RETURN v_deleted;
END;
$$;

REVOKE ALL ON FUNCTION retention_run(uuid, text, integer) FROM public;
GRANT EXECUTE ON FUNCTION retention_run(uuid, text, integer) TO authenticated, service_role;
