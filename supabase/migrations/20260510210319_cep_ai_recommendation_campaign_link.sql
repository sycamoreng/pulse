/*
  # Link AI recommendations to campaigns

  1. Changes
    - Add `campaign_id` (uuid, nullable) to `ai_recommendations` referencing `campaigns(id)` with ON DELETE SET NULL
    - Add index on `campaign_id` for quick lookups
    - Extends the allowed `status` values informally: existing values ('pending','delivered','dismissed','converted') plus a new 'queued' status used when a reco has been turned into a draft campaign.
  2. Security
    - No RLS changes. Existing policies on `ai_recommendations` continue to gate reads/writes.
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'ai_recommendations' AND column_name = 'campaign_id'
  ) THEN
    ALTER TABLE ai_recommendations
      ADD COLUMN campaign_id uuid REFERENCES campaigns(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ai_recommendations_campaign_id
  ON ai_recommendations(campaign_id);
