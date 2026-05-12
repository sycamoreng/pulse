/*
  # Expanded plans, entitlements and configurable trials

  ## What this migration does
  1. Broadens the `plans` table so every tier now has rich feature
     entitlements, resource limits, branding, and a configurable free-trial
     length. This lets admins shape pricing tiers from the UI without a
     migration.
  2. Adds subscription/trial state to `workspaces` so every workspace
     carries `subscription_status` (trialing | active | past_due | cancelled)
     plus `trial_started_at` / `trial_ends_at`.
  3. Adds a `plan_changes` audit table so admins can see who moved a
     workspace from plan X to plan Y and when. Always append-only.
  4. Adds helper RPCs
     - `workspace_effective_limits(workspace_id)` - returns the resolved
       numeric limits for a workspace after applying any admin overrides.
     - `workspace_entitlements(workspace_id)` - returns the resolved feature
       flags for a workspace, falling back to the plan's flags.
     - `admin_set_workspace_plan(workspace_id, plan_id, start_trial, trial_days_override)`
       so the admin UI can atomically assign a plan, optionally start/extend
       a trial, and record the change in `plan_changes`.
     - `admin_set_workspace_trial(workspace_id, trial_ends_at, status)` to
       manually extend or end a trial from the admin UI.
  5. Triggers
     - On workspace insert, if the assigned plan has `default_trial_days > 0`,
       automatically set `subscription_status='trialing'`, `trial_started_at=now()`,
       and `trial_ends_at=now() + default_trial_days`. Otherwise the workspace
       starts as `active`.
  6. Re-seeds the four canonical plans (free / pro / advanced / enterprise)
     with expanded feature maps and sensible default trials (Pro: 14 days,
     Advanced: 14 days, Enterprise: 30 days, Free: none). Only updates rows
     that already exist - no destructive change.

  ## Security
  - All new columns inherit the existing RLS policies on `plans` and
    `workspaces`.
  - `plan_changes` is read-only for workspace members (so owners can see
    plan history) and writable only via the SECURITY DEFINER RPC, which
    requires the caller to be a platform admin.
  - All RPCs are SECURITY DEFINER with explicit authorisation checks.
*/

-- 1. Plans table expansion
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS default_trial_days integer NOT NULL DEFAULT 0;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS price_yearly numeric NOT NULL DEFAULT 0;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS contact_sales boolean NOT NULL DEFAULT false;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS highlight boolean NOT NULL DEFAULT false;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS cta_label text NOT NULL DEFAULT 'Choose plan';
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS tagline text NOT NULL DEFAULT '';
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS max_workspaces integer NOT NULL DEFAULT 1;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS max_active_journeys integer NOT NULL DEFAULT 1;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS max_active_campaigns integer NOT NULL DEFAULT 3;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS max_segments integer NOT NULL DEFAULT 5;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS max_events_per_month integer NOT NULL DEFAULT 10000;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS data_retention_days integer NOT NULL DEFAULT 30;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS support_sla_hours integer NOT NULL DEFAULT 72;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS included_domains integer NOT NULL DEFAULT 1;

-- 2. Workspace subscription state
ALTER TABLE public.workspaces ADD COLUMN IF NOT EXISTS subscription_status text NOT NULL DEFAULT 'active';
ALTER TABLE public.workspaces ADD COLUMN IF NOT EXISTS trial_started_at timestamptz;
ALTER TABLE public.workspaces ADD COLUMN IF NOT EXISTS trial_ends_at timestamptz;
ALTER TABLE public.workspaces ADD COLUMN IF NOT EXISTS feature_overrides jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.workspaces ADD COLUMN IF NOT EXISTS plan_assigned_at timestamptz NOT NULL DEFAULT now();

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'workspaces_subscription_status_check') THEN
    ALTER TABLE public.workspaces
      ADD CONSTRAINT workspaces_subscription_status_check
      CHECK (subscription_status IN ('trialing','active','past_due','cancelled','expired'));
  END IF;
END $$;

-- 3. Plan change history
CREATE TABLE IF NOT EXISTS public.plan_changes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  from_plan_id uuid REFERENCES public.plans(id),
  to_plan_id uuid REFERENCES public.plans(id),
  actor_id uuid REFERENCES auth.users(id),
  note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS plan_changes_workspace_idx ON public.plan_changes(workspace_id, created_at DESC);
ALTER TABLE public.plan_changes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members read plan changes" ON public.plan_changes;
CREATE POLICY "Members read plan changes" ON public.plan_changes
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.workspace_members wm
      WHERE wm.workspace_id = plan_changes.workspace_id
        AND wm.user_id = auth.uid()
    ) OR public.is_platform_admin()
  );

-- 4. Triggers: auto-start trial on workspace insert when plan has trial days
CREATE OR REPLACE FUNCTION public.start_trial_on_workspace_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_days integer := 0;
BEGIN
  IF NEW.plan_id IS NOT NULL THEN
    SELECT default_trial_days INTO v_days FROM public.plans WHERE id = NEW.plan_id;
  END IF;
  IF v_days IS NULL THEN v_days := 0; END IF;

  IF v_days > 0 THEN
    NEW.subscription_status := 'trialing';
    IF NEW.trial_started_at IS NULL THEN NEW.trial_started_at := now(); END IF;
    IF NEW.trial_ends_at IS NULL THEN NEW.trial_ends_at := now() + make_interval(days => v_days); END IF;
  ELSE
    IF NEW.subscription_status IS NULL OR NEW.subscription_status = '' THEN
      NEW.subscription_status := 'active';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS workspaces_start_trial_on_insert ON public.workspaces;
CREATE TRIGGER workspaces_start_trial_on_insert
  BEFORE INSERT ON public.workspaces
  FOR EACH ROW EXECUTE FUNCTION public.start_trial_on_workspace_insert();

-- 5. Entitlement resolver RPCs
CREATE OR REPLACE FUNCTION public.workspace_entitlements(p_workspace_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_plan_flags jsonb;
  v_overrides jsonb;
BEGIN
  IF NOT (
    EXISTS (SELECT 1 FROM public.workspace_members wm WHERE wm.workspace_id = p_workspace_id AND wm.user_id = auth.uid())
    OR public.is_platform_admin()
  ) THEN
    RAISE EXCEPTION 'not authorised';
  END IF;

  SELECT COALESCE(p.feature_flags, '{}'::jsonb), COALESCE(w.feature_overrides, '{}'::jsonb)
    INTO v_plan_flags, v_overrides
    FROM public.workspaces w LEFT JOIN public.plans p ON p.id = w.plan_id
    WHERE w.id = p_workspace_id;

  RETURN COALESCE(v_plan_flags, '{}'::jsonb) || COALESCE(v_overrides, '{}'::jsonb);
END; $$;

CREATE OR REPLACE FUNCTION public.workspace_effective_limits(p_workspace_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_row jsonb;
BEGIN
  IF NOT (
    EXISTS (SELECT 1 FROM public.workspace_members wm WHERE wm.workspace_id = p_workspace_id AND wm.user_id = auth.uid())
    OR public.is_platform_admin()
  ) THEN
    RAISE EXCEPTION 'not authorised';
  END IF;

  SELECT jsonb_build_object(
    'email_monthly_quota', COALESCE(w.email_quota_override, p.email_monthly_quota, 0),
    'sms_monthly_quota',   COALESCE(w.sms_quota_override, p.sms_monthly_quota, 0),
    'push_monthly_quota',  COALESCE(p.push_monthly_quota, 0),
    'seats',               COALESCE(p.seats, 1),
    'max_active_journeys', COALESCE(p.max_active_journeys, 1),
    'max_active_campaigns',COALESCE(p.max_active_campaigns, 3),
    'max_segments',        COALESCE(p.max_segments, 5),
    'max_events_per_month',COALESCE(p.max_events_per_month, 10000),
    'max_workspaces',      COALESCE(p.max_workspaces, 1),
    'data_retention_days', COALESCE(p.data_retention_days, 30),
    'support_sla_hours',   COALESCE(p.support_sla_hours, 72),
    'included_domains',    COALESCE(p.included_domains, 1)
  ) INTO v_row
  FROM public.workspaces w LEFT JOIN public.plans p ON p.id = w.plan_id
  WHERE w.id = p_workspace_id;

  RETURN v_row;
END; $$;

-- 6. Admin RPCs for plan/trial management
CREATE OR REPLACE FUNCTION public.admin_set_workspace_plan(
  p_workspace_id uuid,
  p_plan_id uuid,
  p_start_trial boolean DEFAULT false,
  p_trial_days_override integer DEFAULT NULL,
  p_note text DEFAULT ''
) RETURNS public.workspaces LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_row public.workspaces;
  v_current_plan uuid;
  v_trial_days integer;
BEGIN
  IF NOT public.is_platform_admin() THEN RAISE EXCEPTION 'not authorised'; END IF;

  SELECT plan_id INTO v_current_plan FROM public.workspaces WHERE id = p_workspace_id;

  IF p_start_trial THEN
    IF p_trial_days_override IS NOT NULL AND p_trial_days_override > 0 THEN
      v_trial_days := p_trial_days_override;
    ELSE
      SELECT default_trial_days INTO v_trial_days FROM public.plans WHERE id = p_plan_id;
    END IF;
    IF COALESCE(v_trial_days, 0) <= 0 THEN v_trial_days := 14; END IF;
  END IF;

  UPDATE public.workspaces
     SET plan_id = p_plan_id,
         plan_assigned_at = now(),
         subscription_status = CASE
           WHEN p_start_trial THEN 'trialing'
           ELSE 'active'
         END,
         trial_started_at = CASE WHEN p_start_trial THEN now() ELSE trial_started_at END,
         trial_ends_at = CASE WHEN p_start_trial THEN now() + make_interval(days => v_trial_days) ELSE trial_ends_at END
   WHERE id = p_workspace_id
   RETURNING * INTO v_row;

  INSERT INTO public.plan_changes (workspace_id, from_plan_id, to_plan_id, actor_id, note)
  VALUES (p_workspace_id, v_current_plan, p_plan_id, auth.uid(), COALESCE(p_note, ''));

  RETURN v_row;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_set_workspace_trial(
  p_workspace_id uuid,
  p_trial_ends_at timestamptz,
  p_status text DEFAULT 'trialing'
) RETURNS public.workspaces LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_row public.workspaces;
BEGIN
  IF NOT public.is_platform_admin() THEN RAISE EXCEPTION 'not authorised'; END IF;
  IF p_status NOT IN ('trialing','active','past_due','cancelled','expired') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE public.workspaces
     SET trial_ends_at = p_trial_ends_at,
         trial_started_at = COALESCE(trial_started_at, now()),
         subscription_status = p_status
   WHERE id = p_workspace_id
   RETURNING * INTO v_row;

  RETURN v_row;
END; $$;

REVOKE ALL ON FUNCTION public.workspace_entitlements(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.workspace_effective_limits(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_workspace_plan(uuid, uuid, boolean, integer, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_workspace_trial(uuid, timestamptz, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.workspace_entitlements(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.workspace_effective_limits(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_workspace_plan(uuid, uuid, boolean, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_workspace_trial(uuid, timestamptz, text) TO authenticated;

-- 7. Refresh seeded plans with fuller feature maps
UPDATE public.plans SET
  name = 'Free',
  tagline = 'Get started and send your first 5k emails.',
  description = 'Perfect for small teams testing the waters. Core customer data, one journey, and essential analytics.',
  price_monthly = 0, price_yearly = 0,
  email_monthly_quota = 5000, sms_monthly_quota = 0, push_monthly_quota = 10000,
  seats = 2, max_active_journeys = 1, max_active_campaigns = 3, max_segments = 5,
  max_events_per_month = 50000, data_retention_days = 30, included_domains = 1,
  support_sla_hours = 72, max_workspaces = 1,
  default_trial_days = 0, cta_label = 'Start free',
  feature_flags = jsonb_build_object(
    'journeys', true,
    'segments', true,
    'campaigns', true,
    'templates', true,
    'web_push', true,
    'customer_profiles', true,
    'basic_analytics', true,
    'email_support', true,
    'ab_testing', false,
    'custom_domain', false,
    'advanced_rbac', false,
    'dedicated_ip', false,
    'sso', false,
    'sla', false,
    'priority_support', false,
    'ai_studio', false,
    'predictive', false,
    'scim', false,
    'audit_export', false,
    'white_label', false,
    'inbox_placement', false,
    'scheduled_reports', false,
    'api_access', true,
    'sms', false,
    'commerce_integrations', false,
    'custom_roles', false
  ),
  highlight = false, is_public = true, sort_order = 1
WHERE code = 'free';

UPDATE public.plans SET
  name = 'Pro',
  tagline = 'For growing teams sending serious volume.',
  description = 'Unlock A/B testing, SMS, commerce integrations, and custom sending domains. Ideal for product and growth teams.',
  price_monthly = 99, price_yearly = 990,
  email_monthly_quota = 100000, sms_monthly_quota = 1000, push_monthly_quota = 500000,
  seats = 5, max_active_journeys = 10, max_active_campaigns = 50, max_segments = 50,
  max_events_per_month = 2000000, data_retention_days = 180, included_domains = 3,
  support_sla_hours = 24, max_workspaces = 2,
  default_trial_days = 14, cta_label = 'Start 14-day trial',
  feature_flags = jsonb_build_object(
    'journeys', true, 'segments', true, 'campaigns', true, 'templates', true,
    'web_push', true, 'customer_profiles', true, 'basic_analytics', true,
    'advanced_analytics', true, 'funnels', true, 'cohorts', true, 'rfm', true,
    'ab_testing', true, 'custom_domain', true, 'sms', true,
    'commerce_integrations', true, 'api_access', true, 'webhooks', true,
    'scheduled_reports', true, 'inbox_placement', true, 'custom_roles', true,
    'ai_studio', true, 'predictive', false, 'email_support', true,
    'priority_support', false, 'advanced_rbac', false, 'dedicated_ip', false,
    'sso', false, 'sla', false, 'scim', false, 'audit_export', false, 'white_label', false
  ),
  highlight = true, is_public = true, sort_order = 2
WHERE code = 'pro';

UPDATE public.plans SET
  name = 'Advanced',
  tagline = 'Built for scale, compliance, and performance.',
  description = 'Everything in Pro plus predictive AI, dedicated IP, role-based access control, and priority support.',
  price_monthly = 499, price_yearly = 4990,
  email_monthly_quota = 1000000, sms_monthly_quota = 10000, push_monthly_quota = 5000000,
  seats = 15, max_active_journeys = 100, max_active_campaigns = 500, max_segments = 500,
  max_events_per_month = 20000000, data_retention_days = 365, included_domains = 10,
  support_sla_hours = 8, max_workspaces = 5,
  default_trial_days = 14, cta_label = 'Start 14-day trial',
  feature_flags = jsonb_build_object(
    'journeys', true, 'segments', true, 'campaigns', true, 'templates', true,
    'web_push', true, 'customer_profiles', true, 'basic_analytics', true,
    'advanced_analytics', true, 'funnels', true, 'cohorts', true, 'rfm', true,
    'ab_testing', true, 'custom_domain', true, 'sms', true,
    'commerce_integrations', true, 'api_access', true, 'webhooks', true,
    'scheduled_reports', true, 'inbox_placement', true, 'custom_roles', true,
    'ai_studio', true, 'predictive', true, 'advanced_rbac', true,
    'dedicated_ip', true, 'priority_support', true, 'audit_export', true,
    'email_support', true, 'sso', false, 'sla', false, 'scim', false, 'white_label', false
  ),
  highlight = false, is_public = true, sort_order = 3
WHERE code = 'advanced';

UPDATE public.plans SET
  name = 'Enterprise',
  tagline = 'Custom-built for the largest senders.',
  description = 'Unlimited everything with SSO, SCIM provisioning, SLA-backed uptime, white-labeling, and a dedicated customer success team.',
  price_monthly = 0, price_yearly = 0, contact_sales = true,
  email_monthly_quota = 100000000, sms_monthly_quota = 10000000, push_monthly_quota = 1000000000,
  seats = 100, max_active_journeys = 10000, max_active_campaigns = 10000, max_segments = 10000,
  max_events_per_month = 2000000000, data_retention_days = 730, included_domains = 100,
  support_sla_hours = 1, max_workspaces = 50,
  default_trial_days = 30, cta_label = 'Talk to sales',
  feature_flags = jsonb_build_object(
    'journeys', true, 'segments', true, 'campaigns', true, 'templates', true,
    'web_push', true, 'customer_profiles', true, 'basic_analytics', true,
    'advanced_analytics', true, 'funnels', true, 'cohorts', true, 'rfm', true,
    'ab_testing', true, 'custom_domain', true, 'sms', true,
    'commerce_integrations', true, 'api_access', true, 'webhooks', true,
    'scheduled_reports', true, 'inbox_placement', true, 'custom_roles', true,
    'ai_studio', true, 'predictive', true, 'advanced_rbac', true,
    'dedicated_ip', true, 'priority_support', true, 'audit_export', true,
    'email_support', true, 'sso', true, 'sla', true, 'scim', true, 'white_label', true
  ),
  highlight = false, is_public = true, sort_order = 4
WHERE code = 'enterprise';

-- Backfill existing workspaces: if no subscription_status, set active (except free plan stays active)
UPDATE public.workspaces SET subscription_status = 'active'
 WHERE subscription_status IS NULL OR subscription_status = '';
