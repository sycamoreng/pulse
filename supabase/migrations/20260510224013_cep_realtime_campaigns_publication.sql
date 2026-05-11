/*
  # Enable Realtime for campaign analytics

  1. Changes
    - Add `campaigns` and `campaign_messages` to the `supabase_realtime` publication
      so authenticated clients can subscribe to row-level changes for live
      dashboards. RLS policies continue to restrict what each session can see.

  2. Notes
    - Uses DO blocks with IF NOT EXISTS checks so re-running is safe.
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'campaigns'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.campaigns';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'campaign_messages'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.campaign_messages';
  END IF;
END $$;
