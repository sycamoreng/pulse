/*
  # Workspace commerce opt-in flag

  1. Changed Tables
    - `workspaces` add `commerce_enabled` boolean (default false)

  2. Notes
    - Commerce features (product catalog, order ingest, revenue attribution)
      are now opt-in per workspace. Fintech / non-retail workspaces can keep
      them hidden by leaving the flag disabled.
*/

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='workspaces' AND column_name='commerce_enabled') THEN
    ALTER TABLE workspaces ADD COLUMN commerce_enabled boolean DEFAULT false;
  END IF;
END $$;
