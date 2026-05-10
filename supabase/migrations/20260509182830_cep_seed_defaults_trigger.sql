/*
  # Seed default customer attributes and first app on workspace creation

  1. Changes
    - Adds a trigger function `seed_workspace_defaults()` that runs after every new workspace is created
    - The trigger populates the workspace with the 8 default customer attributes (email, phone, first/last name, country, city, device, platform) and a "Web App" placeholder
    - Adds a backfill pass so existing workspaces that are missing these defaults receive them too
    - Ensures every workspace, new or old, has a usable starting environment without relying on client-side seeding

  2. Security
    - No schema changes. RLS policies unchanged.
    - Trigger runs with SECURITY DEFINER so seed data can be inserted even if the calling user's policy context would otherwise block it. All inserts are scoped to NEW.id of the workspace being created.

  3. Notes
    - Safe to re-run: uses ON CONFLICT DO NOTHING on the (workspace_id, key) unique constraint where available; for apps, checks existence before insert.
*/

CREATE OR REPLACE FUNCTION seed_workspace_defaults() RETURNS trigger AS $$
BEGIN
  INSERT INTO customer_attributes_schema (workspace_id, key, label, data_type, is_default) VALUES
    (NEW.id, 'email', 'Email', 'email', true),
    (NEW.id, 'phone', 'Phone', 'phone', true),
    (NEW.id, 'first_name', 'First Name', 'string', true),
    (NEW.id, 'last_name', 'Last Name', 'string', true),
    (NEW.id, 'country', 'Country', 'string', true),
    (NEW.id, 'city', 'City', 'string', true),
    (NEW.id, 'device', 'Device', 'string', true),
    (NEW.id, 'platform', 'Platform', 'string', true)
  ON CONFLICT (workspace_id, key) DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM apps WHERE workspace_id = NEW.id) THEN
    INSERT INTO apps (workspace_id, name, platform) VALUES (NEW.id, 'Web App', 'web');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS seed_defaults_on_workspace ON workspaces;
CREATE TRIGGER seed_defaults_on_workspace AFTER INSERT ON workspaces
  FOR EACH ROW EXECUTE FUNCTION seed_workspace_defaults();

-- Backfill defaults for any existing workspaces that lack them
INSERT INTO customer_attributes_schema (workspace_id, key, label, data_type, is_default)
SELECT w.id, d.key, d.label, d.data_type, true
FROM workspaces w
CROSS JOIN (
  VALUES
    ('email','Email','email'),
    ('phone','Phone','phone'),
    ('first_name','First Name','string'),
    ('last_name','Last Name','string'),
    ('country','Country','string'),
    ('city','City','string'),
    ('device','Device','string'),
    ('platform','Platform','string')
) AS d(key, label, data_type)
ON CONFLICT (workspace_id, key) DO NOTHING;

INSERT INTO apps (workspace_id, name, platform)
SELECT w.id, 'Web App', 'web' FROM workspaces w
WHERE NOT EXISTS (SELECT 1 FROM apps a WHERE a.workspace_id = w.id);

-- Also seed a starter event catalog so dropdowns aren't empty
INSERT INTO event_definitions (workspace_id, name, category)
SELECT w.id, e.name, 'behavior'
FROM workspaces w
CROSS JOIN (
  VALUES ('app_opened'), ('product_viewed'), ('added_to_cart'),
         ('checkout_started'), ('purchase_completed'), ('signup'), ('login')
) AS e(name)
ON CONFLICT (workspace_id, name) DO NOTHING;
