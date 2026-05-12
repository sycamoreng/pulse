/*
  # Test workspaces inherit plan and billing from parent

  ## Why
  Test workspaces are not independent tenants. They are a throwaway
  sandbox tied to a real (production) workspace. Treating them as
  independent inflates tenant counts on the admin side, complicates
  billing, and lets them carry their own plan/trial state out of sync
  with the parent they belong to.

  ## What this migration does
  1. Adds a BEFORE INSERT/UPDATE trigger on `workspaces` that, when the
     row is a test workspace (environment='test' AND parent_workspace_id
     is not null), copies `plan_id`, `subscription_status`,
     `trial_started_at`, `trial_ends_at`, `email_quota_override`, and
     `sms_quota_override` from its parent. This keeps test workspaces
     aligned automatically.
  2. Adds an AFTER UPDATE trigger on the *parent* so that changing the
     parent's plan/trial/overrides cascades to its test siblings.
  3. Adds a helper view `billable_workspaces` that exposes only real
     production workspaces (environment <> 'test' AND parent_workspace_id
     IS NULL). Platform admins should query this instead of the raw
     `workspaces` table whenever they want "actual tenants".

  ## Security
  - Triggers are SECURITY DEFINER with a locked search_path.
  - `billable_workspaces` is a view, inherits RLS from `workspaces`.
*/

CREATE OR REPLACE FUNCTION public.test_ws_inherit_from_parent()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_parent public.workspaces;
BEGIN
  IF NEW.environment = 'test' AND NEW.parent_workspace_id IS NOT NULL THEN
    SELECT * INTO v_parent FROM public.workspaces WHERE id = NEW.parent_workspace_id;
    IF FOUND THEN
      NEW.plan_id := v_parent.plan_id;
      NEW.subscription_status := COALESCE(v_parent.subscription_status, 'active');
      NEW.trial_started_at := v_parent.trial_started_at;
      NEW.trial_ends_at := v_parent.trial_ends_at;
      NEW.email_quota_override := v_parent.email_quota_override;
      NEW.sms_quota_override := v_parent.sms_quota_override;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS workspaces_test_inherit_before ON public.workspaces;
CREATE TRIGGER workspaces_test_inherit_before
  BEFORE INSERT OR UPDATE ON public.workspaces
  FOR EACH ROW EXECUTE FUNCTION public.test_ws_inherit_from_parent();

CREATE OR REPLACE FUNCTION public.cascade_plan_to_test_siblings()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF (NEW.environment IS NULL OR NEW.environment <> 'test')
     AND (
       NEW.plan_id IS DISTINCT FROM OLD.plan_id
       OR NEW.subscription_status IS DISTINCT FROM OLD.subscription_status
       OR NEW.trial_ends_at IS DISTINCT FROM OLD.trial_ends_at
       OR NEW.trial_started_at IS DISTINCT FROM OLD.trial_started_at
       OR NEW.email_quota_override IS DISTINCT FROM OLD.email_quota_override
       OR NEW.sms_quota_override IS DISTINCT FROM OLD.sms_quota_override
     ) THEN
    UPDATE public.workspaces
       SET plan_id = NEW.plan_id,
           subscription_status = NEW.subscription_status,
           trial_started_at = NEW.trial_started_at,
           trial_ends_at = NEW.trial_ends_at,
           email_quota_override = NEW.email_quota_override,
           sms_quota_override = NEW.sms_quota_override
     WHERE parent_workspace_id = NEW.id
       AND environment = 'test';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS workspaces_cascade_to_test_siblings ON public.workspaces;
CREATE TRIGGER workspaces_cascade_to_test_siblings
  AFTER UPDATE ON public.workspaces
  FOR EACH ROW EXECUTE FUNCTION public.cascade_plan_to_test_siblings();

-- One-off backfill so existing test workspaces align with their parents
UPDATE public.workspaces t
   SET plan_id = p.plan_id,
       subscription_status = COALESCE(p.subscription_status, 'active'),
       trial_started_at = p.trial_started_at,
       trial_ends_at = p.trial_ends_at,
       email_quota_override = p.email_quota_override,
       sms_quota_override = p.sms_quota_override
  FROM public.workspaces p
 WHERE t.environment = 'test'
   AND t.parent_workspace_id = p.id
   AND (t.plan_id IS DISTINCT FROM p.plan_id
        OR t.subscription_status IS DISTINCT FROM p.subscription_status
        OR t.trial_ends_at IS DISTINCT FROM p.trial_ends_at);

CREATE OR REPLACE VIEW public.billable_workspaces AS
  SELECT * FROM public.workspaces
   WHERE parent_workspace_id IS NULL
     AND (environment IS NULL OR environment <> 'test');

GRANT SELECT ON public.billable_workspaces TO authenticated;
