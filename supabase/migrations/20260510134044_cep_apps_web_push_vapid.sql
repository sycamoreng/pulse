/*
  # Apps · web push (VAPID) fields

  1. Modified tables
    - `apps`
      - add `vapid_public_key` (text) — Web Push public key, safe to ship to browser
      - add `vapid_private_key` (text) — Web Push signing key, server-only
      - add `vapid_subject` (text) — contact URL/mailto included in JWT (`sub` claim)

  2. Security
    - Apps table already has RLS; no policy changes are needed. The new
      columns inherit existing policies (workspace members read, admins write).
    - Private key will only be read server-side by edge functions using the
      service role key.

  3. Important notes
    1. Web apps should use the VAPID triple for Web Push (browsers, PWAs). Native
       apps continue to use FCM (Android) or APNs (iOS). Wrapping web apps in
       FCM is unnecessary and was removed from the UI.
*/

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='apps' AND column_name='vapid_public_key') THEN
    ALTER TABLE apps ADD COLUMN vapid_public_key text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='apps' AND column_name='vapid_private_key') THEN
    ALTER TABLE apps ADD COLUMN vapid_private_key text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='apps' AND column_name='vapid_subject') THEN
    ALTER TABLE apps ADD COLUMN vapid_subject text;
  END IF;
END $$;
