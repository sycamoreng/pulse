/*
  # Surveys: buildable form schema + counter fix
  Adds form_schema to surveys, answers to responses, new public RPC for
  form-based submissions, and removes the duplicate counter trigger.
*/

DROP TRIGGER IF EXISTS trg_survey_responses_bump ON survey_responses;
DROP FUNCTION IF EXISTS bump_survey_response_count();
DROP FUNCTION IF EXISTS public_get_survey(uuid);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='surveys' AND column_name='form_schema') THEN
    ALTER TABLE surveys ADD COLUMN form_schema jsonb NOT NULL DEFAULT '[]'::jsonb;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='survey_responses' AND column_name='answers') THEN
    ALTER TABLE survey_responses ADD COLUMN answers jsonb NOT NULL DEFAULT '{}'::jsonb;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public_get_survey(p_id uuid)
RETURNS TABLE(
  id uuid,
  workspace_id uuid,
  name text,
  description text,
  survey_type text,
  question text,
  follow_up text,
  display_mode text,
  status text,
  form_schema jsonb,
  thank_you text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, workspace_id, name, description, survey_type, question, follow_up,
         display_mode, status, form_schema, thank_you
  FROM surveys
  WHERE id = p_id AND status = 'active'
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION submit_survey_form_response(
  p_survey_id uuid,
  p_answers jsonb,
  p_customer_id uuid DEFAULT NULL,
  p_customer_email text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_survey surveys%ROWTYPE;
  v_response_id uuid;
  v_score int := NULL;
  v_comment text := NULL;
  v_answer text := NULL;
  v_customer_id uuid := p_customer_id;
  v_field jsonb;
BEGIN
  SELECT * INTO v_survey FROM surveys WHERE id = p_survey_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'survey_not_found');
  END IF;
  IF v_survey.status <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'survey_inactive');
  END IF;

  IF v_customer_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM customers WHERE id = v_customer_id AND workspace_id = v_survey.workspace_id
  ) THEN
    v_customer_id := NULL;
  END IF;
  IF v_customer_id IS NULL AND p_customer_email IS NOT NULL AND length(p_customer_email) > 0 THEN
    SELECT id INTO v_customer_id
    FROM customers
    WHERE workspace_id = v_survey.workspace_id AND lower(email) = lower(p_customer_email)
    LIMIT 1;
  END IF;

  IF jsonb_typeof(v_survey.form_schema) = 'array' AND jsonb_array_length(v_survey.form_schema) > 0 THEN
    FOR v_field IN SELECT * FROM jsonb_array_elements(v_survey.form_schema)
    LOOP
      IF v_score IS NULL AND (v_field->>'type') IN ('scale','rating','number')
         AND (p_answers ? (v_field->>'id'))
         AND jsonb_typeof(p_answers->(v_field->>'id')) = 'number' THEN
        v_score := (p_answers->>(v_field->>'id'))::int;
      END IF;
      IF v_comment IS NULL AND (v_field->>'type') = 'long_text'
         AND (p_answers ? (v_field->>'id')) THEN
        v_comment := p_answers->>(v_field->>'id');
      END IF;
      IF v_answer IS NULL AND (v_field->>'type') = 'short_text'
         AND (p_answers ? (v_field->>'id')) THEN
        v_answer := p_answers->>(v_field->>'id');
      END IF;
    END LOOP;
  END IF;

  INSERT INTO survey_responses (workspace_id, survey_id, customer_id, score, answer, comment, answers)
  VALUES (v_survey.workspace_id, v_survey.id, v_customer_id, v_score, v_answer, v_comment, COALESCE(p_answers, '{}'::jsonb))
  RETURNING id INTO v_response_id;

  UPDATE surveys
    SET responses_count = COALESCE(responses_count, 0) + 1,
        impressions = GREATEST(COALESCE(impressions, 0), COALESCE(responses_count, 0) + 1)
    WHERE id = v_survey.id;

  RETURN jsonb_build_object('ok', true, 'response_id', v_response_id, 'thank_you', COALESCE(v_survey.thank_you, 'Thanks for your feedback!'));
END;
$$;

GRANT EXECUTE ON FUNCTION public_get_survey(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION submit_survey_form_response(uuid, jsonb, uuid, text) TO anon, authenticated;
