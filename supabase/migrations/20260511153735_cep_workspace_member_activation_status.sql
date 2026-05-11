/*
  # Member activation status

  ## Purpose
  Previously a workspace member was considered "pending" only while
  `user_id` was null. But sending an invite link creates the auth user
  immediately (and the link_pending_invites trigger attaches it), so the
  pending pill vanished before the user had even opened the email. This
  migration introduces an explicit activation signal.

  ## Changes
  1. New column `workspace_members.activated_at timestamptz` — set when the
     invitee completes password setup on the /welcome page.
  2. Backfill `activated_at = created_at` for any member whose user row has
     a password or a recorded sign-in, so existing teams don't regress to
     "pending".
  3. New RPC `mark_member_activated(p_workspace uuid)` so the client can set
     activated_at for the current auth.uid() without broad update rights.

  ## Security
  - No RLS changes. The RPC is SECURITY DEFINER and only updates the row
    matching (workspace_id, auth.uid()).
*/

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='workspace_members' AND column_name='activated_at'
  ) THEN
    ALTER TABLE public.workspace_members ADD COLUMN activated_at timestamptz;
  END IF;
END $$;

-- Backfill: treat any existing member whose auth user has a password or has ever signed in as activated.
UPDATE public.workspace_members wm
   SET activated_at = COALESCE(wm.activated_at, wm.created_at, now())
  FROM auth.users u
 WHERE wm.user_id = u.id
   AND wm.activated_at IS NULL
   AND (u.encrypted_password IS NOT NULL OR u.last_sign_in_at IS NOT NULL);

CREATE OR REPLACE FUNCTION public.mark_member_activated(p_workspace uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
  UPDATE public.workspace_members
     SET activated_at = now()
   WHERE user_id = auth.uid()
     AND (p_workspace IS NULL OR workspace_id = p_workspace)
     AND activated_at IS NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_member_activated(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_member_activated(uuid) TO authenticated;
