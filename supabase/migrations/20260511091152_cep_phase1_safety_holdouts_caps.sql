/*
  # Campaign safety: holdouts, lift measurement, cross-channel frequency caps

  1. New Tables
    - `campaign_holdouts`: Persists customers held out of a campaign send
      so we can measure lift against treatment group later.
      Columns: workspace_id, campaign_id, customer_id, created_at

  2. Modified Tables
    - `campaigns`: goal_event_name, goal_window_hours, lift_control_size,
      lift_treatment_size, lift_control_conversions, lift_treatment_conversions,
      lift_computed_at

  3. New RPCs
    - `compute_campaign_lift(p_campaign_id uuid)`: counts goal_event
      occurrences for both treatment (campaign_messages recipients) and
      control (campaign_holdouts) within the configured window after the
      campaign send and writes totals back onto campaigns.
    - `customer_send_counts(p_workspace_id uuid, p_customer_ids uuid[], p_hours int)`:
      returns per-customer cross-channel send counts over a window for
      enqueue-time frequency capping.

  4. Security
    - RLS enabled on campaign_holdouts with workspace-membership policies.
*/

CREATE TABLE IF NOT EXISTS campaign_holdouts (
  workspace_id uuid NOT NULL,
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (campaign_id, customer_id)
);

CREATE INDEX IF NOT EXISTS idx_campaign_holdouts_workspace ON campaign_holdouts(workspace_id);
CREATE INDEX IF NOT EXISTS idx_campaign_holdouts_customer ON campaign_holdouts(customer_id);

ALTER TABLE campaign_holdouts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Members can view campaign holdouts' AND tablename = 'campaign_holdouts') THEN
    CREATE POLICY "Members can view campaign holdouts" ON campaign_holdouts FOR SELECT TO authenticated USING (
      EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = campaign_holdouts.workspace_id AND wm.user_id = auth.uid())
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Members can insert campaign holdouts' AND tablename = 'campaign_holdouts') THEN
    CREATE POLICY "Members can insert campaign holdouts" ON campaign_holdouts FOR INSERT TO authenticated WITH CHECK (
      EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = campaign_holdouts.workspace_id AND wm.user_id = auth.uid())
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Members can delete campaign holdouts' AND tablename = 'campaign_holdouts') THEN
    CREATE POLICY "Members can delete campaign holdouts" ON campaign_holdouts FOR DELETE TO authenticated USING (
      EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = campaign_holdouts.workspace_id AND wm.user_id = auth.uid())
    );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='campaigns' AND column_name='goal_event_name') THEN
    ALTER TABLE campaigns ADD COLUMN goal_event_name text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='campaigns' AND column_name='goal_window_hours') THEN
    ALTER TABLE campaigns ADD COLUMN goal_window_hours integer DEFAULT 72;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='campaigns' AND column_name='lift_control_size') THEN
    ALTER TABLE campaigns ADD COLUMN lift_control_size integer DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='campaigns' AND column_name='lift_treatment_size') THEN
    ALTER TABLE campaigns ADD COLUMN lift_treatment_size integer DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='campaigns' AND column_name='lift_control_conversions') THEN
    ALTER TABLE campaigns ADD COLUMN lift_control_conversions integer DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='campaigns' AND column_name='lift_treatment_conversions') THEN
    ALTER TABLE campaigns ADD COLUMN lift_treatment_conversions integer DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='campaigns' AND column_name='lift_computed_at') THEN
    ALTER TABLE campaigns ADD COLUMN lift_computed_at timestamptz;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION compute_campaign_lift(p_campaign_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ws uuid;
  v_goal text;
  v_window int;
  v_sent_at timestamptz;
  v_treat_size int;
  v_ctrl_size int;
  v_treat_conv int;
  v_ctrl_conv int;
BEGIN
  SELECT workspace_id, coalesce(goal_event_name,''), coalesce(goal_window_hours,72)
  INTO v_ws, v_goal, v_window
  FROM campaigns WHERE id = p_campaign_id;

  IF v_ws IS NULL THEN
    RETURN jsonb_build_object('error','campaign_not_found');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM workspace_members WHERE workspace_id = v_ws AND user_id = auth.uid()) THEN
    RETURN jsonb_build_object('error','forbidden');
  END IF;

  SELECT min(sent_at) INTO v_sent_at FROM campaign_messages WHERE campaign_id = p_campaign_id AND sent_at IS NOT NULL;
  IF v_sent_at IS NULL THEN v_sent_at := now() - interval '1 hour'; END IF;

  SELECT count(distinct customer_id) INTO v_treat_size FROM campaign_messages WHERE campaign_id = p_campaign_id AND sent_at IS NOT NULL;
  SELECT count(*) INTO v_ctrl_size FROM campaign_holdouts WHERE campaign_id = p_campaign_id;

  IF v_goal = '' THEN
    UPDATE campaigns SET lift_control_size = coalesce(v_ctrl_size,0), lift_treatment_size = coalesce(v_treat_size,0),
      lift_control_conversions = 0, lift_treatment_conversions = 0, lift_computed_at = now()
    WHERE id = p_campaign_id;
    RETURN jsonb_build_object('treatment_size', v_treat_size, 'control_size', v_ctrl_size, 'goal', '');
  END IF;

  SELECT count(distinct e.customer_id) INTO v_treat_conv
  FROM events e
  WHERE e.workspace_id = v_ws
    AND e.name = v_goal
    AND e.created_at >= v_sent_at
    AND e.created_at <= v_sent_at + make_interval(hours => v_window)
    AND e.customer_id IN (SELECT customer_id FROM campaign_messages WHERE campaign_id = p_campaign_id AND sent_at IS NOT NULL);

  SELECT count(distinct e.customer_id) INTO v_ctrl_conv
  FROM events e
  WHERE e.workspace_id = v_ws
    AND e.name = v_goal
    AND e.created_at >= v_sent_at
    AND e.created_at <= v_sent_at + make_interval(hours => v_window)
    AND e.customer_id IN (SELECT customer_id FROM campaign_holdouts WHERE campaign_id = p_campaign_id);

  UPDATE campaigns
  SET lift_control_size = coalesce(v_ctrl_size,0),
      lift_treatment_size = coalesce(v_treat_size,0),
      lift_control_conversions = coalesce(v_ctrl_conv,0),
      lift_treatment_conversions = coalesce(v_treat_conv,0),
      lift_computed_at = now()
  WHERE id = p_campaign_id;

  RETURN jsonb_build_object(
    'goal', v_goal,
    'window_hours', v_window,
    'treatment_size', v_treat_size,
    'control_size', v_ctrl_size,
    'treatment_conversions', v_treat_conv,
    'control_conversions', v_ctrl_conv
  );
END; $$;

GRANT EXECUTE ON FUNCTION compute_campaign_lift(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION customer_send_counts(p_workspace_id uuid, p_customer_ids uuid[], p_hours int)
RETURNS TABLE(customer_id uuid, sends bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT cm.customer_id, count(*)::bigint AS sends
  FROM campaign_messages cm
  WHERE cm.workspace_id = p_workspace_id
    AND cm.customer_id = ANY(p_customer_ids)
    AND cm.sent_at >= now() - make_interval(hours => p_hours)
  GROUP BY cm.customer_id
$$;

GRANT EXECUTE ON FUNCTION customer_send_counts(uuid, uuid[], int) TO authenticated;
