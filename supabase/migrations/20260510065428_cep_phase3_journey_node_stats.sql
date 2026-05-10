/*
  # Phase 3 — Journey node analytics

  1. New Table: `journey_node_stats`
     - Rolling per-node counters (entered, completed, exited) keyed by
       (journey_id, node_id). Incremented by the journey runner and displayed
       as an overlay on each canvas node.
  2. New Table: `journey_variant_stats`
     - Per-branch counts for `ab_split` nodes, split by variant key ('a','b').
  3. Security
     - RLS: only workspace members can read. Writes go through service role
       (edge functions / journey runner), so no insert policy exposed.
*/

CREATE TABLE IF NOT EXISTS journey_node_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  journey_id uuid NOT NULL REFERENCES journeys(id) ON DELETE CASCADE,
  node_id text NOT NULL,
  node_kind text NOT NULL DEFAULT '',
  entered_count integer NOT NULL DEFAULT 0,
  completed_count integer NOT NULL DEFAULT 0,
  exited_count integer NOT NULL DEFAULT 0,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (journey_id, node_id)
);
CREATE INDEX IF NOT EXISTS idx_jns_journey ON journey_node_stats(journey_id);
ALTER TABLE journey_node_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members read node stats" ON journey_node_stats;
CREATE POLICY "Members read node stats" ON journey_node_stats FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = journey_node_stats.workspace_id AND wm.user_id = auth.uid()));

CREATE TABLE IF NOT EXISTS journey_variant_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  journey_id uuid NOT NULL REFERENCES journeys(id) ON DELETE CASCADE,
  node_id text NOT NULL,
  variant text NOT NULL,
  entered_count integer NOT NULL DEFAULT 0,
  converted_count integer NOT NULL DEFAULT 0,
  UNIQUE (journey_id, node_id, variant)
);
ALTER TABLE journey_variant_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members read variant stats" ON journey_variant_stats;
CREATE POLICY "Members read variant stats" ON journey_variant_stats FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = journey_variant_stats.workspace_id AND wm.user_id = auth.uid()));
