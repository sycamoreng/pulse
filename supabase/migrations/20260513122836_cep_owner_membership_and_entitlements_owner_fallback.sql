/*
  # Make workspace owners always recognised

  1. Why
    - `workspace_members` is the source of truth for "who can do what" in a
      workspace. The trigger `ensure_owner_member_on_workspace` already
      inserts an Owner row when a workspace is created, but production data
      contained workspaces whose owner had no membership row (e.g. Daniel
      owns Sycamore but has no row in `workspace_members` for it). When that
      drift happens, two things break:
        - `workspace_entitlements()` raises 'not authorised' so the entire
          plan feature map falls back to empty - the owner sees the UI as if
          they were on the Free plan even though `plan_id` is Enterprise.
        - The `send-invite-link` edge function rejects them with
          "only workspace admins can send registration links".

  2. Changes
    - Backfills any missing owner memberships for existing workspaces.
    - Updates `workspace_entitlements(uuid)` so the owner is always
      authorised, even if the membership row is somehow missing.
    - Updates `workspace_effective_limits(uuid)` the same way (it has the
      same authorisation guard).

  3. Security
    - Both RPCs remain SECURITY DEFINER with explicit search_path.
    - The owner check uses `auth.uid() = workspaces.owner_id`, which is the
      same identity check RLS policies elsewhere already trust.
*/

-- 1. Backfill: ensure every workspace owner has an Owner membership row.
INSERT INTO public.workspace_members (workspace_id, user_id, email, role, role_id, activated_at)
SELECT
  w.id,
  w.owner_id,
  u.email,
  'owner',
  (SELECT wr.id FROM public.workspace_roles wr
    WHERE wr.workspace_id = w.id AND wr.name = 'Owner' LIMIT 1),
  now()
FROM public.workspaces w
LEFT JOIN auth.users u ON u.id = w.owner_id
WHERE w.owner_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.workspace_members wm
    WHERE wm.workspace_id = w.id AND wm.user_id = w.owner_id
  );

-- 2. workspace_entitlements: authorise owner as well as members and platform admins.
CREATE OR REPLACE FUNCTION public.workspace_entitlements(p_workspace_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_plan_flags jsonb;
  v_overrides jsonb;
BEGIN
  IF NOT (
    EXISTS (SELECT 1 FROM public.workspaces w
            WHERE w.id = p_workspace_id AND w.owner_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.workspace_members wm
               WHERE wm.workspace_id = p_workspace_id AND wm.user_id = auth.uid())
    OR public.is_platform_admin()
  ) THEN
    RAISE EXCEPTION 'not authorised';
  END IF;

  SELECT COALESCE(p.feature_flags, '{}'::jsonb), COALESCE(w.feature_overrides, '{}'::jsonb)
    INTO v_plan_flags, v_overrides
    FROM public.workspaces w LEFT JOIN public.plans p ON p.id = w.plan_id
   WHERE w.id = p_workspace_id;

  RETURN COALESCE(v_plan_flags, '{}'::jsonb) || COALESCE(v_overrides, '{}'::jsonb);
END;
$function$;

-- 3. workspace_effective_limits: same fix.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'workspace_effective_limits'
  ) THEN
    EXECUTE $body$
      CREATE OR REPLACE FUNCTION public.workspace_effective_limits(p_workspace_id uuid)
      RETURNS jsonb
      LANGUAGE plpgsql
      STABLE SECURITY DEFINER
      SET search_path TO 'public', 'pg_temp'
      AS $inner$
      DECLARE
        v jsonb;
      BEGIN
        IF NOT (
          EXISTS (SELECT 1 FROM public.workspaces w
                  WHERE w.id = p_workspace_id AND w.owner_id = auth.uid())
          OR EXISTS (SELECT 1 FROM public.workspace_members wm
                     WHERE wm.workspace_id = p_workspace_id AND wm.user_id = auth.uid())
          OR public.is_platform_admin()
        ) THEN
          RAISE EXCEPTION 'not authorised';
        END IF;

        SELECT to_jsonb(p) - 'id' - 'code' - 'name' - 'feature_flags' - 'created_at' - 'updated_at'
          INTO v
          FROM public.workspaces w
          LEFT JOIN public.plans p ON p.id = w.plan_id
         WHERE w.id = p_workspace_id;

        RETURN COALESCE(v, '{}'::jsonb);
      END;
      $inner$;
    $body$;
  END IF;
END $$;
