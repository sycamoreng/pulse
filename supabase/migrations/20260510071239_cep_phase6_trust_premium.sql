/*
  # Phase 6: Trust & Premium features

  1. New Tables
    - `customer_consents` — per-channel consent records (email, sms, push) with source, timestamp, and reason
    - `predictive_scores` — per-customer predictive score (churn risk, purchase propensity, lifetime value bucket)
    - `seed_inbox_tests` — inbox placement tests against seed lists with provider results
    - `seed_inbox_addresses` — seed list management per workspace

  2. Changed Tables
    - `templates` add `amp_html` column (AMP for Email variant)
    - `campaigns` add `amp_html` column

  3. Security
    - RLS enabled on all new tables, workspace scoping through `workspace_members` with role checks for writes.
*/

CREATE TABLE IF NOT EXISTS customer_consents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  channel text NOT NULL,
  state text NOT NULL DEFAULT 'opted_in',
  source text DEFAULT 'manual',
  reason text DEFAULT '',
  changed_at timestamptz DEFAULT now(),
  UNIQUE(workspace_id, customer_id, channel)
);

CREATE INDEX IF NOT EXISTS idx_customer_consents_cust ON customer_consents(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_consents_ws ON customer_consents(workspace_id);

ALTER TABLE customer_consents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members read consents"
  ON customer_consents FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = customer_consents.workspace_id AND wm.user_id = auth.uid()));

CREATE POLICY "Editors insert consents"
  ON customer_consents FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = customer_consents.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin','editor')));

CREATE POLICY "Editors update consents"
  ON customer_consents FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = customer_consents.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin','editor')))
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = customer_consents.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin','editor')));

CREATE POLICY "Admins delete consents"
  ON customer_consents FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = customer_consents.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));


CREATE TABLE IF NOT EXISTS predictive_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  churn_risk numeric DEFAULT 0,
  purchase_propensity numeric DEFAULT 0,
  ltv_bucket text DEFAULT 'low',
  computed_at timestamptz DEFAULT now(),
  UNIQUE(workspace_id, customer_id)
);

CREATE INDEX IF NOT EXISTS idx_predictive_scores_ws ON predictive_scores(workspace_id);

ALTER TABLE predictive_scores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members read scores"
  ON predictive_scores FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = predictive_scores.workspace_id AND wm.user_id = auth.uid()));

CREATE POLICY "Admins write scores insert"
  ON predictive_scores FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = predictive_scores.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin','editor')));

CREATE POLICY "Admins write scores update"
  ON predictive_scores FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = predictive_scores.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin','editor')))
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = predictive_scores.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin','editor')));

CREATE POLICY "Admins write scores delete"
  ON predictive_scores FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = predictive_scores.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));


CREATE TABLE IF NOT EXISTS seed_inbox_addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  email text NOT NULL,
  provider text NOT NULL DEFAULT 'gmail',
  created_at timestamptz DEFAULT now(),
  UNIQUE(workspace_id, email)
);

ALTER TABLE seed_inbox_addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members read seeds"
  ON seed_inbox_addresses FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = seed_inbox_addresses.workspace_id AND wm.user_id = auth.uid()));

CREATE POLICY "Admins insert seeds"
  ON seed_inbox_addresses FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = seed_inbox_addresses.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

CREATE POLICY "Admins update seeds"
  ON seed_inbox_addresses FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = seed_inbox_addresses.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = seed_inbox_addresses.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

CREATE POLICY "Admins delete seeds"
  ON seed_inbox_addresses FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = seed_inbox_addresses.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));


CREATE TABLE IF NOT EXISTS seed_inbox_tests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  subject text DEFAULT '',
  from_address text DEFAULT '',
  sent_count integer DEFAULT 0,
  inbox_count integer DEFAULT 0,
  spam_count integer DEFAULT 0,
  missing_count integer DEFAULT 0,
  results jsonb DEFAULT '[]'::jsonb,
  status text DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  completed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_seed_inbox_tests_ws ON seed_inbox_tests(workspace_id);

ALTER TABLE seed_inbox_tests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members read inbox tests"
  ON seed_inbox_tests FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = seed_inbox_tests.workspace_id AND wm.user_id = auth.uid()));

CREATE POLICY "Admins insert inbox tests"
  ON seed_inbox_tests FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = seed_inbox_tests.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin','editor')));

CREATE POLICY "Admins update inbox tests"
  ON seed_inbox_tests FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = seed_inbox_tests.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin','editor')))
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = seed_inbox_tests.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin','editor')));

CREATE POLICY "Admins delete inbox tests"
  ON seed_inbox_tests FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = seed_inbox_tests.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));


DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='templates' AND column_name='amp_html') THEN
    ALTER TABLE templates ADD COLUMN amp_html text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='campaigns' AND column_name='amp_html') THEN
    ALTER TABLE campaigns ADD COLUMN amp_html text DEFAULT '';
  END IF;
END $$;
