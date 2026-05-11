/*
  # Private secrets schema for encrypted workspace credentials

  1. New schema
    - `pulse_secrets` — a schema that is NOT exposed to PostgREST/clients.
      Only the service role can access it. Used to store AES-GCM encrypted
      third-party credentials (ad platform access tokens, etc.).

  2. New tables
    - `pulse_secrets.ad_destination_credentials`
      - `destination_id` (uuid, primary key) — FK to public.ad_audience_destinations
      - `payload` (text) — base64(IV || ciphertext); encryption is performed
        in the edge function with a key derived from the service role key.
      - `updated_at` (timestamptz)

  3. Security
    - Revoke all privileges from `anon` and `authenticated` on the schema.
    - Only `service_role` can read/write via edge functions.
    - No RLS policies are exposed to the client at all.

  4. Notes
    - Clients POST plaintext credentials to the `audience-connect` edge function.
    - The edge function encrypts with AES-GCM (key derived via HKDF from
      SUPABASE_SERVICE_ROLE_KEY) and upserts into this table.
    - The `audience-sync` edge function decrypts at send time.
    - The previous `credentials_secret_name` column on ad_audience_destinations
      is kept for backward compatibility but is no longer written from the UI.
*/

CREATE SCHEMA IF NOT EXISTS pulse_secrets;

REVOKE ALL ON SCHEMA pulse_secrets FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA pulse_secrets TO service_role;

CREATE TABLE IF NOT EXISTS pulse_secrets.ad_destination_credentials (
  destination_id uuid PRIMARY KEY REFERENCES public.ad_audience_destinations(id) ON DELETE CASCADE,
  payload text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON pulse_secrets.ad_destination_credentials FROM PUBLIC, anon, authenticated;
GRANT ALL ON pulse_secrets.ad_destination_credentials TO service_role;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ad_audience_destinations' AND column_name = 'has_credentials'
  ) THEN
    ALTER TABLE public.ad_audience_destinations ADD COLUMN has_credentials boolean NOT NULL DEFAULT false;
  END IF;
END $$;
