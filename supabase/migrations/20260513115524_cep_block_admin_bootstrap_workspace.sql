/*
  # Block platform admins from auto-provisioning tenant workspaces

  1. Changes
    - Updates `bootstrap_workspace_for_current_user(text, uuid)` to refuse
      creating a brand-new tenant workspace when the calling user is registered
      in `platform_admins`. Existing memberships and pending invites are still
      honoured (the RPC will return the existing workspace or attach the invite),
      but the "fall through to create" branch now raises an error instead.

  2. Why
    - Platform admins are operations-team accounts. They sign in via the admin
      console only and should never accidentally end up owning a tenant workspace
      just because the tenant SPA called this RPC. Several ghost workspaces were
      created this way before today's client-side fix landed; this is the
      server-side belt-and-braces.

  3. Security
    - SECURITY DEFINER preserved with explicit search_path.
    - No RLS policy changes.
*/

CREATE OR REPLACE FUNCTION public.bootstrap_workspace_for_current_user(
  p_name text DEFAULT NULL::text,
  p_plan_id uuid DEFAULT NULL::uuid
)
RETURNS public.workspaces
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_email text;
  v_existing public.workspaces;
  v_pending integer;
  v_ws public.workspaces;
  v_slug text;
  v_name text;
  v_plan uuid := p_plan_id;
  v_owner_role uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated.'; END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;

  -- Already owns or is a member of any workspace? Return it, do nothing.
  SELECT w.* INTO v_existing
  FROM public.workspaces w
  LEFT JOIN public.workspace_members wm
    ON wm.workspace_id = w.id AND wm.user_id = v_uid
  WHERE (w.owner_id = v_uid OR wm.user_id = v_uid)
    AND (w.parent_workspace_id IS NULL)
  ORDER BY w.created_at ASC
  LIMIT 1;
  IF FOUND THEN RETURN v_existing; END IF;

  -- Pending invite at this email? Attach and bail - no new workspace.
  IF v_email IS NOT NULL THEN
    UPDATE public.workspace_members
       SET user_id = v_uid, activated_at = COALESCE(activated_at, now())
     WHERE user_id IS NULL AND lower(email) = lower(v_email);
    GET DIAGNOSTICS v_pending = ROW_COUNT;
    IF v_pending > 0 THEN
      SELECT w.* INTO v_existing FROM public.workspaces w
        JOIN public.workspace_members wm ON wm.workspace_id = w.id
       WHERE wm.user_id = v_uid AND (w.parent_workspace_id IS NULL)
       ORDER BY w.created_at ASC LIMIT 1;
      RETURN v_existing;
    END IF;
  END IF;

  -- HARD STOP: platform admins must never auto-provision a tenant workspace.
  IF EXISTS (SELECT 1 FROM public.platform_admins WHERE user_id = v_uid) THEN
    RAISE EXCEPTION 'Platform admin accounts cannot create tenant workspaces.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Fall through: brand new solo account. Create production + test sibling.
  v_name := COALESCE(NULLIF(p_name, ''), split_part(COALESCE(v_email, 'user'), '@', 1) || '''s Workspace');
  v_slug := 'ws-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  IF v_plan IS NULL THEN
    SELECT id INTO v_plan FROM public.plans WHERE code = 'free' LIMIT 1;
  END IF;

  INSERT INTO public.workspaces (name, slug, owner_id, environment, plan_id)
  VALUES (v_name, v_slug, v_uid, 'production', v_plan)
  RETURNING * INTO v_ws;

  INSERT INTO public.workspaces (name, slug, owner_id, environment, parent_workspace_id, plan_id, demo_seeded)
  VALUES (v_name || ' (Test)', v_slug || '-test', v_uid, 'test', v_ws.id, v_plan, true);

  -- Make sure the owner has a membership row with the Owner role.
  SELECT id INTO v_owner_role FROM public.workspace_roles
   WHERE workspace_id = v_ws.id AND name = 'Owner' LIMIT 1;

  IF v_owner_role IS NOT NULL THEN
    INSERT INTO public.workspace_members (workspace_id, user_id, email, role, role_id, activated_at)
    VALUES (v_ws.id, v_uid, v_email, 'owner', v_owner_role, now())
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN v_ws;
END;
$function$;
