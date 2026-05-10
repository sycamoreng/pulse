/*
  # Extend workspace defaults trigger to seed event definitions

  1. Changes
    - Updates `seed_workspace_defaults()` to also insert a starter event catalog
      (app_opened, product_viewed, added_to_cart, checkout_started,
       purchase_completed, signup, login) for every new workspace
    - Backfills event_definitions for any existing workspace that has none

  2. Security
    - No schema changes. Trigger continues to run with SECURITY DEFINER.
    - All inserts remain scoped to the created workspace's id.
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

  INSERT INTO event_definitions (workspace_id, name, category) VALUES
    (NEW.id, 'app_opened', 'behavior'),
    (NEW.id, 'product_viewed', 'behavior'),
    (NEW.id, 'added_to_cart', 'behavior'),
    (NEW.id, 'checkout_started', 'behavior'),
    (NEW.id, 'purchase_completed', 'behavior'),
    (NEW.id, 'signup', 'behavior'),
    (NEW.id, 'login', 'behavior')
  ON CONFLICT (workspace_id, name) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Backfill events for workspaces missing them (e.g. created between migrations)
INSERT INTO event_definitions (workspace_id, name, category)
SELECT w.id, e.name, 'behavior'
FROM workspaces w
CROSS JOIN (
  VALUES ('app_opened'), ('product_viewed'), ('added_to_cart'),
         ('checkout_started'), ('purchase_completed'), ('signup'), ('login')
) AS e(name)
ON CONFLICT (workspace_id, name) DO NOTHING;
