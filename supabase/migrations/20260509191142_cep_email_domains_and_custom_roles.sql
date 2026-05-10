/*
  # Email sender identities, sending domains, and custom role support

  1. New tables
    - `email_domains` — a workspace's verified sending domains with SPF/DKIM/DMARC record status.
      - id, workspace_id, domain, status (pending|verified|failed),
        spf_status, dkim_status, dmarc_status, dkim_selector, dkim_public_key,
        return_path, created_at, verified_at.
    - `email_senders` — per-domain "From" identities used by campaigns.
      - id, workspace_id, domain_id, from_name, from_email, reply_to, is_default, verified, created_at.

  2. Changes to existing tables
    - No destructive changes. `workspace_roles` already supports custom (non-system) rows.

  3. Security
    - RLS enabled on both new tables.
    - Members can view; only workspace owners can create/update/delete.
*/

CREATE TABLE IF NOT EXISTS email_domains (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  domain text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  spf_status text NOT NULL DEFAULT 'pending',
  dkim_status text NOT NULL DEFAULT 'pending',
  dmarc_status text NOT NULL DEFAULT 'pending',
  dkim_selector text NOT NULL DEFAULT 'sycamore',
  dkim_public_key text NOT NULL DEFAULT '',
  return_path text NOT NULL DEFAULT '',
  created_at timestamptz DEFAULT now(),
  verified_at timestamptz,
  UNIQUE (workspace_id, domain)
);

CREATE TABLE IF NOT EXISTS email_senders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  domain_id uuid REFERENCES email_domains(id) ON DELETE SET NULL,
  from_name text NOT NULL DEFAULT '',
  from_email text NOT NULL,
  reply_to text NOT NULL DEFAULT '',
  is_default boolean NOT NULL DEFAULT false,
  verified boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  UNIQUE (workspace_id, from_email)
);

ALTER TABLE email_domains ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_senders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ws view email_domains" ON email_domains;
CREATE POLICY "ws view email_domains" ON email_domains FOR SELECT TO authenticated
  USING (is_workspace_owner(workspace_id) OR is_workspace_member(workspace_id));
DROP POLICY IF EXISTS "owner insert email_domains" ON email_domains;
CREATE POLICY "owner insert email_domains" ON email_domains FOR INSERT TO authenticated
  WITH CHECK (is_workspace_owner(workspace_id));
DROP POLICY IF EXISTS "owner update email_domains" ON email_domains;
CREATE POLICY "owner update email_domains" ON email_domains FOR UPDATE TO authenticated
  USING (is_workspace_owner(workspace_id)) WITH CHECK (is_workspace_owner(workspace_id));
DROP POLICY IF EXISTS "owner delete email_domains" ON email_domains;
CREATE POLICY "owner delete email_domains" ON email_domains FOR DELETE TO authenticated
  USING (is_workspace_owner(workspace_id));

DROP POLICY IF EXISTS "ws view email_senders" ON email_senders;
CREATE POLICY "ws view email_senders" ON email_senders FOR SELECT TO authenticated
  USING (is_workspace_owner(workspace_id) OR is_workspace_member(workspace_id));
DROP POLICY IF EXISTS "owner insert email_senders" ON email_senders;
CREATE POLICY "owner insert email_senders" ON email_senders FOR INSERT TO authenticated
  WITH CHECK (is_workspace_owner(workspace_id));
DROP POLICY IF EXISTS "owner update email_senders" ON email_senders;
CREATE POLICY "owner update email_senders" ON email_senders FOR UPDATE TO authenticated
  USING (is_workspace_owner(workspace_id)) WITH CHECK (is_workspace_owner(workspace_id));
DROP POLICY IF EXISTS "owner delete email_senders" ON email_senders;
CREATE POLICY "owner delete email_senders" ON email_senders FOR DELETE TO authenticated
  USING (is_workspace_owner(workspace_id));

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'workspace_roles' AND policyname = 'owner insert roles') THEN
    CREATE POLICY "owner insert roles" ON workspace_roles FOR INSERT TO authenticated
      WITH CHECK (is_workspace_owner(workspace_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'workspace_roles' AND policyname = 'owner update roles') THEN
    CREATE POLICY "owner update roles" ON workspace_roles FOR UPDATE TO authenticated
      USING (is_workspace_owner(workspace_id) AND NOT is_system)
      WITH CHECK (is_workspace_owner(workspace_id) AND NOT is_system);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'workspace_roles' AND policyname = 'owner delete roles') THEN
    CREATE POLICY "owner delete roles" ON workspace_roles FOR DELETE TO authenticated
      USING (is_workspace_owner(workspace_id) AND NOT is_system);
  END IF;
END $$;
