/*
  # Journey runtime: per-enrollment current node, wait state, attribute updates

  1. Modified Tables
    - `journey_enrollments`: current_node_id text, wait_until timestamptz,
      waiting_for_event text, last_advanced_at timestamptz, branch_taken text

  2. Security
    - RLS remains unchanged; new columns follow existing row policies.
*/

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='journey_enrollments' AND column_name='current_node_id') THEN
    ALTER TABLE journey_enrollments ADD COLUMN current_node_id text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='journey_enrollments' AND column_name='wait_until') THEN
    ALTER TABLE journey_enrollments ADD COLUMN wait_until timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='journey_enrollments' AND column_name='waiting_for_event') THEN
    ALTER TABLE journey_enrollments ADD COLUMN waiting_for_event text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='journey_enrollments' AND column_name='last_advanced_at') THEN
    ALTER TABLE journey_enrollments ADD COLUMN last_advanced_at timestamptz DEFAULT now();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='journey_enrollments' AND column_name='branch_taken') THEN
    ALTER TABLE journey_enrollments ADD COLUMN branch_taken text DEFAULT '';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_journey_enrollments_runnable
  ON journey_enrollments(status, wait_until)
  WHERE status = 'active';
