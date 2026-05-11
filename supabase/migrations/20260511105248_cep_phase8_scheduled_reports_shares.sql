/*
  # Phase 8 — Scheduled email reports and shareable dashboards

  1. New Tables
    - `scheduled_reports` — a workspace can schedule recurring email reports
      - `id` (uuid PK)
      - `workspace_id` (uuid FK -> workspaces)
      - `name` (text)
      - `scope` (text) — which view to summarise: dashboard | deliverability | campaigns
      - `cadence` (text) — daily | weekly | monthly
      - `recipients` (text[]) — plain email list
      - `is_active` (bool)
      - `last_run_at` / `next_run_at` (timestamptz)
      - `last_status` / `last_error` (text)
      - `created_at` / `updated_at`
    - `dashboard_shares` — signed read-only links for the dashboard
      - `id` (uuid PK)
      - `workspace_id` (uuid FK -> workspaces)
      - `share_token` (text UNIQUE) — opaque, used in public URL
      - `label` (text)
      - `expires_at` (timestamptz, nullable = never)
      - `is_active` (bool)
      - `view_count` (int)
      - `created_by` (uuid FK -> auth.users)
      - `created_at`
  2. Security
    - RLS enabled on both
    - Members can SELECT; only admin/owner can INSERT/UPDATE/DELETE
    - A SECURITY DEFINER RPC `dashboard_share_snapshot(token)` returns a safe
      aggregate snapshot for anonymous callers — no raw PII leaves the function
*/

CREATE TABLE IF NOT EXISTS scheduled_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT 'Daily engagement report',
  scope text NOT NULL DEFAULT 'dashboard',
  cadence text NOT NULL DEFAULT 'daily',
  recipients text[] NOT NULL DEFAULT ARRAY[]::text[],
  is_active boolean NOT NULL DEFAULT true,
  last_run_at timestamptz,
  next_run_at timestamptz DEFAULT now(),
  last_status text DEFAULT '',
  last_error text DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_scheduled_reports_workspace ON scheduled_reports(workspace_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_reports_due ON scheduled_reports(next_run_at) WHERE is_active;

ALTER TABLE scheduled_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members view scheduled reports" ON scheduled_reports;
CREATE POLICY "Members view scheduled reports" ON scheduled_reports FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = scheduled_reports.workspace_id AND wm.user_id = auth.uid()));

DROP POLICY IF EXISTS "Admins insert scheduled reports" ON scheduled_reports;
CREATE POLICY "Admins insert scheduled reports" ON scheduled_reports FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = scheduled_reports.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins update scheduled reports" ON scheduled_reports;
CREATE POLICY "Admins update scheduled reports" ON scheduled_reports FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = scheduled_reports.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = scheduled_reports.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins delete scheduled reports" ON scheduled_reports;
CREATE POLICY "Admins delete scheduled reports" ON scheduled_reports FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = scheduled_reports.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));


CREATE TABLE IF NOT EXISTS dashboard_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  share_token text NOT NULL UNIQUE,
  label text NOT NULL DEFAULT 'Shared dashboard',
  expires_at timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  view_count integer NOT NULL DEFAULT 0,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dashboard_shares_workspace ON dashboard_shares(workspace_id);
CREATE INDEX IF NOT EXISTS idx_dashboard_shares_token ON dashboard_shares(share_token);

ALTER TABLE dashboard_shares ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members view dashboard shares" ON dashboard_shares;
CREATE POLICY "Members view dashboard shares" ON dashboard_shares FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = dashboard_shares.workspace_id AND wm.user_id = auth.uid()));

DROP POLICY IF EXISTS "Admins insert dashboard shares" ON dashboard_shares;
CREATE POLICY "Admins insert dashboard shares" ON dashboard_shares FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = dashboard_shares.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins update dashboard shares" ON dashboard_shares;
CREATE POLICY "Admins update dashboard shares" ON dashboard_shares FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = dashboard_shares.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = dashboard_shares.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

DROP POLICY IF EXISTS "Admins delete dashboard shares" ON dashboard_shares;
CREATE POLICY "Admins delete dashboard shares" ON dashboard_shares FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = dashboard_shares.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));


-- Public RPC: resolve a share token into a safe aggregate snapshot
CREATE OR REPLACE FUNCTION dashboard_share_snapshot(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_share dashboard_shares%ROWTYPE;
  v_ws workspaces%ROWTYPE;
  v_customers int;
  v_events_30d int;
  v_segments int;
  v_campaigns int;
  v_chart jsonb;
BEGIN
  SELECT * INTO v_share FROM dashboard_shares
    WHERE share_token = p_token AND is_active = true
      AND (expires_at IS NULL OR expires_at > now())
    LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Share not found or expired');
  END IF;

  SELECT * INTO v_ws FROM workspaces WHERE id = v_share.workspace_id;

  SELECT count(*) INTO v_customers FROM customers WHERE workspace_id = v_share.workspace_id;
  SELECT count(*) INTO v_events_30d FROM events
    WHERE workspace_id = v_share.workspace_id
      AND occurred_at >= now() - interval '30 days';
  SELECT count(*) INTO v_segments FROM segments WHERE workspace_id = v_share.workspace_id;
  SELECT count(*) INTO v_campaigns FROM campaigns WHERE workspace_id = v_share.workspace_id;

  SELECT coalesce(jsonb_agg(jsonb_build_object('d', d::date, 'c', c) ORDER BY d), '[]'::jsonb)
    INTO v_chart
  FROM (
    SELECT date_trunc('day', occurred_at) AS d, count(*)::int AS c
    FROM events
    WHERE workspace_id = v_share.workspace_id
      AND occurred_at >= now() - interval '14 days'
    GROUP BY 1
  ) t;

  UPDATE dashboard_shares SET view_count = view_count + 1 WHERE id = v_share.id;

  RETURN jsonb_build_object(
    'ok', true,
    'workspace', jsonb_build_object('name', v_ws.name, 'industry', v_ws.industry),
    'label', v_share.label,
    'stats', jsonb_build_object(
      'customers', v_customers,
      'events_30d', v_events_30d,
      'segments', v_segments,
      'campaigns', v_campaigns
    ),
    'chart', v_chart,
    'generated_at', now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION dashboard_share_snapshot(text) TO anon, authenticated;
