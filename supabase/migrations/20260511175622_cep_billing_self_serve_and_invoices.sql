/*
  # Self-serve billing: change plan RPC, invoices, payment methods

  Same as the previous attempt, but matches the actual workspace_roles
  schema (uses `name` column, not `code`).

  ## What this migration does
  1. Backfills any workspaces with NULL plan_id to the Free plan and
     marks plan_id NOT NULL going forward.
  2. Creates `payment_methods` and `invoices` tables, scoped to a
     workspace with strict RLS.
  3. Adds `is_workspace_admin(uuid)` helper - true when the caller
     owns the workspace or is a member whose role name resembles
     owner/admin.
  4. Adds `change_workspace_plan(workspace_id, plan_id)` that any
     workspace owner or admin can call to move between standard plans.
     Rules:
       - Cannot move into or out of Enterprise via this RPC (must go
         through platform admin).
       - Trial is ended on plan change.
       - Plan history is recorded in `plan_changes`.
  5. Adds `cancel_workspace_subscription(workspace_id)` which sends
     the workspace back to Free via the same gate.

  ## Security
  All new tables have RLS enabled. RPCs are SECURITY DEFINER and
  enforce authorisation explicitly.
*/

DO $$
DECLARE v_free_id uuid;
BEGIN
  SELECT id INTO v_free_id FROM public.plans WHERE code = 'free' LIMIT 1;
  IF v_free_id IS NOT NULL THEN
    UPDATE public.workspaces SET plan_id = v_free_id WHERE plan_id IS NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'workspaces'
       AND column_name = 'plan_id' AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE public.workspaces ALTER COLUMN plan_id SET NOT NULL;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  brand text NOT NULL DEFAULT 'card',
  last4 text NOT NULL DEFAULT '',
  exp_month integer,
  exp_year integer,
  holder_name text NOT NULL DEFAULT '',
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS payment_methods_ws_idx ON public.payment_methods(workspace_id);
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "members read payment methods" ON public.payment_methods;
CREATE POLICY "members read payment methods" ON public.payment_methods
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.workspace_members wm
            WHERE wm.workspace_id = payment_methods.workspace_id AND wm.user_id = auth.uid())
    OR public.is_platform_admin()
  );

DROP POLICY IF EXISTS "owners insert payment methods" ON public.payment_methods;
CREATE POLICY "owners insert payment methods" ON public.payment_methods
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.workspaces w
            WHERE w.id = payment_methods.workspace_id AND w.owner_id = auth.uid())
    OR public.is_platform_admin()
  );

DROP POLICY IF EXISTS "owners update payment methods" ON public.payment_methods;
CREATE POLICY "owners update payment methods" ON public.payment_methods
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.workspaces w
            WHERE w.id = payment_methods.workspace_id AND w.owner_id = auth.uid())
    OR public.is_platform_admin()
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.workspaces w
            WHERE w.id = payment_methods.workspace_id AND w.owner_id = auth.uid())
    OR public.is_platform_admin()
  );

DROP POLICY IF EXISTS "owners delete payment methods" ON public.payment_methods;
CREATE POLICY "owners delete payment methods" ON public.payment_methods
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.workspaces w
            WHERE w.id = payment_methods.workspace_id AND w.owner_id = auth.uid())
    OR public.is_platform_admin()
  );

CREATE TABLE IF NOT EXISTS public.invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  plan_id uuid REFERENCES public.plans(id),
  number text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'paid',
  amount_cents integer NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'USD',
  period_start timestamptz,
  period_end timestamptz,
  issued_at timestamptz NOT NULL DEFAULT now(),
  paid_at timestamptz,
  hosted_url text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS invoices_ws_idx ON public.invoices(workspace_id, issued_at DESC);
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "members read invoices" ON public.invoices;
CREATE POLICY "members read invoices" ON public.invoices
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.workspace_members wm
            WHERE wm.workspace_id = invoices.workspace_id AND wm.user_id = auth.uid())
    OR public.is_platform_admin()
  );

CREATE OR REPLACE FUNCTION public.is_workspace_admin(p_workspace_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.workspaces w
     WHERE w.id = p_workspace_id AND w.owner_id = auth.uid()
  ) OR EXISTS (
    SELECT 1 FROM public.workspace_members wm
     LEFT JOIN public.workspace_roles r ON r.id = wm.role_id
     WHERE wm.workspace_id = p_workspace_id
       AND wm.user_id = auth.uid()
       AND lower(COALESCE(r.name, '')) IN ('owner', 'admin', 'administrator')
  );
$$;
GRANT EXECUTE ON FUNCTION public.is_workspace_admin(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.change_workspace_plan(
  p_workspace_id uuid,
  p_plan_id uuid
) RETURNS public.workspaces LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_row public.workspaces;
  v_current_plan uuid;
  v_current_code text;
  v_next_code text;
BEGIN
  IF NOT public.is_workspace_admin(p_workspace_id) THEN
    RAISE EXCEPTION 'Only workspace owners or admins can change the plan.';
  END IF;

  SELECT w.plan_id, p.code INTO v_current_plan, v_current_code
    FROM public.workspaces w
    LEFT JOIN public.plans p ON p.id = w.plan_id
   WHERE w.id = p_workspace_id;

  SELECT code INTO v_next_code FROM public.plans WHERE id = p_plan_id;
  IF v_next_code IS NULL THEN RAISE EXCEPTION 'Target plan not found.'; END IF;

  IF v_current_code = 'enterprise' OR v_next_code = 'enterprise' THEN
    RAISE EXCEPTION 'Enterprise plan changes require a platform admin.';
  END IF;

  UPDATE public.workspaces
     SET plan_id = p_plan_id,
         plan_assigned_at = now(),
         subscription_status = 'active',
         trial_ends_at = NULL,
         trial_started_at = NULL
   WHERE id = p_workspace_id
   RETURNING * INTO v_row;

  INSERT INTO public.plan_changes (workspace_id, from_plan_id, to_plan_id, actor_id, note)
  VALUES (p_workspace_id, v_current_plan, p_plan_id, auth.uid(), 'self-serve plan change');

  RETURN v_row;
END; $$;

REVOKE ALL ON FUNCTION public.change_workspace_plan(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.change_workspace_plan(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.cancel_workspace_subscription(
  p_workspace_id uuid
) RETURNS public.workspaces LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_free_id uuid;
BEGIN
  SELECT id INTO v_free_id FROM public.plans WHERE code = 'free' LIMIT 1;
  IF v_free_id IS NULL THEN RAISE EXCEPTION 'Free plan not configured.'; END IF;
  RETURN public.change_workspace_plan(p_workspace_id, v_free_id);
END; $$;

REVOKE ALL ON FUNCTION public.cancel_workspace_subscription(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_workspace_subscription(uuid) TO authenticated;