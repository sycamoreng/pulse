/*
  # Publishable API keys for client-side SDKs

  1. Changed Tables
    - `api_keys` gains:
      - `key_type` text ('secret' | 'publishable'), default 'secret'
      - `allowed_origins` text[] — CSV host allowlist for browser use
      - `allowed_bundle_ids` text[] — iOS / Android / RN bundle allowlist

  2. Notes
    - Secret keys (prefix `pk_`) stay unchanged and are server-only.
    - Publishable keys (prefix `ppk_`) are safe to embed in browser / mobile
      bundles. They are restricted by origin or bundle ID and should only carry
      the `track:write` scope.
    - Existing rows default to `key_type='secret'`, keeping behavior identical.
*/

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='api_keys' AND column_name='key_type') THEN
    ALTER TABLE api_keys ADD COLUMN key_type text DEFAULT 'secret';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='api_keys' AND column_name='allowed_origins') THEN
    ALTER TABLE api_keys ADD COLUMN allowed_origins text[] DEFAULT '{}'::text[];
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='api_keys' AND column_name='allowed_bundle_ids') THEN
    ALTER TABLE api_keys ADD COLUMN allowed_bundle_ids text[] DEFAULT '{}'::text[];
  END IF;
END $$;
