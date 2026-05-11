/*
  # Fix auth.users trigger search_path

  ## Problem
  Admin-generated invite links (and any other signup flow) were failing with
  "Database error saving new user". The root cause was two SECURITY DEFINER
  trigger functions attached to auth.users that did not pin their search_path.
  When the triggers fire during an auth.users insert, the session search_path
  is the auth schema, so unqualified references to public tables like
  workspace_members and platform_admins failed to resolve, aborting the
  transaction that creates the new auth user.

  ## Changes
  1. Replace link_pending_invites with an explicit schema-qualified body and
     pin search_path to public, auth, pg_temp.
  2. Replace bootstrap_first_super_admin with the same hardening.

  No data is modified. Triggers remain attached via the existing definitions.
*/

CREATE OR REPLACE FUNCTION public.link_pending_invites()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
  UPDATE public.workspace_members
     SET user_id = NEW.id
   WHERE user_id IS NULL
     AND NEW.email IS NOT NULL
     AND lower(email) = lower(NEW.email);
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- never block auth user creation on bookkeeping errors
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.bootstrap_first_super_admin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
  IF NEW.email IS NOT NULL AND lower(NEW.email) = 'tech@sycamore.ng' THEN
    INSERT INTO public.platform_admins (user_id, role)
    VALUES (NEW.id, 'super_admin')
    ON CONFLICT (user_id) DO NOTHING;
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$;
