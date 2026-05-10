/*
  # Allow pending invites by email

  1. Modifications
    - workspace_members.user_id becomes nullable to allow pending invites
    - add unique (workspace_id, email) to prevent duplicate invites
  2. Trigger
    - on new auth.users row, auto-link any pending workspace_members rows whose email matches
  3. Security
    - existing RLS policies remain unchanged
*/

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'workspace_members' AND column_name = 'user_id' AND is_nullable = 'NO') THEN
    ALTER TABLE workspace_members ALTER COLUMN user_id DROP NOT NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'workspace_members_ws_email_key') THEN
    ALTER TABLE workspace_members ADD CONSTRAINT workspace_members_ws_email_key UNIQUE (workspace_id, email);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION link_pending_invites() RETURNS trigger AS $$
BEGIN
  UPDATE workspace_members SET user_id = NEW.id
    WHERE user_id IS NULL AND lower(email) = lower(NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS link_invites_on_signup ON auth.users;
CREATE TRIGGER link_invites_on_signup AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION link_pending_invites();
