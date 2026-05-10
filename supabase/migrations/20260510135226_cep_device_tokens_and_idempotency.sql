/*
  # Device tokens + event idempotency

  1. New Tables
    - `device_tokens`
      - `id` uuid primary key
      - `workspace_id` uuid — owning workspace
      - `customer_id` uuid — who owns this device
      - `platform` text — 'web' | 'ios' | 'android'
      - `token` text — FCM token / APNs device token / Web Push subscription JSON
      - `app_id` uuid — optional link to `apps.id`
      - `bundle_id` text — iOS bundle / Android package
      - `last_seen_at` timestamptz
      - `revoked_at` timestamptz — soft-delete when the token becomes invalid
      - `created_at` timestamptz default now()
      - Unique per (workspace_id, token) so re-registration upserts cleanly.

  2. Modified Tables
    - `events`
      - add `idempotency_key` text — set when the client passes an
        `X-Idempotency-Key` header so retries don't double-insert.

  3. Security
    - RLS enabled on `device_tokens`.
    - Workspace members can SELECT their tokens.
    - Owners/admins can INSERT/UPDATE/DELETE.
    - Edge functions use the service-role client; policies do not apply.

  4. Indexes
    - Lookup by (workspace_id, customer_id) for campaign targeting.
    - Lookup by (workspace_id, platform) for channel stats.
    - Partial index on non-revoked tokens.
    - Unique index on (workspace_id, idempotency_key) on events when key present.
*/

CREATE TABLE IF NOT EXISTS device_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  platform text NOT NULL CHECK (platform IN ('web','ios','android')),
  token text NOT NULL,
  app_id uuid REFERENCES apps(id) ON DELETE SET NULL,
  bundle_id text DEFAULT '',
  last_seen_at timestamptz DEFAULT now(),
  revoked_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_device_tokens_ws_token
  ON device_tokens (workspace_id, token);
CREATE INDEX IF NOT EXISTS idx_device_tokens_customer
  ON device_tokens (workspace_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_active
  ON device_tokens (workspace_id, platform) WHERE revoked_at IS NULL;

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='device_tokens' AND policyname='Workspace members read device tokens') THEN
    CREATE POLICY "Workspace members read device tokens"
      ON device_tokens FOR SELECT
      TO authenticated
      USING (is_workspace_member(workspace_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='device_tokens' AND policyname='Workspace owners insert device tokens') THEN
    CREATE POLICY "Workspace owners insert device tokens"
      ON device_tokens FOR INSERT
      TO authenticated
      WITH CHECK (is_workspace_owner(workspace_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='device_tokens' AND policyname='Workspace owners update device tokens') THEN
    CREATE POLICY "Workspace owners update device tokens"
      ON device_tokens FOR UPDATE
      TO authenticated
      USING (is_workspace_owner(workspace_id))
      WITH CHECK (is_workspace_owner(workspace_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='device_tokens' AND policyname='Workspace owners delete device tokens') THEN
    CREATE POLICY "Workspace owners delete device tokens"
      ON device_tokens FOR DELETE
      TO authenticated
      USING (is_workspace_owner(workspace_id));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='events' AND column_name='idempotency_key') THEN
    ALTER TABLE events ADD COLUMN idempotency_key text;
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_events_idempotency
  ON events (workspace_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
