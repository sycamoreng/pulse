/*
  # Bootstrap first super admin

  Grants super_admin to tech@sycamore.ng on signup. This is a one-shot
  bootstrap so the very first Pulse team member can sign up through the
  normal flow and automatically land in the admin area without anyone
  needing direct DB access.

  1. Attempt immediate grant — if the user already exists, insert now.
  2. Install AFTER INSERT trigger on auth.users that grants super_admin
     when a row is created with this exact email. Safe to keep in place;
     adding more admins after the fact is done via /admin/admins.
*/

-- Immediate grant if the user exists now
DO $$
DECLARE uid uuid;
BEGIN
  SELECT id INTO uid FROM auth.users WHERE lower(email) = 'tech@sycamore.ng' LIMIT 1;
  IF uid IS NOT NULL THEN
    INSERT INTO platform_admins (user_id, role)
    VALUES (uid, 'super_admin')
    ON CONFLICT (user_id) DO UPDATE SET role = 'super_admin';
  END IF;
END $$;

-- Trigger function
CREATE OR REPLACE FUNCTION bootstrap_first_super_admin()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF lower(NEW.email) = 'tech@sycamore.ng' THEN
    INSERT INTO platform_admins (user_id, role)
    VALUES (NEW.id, 'super_admin')
    ON CONFLICT (user_id) DO NOTHING;
  END IF;
  RETURN NEW;
END $$;

-- Install trigger (idempotent)
DROP TRIGGER IF EXISTS bootstrap_super_admin_on_signup ON auth.users;
CREATE TRIGGER bootstrap_super_admin_on_signup
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION bootstrap_first_super_admin();
