/*
  # Phases 4 & 5 — Commerce ingest + Integrations

  Adds commerce (orders, products, attributions), outbound webhooks,
  API key scopes, scheduled exports, and a revenue rollup view.
  See previous migration attempt for full description.

  Note: `api_keys` already existed with a basic shape; this migration
  augments it with scopes, key_prefix, key_hash, last_used_at, expires_at,
  and revoked_at. The legacy `key` column is preserved for backwards-compat.
*/

-- Phase 4 -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS commerce_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES customers(id) ON DELETE SET NULL,
  source text NOT NULL DEFAULT 'manual',
  external_id text NOT NULL,
  email text NOT NULL DEFAULT '',
  currency text NOT NULL DEFAULT 'USD',
  total_amount numeric(14,2) NOT NULL DEFAULT 0,
  subtotal numeric(14,2) NOT NULL DEFAULT 0,
  tax numeric(14,2) NOT NULL DEFAULT 0,
  shipping numeric(14,2) NOT NULL DEFAULT 0,
  discount numeric(14,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  raw jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (workspace_id, source, external_id)
);
CREATE INDEX IF NOT EXISTS idx_commerce_orders_ws_time ON commerce_orders(workspace_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_commerce_orders_customer ON commerce_orders(customer_id);
ALTER TABLE commerce_orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members read orders" ON commerce_orders;
CREATE POLICY "Members read orders" ON commerce_orders FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = commerce_orders.workspace_id AND wm.user_id = auth.uid()));
DROP POLICY IF EXISTS "Members insert orders" ON commerce_orders;
CREATE POLICY "Members insert orders" ON commerce_orders FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = commerce_orders.workspace_id AND wm.user_id = auth.uid()));

CREATE TABLE IF NOT EXISTS commerce_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  source text NOT NULL DEFAULT 'manual',
  external_id text NOT NULL,
  title text NOT NULL DEFAULT '',
  description text NOT NULL DEFAULT '',
  image_url text NOT NULL DEFAULT '',
  product_url text NOT NULL DEFAULT '',
  price numeric(14,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'USD',
  tags text[] NOT NULL DEFAULT '{}',
  in_stock boolean NOT NULL DEFAULT true,
  raw jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (workspace_id, source, external_id)
);
ALTER TABLE commerce_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members read products" ON commerce_products;
CREATE POLICY "Members read products" ON commerce_products FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = commerce_products.workspace_id AND wm.user_id = auth.uid()));
DROP POLICY IF EXISTS "Members write products" ON commerce_products;
CREATE POLICY "Members write products" ON commerce_products FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = commerce_products.workspace_id AND wm.user_id = auth.uid()));
DROP POLICY IF EXISTS "Members update products" ON commerce_products;
CREATE POLICY "Members update products" ON commerce_products FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = commerce_products.workspace_id AND wm.user_id = auth.uid()))
WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = commerce_products.workspace_id AND wm.user_id = auth.uid()));

CREATE TABLE IF NOT EXISTS campaign_attributions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  campaign_id uuid REFERENCES campaigns(id) ON DELETE CASCADE,
  journey_id uuid REFERENCES journeys(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES customers(id) ON DELETE SET NULL,
  order_id uuid REFERENCES commerce_orders(id) ON DELETE SET NULL,
  revenue numeric(14,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'USD',
  model text NOT NULL DEFAULT 'last_touch',
  window_hours integer NOT NULL DEFAULT 168,
  attributed_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_attr_campaign ON campaign_attributions(campaign_id);
CREATE INDEX IF NOT EXISTS idx_attr_journey ON campaign_attributions(journey_id);
ALTER TABLE campaign_attributions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members read attributions" ON campaign_attributions;
CREATE POLICY "Members read attributions" ON campaign_attributions FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = campaign_attributions.workspace_id AND wm.user_id = auth.uid()));

-- Phase 5 -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS webhook_destinations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT '',
  url text NOT NULL,
  event_filters text[] NOT NULL DEFAULT '{}',
  secret text NOT NULL DEFAULT '',
  is_active boolean NOT NULL DEFAULT true,
  last_success_at timestamptz,
  last_failure_at timestamptz,
  failure_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
ALTER TABLE webhook_destinations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members read hooks" ON webhook_destinations;
CREATE POLICY "Members read hooks" ON webhook_destinations FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = webhook_destinations.workspace_id AND wm.user_id = auth.uid()));
DROP POLICY IF EXISTS "Admins insert hooks" ON webhook_destinations;
CREATE POLICY "Admins insert hooks" ON webhook_destinations FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = webhook_destinations.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));
DROP POLICY IF EXISTS "Admins update hooks" ON webhook_destinations;
CREATE POLICY "Admins update hooks" ON webhook_destinations FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = webhook_destinations.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = webhook_destinations.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));
DROP POLICY IF EXISTS "Admins delete hooks" ON webhook_destinations;
CREATE POLICY "Admins delete hooks" ON webhook_destinations FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = webhook_destinations.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

CREATE TABLE IF NOT EXISTS webhook_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  destination_id uuid NOT NULL REFERENCES webhook_destinations(id) ON DELETE CASCADE,
  event_type text NOT NULL DEFAULT '',
  status_code integer NOT NULL DEFAULT 0,
  ok boolean NOT NULL DEFAULT false,
  attempt integer NOT NULL DEFAULT 1,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  response text NOT NULL DEFAULT '',
  sent_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_wd_dest ON webhook_deliveries(destination_id, sent_at DESC);
ALTER TABLE webhook_deliveries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members read deliveries" ON webhook_deliveries;
CREATE POLICY "Members read deliveries" ON webhook_deliveries FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = webhook_deliveries.workspace_id AND wm.user_id = auth.uid()));

-- Augment existing api_keys
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='api_keys' AND column_name='key_prefix') THEN
    ALTER TABLE api_keys ADD COLUMN key_prefix text NOT NULL DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='api_keys' AND column_name='key_hash') THEN
    ALTER TABLE api_keys ADD COLUMN key_hash text NOT NULL DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='api_keys' AND column_name='scopes') THEN
    ALTER TABLE api_keys ADD COLUMN scopes text[] NOT NULL DEFAULT '{}';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='api_keys' AND column_name='last_used_at') THEN
    ALTER TABLE api_keys ADD COLUMN last_used_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='api_keys' AND column_name='expires_at') THEN
    ALTER TABLE api_keys ADD COLUMN expires_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='api_keys' AND column_name='revoked_at') THEN
    ALTER TABLE api_keys ADD COLUMN revoked_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='api_keys' AND column_name='created_by') THEN
    ALTER TABLE api_keys ADD COLUMN created_by uuid;
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_api_keys_prefix ON api_keys(key_prefix);
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members read keys" ON api_keys;
CREATE POLICY "Members read keys" ON api_keys FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = api_keys.workspace_id AND wm.user_id = auth.uid()));
DROP POLICY IF EXISTS "Admins insert keys" ON api_keys;
CREATE POLICY "Admins insert keys" ON api_keys FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = api_keys.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));
DROP POLICY IF EXISTS "Admins update keys" ON api_keys;
CREATE POLICY "Admins update keys" ON api_keys FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = api_keys.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = api_keys.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

CREATE TABLE IF NOT EXISTS data_exports_scheduled (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT '',
  scope text NOT NULL DEFAULT 'customers',
  format text NOT NULL DEFAULT 'csv',
  destination text NOT NULL DEFAULT 'download',
  destination_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  cron text NOT NULL DEFAULT '0 5 * * *',
  is_active boolean NOT NULL DEFAULT true,
  last_run_at timestamptz,
  last_status text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
ALTER TABLE data_exports_scheduled ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members read scheduled exports" ON data_exports_scheduled;
CREATE POLICY "Members read scheduled exports" ON data_exports_scheduled FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = data_exports_scheduled.workspace_id AND wm.user_id = auth.uid()));
DROP POLICY IF EXISTS "Admins insert scheduled exports" ON data_exports_scheduled;
CREATE POLICY "Admins insert scheduled exports" ON data_exports_scheduled FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = data_exports_scheduled.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));
DROP POLICY IF EXISTS "Admins update scheduled exports" ON data_exports_scheduled;
CREATE POLICY "Admins update scheduled exports" ON data_exports_scheduled FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = data_exports_scheduled.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')))
WITH CHECK (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = data_exports_scheduled.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));
DROP POLICY IF EXISTS "Admins delete scheduled exports" ON data_exports_scheduled;
CREATE POLICY "Admins delete scheduled exports" ON data_exports_scheduled FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM workspace_members wm WHERE wm.workspace_id = data_exports_scheduled.workspace_id AND wm.user_id = auth.uid() AND wm.role IN ('owner','admin')));

CREATE OR REPLACE VIEW campaign_revenue_v AS
SELECT
  workspace_id,
  campaign_id,
  count(*) AS attributed_orders,
  coalesce(sum(revenue), 0) AS attributed_revenue,
  max(currency) AS currency
FROM campaign_attributions
WHERE campaign_id IS NOT NULL
GROUP BY workspace_id, campaign_id;
