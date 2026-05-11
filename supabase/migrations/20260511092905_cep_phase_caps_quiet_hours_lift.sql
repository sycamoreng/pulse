/*
  # Phase 1 — Frequency caps, quiet hours & control-group lift

  Adds the plumbing for three PRD items that were partially implemented:

  1. Frequency capping for campaign sends
     - Queue-worker will consult `sending_policies.max_messages_per_contact_24h/7d`
       before dispatching. No schema change; we rely on existing rows in
       `transactional_sends` and `campaign_messages` as the audit trail.

  2. Quiet hours enforcement on bulk sends
     - Queue-worker will re-queue any delivery_queue row whose recipient is
       inside `sending_policies.quiet_hours_*` (requires recipient timezone,
       falls back to workspace timezone).

  3. Control / holdout groups with statistical lift
     - New column `campaign_messages.is_control` marks the held-out audience
       (they do NOT receive the message but DO count toward the lift test).
     - New column `campaign_messages.goal_converted` flips to true when the
       recipient fires the campaign's goal event within its window.
     - New RPC `compute_campaign_lift(campaign_id)` counts treatment vs
       control conversions inside `goal_window_hours` and writes the totals
       plus `lift_computed_at` back to the `campaigns` row.

  ## Security
  All changes respect existing `campaign_messages` and `campaigns` RLS.
  The RPC runs as `security invoker` — callers must already have UPDATE on
  the campaign to recompute.
*/

-- 1. New columns on campaign_messages
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='campaign_messages' AND column_name='is_control') THEN
    ALTER TABLE campaign_messages ADD COLUMN is_control boolean NOT NULL DEFAULT false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='campaign_messages' AND column_name='goal_converted') THEN
    ALTER TABLE campaign_messages ADD COLUMN goal_converted boolean NOT NULL DEFAULT false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='campaign_messages' AND column_name='goal_converted_at') THEN
    ALTER TABLE campaign_messages ADD COLUMN goal_converted_at timestamptz;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_campaign_messages_campaign_control
  ON campaign_messages(campaign_id, is_control);

-- 2. Lift computation RPC
CREATE OR REPLACE FUNCTION compute_campaign_lift(p_campaign_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_campaign campaigns%ROWTYPE;
  v_window_hours integer;
  v_goal_event text;
  v_control_size integer := 0;
  v_treatment_size integer := 0;
  v_control_conv integer := 0;
  v_treatment_conv integer := 0;
  v_cutoff timestamptz;
BEGIN
  SELECT * INTO v_campaign FROM campaigns WHERE id = p_campaign_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign % not found', p_campaign_id;
  END IF;

  v_window_hours := COALESCE(v_campaign.goal_window_hours, 168);
  v_goal_event := COALESCE(v_campaign.goal_event_name, '');

  IF v_goal_event = '' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'No goal event set');
  END IF;

  -- Mark goal conversions: any recipient (control or treatment) whose workspace
  -- fired the goal event between the send and window expiry counts.
  UPDATE campaign_messages cm
  SET goal_converted = true,
      goal_converted_at = sub.first_hit
  FROM (
    SELECT cm2.id AS message_id,
           MIN(e.created_at) AS first_hit
    FROM campaign_messages cm2
    JOIN events e ON e.customer_id = cm2.customer_id
                  AND e.workspace_id = cm2.workspace_id
                  AND e.name = v_goal_event
                  AND e.created_at >= COALESCE(cm2.sent_at, cm2.scheduled_at, cm2.created_at::timestamptz, now() - interval '30 days')
                  AND e.created_at <= COALESCE(cm2.sent_at, cm2.scheduled_at, now()) + make_interval(hours => v_window_hours)
    WHERE cm2.campaign_id = p_campaign_id
      AND cm2.goal_converted = false
    GROUP BY cm2.id
  ) sub
  WHERE cm.id = sub.message_id;

  SELECT
    count(*) FILTER (WHERE is_control),
    count(*) FILTER (WHERE NOT is_control),
    count(*) FILTER (WHERE is_control AND goal_converted),
    count(*) FILTER (WHERE NOT is_control AND goal_converted)
  INTO v_control_size, v_treatment_size, v_control_conv, v_treatment_conv
  FROM campaign_messages
  WHERE campaign_id = p_campaign_id;

  UPDATE campaigns
  SET lift_control_size = v_control_size,
      lift_treatment_size = v_treatment_size,
      lift_control_conversions = v_control_conv,
      lift_treatment_conversions = v_treatment_conv,
      lift_computed_at = now()
  WHERE id = p_campaign_id;

  RETURN jsonb_build_object(
    'ok', true,
    'control_size', v_control_size,
    'treatment_size', v_treatment_size,
    'control_conversions', v_control_conv,
    'treatment_conversions', v_treatment_conv
  );
END;
$$;

GRANT EXECUTE ON FUNCTION compute_campaign_lift(uuid) TO authenticated;