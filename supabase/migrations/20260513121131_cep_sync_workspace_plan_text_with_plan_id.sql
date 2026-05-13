/*
  # Keep legacy `workspaces.plan` text column in sync with `plan_id`

  1. Why
    - `workspaces` has both a legacy `plan` text column (e.g. 'free', 'pro')
      and the canonical `plan_id` foreign key into `plans`. The admin RPC
      `admin_set_workspace_plan` only updates `plan_id`, so the legacy text
      column drifts and surfaces as "Free" in the workspace settings UI even
      though the workspace is on Enterprise.

  2. Changes
    - Adds a `BEFORE INSERT OR UPDATE` trigger on `workspaces` that copies
      `plans.code` into `workspaces.plan` whenever `plan_id` is set or
      changes. Idempotent: if `plan_id` is null the legacy column is left
      alone.
    - Backfills the legacy column for all existing rows so current
      mismatches resolve immediately.

  3. Security
    - Trigger function is SECURITY INVOKER (no privilege escalation).
    - No RLS policy changes.
*/

CREATE OR REPLACE FUNCTION public.sync_workspace_plan_code()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_code text;
BEGIN
  IF NEW.plan_id IS NULL THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND NEW.plan_id IS NOT DISTINCT FROM OLD.plan_id THEN
    RETURN NEW;
  END IF;
  SELECT code INTO v_code FROM public.plans WHERE id = NEW.plan_id;
  IF v_code IS NOT NULL THEN
    NEW.plan := v_code;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS workspaces_sync_plan_code ON public.workspaces;
CREATE TRIGGER workspaces_sync_plan_code
BEFORE INSERT OR UPDATE OF plan_id ON public.workspaces
FOR EACH ROW EXECUTE FUNCTION public.sync_workspace_plan_code();

UPDATE public.workspaces w
   SET plan = p.code
  FROM public.plans p
 WHERE p.id = w.plan_id
   AND w.plan IS DISTINCT FROM p.code;
