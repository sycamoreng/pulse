/*
  # Functional Expansion

  1. New Tables
    - `campaign_messages` - per-recipient delivery record with status/opens/clicks
    - `journey_enrollments` - customers enrolled in a journey with current step
    - `api_keys` - workspace-level API keys for SDK ingestion

  2. Security
    - RLS enabled with workspace-scoped policies
*/

CREATE TABLE IF NOT EXISTS campaign_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'queued',
  opened_at timestamptz,
  clicked_at timestamptz,
  sent_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cm_campaign ON campaign_messages(campaign_id);

CREATE TABLE IF NOT EXISTS journey_enrollments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  journey_id uuid NOT NULL REFERENCES journeys(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  current_step integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active',
  entered_at timestamptz DEFAULT now(),
  completed_at timestamptz,
  UNIQUE(journey_id, customer_id)
);
CREATE INDEX IF NOT EXISTS idx_je_journey ON journey_enrollments(journey_id);

CREATE TABLE IF NOT EXISTS api_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT 'Default',
  key text UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(24), 'hex'),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE campaign_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE journey_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ws view cm" ON campaign_messages FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = campaign_messages.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert cm" ON campaign_messages FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = campaign_messages.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update cm" ON campaign_messages FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = campaign_messages.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = campaign_messages.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete cm" ON campaign_messages FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = campaign_messages.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view je" ON journey_enrollments FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journey_enrollments.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert je" ON journey_enrollments FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journey_enrollments.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update je" ON journey_enrollments FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journey_enrollments.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journey_enrollments.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete je" ON journey_enrollments FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journey_enrollments.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view keys" ON api_keys FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = api_keys.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert keys" ON api_keys FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = api_keys.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete keys" ON api_keys FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = api_keys.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
