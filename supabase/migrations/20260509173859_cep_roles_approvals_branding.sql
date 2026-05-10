/*
  # Roles, approvals, branding, multi-workspace

  1. New columns on workspaces
    - logo_url, website, industry, timezone
    - brand_primary, brand_accent (hex strings for workspace branding)
  2. New tables
    - workspace_roles: predefined + custom roles with permissions jsonb
    - approvals: approval requests for campaigns and journeys
  3. Modifications
    - workspace_members: add role_id referencing workspace_roles
  4. Seeded system roles created per-workspace via trigger
    - Owner, Product, Marketing, Customer Experience, Tech, Viewer
  5. Security
    - RLS enabled on all new tables with workspace-scoped policies
*/

-- Branding columns
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'workspaces' AND column_name = 'logo_url') THEN
    ALTER TABLE workspaces ADD COLUMN logo_url text DEFAULT '';
    ALTER TABLE workspaces ADD COLUMN website text DEFAULT '';
    ALTER TABLE workspaces ADD COLUMN industry text DEFAULT '';
    ALTER TABLE workspaces ADD COLUMN timezone text DEFAULT 'UTC';
    ALTER TABLE workspaces ADD COLUMN brand_primary text DEFAULT '#3087B9';
    ALTER TABLE workspaces ADD COLUMN brand_accent text DEFAULT '#26C165';
    ALTER TABLE workspaces ADD COLUMN demo_seeded boolean DEFAULT false;
  END IF;
END $$;

-- Roles
CREATE TABLE IF NOT EXISTS workspace_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text DEFAULT '',
  permissions jsonb DEFAULT '{}'::jsonb,
  is_system boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  UNIQUE (workspace_id, name)
);
ALTER TABLE workspace_roles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'workspace_roles' AND policyname = 'ws view roles') THEN
    CREATE POLICY "ws view roles" ON workspace_roles FOR SELECT TO authenticated
      USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = workspace_roles.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
    CREATE POLICY "ws insert roles" ON workspace_roles FOR INSERT TO authenticated
      WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = workspace_roles.workspace_id AND w.owner_id = auth.uid()));
    CREATE POLICY "ws update roles" ON workspace_roles FOR UPDATE TO authenticated
      USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = workspace_roles.workspace_id AND w.owner_id = auth.uid()))
      WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = workspace_roles.workspace_id AND w.owner_id = auth.uid()));
    CREATE POLICY "ws delete roles" ON workspace_roles FOR DELETE TO authenticated
      USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = workspace_roles.workspace_id AND w.owner_id = auth.uid()) AND is_system = false);
  END IF;
END $$;

-- Members role link
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'workspace_members' AND column_name = 'role_id') THEN
    ALTER TABLE workspace_members ADD COLUMN role_id uuid REFERENCES workspace_roles(id) ON DELETE SET NULL;
    ALTER TABLE workspace_members ADD COLUMN email text DEFAULT '';
  END IF;
END $$;

-- Approvals
CREATE TABLE IF NOT EXISTS approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  entity_name text DEFAULT '',
  requested_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  status text DEFAULT 'pending',
  notes text DEFAULT '',
  created_at timestamptz DEFAULT now(),
  reviewed_at timestamptz
);
ALTER TABLE approvals ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'approvals' AND policyname = 'ws view approvals') THEN
    CREATE POLICY "ws view approvals" ON approvals FOR SELECT TO authenticated
      USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = approvals.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
    CREATE POLICY "ws insert approvals" ON approvals FOR INSERT TO authenticated
      WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = approvals.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
    CREATE POLICY "ws update approvals" ON approvals FOR UPDATE TO authenticated
      USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = approvals.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))))
      WITH CHECK (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = approvals.workspace_id AND (w.owner_id = auth.uid() OR EXISTS (SELECT 1 FROM workspace_members m WHERE m.workspace_id = w.id AND m.user_id = auth.uid()))));
    CREATE POLICY "ws delete approvals" ON approvals FOR DELETE TO authenticated
      USING (EXISTS (SELECT 1 FROM workspaces w WHERE w.id = approvals.workspace_id AND w.owner_id = auth.uid()));
  END IF;
END $$;

-- Trigger: seed system roles when a workspace is created
CREATE OR REPLACE FUNCTION seed_workspace_roles() RETURNS trigger AS $$
BEGIN
  INSERT INTO workspace_roles (workspace_id, name, description, permissions, is_system) VALUES
    (NEW.id, 'Owner', 'Full access to everything, including billing and workspace settings.',
     '{"all": true, "campaigns": {"create": true, "edit": true, "delete": true, "approve": true, "send": true}, "journeys": {"create": true, "edit": true, "delete": true, "approve": true, "activate": true}, "templates": {"create": true, "edit": true, "delete": true}, "customers": {"view": true, "edit": true, "delete": true, "import": true}, "analytics": {"view": true}, "settings": {"view": true, "edit": true, "members": true}}'::jsonb, true),
    (NEW.id, 'Product', 'Owns journeys and product-led flows. Can approve journey rollouts.',
     '{"campaigns": {"create": false, "edit": false, "delete": false, "approve": false, "send": false}, "journeys": {"create": true, "edit": true, "delete": true, "approve": true, "activate": true}, "templates": {"create": true, "edit": true, "delete": false}, "customers": {"view": true, "edit": false, "delete": false, "import": false}, "analytics": {"view": true}, "settings": {"view": true, "edit": false, "members": false}}'::jsonb, true),
    (NEW.id, 'Marketing', 'Runs campaigns and templates. Sends approved campaigns.',
     '{"campaigns": {"create": true, "edit": true, "delete": true, "approve": false, "send": true}, "journeys": {"create": true, "edit": true, "delete": false, "approve": false, "activate": false}, "templates": {"create": true, "edit": true, "delete": true}, "customers": {"view": true, "edit": false, "delete": false, "import": true}, "analytics": {"view": true}, "settings": {"view": true, "edit": false, "members": false}}'::jsonb, true),
    (NEW.id, 'Customer Experience', 'Supports customers, manages lists and blacklists.',
     '{"campaigns": {"create": false, "edit": false, "delete": false, "approve": false, "send": false}, "journeys": {"create": false, "edit": false, "delete": false, "approve": false, "activate": false}, "templates": {"create": false, "edit": false, "delete": false}, "customers": {"view": true, "edit": true, "delete": false, "import": false}, "analytics": {"view": true}, "settings": {"view": true, "edit": false, "members": false}}'::jsonb, true),
    (NEW.id, 'Tech', 'Manages apps, SDKs, events and integrations.',
     '{"campaigns": {"create": false, "edit": false, "delete": false, "approve": false, "send": false}, "journeys": {"create": false, "edit": false, "delete": false, "approve": false, "activate": false}, "templates": {"create": false, "edit": false, "delete": false}, "customers": {"view": true, "edit": false, "delete": false, "import": false}, "apps": {"create": true, "edit": true, "delete": true}, "events": {"create": true, "edit": true, "delete": true}, "analytics": {"view": true}, "settings": {"view": true, "edit": true, "members": false}}'::jsonb, true),
    (NEW.id, 'Viewer', 'Read-only access to data, campaigns and analytics.',
     '{"campaigns": {"create": false, "edit": false, "delete": false, "approve": false, "send": false}, "journeys": {"create": false, "edit": false, "delete": false, "approve": false, "activate": false}, "templates": {"create": false, "edit": false, "delete": false}, "customers": {"view": true, "edit": false, "delete": false, "import": false}, "analytics": {"view": true}, "settings": {"view": false, "edit": false, "members": false}}'::jsonb, true)
  ON CONFLICT (workspace_id, name) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS seed_roles_on_workspace ON workspaces;
CREATE TRIGGER seed_roles_on_workspace AFTER INSERT ON workspaces
  FOR EACH ROW EXECUTE FUNCTION seed_workspace_roles();

-- Backfill roles for existing workspaces
INSERT INTO workspace_roles (workspace_id, name, description, permissions, is_system)
SELECT w.id, r.name, r.description, r.permissions, true
FROM workspaces w
CROSS JOIN (
  VALUES
    ('Owner', 'Full access to everything, including billing and workspace settings.', '{"all": true}'::jsonb),
    ('Product', 'Owns journeys and product-led flows. Can approve journey rollouts.', '{"journeys": {"create": true, "edit": true, "delete": true, "approve": true, "activate": true}}'::jsonb),
    ('Marketing', 'Runs campaigns and templates.', '{"campaigns": {"create": true, "edit": true, "delete": true, "send": true}}'::jsonb),
    ('Customer Experience', 'Supports customers.', '{"customers": {"view": true, "edit": true}}'::jsonb),
    ('Tech', 'Manages apps, SDKs and events.', '{"apps": {"create": true, "edit": true, "delete": true}}'::jsonb),
    ('Viewer', 'Read-only access.', '{"analytics": {"view": true}}'::jsonb)
) AS r(name, description, permissions)
ON CONFLICT (workspace_id, name) DO NOTHING;

-- Approval status on campaigns and journeys (use existing status field but add requires_approval flag)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'campaigns' AND column_name = 'requires_approval') THEN
    ALTER TABLE campaigns ADD COLUMN requires_approval boolean DEFAULT false;
    ALTER TABLE campaigns ADD COLUMN approval_status text DEFAULT 'not_required';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'journeys' AND column_name = 'requires_approval') THEN
    ALTER TABLE journeys ADD COLUMN requires_approval boolean DEFAULT false;
    ALTER TABLE journeys ADD COLUMN approval_status text DEFAULT 'not_required';
  END IF;
END $$;
