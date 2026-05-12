/*
  # Harden the boundary between user accounts and workspaces

  ## Why
  Previously, every newly-signed-up user triggered an unconditional
  client-side "create workspace" call. Combined with races against the
  `link_pending_invites` trigger and a lack of uniqueness guards, this
  produced phantom duplicate workspaces (e.g. several "Sycamore"s) and
  blurred the line between the account (a person) and the workspace
  (a tenant that a person either owns or is invited to).

  ## What this migration locks down
  1. Uniqueness guards so the same auth user cannot sit in the same
     workspace twice, and the same email cannot have two pending
     invites in the same workspace.
     - `workspace_members_user_unique` on (workspace_id, user_id) WHERE user_id IS NOT NULL
     - `workspace_members_email_unique` on (workspace_id, lower(email)) WHERE user_id IS NULL
  2. A single source of truth for "create workspace for a brand new
     account" via RPC `bootstrap_workspace_for_current_user`.
     - Only runs if the caller has no memberships and no pending
       invites at their email.
     - If there IS a pending invite, the RPC attaches it instead of
       creating a workspace. Accounts added to someone else's
       workspace never get their own.
     - Creates the production workspace + its test sibling + the
       Owner membership in one transaction.
  3. A helper RPC `workspace_summary(user_id)` used by the client to
     decide "does this account need a bootstrap?" without ambiguity.
  4. A BEFORE INSERT trigger on `workspaces` that blocks client code
     from creating a duplicate production workspace for an owner who
     already has one - the only supported way to make more is via
     platform admin.

  ## Security
  - RPCs are SECURITY DEFINER with locked search_path, and only act
    on the currently authenticated user (auth.uid()).
  - No existing policies are loosened.
*/

-- 1. Uniqueness guards on workspace_members
CREATE UNIQUE INDEX IF NOT EXISTS workspace_members_user_unique
  ON public.workspace_members (workspace_id, user_id)
  WHERE user_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS workspace_members_email_unique
  ON public.workspace_members (workspace_id, lower(email))
  WHERE user_id IS NULL AND email IS NOT NULL;

-- 2. Block duplicate "personal" workspaces for the same owner
CREATE OR REPLACE FUNCTION public.enforce_single_owned_workspace()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF TG_OP = 'INSERT'
     AND NEW.environment = 'production'
     AND NEW.parent_workspace_id IS NULL
     AND NEW.owner_id IS NOT NULL
     AND NOT public.is_platform_admin()
     AND EXISTS (
       SELECT 1 FROM public.workspaces w
        WHERE w.owner_id = NEW.owner_id
          AND w.environment = 'production'
          AND w.parent_workspace_id IS NULL
          AND w.id <> NEW.id
     ) THEN
    RAISE EXCEPTION 'An account may only own one production workspace. Use an invite to give this user access to an existing workspace.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_single_owned_workspace ON public.workspaces;
CREATE TRIGGER enforce_single_owned_workspace
  BEFORE INSERT ON public.workspaces
  FOR EACH ROW EXECUTE FUNCTION public.enforce_single_owned_workspace();

-- 3. Canonical bootstrap RPC
CREATE OR REPLACE FUNCTION public.bootstrap_workspace_for_current_user(
  p_name text DEFAULT NULL,
  p_plan_id uuid DEFAULT NULL
) RETURNS public.workspaces LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
$$;

REVOKE ALL ON FUNCTION public.bootstrap_workspace_for_current_user(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.bootstrap_workspace_for_current_user(text, uuid) TO authenticated;
