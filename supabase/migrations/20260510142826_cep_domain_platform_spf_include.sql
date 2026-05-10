/*
  # Email domains · store platform SPF include per row

  1. Modified Tables
    - `email_domains`
      - add `spf_include` text — the platform include customers must add
        to their SPF record (e.g. `mail.pulseengage.io`). Stamped at
        create/rotate time so the UI shows the real include even if the
        env var changes later.

  2. Security
    - RLS unchanged. Column is public-readable by workspace members
      since they need it to publish DNS.
*/

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='email_domains' AND column_name='spf_include') THEN
    ALTER TABLE email_domains ADD COLUMN spf_include text DEFAULT '';
  END IF;
END $$;
