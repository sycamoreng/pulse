/*
  # Templates, Funnels, Cohorts, and RFM

  1. New Tables
    - `templates` - reusable message templates (email/push/sms/inapp/onsite)
    - `journey_templates` - pre-built journey blueprints (system + user)
    - `funnels` - multi-step conversion funnels
    - `cohorts` - retention cohorts based on signup/event date
    - `rfm_configs` - RFM segmentation configurations with computed results

  2. Changes
    - Adds UNIQUE constraints on segments/lists/campaigns for safe upsert
    - Seeds system journey templates

  3. Security
    - RLS on all new tables with workspace-scoped policies
    - System journey templates readable by all authenticated users
*/

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'segments_ws_name_key') THEN
    ALTER TABLE segments ADD CONSTRAINT segments_ws_name_key UNIQUE(workspace_id, name);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'lists_ws_name_key') THEN
    ALTER TABLE lists ADD CONSTRAINT lists_ws_name_key UNIQUE(workspace_id, name);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'campaigns_ws_name_key') THEN
    ALTER TABLE campaigns ADD CONSTRAINT campaigns_ws_name_key UNIQUE(workspace_id, name);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  channel text NOT NULL DEFAULT 'email',
  subject text DEFAULT '',
  content text DEFAULT '',
  preview_text text DEFAULT '',
  variables jsonb NOT NULL DEFAULT '[]'::jsonb,
  category text DEFAULT 'general',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS journey_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  is_system boolean DEFAULT false,
  name text NOT NULL,
  description text DEFAULT '',
  category text DEFAULT 'general',
  icon text DEFAULT 'route',
  trigger_event text DEFAULT '',
  steps jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS funnels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text DEFAULT '',
  steps jsonb NOT NULL DEFAULT '[]'::jsonb,
  window_days integer DEFAULT 7,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cohorts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text DEFAULT '',
  cohort_type text NOT NULL DEFAULT 'signup',
  retention_event text DEFAULT 'app_opened',
  period text NOT NULL DEFAULT 'week',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS rfm_configs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT 'Default RFM',
  monetary_event text DEFAULT 'purchase_completed',
  monetary_property text DEFAULT 'value',
  window_days integer DEFAULT 90,
  last_computed_at timestamptz,
  segments jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE journey_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE funnels ENABLE ROW LEVEL SECURITY;
ALTER TABLE cohorts ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfm_configs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ws view templates" ON templates FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = templates.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert templates" ON templates FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = templates.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update templates" ON templates FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = templates.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = templates.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete templates" ON templates FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = templates.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "anyone view system jt" ON journey_templates FOR SELECT TO authenticated USING (is_system = true OR EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journey_templates.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert jt" ON journey_templates FOR INSERT TO authenticated WITH CHECK (workspace_id IS NOT NULL AND EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journey_templates.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update jt" ON journey_templates FOR UPDATE TO authenticated USING (workspace_id IS NOT NULL AND EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journey_templates.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (workspace_id IS NOT NULL AND EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journey_templates.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete jt" ON journey_templates FOR DELETE TO authenticated USING (workspace_id IS NOT NULL AND EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journey_templates.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view funnels" ON funnels FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = funnels.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert funnels" ON funnels FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = funnels.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update funnels" ON funnels FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = funnels.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = funnels.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete funnels" ON funnels FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = funnels.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view cohorts" ON cohorts FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = cohorts.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert cohorts" ON cohorts FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = cohorts.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update cohorts" ON cohorts FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = cohorts.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = cohorts.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete cohorts" ON cohorts FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = cohorts.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view rfm" ON rfm_configs FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = rfm_configs.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert rfm" ON rfm_configs FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = rfm_configs.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update rfm" ON rfm_configs FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = rfm_configs.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = rfm_configs.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete rfm" ON rfm_configs FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = rfm_configs.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

-- Seed system journey templates (shared blueprints)
INSERT INTO journey_templates (is_system, name, description, category, icon, trigger_event, steps) VALUES
  (true, 'Welcome onboarding', 'Greet new signups and guide them to activation.', 'onboarding', 'users', 'signup',
    '[{"type":"email","title":"Welcome aboard!","body":"Thanks for joining. Here is how to get started."},{"type":"wait","hours":24,"label":"wait 24h"},{"type":"push","title":"Finish setup","body":"Complete your profile to unlock personalized recommendations."}]'::jsonb),
  (true, 'Abandoned cart recovery', 'Win back users who left items in their cart.', 'conversion', 'send', 'added_to_cart',
    '[{"type":"wait","hours":1,"label":"wait 1h"},{"type":"email","title":"You left something behind","body":"Complete your purchase and save 10%."},{"type":"wait","hours":24,"label":"wait 24h"},{"type":"push","title":"Still interested?","body":"Your cart is waiting for you."}]'::jsonb),
  (true, 'Post-purchase thank you', 'Thank buyers and encourage repeat purchases.', 'retention', 'check', 'purchase_completed',
    '[{"type":"email","title":"Thanks for your purchase!","body":"Your order is on its way."},{"type":"wait","hours":72,"label":"wait 3 days"},{"type":"email","title":"How was it?","body":"Share your experience with a quick review."}]'::jsonb),
  (true, 'Re-engage inactive users', 'Bring back users who have gone quiet.', 'retention', 'clock', '',
    '[{"type":"push","title":"We miss you!","body":"Come back and see what is new."},{"type":"wait","hours":168,"label":"wait 7 days"},{"type":"email","title":"Here is 20% off","body":"A little something to welcome you back."}]'::jsonb),
  (true, 'Trial expiration nurture', 'Convert trial users before their trial ends.', 'conversion', 'calendar', 'signup',
    '[{"type":"wait","hours":120,"label":"wait 5 days"},{"type":"email","title":"Your trial ends soon","body":"Upgrade now to keep your data and features."},{"type":"wait","hours":48,"label":"wait 2 days"},{"type":"email","title":"Last chance","body":"Your trial expires in 24 hours."}]'::jsonb),
  (true, 'Birthday delight', 'Make customers feel special on their birthday.', 'loyalty', 'bell', 'birthday',
    '[{"type":"email","title":"Happy Birthday!","body":"Here is a gift from us to you."},{"type":"push","title":"Enjoy your day!","body":"Use code BIRTHDAY20 for 20% off."}]'::jsonb)
ON CONFLICT DO NOTHING;
