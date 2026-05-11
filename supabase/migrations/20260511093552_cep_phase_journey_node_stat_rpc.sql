/*
  # Phase 2 — Journey node-stat increment helper

  Single RPC used by the journey-runner edge function to bump the
  `entered_count` on `journey_node_stats` for the node a customer just
  processed. Runs as SECURITY DEFINER so the service role can call it
  without needing direct write grants.
*/

CREATE OR REPLACE FUNCTION increment_journey_node_stat(p_journey uuid, p_node text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_workspace uuid;
BEGIN
  SELECT workspace_id INTO v_workspace FROM journeys WHERE id = p_journey;
  IF v_workspace IS NULL THEN RETURN; END IF;

  INSERT INTO journey_node_stats (workspace_id, journey_id, node_id, entered_count, completed_count)
  VALUES (v_workspace, p_journey, p_node, 1, 0)
  ON CONFLICT (journey_id, node_id)
  DO UPDATE SET entered_count = journey_node_stats.entered_count + 1;
END;
$$;

GRANT EXECUTE ON FUNCTION increment_journey_node_stat(uuid, text) TO service_role;
