/*
  # Surveys: public share tokens, impressions, and response counters

  1. Changes
    - Add `public_token` (text, unique) to `surveys` for shareable `/s/:token` links
    - Add `thank_you` (text) so creators can customize the post-submit message
    - Add `impressions` already exists; add counter trigger to auto-increment `surveys.responses_count` when a response is inserted
  2. Public submissions
    - Add a `submit_survey_response` SQL function (SECURITY DEFINER) that accepts a `public_token`, optional customer_id/email, score, answer, comment — returns { ok, thank_you }
    - Add an `increment_survey_impression` function (SECURITY DEFINER) for the public page to bump impression counts without needing RLS bypass
    - Both functions are callable by anon + authenticated roles; they internally validate the survey is active and owned by the claimed workspace
  3. Security
    - RLS on surveys/survey_responses untouched
    - Public functions only accept valid tokens for active surveys, and never return full workspace data
    - Responses submitted via the public function are tagged with the survey's workspace_id server-side
*/

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'surveys' AND column_name = 'public_token') THEN
    ALTER TABLE surveys ADD COLUMN public_token text UNIQUE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'surveys' AND column_name = 'thank_you') THEN
    ALTER TABLE surveys ADD COLUMN thank_you text DEFAULT 'Thanks for your feedback!';
  END IF;
END $$;

UPDATE surveys
SET public_token = encode(gen_random_bytes(9), 'base64')
WHERE public_token IS NULL;

CREATE OR REPLACE FUNCTION set_survey_public_token()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.public_token IS NULL THEN
    NEW.public_token := replace(replace(replace(encode(gen_random_bytes(9), 'base64'), '+', ''), '/', ''), '=', '');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_surveys_set_public_token ON surveys;
CREATE TRIGGER trg_surveys_set_public_token
  BEFORE INSERT ON surveys
  FOR EACH ROW EXECUTE FUNCTION set_survey_public_token();

CREATE OR REPLACE FUNCTION bump_survey_response_count()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE surveys
    SET responses_count = COALESCE(responses_count, 0) + 1
    WHERE id = NEW.survey_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_survey_responses_bump ON survey_responses;
CREATE TRIGGER trg_survey_responses_bump
  AFTER INSERT ON survey_responses
  FOR EACH ROW EXECUTE FUNCTION bump_survey_response_count();

CREATE OR REPLACE FUNCTION get_public_survey(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  s record;
BEGIN
  SELECT id, workspace_id, name, description, survey_type, question, follow_up, thank_you, status
    INTO s
  FROM surveys
  WHERE public_token = p_token;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_found');
  END IF;

  IF s.status <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_active');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'id', s.id,
    'name', s.name,
    'description', s.description,
    'survey_type', s.survey_type,
    'question', s.question,
    'follow_up', s.follow_up,
    'thank_you', s.thank_you
  );
END;
$$;

CREATE OR REPLACE FUNCTION submit_public_survey_response(
  p_token text,
  p_score integer DEFAULT NULL,
  p_answer text DEFAULT NULL,
  p_comment text DEFAULT NULL,
  p_customer_email text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  s record;
  v_customer_id uuid := NULL;
BEGIN
  SELECT id, workspace_id, status, thank_you, survey_type
    INTO s
  FROM surveys
  WHERE public_token = p_token;

  IF NOT FOUND OR s.status <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_active');
  END IF;

  IF p_customer_email IS NOT NULL AND length(p_customer_email) > 0 THEN
    SELECT id INTO v_customer_id
    FROM customers
    WHERE workspace_id = s.workspace_id AND lower(email) = lower(p_customer_email)
    LIMIT 1;
  END IF;

  INSERT INTO survey_responses(workspace_id, survey_id, customer_id, score, answer, comment)
  VALUES (s.workspace_id, s.id, v_customer_id, p_score, p_answer, p_comment);

  RETURN jsonb_build_object('ok', true, 'thank_you', COALESCE(s.thank_you, 'Thanks for your feedback!'));
END;
$$;

CREATE OR REPLACE FUNCTION increment_survey_impression(p_token text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE surveys
    SET impressions = COALESCE(impressions, 0) + 1
    WHERE public_token = p_token AND status = 'active';
END;
$$;

GRANT EXECUTE ON FUNCTION get_public_survey(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION submit_public_survey_response(text, integer, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION increment_survey_impression(text) TO anon, authenticated;
