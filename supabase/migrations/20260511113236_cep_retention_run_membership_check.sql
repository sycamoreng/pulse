/*
  # Retention run — enforce workspace admin membership

  1. Purpose
     - Harden `retention_run(p_workspace, p_entity, p_days)` so the function can only be
       invoked by users who are owner/admin of the target workspace, or by the service role
       (edge functions and cron workers).
  2. Changes
     - Replaces the function body with a membership guard that runs before any delete.
     - The service_role is permitted to bypass the membership check (used by the
       retention-runner edge function for operator-initiated cleanups).
  3. Security notes
     - SECURITY DEFINER with explicit search_path remains.
     - Authenticated users without owner/admin role in the target workspace get a clear
       "not authorised" error instead of silently deleting rows.
*/

CREATE OR REPLACE FUNCTION retention_run(p_workspace uuid, p_entity text, p_days integer)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cutoff timestamptz := now() - make_interval(days => greatest(p_days, 1));
  v_deleted integer := 0;
  v_role text := current_setting('role', true);
  v_is_service boolean := (v_role = 'service_role');
  v_uid uuid := auth.uid();
BEGIN
  IF NOT v_is_service THEN
    IF v_uid IS NULL THEN
      RAISE EXCEPTION 'not authenticated';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM workspace_members wm
      WHERE wm.workspace_id = p_workspace
        AND wm.user_id = v_uid
        AND wm.role IN ('owner','admin')
    ) THEN
      RAISE EXCEPTION 'not authorised for this workspace';
    END IF;
  END IF;

  IF p_entity = 'events' THEN
    WITH d AS (DELETE FROM events WHERE workspace_id = p_workspace AND occurred_at < v_cutoff RETURNING 1)
    SELECT count(*) INTO v_deleted FROM d;
  ELSIF p_entity = 'audit_logs' THEN
    WITH d AS (DELETE FROM audit_logs WHERE workspace_id = p_workspace AND created_at < v_cutoff RETURNING 1)
    SELECT count(*) INTO v_deleted FROM d;
  ELSIF p_entity = 'campaign_messages' THEN
    WITH d AS (DELETE FROM campaign_messages WHERE workspace_id = p_workspace AND coalesce(sent_at, created_at) < v_cutoff RETURNING 1)
    SELECT count(*) INTO v_deleted FROM d;
  ELSIF p_entity = 'customer_signals' THEN
    WITH d AS (DELETE FROM customer_signals WHERE workspace_id = p_workspace AND detected_at < v_cutoff RETURNING 1)
    SELECT count(*) INTO v_deleted FROM d;
  ELSE
    RAISE EXCEPTION 'Unsupported retention entity: %', p_entity;
  END IF;

  UPDATE retention_policies
    SET last_run_at = now(), last_deleted = v_deleted, updated_at = now()
    WHERE workspace_id = p_workspace AND entity = p_entity;

  RETURN v_deleted;
END;
$$;
