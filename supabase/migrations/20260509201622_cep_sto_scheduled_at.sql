/*
  # Send-time optimization scheduling column

  1. Schema changes
    - campaign_messages: add `scheduled_at` (timestamptz) — when the message is
      planned to deliver for send-time optimized (STO) or timezone-respecting
      campaigns.

  2. Notes
    - Immediate sends will leave this NULL; sent_at still marks the actual send.
    - STO picks this per customer based on their historical active hours.
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'campaign_messages' AND column_name = 'scheduled_at'
  ) THEN
    ALTER TABLE campaign_messages ADD COLUMN scheduled_at timestamptz;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_campaign_messages_scheduled_at
  ON campaign_messages (campaign_id, scheduled_at);
