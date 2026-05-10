/*
  # Admin user lookup helpers

  RPCs that let platform admins resolve user IDs/emails from auth.users
  without exposing the whole table. Both check is_platform_admin() and
  return nothing otherwise.

  1. get_user_id_by_email(email_in text) returns uuid
  2. get_user_emails_by_ids(user_ids uuid[]) returns table(id uuid, email text)
*/

CREATE OR REPLACE FUNCTION get_user_id_by_email(email_in text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE uid uuid;
BEGIN
  IF NOT is_platform_admin() THEN RETURN NULL; END IF;
  SELECT id INTO uid FROM auth.users WHERE lower(email) = lower(email_in) LIMIT 1;
  RETURN uid;
END $$;

CREATE OR REPLACE FUNCTION get_user_emails_by_ids(user_ids uuid[])
RETURNS TABLE(id uuid, email text) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT is_platform_admin() THEN RETURN; END IF;
  RETURN QUERY SELECT u.id, u.email::text FROM auth.users u WHERE u.id = ANY(user_ids);
END $$;
