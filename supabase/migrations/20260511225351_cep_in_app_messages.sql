/*
  # In-App Messages for SDK-embedded apps

  1. New Tables
    - `in_app_messages`
      - `id` (uuid, pk)
      - `workspace_id` (uuid) - tenant
      - `customer_id` (uuid) - recipient
      - `placement` (text) - inbox | banner | modal | toast
      - `title`, `body`, `image_url`, `cta_label`, `cta_url`
      - `payload` (jsonb) - extra structured data
      - `journey_id`, `campaign_id` - optional source refs
      - `delivered_at`, `seen_at`, `dismissed_at`, `clicked_at`
      - `expires_at`
      - `created_at`
  2. Channel extension
    - Adds 'in_app' to `delivery_queue.channel` check constraint
  3. Security
    - RLS enabled; workspace members can read their workspace's messages
    - Inserts/updates happen only via service role (edge functions)
    - SDK reads happen via publishable-key authenticated edge function, not direct anon access
  4. Indexes
    - `(workspace_id, customer_id, created_at desc)` for inbox lookups
    - `(workspace_id, placement, dismissed_at)` for active banner queries
*/

CREATE TABLE IF NOT EXISTS in_app_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  placement text NOT NULL DEFAULT 'inbox',
  title text NOT NULL DEFAULT '',
  body text NOT NULL DEFAULT '',
  image_url text DEFAULT '',
  cta_label text DEFAULT '',
  cta_url text DEFAULT '',
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  journey_id uuid,
  campaign_id uuid,
  delivered_at timestamptz NOT NULL DEFAULT now(),
  seen_at timestamptz,
  dismissed_at timestamptz,
  clicked_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iam_workspace_customer_created
  ON in_app_messages (workspace_id, customer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_iam_placement_active
  ON in_app_messages (workspace_id, placement)
  WHERE dismissed_at IS NULL;

ALTER TABLE in_app_messages ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'in_app_messages'
      AND policyname = 'Workspace members can read in-app messages'
  ) THEN
    CREATE POLICY "Workspace members can read in-app messages"
      ON in_app_messages FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM workspace_members wm
          WHERE wm.workspace_id = in_app_messages.workspace_id
            AND wm.user_id = auth.uid()
        )
        OR EXISTS (
          SELECT 1 FROM workspaces w
          WHERE w.id = in_app_messages.workspace_id
            AND w.owner_id = auth.uid()
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'delivery_queue' AND constraint_name = 'delivery_queue_channel_check'
  ) THEN
    ALTER TABLE delivery_queue DROP CONSTRAINT delivery_queue_channel_check;
  END IF;
END $$;

ALTER TABLE delivery_queue
  ADD CONSTRAINT delivery_queue_channel_check
  CHECK (channel IN ('email','push','sms','webhook','whatsapp','rcs','in_app'));
