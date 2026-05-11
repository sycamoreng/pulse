/*
  # Phase 2 — Journey runner support

  Adds the missing plumbing for the new journey nodes (update-attribute,
  wait-until-event, condition-branch) and the runner that advances
  enrollments through them.

  1. `journey_enrollments` — two new columns
     - `last_error text` — so the runner can surface a broken node without
       killing the enrollment
     - `steps_done integer` — counter used for UI and debugging

  2. `journey_edges` nodes carry an optional `branch` label ("yes"/"no"/
     "default" etc.). No schema change — edges live inside `journeys.edges`
     JSONB and already accept arbitrary keys.

  3. No RLS changes: existing policies already scope to workspace_id.
*/

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='journey_enrollments' AND column_name='last_error') THEN
    ALTER TABLE journey_enrollments ADD COLUMN last_error text NOT NULL DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='journey_enrollments' AND column_name='steps_done') THEN
    ALTER TABLE journey_enrollments ADD COLUMN steps_done integer NOT NULL DEFAULT 0;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_journey_enrollments_waiting
  ON journey_enrollments(status, wait_until)
  WHERE status IN ('active', 'waiting');
