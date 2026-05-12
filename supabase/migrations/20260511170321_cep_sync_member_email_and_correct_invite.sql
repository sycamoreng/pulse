/*
  # Sync auth email changes and let admins correct typo'd invites

  ## Purpose
  1. When a user changes their email in Supabase Auth, mirror that to
     every workspace_members row pointing at that user so the admin UI
     stays accurate and invite status flips correctly.
  2. Give workspace owners/admins a supported way to fix a mistyped
     pending invite email (e.g. .com -> .ng) without having to delete
     and recreate the row. If an auth user already exists for the new
     email, we attach it; otherwise the row stays pending under the
     corrected address.

  ## Changes
  - Trigger `sync_member_email_on_auth_email_change` on auth.users:
    when email changes, update workspace_members.email for rows whose
    user_id = NEW.id AND email is distinct from the new email.
  - RPC `update_pending_invite_email(p_member_id, p_new_email)`:
    SECURITY DEFINER, owner/admin-only. Validates email shape, rejects
    collisions with another member in the same workspace, and re-points
    user_id to any existing auth user with that email (else leaves null).

  ## Security
  - Trigger runs with SECURITY DEFINER but only touches rows linked to
    the user whose auth row changed.
  - RPC checks the caller is an owner or admin of the workspace the
    target member belongs to before mutating anything.
*/

CREATE OR REPLACE FUNCTION public.sync_member_email_on_auth_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
  IF NEW.email IS DISTINCT FROM OLD.email THEN
    UPDATE public.workspace_members
       SET email = NEW.email
     WHERE user_id = NEW.id
       AND (email IS DISTINCT FROM NEW.email);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_member_email_on_auth_email_change ON auth.users;
CREATE TRIGGER sync_member_email_on_auth_email_change
AFTER UPDATE OF email ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.sync_member_email_on_auth_change();

CREATE OR REPLACE FUNCTION public.update_pending_invite_email(
  p_member_id uuid,
  p_new_email text
) RETURNS public.workspace_members
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_member public.workspace_members;
  v_new_email text := lower(trim(p_new_email));
  v_caller_role text;
  v_existing_user uuid;
BEGIN
  IF v_new_email IS NULL OR v_new_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
    RAISE EXCEPTION 'invalid email address';
  END IF;

  SELECT * INTO v_member FROM public.workspace_members WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'member not found';
  END IF;

  SELECT role INTO v_caller_role
    FROM public.workspace_members
   WHERE workspace_id = v_member.workspace_id
     AND user_id = auth.uid();
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('owner','admin') THEN
    RAISE EXCEPTION 'not authorised';
  END IF;

  IF v_member.activated_at IS NOT NULL THEN
    RAISE EXCEPTION 'cannot edit an activated member; remove and re-invite instead';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.workspace_members
     WHERE workspace_id = v_member.workspace_id
       AND id <> v_member.id
       AND lower(email) = v_new_email
  ) THEN
    RAISE EXCEPTION 'another member with that email already exists in this workspace';
  END IF;

  SELECT id INTO v_existing_user FROM auth.users WHERE lower(email) = v_new_email LIMIT 1;

  UPDATE public.workspace_members
     SET email = v_new_email,
         user_id = COALESCE(v_existing_user, NULL)
   WHERE id = p_member_id
  RETURNING * INTO v_member;

  RETURN v_member;
END;
$$;

REVOKE ALL ON FUNCTION public.update_pending_invite_email(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_pending_invite_email(uuid, text) TO authenticated;
