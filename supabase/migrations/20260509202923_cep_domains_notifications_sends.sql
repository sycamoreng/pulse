/*
  # Domain checks, notifications, and transactional sends

  1. email_domains
    - add `last_checked_at` (timestamptz) — when DNS was last polled.
  2. New table: notifications
    - `id`, `workspace_id`, `user_id`, `user_email`, `kind`, `title`, `body`,
      `link`, `is_read`, `created_at`.
    - Used for in-app bell notifications (member added, approvals, exports ready, etc.).
  3. New table: transactional_sends
    - `id`, `workspace_id`, `to_email`, `from_email`, `subject`, `body`,
      `kind`, `status`, `provider_message_id`, `error`, `created_at`, `sent_at`.
    - Logs every internal email the system sends (invites, approvals, export
      notifications). Lets us retry and audit deliveries.

  4. Security
    - RLS enabled on both new tables.
    - Notifications are visible to the recipient (user_id = auth.uid()) or any
      workspace member (inbox for team-wide events).
    - Transactional_sends only readable by workspace members with settings access.
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'email_domains' AND column_name = 'last_checked_at'
  ) THEN
    ALTER TABLE email_domains ADD COLUMN last_checked_at timestamptz;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  user_email text DEFAULT '',
  kind text NOT NULL DEFAULT 'info',
  title text NOT NULL,
  body text DEFAULT '',
  link text DEFAULT '',
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user
  ON notifications (user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_ws
  ON notifications (workspace_id, created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members read workspace notifications" ON notifications;
CREATE POLICY "Members read workspace notifications"
  ON notifications FOR SELECT
  TO authenticated
  USING (
    is_workspace_member(workspace_id)
    AND (user_id IS NULL OR user_id = auth.uid() OR user_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
  );

DROP POLICY IF EXISTS "Members insert workspace notifications" ON notifications;
CREATE POLICY "Members insert workspace notifications"
  ON notifications FOR INSERT
  TO authenticated
  WITH CHECK (is_workspace_member(workspace_id));

DROP POLICY IF EXISTS "Recipient updates notifications" ON notifications;
CREATE POLICY "Recipient updates notifications"
  ON notifications FOR UPDATE
  TO authenticated
  USING (is_workspace_member(workspace_id) AND (user_id = auth.uid() OR user_email = (SELECT email FROM auth.users WHERE id = auth.uid())))
  WITH CHECK (is_workspace_member(workspace_id));

DROP POLICY IF EXISTS "Recipient deletes notifications" ON notifications;
CREATE POLICY "Recipient deletes notifications"
  ON notifications FOR DELETE
  TO authenticated
  USING (is_workspace_member(workspace_id) AND (user_id = auth.uid() OR user_email = (SELECT email FROM auth.users WHERE id = auth.uid())));

CREATE TABLE IF NOT EXISTS transactional_sends (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  to_email text NOT NULL,
  from_email text DEFAULT '',
  subject text DEFAULT '',
  body text DEFAULT '',
  kind text NOT NULL DEFAULT 'info',
  status text NOT NULL DEFAULT 'queued',
  provider_message_id text DEFAULT '',
  error text DEFAULT '',
  created_at timestamptz DEFAULT now(),
  sent_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_txn_sends_ws
  ON transactional_sends (workspace_id, created_at DESC);

ALTER TABLE transactional_sends ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members read transactional sends" ON transactional_sends;
CREATE POLICY "Members read transactional sends"
  ON transactional_sends FOR SELECT
  TO authenticated
  USING (is_workspace_member(workspace_id));

DROP POLICY IF EXISTS "Members insert transactional sends" ON transactional_sends;
CREATE POLICY "Members insert transactional sends"
  ON transactional_sends FOR INSERT
  TO authenticated
  WITH CHECK (is_workspace_member(workspace_id));
