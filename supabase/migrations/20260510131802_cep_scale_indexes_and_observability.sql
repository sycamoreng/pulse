/*
  # Scaling foundations: indexes, usage rollups, rate limits, observability

  1. New indexes (CREATE INDEX IF NOT EXISTS)
    - `idx_events_ws_name_time` on events(workspace_id, name, occurred_at DESC)
      Accelerates per-tenant event-name timeline queries used by funnels,
      cohorts, RFM, and journey triggers.
    - `idx_events_customer_time` on events(customer_id, occurred_at DESC)
      Accelerates customer profile activity feed.
    - `idx_events_properties_gin` on events USING GIN (properties jsonb_path_ops)
      Accelerates property filters in segments and attribution queries.
    - `idx_customers_attributes_gin` on customers USING GIN (attributes jsonb_path_ops)
      Accelerates attribute-based segment previews.
    - `idx_customers_ws_last_seen` on customers(workspace_id, last_seen_at DESC)
      Accelerates recency-based segmentation and the dashboard.
    - `idx_cm_workspace_sent` on campaign_messages(workspace_id, sent_at DESC)
      Accelerates per-tenant send-rate and engagement queries.

  2. New tables
    - `workspace_usage_daily` — per-day rollup of events and sends for
      capacity planning and plan-gate enforcement without scanning raw tables.
    - `rate_limits` — lightweight per-(workspace, key) counter with a rolling
      window used by ingestion and send paths.

  3. Security
    - RLS enabled on both new tables.
    - Usage rows readable by workspace members; writable only via service role
      (functions run with service role key, so no write policy is needed).
    - Rate-limit rows are internal; no client-side read/write policies.

  4. Important notes
    1. All indexes are created IF NOT EXISTS and do not require downtime on an
       empty (just-purged) events table. On large tables in the future, prefer
       CREATE INDEX CONCURRENTLY in a manual migration.
    2. pg_stat_statements is already installed on this Supabase project and is
       used as the query observability source; no extension change needed.
*/

CREATE INDEX IF NOT EXISTS idx_events_ws_name_time
  ON events (workspace_id, name, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_events_customer_time
  ON events (customer_id, occurred_at DESC)
  WHERE customer_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_events_properties_gin
  ON events USING GIN (properties jsonb_path_ops);

CREATE INDEX IF NOT EXISTS idx_customers_attributes_gin
  ON customers USING GIN (attributes jsonb_path_ops);

CREATE INDEX IF NOT EXISTS idx_customers_ws_last_seen
  ON customers (workspace_id, last_seen_at DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_cm_workspace_sent
  ON campaign_messages (workspace_id, sent_at DESC NULLS LAST);

CREATE TABLE IF NOT EXISTS workspace_usage_daily (
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  day date NOT NULL,
  events_count bigint NOT NULL DEFAULT 0,
  email_sends bigint NOT NULL DEFAULT 0,
  sms_sends bigint NOT NULL DEFAULT 0,
  push_sends bigint NOT NULL DEFAULT 0,
  bounces bigint NOT NULL DEFAULT 0,
  complaints bigint NOT NULL DEFAULT 0,
  unsubscribes bigint NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (workspace_id, day)
);

ALTER TABLE workspace_usage_daily ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'workspace_usage_daily'
    AND policyname = 'Members can read their workspace usage'
  ) THEN
    CREATE POLICY "Members can read their workspace usage"
      ON workspace_usage_daily FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM workspace_members
          WHERE workspace_members.workspace_id = workspace_usage_daily.workspace_id
          AND workspace_members.user_id = auth.uid()
        )
      );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS rate_limits (
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  key text NOT NULL,
  window_start timestamptz NOT NULL,
  count bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (workspace_id, key, window_start)
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_window
  ON rate_limits (window_start);

ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION increment_usage(
  p_workspace_id uuid,
  p_events bigint DEFAULT 0,
  p_email_sends bigint DEFAULT 0,
  p_sms_sends bigint DEFAULT 0,
  p_push_sends bigint DEFAULT 0,
  p_bounces bigint DEFAULT 0,
  p_complaints bigint DEFAULT 0,
  p_unsubscribes bigint DEFAULT 0
) RETURNS void AS $$
BEGIN
  INSERT INTO workspace_usage_daily (
    workspace_id, day, events_count, email_sends, sms_sends, push_sends,
    bounces, complaints, unsubscribes
  ) VALUES (
    p_workspace_id, current_date, p_events, p_email_sends, p_sms_sends,
    p_push_sends, p_bounces, p_complaints, p_unsubscribes
  )
  ON CONFLICT (workspace_id, day) DO UPDATE SET
    events_count = workspace_usage_daily.events_count + EXCLUDED.events_count,
    email_sends = workspace_usage_daily.email_sends + EXCLUDED.email_sends,
    sms_sends = workspace_usage_daily.sms_sends + EXCLUDED.sms_sends,
    push_sends = workspace_usage_daily.push_sends + EXCLUDED.push_sends,
    bounces = workspace_usage_daily.bounces + EXCLUDED.bounces,
    complaints = workspace_usage_daily.complaints + EXCLUDED.complaints,
    unsubscribes = workspace_usage_daily.unsubscribes + EXCLUDED.unsubscribes,
    updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE VIEW slow_queries AS
SELECT
  substring(query for 200) AS query_preview,
  calls,
  round(total_exec_time::numeric, 2) AS total_ms,
  round(mean_exec_time::numeric, 2) AS mean_ms,
  round((100 * total_exec_time / NULLIF(sum(total_exec_time) OVER (), 0))::numeric, 2) AS pct_total,
  rows
FROM extensions.pg_stat_statements
WHERE query NOT ILIKE '%pg_stat_statements%'
ORDER BY total_exec_time DESC
LIMIT 50;
