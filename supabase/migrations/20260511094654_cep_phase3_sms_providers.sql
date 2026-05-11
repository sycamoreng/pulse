/*
  # SMS / WhatsApp / RCS providers

  1. New Tables
    - `sms_providers` — per-workspace SMS/WhatsApp/RCS provider config
      - `id` (uuid, primary key)
      - `workspace_id` (uuid, fk workspaces)
      - `provider` (text) — "twilio" | "twilio_whatsapp" | "twilio_rcs" | "vonage"
      - `channel` (text) — "sms" | "whatsapp" | "rcs"
      - `from_number` (text) — E.164 sender, or messaging-service SID for Twilio
      - `messaging_service_sid` (text, nullable)
      - `is_active` (boolean)
      - `config` (jsonb) — provider-specific extras (region, etc.)
      - `credentials_secret_name` (text) — name of the secret in vault.secrets

  2. Security
    - RLS enabled on `sms_providers`
    - Authenticated members of the workspace can read / manage
*/

CREATE TABLE IF NOT EXISTS sms_providers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  provider text NOT NULL DEFAULT 'twilio',
  channel text NOT NULL DEFAULT 'sms',
  from_number text NOT NULL DEFAULT '',
  messaging_service_sid text DEFAULT '',
  is_active boolean NOT NULL DEFAULT true,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  credentials_secret_name text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS sms_providers_workspace_channel_idx
  ON sms_providers (workspace_id, channel, is_active);

ALTER TABLE sms_providers ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='sms_providers_select' AND tablename='sms_providers') THEN
    CREATE POLICY "sms_providers_select" ON sms_providers FOR SELECT TO authenticated
      USING (EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = sms_providers.workspace_id AND m.user_id = auth.uid()));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='sms_providers_insert' AND tablename='sms_providers') THEN
    CREATE POLICY "sms_providers_insert" ON sms_providers FOR INSERT TO authenticated
      WITH CHECK (EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = sms_providers.workspace_id AND m.user_id = auth.uid() AND m.role IN ('owner','admin')));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='sms_providers_update' AND tablename='sms_providers') THEN
    CREATE POLICY "sms_providers_update" ON sms_providers FOR UPDATE TO authenticated
      USING (EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = sms_providers.workspace_id AND m.user_id = auth.uid() AND m.role IN ('owner','admin')))
      WITH CHECK (EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = sms_providers.workspace_id AND m.user_id = auth.uid() AND m.role IN ('owner','admin')));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='sms_providers_delete' AND tablename='sms_providers') THEN
    CREATE POLICY "sms_providers_delete" ON sms_providers FOR DELETE TO authenticated
      USING (EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = sms_providers.workspace_id AND m.user_id = auth.uid() AND m.role IN ('owner','admin')));
  END IF;
END $$;
