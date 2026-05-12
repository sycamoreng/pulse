/*
  # Add APNs environment toggle to apps

  1. Changes
    - `apps` gains `apns_environment` text column. Values: 'production'
      (default) or 'sandbox'. Used by the push-dispatch edge function to
      choose between api.push.apple.com and api.sandbox.push.apple.com.
      Sandbox is required when sending to tokens from a debug / TestFlight
      build; production for App Store builds.

  2. Security
    - Inherits existing `apps` RLS (workspace owner/member scoped). No new
      policies needed.
*/
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'apps' AND column_name = 'apns_environment'
  ) THEN
    ALTER TABLE apps ADD COLUMN apns_environment text DEFAULT 'production';
  END IF;
END $$;
