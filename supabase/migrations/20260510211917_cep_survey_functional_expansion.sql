/*
  # Survey functional expansion

  1. New
    - `public_get_survey(p_id uuid)` RPC returning active survey fields for the public landing page. SECURITY DEFINER, returns nothing for non-active surveys.
    - `submit_survey_response(p_survey_id uuid, p_score int, p_answer text, p_comment text, p_customer_id uuid)` RPC. SECURITY DEFINER. Inserts into `survey_responses`, validates score ranges per survey_type, bumps `surveys.responses_count` and `surveys.impressions` if not already counted in session, and returns `{ ok, response_id }`.
    - `increment_survey_impression(p_id uuid)` RPC that ups `surveys.impressions`.
  2. Changes
    - None to columns; only functions added.
  3. Security
    - All RPCs are SECURITY DEFINER and only touch rows for the survey's own workspace. Anonymous callers (role `anon`) are granted EXECUTE so the public survey page can call them without exposing direct table writes.
*/

CREATE OR REPLACE FUNCTION public_get_survey(p_id uuid)
RETURNS TABLE (
  id uuid,
  workspace_id uuid,
  name text,
  description text,
  survey_type text,
  question text,
  follow_up text,
  display_mode text,
  status text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, workspace_id, name, description, survey_type, question, follow_up, display_mode, status
  FROM surveys
  WHERE id = p_id
    AND status = 'active'
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION increment_survey_impression(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status text;
BEGIN
  SELECT status INTO v_status FROM surveys WHERE id = p_id;
  IF v_status IS NULL OR v_status <> 'active' THEN
    RETURN;
  END IF;
  UPDATE surveys SET impressions = COALESCE(impressions, 0) + 1 WHERE id = p_id;
END;
$$;

CREATE OR REPLACE FUNCTION submit_survey_response(
  p_survey_id uuid,
  p_score int DEFAULT NULL,
  p_answer text DEFAULT NULL,
  p_comment text DEFAULT NULL,
  p_customer_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_survey surveys%ROWTYPE;
  v_response_id uuid;
  v_min int;
  v_max int;
BEGIN
  SELECT * INTO v_survey FROM surveys WHERE id = p_survey_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'survey_not_found');
  END IF;
  IF v_survey.status <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'survey_inactive');
  END IF;

  IF v_survey.survey_type = 'nps' THEN
    v_min := 0; v_max := 10;
  ELSIF v_survey.survey_type = 'csat' THEN
    v_min := 1; v_max := 5;
  ELSIF v_survey.survey_type = 'ces' THEN
    v_min := 1; v_max := 7;
  ELSE
    v_min := NULL;
  END IF;

  IF v_min IS NOT NULL THEN
    IF p_score IS NULL OR p_score < v_min OR p_score > v_max THEN
      RETURN jsonb_build_object('ok', false, 'error', 'invalid_score');
    END IF;
  END IF;

  IF p_customer_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM customers WHERE id = p_customer_id AND workspace_id = v_survey.workspace_id) THEN
      p_customer_id := NULL;
    END IF;
  END IF;

  INSERT INTO survey_responses (workspace_id, survey_id, customer_id, score, answer, comment)
  VALUES (v_survey.workspace_id, v_survey.id, p_customer_id, p_score, p_answer, p_comment)
  RETURNING id INTO v_response_id;

  UPDATE surveys
  SET responses_count = COALESCE(responses_count, 0) + 1,
      impressions = GREATEST(COALESCE(impressions, 0), COALESCE(responses_count, 0) + 1)
  WHERE id = v_survey.id;

  RETURN jsonb_build_object('ok', true, 'response_id', v_response_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public_get_survey(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION increment_survey_impression(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION submit_survey_response(uuid, int, text, text, uuid) TO anon, authenticated;
