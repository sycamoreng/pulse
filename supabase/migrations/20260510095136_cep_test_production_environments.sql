/*
  # Test & Production Environments

  1. Changes to `workspaces`
    - `environment` text ('production' | 'test'), default 'production'
    - `parent_workspace_id` uuid — for test workspaces, points to their
      production sibling. Null for production workspaces.

  2. Changes to `api_keys`
    - `environment` text ('production' | 'test'), default 'production'
    - Existing rows backfilled from the owning workspace's environment.

  3. Behavior
    - Every production workspace pairs with a linked test workspace. The
      UI will auto-create the pair and allow switching between them.
    - API keys are issued per-environment. Client-side (publishable) and
      server-side (secret) keys now carry an environment tag; prefixes:
        - `pk_live_...` (secret, production)
        - `pk_test_...` (secret, test)
        - `ppk_live_...` (publishable, production)
        - `ppk_test_...` (publishable, test)
    - Track function will validate that the key's environment matches the
      target workspace's environment.

  4. Security
    - No RLS changes. Access is still scoped by `workspace_id` membership.
    - Test workspaces inherit the same membership model as production;
      members with access to the production workspace are automatically
      added to its paired test workspace by the app layer.
*/

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='workspaces' AND column_name='environment') THEN
    ALTER TABLE workspaces ADD COLUMN environment text DEFAULT 'production';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='workspaces' AND column_name='parent_workspace_id') THEN
    ALTER TABLE workspaces ADD COLUMN parent_workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='api_keys' AND column_name='environment') THEN
    ALTER TABLE api_keys ADD COLUMN environment text DEFAULT 'production';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_workspaces_parent ON workspaces(parent_workspace_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_env ON api_keys(workspace_id, environment);
