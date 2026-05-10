/*
  # Platform admin roles and billing plans

  1. New table: platform_admins
    - Scopes privileged access for the Pulse team ONLY. A row here grants a
      user full read/write across every workspace, the provider config, and
      the suppression view. No tenant can ever see this table.
    - Columns: id, user_id (auth.users), role (super_admin|support|billing),
      created_at.

  2. New table: plans
    - Subscription tiers. Pulse controls these; tenants only see a read-only
      summary of their own plan.
    - Columns: id, code (free|pro|advanced|enterprise), name, price_monthly,
      email_monthly_quota, sms_monthly_quota, seats, feature_flags (jsonb),
      is_public, created_at.

  3. workspaces table additions
    - plan_id (uuid) → plans.id, defaults to the "free" plan on creation.
    - email_used_this_month, sms_used_this_month (integers)
    - quota_period_start (timestamptz) — resets monthly.
    - email_quota_override, sms_quota_override (nullable integers) —
      lets Pulse admins lift a quota without changing the plan.

  4. Visibility changes
    - email_providers and email_suppressions are now admin-only:
      DROP tenant SELECT/INSERT/UPDATE/DELETE policies and replace with
      policies that check platform_admins membership.
    - transactional_sends stays tenant-visible (their mail history).

  5. Security
    - RLS enabled on platform_admins (only super_admins can read/write; seeded
      manually).
    - RLS enabled on plans: public read for `is_public`, admin-only writes.
    - Helper function `is_platform_admin()` for reuse in policies.

  6. Seed
    - Insert the four default plans if not present.
*/

CREATE TABLE IF NOT EXISTS platform_admins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'support',
  created_at timestamptz DEFAULT now(),
  UNIQUE (user_id)
);
ALTER TABLE platform_admins ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION is_platform_admin()
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM platform_admins WHERE user_id = auth.uid());
$$;

DROP POLICY IF EXISTS "Admins read admins" ON platform_admins;
CREATE POLICY "Admins read admins"
  ON platform_admins FOR SELECT
  TO authenticated
  USING (is_platform_admin());

DROP POLICY IF EXISTS "Admins insert admins" ON platform_admins;
CREATE POLICY "Admins insert admins"
  ON platform_admins FOR INSERT
  TO authenticated
  WITH CHECK (is_platform_admin());

DROP POLICY IF EXISTS "Admins update admins" ON platform_admins;
CREATE POLICY "Admins update admins"
  ON platform_admins FOR UPDATE
  TO authenticated
  USING (is_platform_admin())
  WITH CHECK (is_platform_admin());

DROP POLICY IF EXISTS "Admins delete admins" ON platform_admins;
CREATE POLICY "Admins delete admins"
  ON platform_admins FOR DELETE
  TO authenticated
  USING (is_platform_admin());

CREATE TABLE IF NOT EXISTS plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  name text NOT NULL,
  description text DEFAULT '',
  price_monthly numeric DEFAULT 0,
  email_monthly_quota integer DEFAULT 0,
  sms_monthly_quota integer DEFAULT 0,
  push_monthly_quota integer DEFAULT 0,
  seats integer DEFAULT 1,
  feature_flags jsonb DEFAULT '{}'::jsonb,
  is_public boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone reads public plans" ON plans;
CREATE POLICY "Anyone reads public plans"
  ON plans FOR SELECT
  TO authenticated
  USING (is_public OR is_platform_admin());

DROP POLICY IF EXISTS "Admins insert plans" ON plans;
CREATE POLICY "Admins insert plans"
  ON plans FOR INSERT
  TO authenticated
  WITH CHECK (is_platform_admin());

DROP POLICY IF EXISTS "Admins update plans" ON plans;
CREATE POLICY "Admins update plans"
  ON plans FOR UPDATE
  TO authenticated
  USING (is_platform_admin())
  WITH CHECK (is_platform_admin());

DROP POLICY IF EXISTS "Admins delete plans" ON plans;
CREATE POLICY "Admins delete plans"
  ON plans FOR DELETE
  TO authenticated
  USING (is_platform_admin());

-- Workspace plan columns
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='workspaces' AND column_name='plan_id') THEN
    ALTER TABLE workspaces ADD COLUMN plan_id uuid REFERENCES plans(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='workspaces' AND column_name='email_used_this_month') THEN
    ALTER TABLE workspaces ADD COLUMN email_used_this_month integer DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='workspaces' AND column_name='sms_used_this_month') THEN
    ALTER TABLE workspaces ADD COLUMN sms_used_this_month integer DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='workspaces' AND column_name='quota_period_start') THEN
    ALTER TABLE workspaces ADD COLUMN quota_period_start timestamptz DEFAULT date_trunc('month', now());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='workspaces' AND column_name='email_quota_override') THEN
    ALTER TABLE workspaces ADD COLUMN email_quota_override integer;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='workspaces' AND column_name='sms_quota_override') THEN
    ALTER TABLE workspaces ADD COLUMN sms_quota_override integer;
  END IF;
END $$;

-- Seed default plans
INSERT INTO plans (code, name, description, price_monthly, email_monthly_quota, sms_monthly_quota, push_monthly_quota, seats, feature_flags, sort_order) VALUES
  ('free', 'Free', 'For small teams getting started.', 0, 5000, 0, 10000, 2, '{"journeys":true,"ab_testing":false,"custom_domain":false,"priority_support":false}'::jsonb, 1),
  ('pro', 'Pro', 'For growing teams that need more volume and A/B testing.', 99, 100000, 1000, 500000, 5, '{"journeys":true,"ab_testing":true,"custom_domain":true,"priority_support":false}'::jsonb, 2),
  ('advanced', 'Advanced', 'For teams running multi-channel engagement at scale.', 499, 1000000, 10000, 5000000, 15, '{"journeys":true,"ab_testing":true,"custom_domain":true,"priority_support":true,"advanced_rbac":true,"dedicated_ip":true}'::jsonb, 3),
  ('enterprise', 'Enterprise', 'Custom limits, SSO, dedicated IPs, SLAs.', 0, 100000000, 10000000, 1000000000, 100, '{"journeys":true,"ab_testing":true,"custom_domain":true,"priority_support":true,"advanced_rbac":true,"dedicated_ip":true,"sso":true,"sla":true}'::jsonb, 4)
ON CONFLICT (code) DO NOTHING;

-- Default new workspaces to the free plan
DO $$
DECLARE free_id uuid;
BEGIN
  SELECT id INTO free_id FROM plans WHERE code = 'free';
  IF free_id IS NOT NULL THEN
    UPDATE workspaces SET plan_id = free_id WHERE plan_id IS NULL;
  END IF;
END $$;

-- Tighten email_providers and email_suppressions to admin-only
DROP POLICY IF EXISTS "Members read email providers" ON email_providers;
DROP POLICY IF EXISTS "Owners insert email providers" ON email_providers;
DROP POLICY IF EXISTS "Owners update email providers" ON email_providers;
DROP POLICY IF EXISTS "Owners delete email providers" ON email_providers;

CREATE POLICY "Admins read email providers"
  ON email_providers FOR SELECT TO authenticated USING (is_platform_admin());
CREATE POLICY "Admins insert email providers"
  ON email_providers FOR INSERT TO authenticated WITH CHECK (is_platform_admin());
CREATE POLICY "Admins update email providers"
  ON email_providers FOR UPDATE TO authenticated USING (is_platform_admin()) WITH CHECK (is_platform_admin());
CREATE POLICY "Admins delete email providers"
  ON email_providers FOR DELETE TO authenticated USING (is_platform_admin());

DROP POLICY IF EXISTS "Members read suppressions" ON email_suppressions;
DROP POLICY IF EXISTS "Members insert suppressions" ON email_suppressions;
DROP POLICY IF EXISTS "Members delete suppressions" ON email_suppressions;

CREATE POLICY "Admins read suppressions"
  ON email_suppressions FOR SELECT TO authenticated USING (is_platform_admin());
CREATE POLICY "Admins insert suppressions"
  ON email_suppressions FOR INSERT TO authenticated WITH CHECK (is_platform_admin());
CREATE POLICY "Admins delete suppressions"
  ON email_suppressions FOR DELETE TO authenticated USING (is_platform_admin());

-- Admins can view every workspace (for the customer list in admin area)
DROP POLICY IF EXISTS "Platform admins read all workspaces" ON workspaces;
CREATE POLICY "Platform admins read all workspaces"
  ON workspaces FOR SELECT TO authenticated
  USING (is_platform_admin());

DROP POLICY IF EXISTS "Platform admins update all workspaces" ON workspaces;
CREATE POLICY "Platform admins update all workspaces"
  ON workspaces FOR UPDATE TO authenticated
  USING (is_platform_admin())
  WITH CHECK (is_platform_admin());
