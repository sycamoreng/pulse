/*
  # Multi-provider email sending + suppression

  1. New table: email_providers
    - Holds per-workspace provider config. Each workspace can have one "bulk"
      provider (marketing) and one "transactional" provider (invites, OTPs).
    - Columns: id, workspace_id, provider (ses|postmark|resend|mailgun|sendgrid),
      stream (bulk|transactional), region, ip_pool, is_active, config (jsonb — keys
      are provider-specific refs, e.g. {"configuration_set":"pulse-bulk"}),
      credentials_secret_name (text — name of the secret in Edge Function env,
      NEVER store the raw key in the DB), created_at.

  2. New table: email_suppressions
    - Per-workspace, per-domain suppression list populated from provider bounce
      and complaint webhooks. Prevents retries and protects sender reputation.
    - Columns: id, workspace_id, email, reason (hard_bounce|complaint|unsubscribe),
      source (ses|postmark|...|manual), details (jsonb), created_at.

  3. Security
    - RLS: only workspace members can read; only service role (via webhook)
      inserts suppressions, but members can manually insert/delete their own.
    - email_providers.credentials_secret_name stores ONLY the env-var name.
      Secrets live in Edge Function configuration, never in Postgres.
*/

CREATE TABLE IF NOT EXISTS email_providers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  provider text NOT NULL DEFAULT 'ses',
  stream text NOT NULL DEFAULT 'bulk',
  region text DEFAULT '',
  ip_pool text DEFAULT '',
  is_active boolean DEFAULT true,
  config jsonb DEFAULT '{}'::jsonb,
  credentials_secret_name text DEFAULT '',
  created_at timestamptz DEFAULT now(),
  UNIQUE (workspace_id, stream)
);

ALTER TABLE email_providers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members read email providers" ON email_providers;
CREATE POLICY "Members read email providers"
  ON email_providers FOR SELECT
  TO authenticated
  USING (is_workspace_member(workspace_id));

DROP POLICY IF EXISTS "Owners insert email providers" ON email_providers;
CREATE POLICY "Owners insert email providers"
  ON email_providers FOR INSERT
  TO authenticated
  WITH CHECK (is_workspace_owner(workspace_id));

DROP POLICY IF EXISTS "Owners update email providers" ON email_providers;
CREATE POLICY "Owners update email providers"
  ON email_providers FOR UPDATE
  TO authenticated
  USING (is_workspace_owner(workspace_id))
  WITH CHECK (is_workspace_owner(workspace_id));

DROP POLICY IF EXISTS "Owners delete email providers" ON email_providers;
CREATE POLICY "Owners delete email providers"
  ON email_providers FOR DELETE
  TO authenticated
  USING (is_workspace_owner(workspace_id));

CREATE TABLE IF NOT EXISTS email_suppressions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  email text NOT NULL,
  reason text NOT NULL DEFAULT 'hard_bounce',
  source text NOT NULL DEFAULT 'manual',
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  UNIQUE (workspace_id, email)
);

CREATE INDEX IF NOT EXISTS idx_suppressions_ws_email
  ON email_suppressions (workspace_id, email);

ALTER TABLE email_suppressions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members read suppressions" ON email_suppressions;
CREATE POLICY "Members read suppressions"
  ON email_suppressions FOR SELECT
  TO authenticated
  USING (is_workspace_member(workspace_id));

DROP POLICY IF EXISTS "Members insert suppressions" ON email_suppressions;
CREATE POLICY "Members insert suppressions"
  ON email_suppressions FOR INSERT
  TO authenticated
  WITH CHECK (is_workspace_member(workspace_id));

DROP POLICY IF EXISTS "Members delete suppressions" ON email_suppressions;
CREATE POLICY "Members delete suppressions"
  ON email_suppressions FOR DELETE
  TO authenticated
  USING (is_workspace_member(workspace_id));
