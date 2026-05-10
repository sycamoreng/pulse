/*
  # Email domains · real DKIM + sender email verification

  1. Modified Tables
    - `email_domains`
      - add `dkim_private_key` text — server-only, used to sign outgoing mail
      - (existing `dkim_public_key` will now hold the real base64 modulus)
    - `email_senders`
      - add `verification_token` text — unique token mailed to the from_email
      - add `verification_sent_at` timestamptz
      - add `verified_at` timestamptz

  2. Security
    - RLS is already enabled on both tables. `dkim_private_key` and
      `verification_token` will only be read through the service-role client
      in edge functions; no frontend code selects them.
    - Existing workspace-member policies continue to apply.

  3. Important notes
    1. Existing rows keep their current (fake) DKIM key until the domain is
       rotated via the new "Regenerate DKIM keypair" action.
    2. Sender verification is optional for platform-SES sends but required
       before a sender can be used with a customer-owned provider.
*/

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='email_domains' AND column_name='dkim_private_key') THEN
    ALTER TABLE email_domains ADD COLUMN dkim_private_key text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='email_senders' AND column_name='verification_token') THEN
    ALTER TABLE email_senders ADD COLUMN verification_token text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='email_senders' AND column_name='verification_sent_at') THEN
    ALTER TABLE email_senders ADD COLUMN verification_sent_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='email_senders' AND column_name='verified_at') THEN
    ALTER TABLE email_senders ADD COLUMN verified_at timestamptz;
  END IF;
END $$;
