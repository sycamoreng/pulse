/*
  # Journey canvas data

  1. Modifications
    - journeys.nodes: jsonb array of {id, type, kind, x, y, data}
    - journeys.edges: jsonb array of {from, to}
    - journeys.goal: jsonb (optional journey goal)
  2. Keep existing steps column for backward compatibility.
*/

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'journeys' AND column_name = 'nodes') THEN
    ALTER TABLE journeys ADD COLUMN nodes jsonb DEFAULT '[]'::jsonb;
    ALTER TABLE journeys ADD COLUMN edges jsonb DEFAULT '[]'::jsonb;
    ALTER TABLE journeys ADD COLUMN goal jsonb DEFAULT '{}'::jsonb;
  END IF;
END $$;
