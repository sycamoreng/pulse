/*
  # API key usage tracking + publishable key defaults

  1. Changes
    - `api_keys` gains `last_used_at` (timestamptz, null by default) so
      the dashboard can show live "SDK connected" status.
    - A BEFORE INSERT trigger normalises key prefixes when the row inserts
      with a fresh random `key`: publishable keys get the `ppk_` prefix,
      secret keys get `pk_`. Existing rows are left untouched so nothing
      in the wild breaks.
    - New `touch_api_key(p_key_id uuid)` RPC, security-definer, so the
      edge function can stamp `last_used_at` cheaply from the service-role
      context without widening RLS.

  2. Security
    - `last_used_at` inherits the table's existing RLS.
    - `touch_api_key` is SECURITY DEFINER with `search_path = public` and
      granted to `service_role` only. No authenticated user can call it.
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'api_keys' AND column_name = 'last_used_at'
  ) THEN
    ALTER TABLE api_keys ADD COLUMN last_used_at timestamptz;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION api_keys_apply_prefix()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.key IS NULL OR NEW.key = '' THEN
    NEW.key := encode(gen_random_bytes(24), 'hex');
  END IF;
  IF NEW.key_type = 'publishable' AND NEW.key NOT LIKE 'ppk_%' THEN
    NEW.key := 'ppk_' || NEW.key;
  ELSIF COALESCE(NEW.key_type, 'secret') = 'secret' AND NEW.key NOT LIKE 'pk_%' AND NEW.key NOT LIKE 'ppk_%' THEN
    NEW.key := 'pk_' || NEW.key;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS api_keys_apply_prefix_trg ON api_keys;
CREATE TRIGGER api_keys_apply_prefix_trg
  BEFORE INSERT ON api_keys
  FOR EACH ROW EXECUTE FUNCTION api_keys_apply_prefix();

CREATE OR REPLACE FUNCTION touch_api_key(p_key_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE api_keys SET last_used_at = now() WHERE id = p_key_id;
$$;

REVOKE ALL ON FUNCTION touch_api_key(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION touch_api_key(uuid) TO service_role;
