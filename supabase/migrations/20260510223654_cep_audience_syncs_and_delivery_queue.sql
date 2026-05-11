/*
  # Audience sync destinations + durable delivery queue

  1. New Tables
    - `ad_audience_destinations` — Connected advertising audience targets
      (Facebook Custom Audiences, Google Customer Match). Stores credentials
      reference names, target audience/list ids, and last sync state.
    - `ad_audience_syncs` — Per-run sync jobs queued to push a list or segment
      to a destination. Tracks matched/unmatched counts and error state.
    - `delivery_queue` — Durable queue for outbound channel sends
      (email/push/sms). Workers pop rows with `next_attempt_at <= now()`,
      progress through attempts with exponential backoff, and settle to
      `sent` / `failed` / `expired`.

  2. Security
    - RLS enabled on all three tables.
    - Read restricted to workspace members; writes (insert/update/delete)
      restricted to owner/admin for destinations, and to any workspace
      member for syncs (they are created when a user triggers a sync).
    - `delivery_queue` is service-role only for reads (workers use service
      key); authenticated users can see rows for their workspace (read-only)
      for observability.

  3. Notes
    - Credentials themselves are never stored — only a secret *name* that
      matches an Edge Function secret (e.g. `FACEBOOK_ACCESS_TOKEN_<wsid>`).
    - Phone / email hashing happens in the edge function prior to upload.
*/

CREATE TABLE IF NOT EXISTS ad_audience_destinations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  provider text NOT NULL CHECK (provider IN ('facebook','google')),
  name text NOT NULL DEFAULT '',
  external_audience_id text NOT NULL DEFAULT '',
  account_id text NOT NULL DEFAULT '',
  credentials_secret_name text NOT NULL DEFAULT '',
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  last_synced_at timestamptz,
  last_status text NOT NULL DEFAULT '',
  last_error text NOT NULL DEFAULT '',
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ad_aud_dest_ws ON ad_audience_destinations(workspace_id);

ALTER TABLE ad_audience_destinations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members view audience destinations"
  ON ad_audience_destinations FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ad_audience_destinations.workspace_id AND wm.user_id = auth.uid()));

CREATE POLICY "Admins insert audience destinations"
  ON ad_audience_destinations FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ad_audience_destinations.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

CREATE POLICY "Admins update audience destinations"
  ON ad_audience_destinations FOR UPDATE
  TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ad_audience_destinations.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ad_audience_destinations.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

CREATE POLICY "Admins delete audience destinations"
  ON ad_audience_destinations FOR DELETE
  TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ad_audience_destinations.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

CREATE TABLE IF NOT EXISTS ad_audience_syncs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  destination_id uuid NOT NULL REFERENCES ad_audience_destinations(id) ON DELETE CASCADE,
  source_type text NOT NULL CHECK (source_type IN ('list','segment','all')),
  source_id uuid,
  operation text NOT NULL DEFAULT 'add' CHECK (operation IN ('add','remove','replace')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','running','completed','failed')),
  matched_count integer NOT NULL DEFAULT 0,
  unmatched_count integer NOT NULL DEFAULT 0,
  total_count integer NOT NULL DEFAULT 0,
  error text NOT NULL DEFAULT '',
  started_at timestamptz,
  finished_at timestamptz,
  triggered_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ad_aud_sync_ws ON ad_audience_syncs(workspace_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ad_aud_sync_dest ON ad_audience_syncs(destination_id);

ALTER TABLE ad_audience_syncs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members view audience syncs"
  ON ad_audience_syncs FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ad_audience_syncs.workspace_id AND wm.user_id = auth.uid()));

CREATE POLICY "Members insert audience syncs"
  ON ad_audience_syncs FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ad_audience_syncs.workspace_id AND wm.user_id = auth.uid()));

CREATE POLICY "Admins update audience syncs"
  ON ad_audience_syncs FOR UPDATE
  TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ad_audience_syncs.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ad_audience_syncs.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

CREATE POLICY "Admins delete audience syncs"
  ON ad_audience_syncs FOR DELETE
  TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = ad_audience_syncs.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

CREATE TABLE IF NOT EXISTS delivery_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  channel text NOT NULL CHECK (channel IN ('email','push','sms','webhook')),
  campaign_id uuid REFERENCES campaigns(id) ON DELETE CASCADE,
  journey_id uuid REFERENCES journeys(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES customers(id) ON DELETE CASCADE,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','running','sent','failed','expired','cancelled')),
  attempts integer NOT NULL DEFAULT 0,
  max_attempts integer NOT NULL DEFAULT 5,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  last_error text NOT NULL DEFAULT '',
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_delivery_queue_ws_status ON delivery_queue(workspace_id, status);
CREATE INDEX IF NOT EXISTS idx_delivery_queue_runnable ON delivery_queue(status, next_attempt_at) WHERE status IN ('queued','running');

ALTER TABLE delivery_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members view delivery queue"
  ON delivery_queue FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = delivery_queue.workspace_id AND wm.user_id = auth.uid()));

CREATE POLICY "Admins cancel queued items"
  ON delivery_queue FOR UPDATE
  TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = delivery_queue.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = delivery_queue.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));
