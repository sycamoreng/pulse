/*
  # Add unique (workspace_id, name) constraints to seed-target tables

  1. Problem
    - The demo seeder upserts with onConflict 'workspace_id,name' for templates, funnels, cohorts and rfm_configs but these tables had no matching unique constraint, so upserts failed and seeding silently stopped. Duplicates from earlier runs are also present in templates.

  2. Changes
    - Dedupe existing rows in templates, funnels, cohorts, rfm_configs keeping the earliest row by (workspace_id, name).
    - Add composite UNIQUE (workspace_id, name) to each of those tables.
    - Idempotent: wrapped in DO block + IF NOT EXISTS guards.

  3. Security
    - No RLS changes. Constraints only.
*/

WITH ranked AS (
  SELECT id, row_number() OVER (PARTITION BY workspace_id, name ORDER BY created_at NULLS LAST, id) rn
  FROM templates
)
DELETE FROM templates WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

WITH ranked AS (
  SELECT id, row_number() OVER (PARTITION BY workspace_id, name ORDER BY created_at NULLS LAST, id) rn
  FROM funnels
)
DELETE FROM funnels WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

WITH ranked AS (
  SELECT id, row_number() OVER (PARTITION BY workspace_id, name ORDER BY created_at NULLS LAST, id) rn
  FROM cohorts
)
DELETE FROM cohorts WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

WITH ranked AS (
  SELECT id, row_number() OVER (PARTITION BY workspace_id, name ORDER BY created_at NULLS LAST, id) rn
  FROM rfm_configs
)
DELETE FROM rfm_configs WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'templates_ws_name_key') THEN
    ALTER TABLE templates ADD CONSTRAINT templates_ws_name_key UNIQUE (workspace_id, name);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'funnels_ws_name_key') THEN
    ALTER TABLE funnels ADD CONSTRAINT funnels_ws_name_key UNIQUE (workspace_id, name);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'cohorts_ws_name_key') THEN
    ALTER TABLE cohorts ADD CONSTRAINT cohorts_ws_name_key UNIQUE (workspace_id, name);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'rfm_configs_ws_name_key') THEN
    ALTER TABLE rfm_configs ADD CONSTRAINT rfm_configs_ws_name_key UNIQUE (workspace_id, name);
  END IF;
END $$;
