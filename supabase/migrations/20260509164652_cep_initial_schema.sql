/*
  # Customer Engagement Platform - Initial Schema

  1. New Tables
    - `workspaces` - Organizations/tenants
    - `workspace_members` - Users linked to workspaces
    - `apps` - Connected apps (iOS/Android/Web) with SDK keys
    - `customers` - End-users imported or tracked
    - `customer_attributes_schema` - Default and custom attributes metadata
    - `events` - Tracked events
    - `event_definitions` - Event metadata
    - `segments` - User segments with rules
    - `lists` - Static user lists
    - `list_members` - Members of lists
    - `blacklists` - Blacklisted users
    - `campaigns` - Email/push/SMS campaigns
    - `journeys` - Customer journeys with steps
    - `onsite_messages` - Website on-site messages
    - `inapp_banners` - Mobile in-app banners
    - `imports` - CSV import history

  2. Security
    - RLS enabled on all tables
    - Workspace-scoped policies
*/

CREATE TABLE IF NOT EXISTS workspaces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL DEFAULT 'My Workspace',
  slug text UNIQUE NOT NULL,
  plan text NOT NULL DEFAULT 'free',
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS workspace_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member',
  created_at timestamptz DEFAULT now(),
  UNIQUE(workspace_id, user_id)
);

CREATE TABLE IF NOT EXISTS apps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  platform text NOT NULL DEFAULT 'web',
  sdk_key text UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(24), 'hex'),
  bundle_id text DEFAULT '',
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  external_id text NOT NULL,
  email text DEFAULT '',
  phone text DEFAULT '',
  first_name text DEFAULT '',
  last_name text DEFAULT '',
  country text DEFAULT '',
  city text DEFAULT '',
  device text DEFAULT '',
  platform text DEFAULT '',
  attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_blacklisted boolean DEFAULT false,
  last_seen_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(workspace_id, external_id)
);

CREATE INDEX IF NOT EXISTS idx_customers_workspace ON customers(workspace_id);
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(workspace_id, email);

CREATE TABLE IF NOT EXISTS customer_attributes_schema (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  key text NOT NULL,
  label text NOT NULL,
  data_type text NOT NULL DEFAULT 'string',
  is_default boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  UNIQUE(workspace_id, key)
);

CREATE TABLE IF NOT EXISTS event_definitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text DEFAULT '',
  category text DEFAULT 'custom',
  created_at timestamptz DEFAULT now(),
  UNIQUE(workspace_id, name)
);

CREATE TABLE IF NOT EXISTS events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES customers(id) ON DELETE CASCADE,
  app_id uuid REFERENCES apps(id) ON DELETE SET NULL,
  name text NOT NULL,
  properties jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_events_workspace ON events(workspace_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_customer ON events(customer_id);

CREATE TABLE IF NOT EXISTS segments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text DEFAULT '',
  rules jsonb NOT NULL DEFAULT '{"conditions":[]}'::jsonb,
  estimated_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS lists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text DEFAULT '',
  type text NOT NULL DEFAULT 'static',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS list_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  list_id uuid NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  added_at timestamptz DEFAULT now(),
  UNIQUE(list_id, customer_id)
);

CREATE TABLE IF NOT EXISTS campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  channel text NOT NULL DEFAULT 'email',
  status text NOT NULL DEFAULT 'draft',
  subject text DEFAULT '',
  content text DEFAULT '',
  audience_type text DEFAULT 'all',
  audience_id uuid,
  scheduled_at timestamptz,
  sent_count integer DEFAULT 0,
  open_count integer DEFAULT 0,
  click_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS journeys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text DEFAULT '',
  status text NOT NULL DEFAULT 'draft',
  trigger_event text DEFAULT '',
  steps jsonb NOT NULL DEFAULT '[]'::jsonb,
  entered_count integer DEFAULT 0,
  completed_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS onsite_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  message_type text NOT NULL DEFAULT 'popup',
  title text DEFAULT '',
  body text DEFAULT '',
  cta_text text DEFAULT '',
  cta_url text DEFAULT '',
  position text DEFAULT 'center',
  status text NOT NULL DEFAULT 'draft',
  target_url text DEFAULT '',
  impressions integer DEFAULT 0,
  clicks integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS inapp_banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  title text DEFAULT '',
  body text DEFAULT '',
  image_url text DEFAULT '',
  cta_text text DEFAULT '',
  cta_action text DEFAULT '',
  platform text NOT NULL DEFAULT 'both',
  status text NOT NULL DEFAULT 'draft',
  impressions integer DEFAULT 0,
  clicks integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS imports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  filename text NOT NULL,
  total_rows integer DEFAULT 0,
  imported_rows integer DEFAULT 0,
  failed_rows integer DEFAULT 0,
  mapping jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'completed',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE apps ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_attributes_schema ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE list_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE journeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE onsite_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE inapp_banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE imports ENABLE ROW LEVEL SECURITY;

-- Workspaces: owner or member can read
CREATE POLICY "members view workspace" ON workspaces FOR SELECT TO authenticated
  USING (owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members WHERE workspace_id = workspaces.id AND user_id = auth.uid()));
CREATE POLICY "users create workspace" ON workspaces FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());
CREATE POLICY "owner updates workspace" ON workspaces FOR UPDATE TO authenticated
  USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());
CREATE POLICY "owner deletes workspace" ON workspaces FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "members view members" ON workspace_members FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR EXISTS (SELECT 1 FROM workspaces w WHERE w.id = workspace_id AND w.owner_id = auth.uid()));
CREATE POLICY "owner adds members" ON workspace_members FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = workspace_id AND w.owner_id = auth.uid()));
CREATE POLICY "owner updates members" ON workspace_members FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = workspace_id AND w.owner_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = workspace_id AND w.owner_id = auth.uid()));
CREATE POLICY "owner removes members" ON workspace_members FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = workspace_id AND w.owner_id = auth.uid()));

-- Generic workspace scoped policies helper pattern
-- apps
CREATE POLICY "ws view apps" ON apps FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = apps.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert apps" ON apps FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = apps.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update apps" ON apps FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = apps.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = apps.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete apps" ON apps FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = apps.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view customers" ON customers FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = customers.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert customers" ON customers FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = customers.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update customers" ON customers FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = customers.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = customers.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete customers" ON customers FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = customers.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view attrs" ON customer_attributes_schema FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = customer_attributes_schema.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert attrs" ON customer_attributes_schema FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = customer_attributes_schema.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update attrs" ON customer_attributes_schema FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = customer_attributes_schema.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = customer_attributes_schema.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete attrs" ON customer_attributes_schema FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = customer_attributes_schema.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view evdef" ON event_definitions FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = event_definitions.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert evdef" ON event_definitions FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = event_definitions.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update evdef" ON event_definitions FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = event_definitions.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = event_definitions.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete evdef" ON event_definitions FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = event_definitions.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view events" ON events FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = events.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert events" ON events FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = events.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update events" ON events FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = events.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = events.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete events" ON events FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = events.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view segments" ON segments FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = segments.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert segments" ON segments FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = segments.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update segments" ON segments FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = segments.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = segments.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete segments" ON segments FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = segments.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view lists" ON lists FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = lists.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert lists" ON lists FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = lists.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update lists" ON lists FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = lists.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = lists.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete lists" ON lists FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = lists.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view lmem" ON list_members FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM lists l JOIN workspaces w ON w.id=l.workspace_id WHERE l.id = list_members.list_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert lmem" ON list_members FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM lists l JOIN workspaces w ON w.id=l.workspace_id WHERE l.id = list_members.list_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete lmem" ON list_members FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM lists l JOIN workspaces w ON w.id=l.workspace_id WHERE l.id = list_members.list_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view campaigns" ON campaigns FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = campaigns.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert campaigns" ON campaigns FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = campaigns.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update campaigns" ON campaigns FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = campaigns.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = campaigns.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete campaigns" ON campaigns FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = campaigns.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view journeys" ON journeys FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journeys.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert journeys" ON journeys FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journeys.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update journeys" ON journeys FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journeys.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journeys.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete journeys" ON journeys FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = journeys.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view onsite" ON onsite_messages FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = onsite_messages.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert onsite" ON onsite_messages FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = onsite_messages.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update onsite" ON onsite_messages FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = onsite_messages.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = onsite_messages.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete onsite" ON onsite_messages FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = onsite_messages.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view banners" ON inapp_banners FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = inapp_banners.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert banners" ON inapp_banners FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = inapp_banners.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws update banners" ON inapp_banners FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = inapp_banners.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid())))) WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = inapp_banners.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete banners" ON inapp_banners FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = inapp_banners.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));

CREATE POLICY "ws view imports" ON imports FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = imports.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws insert imports" ON imports FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = imports.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
CREATE POLICY "ws delete imports" ON imports FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = imports.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
