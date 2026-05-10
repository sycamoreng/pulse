/*
  # Fix infinite recursion between workspaces and workspace_members policies

  1. Problem
    - workspaces SELECT policy referenced workspace_members to check membership
    - workspace_members SELECT policy referenced workspaces to check ownership
    - Postgres detects the cycle and raises "infinite recursion detected in policy for relation workspaces"

  2. Fix
    - Introduce a SECURITY DEFINER helper `is_workspace_member(wid uuid)` that looks up membership without triggering RLS, breaking the cycle
    - Rewrite the workspaces SELECT policy to use the helper
    - Rewrite workspace_members SELECT policy to either match the caller's user_id directly or use the helper for admin visibility

  3. Security
    - Helper uses SECURITY DEFINER and only reads the `workspace_members` table by `(wid, auth.uid())`; it returns a boolean only. No data is leaked.
    - Policies remain restrictive: only owners and confirmed members can read their workspace or its member rows.
*/

CREATE OR REPLACE FUNCTION is_workspace_member(wid uuid) RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM workspace_members
    WHERE workspace_id = wid AND user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION is_workspace_owner(wid uuid) RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM workspaces
    WHERE id = wid AND owner_id = auth.uid()
  );
$$;

DROP POLICY IF EXISTS "members view workspace" ON workspaces;
CREATE POLICY "members view workspace" ON workspaces FOR SELECT TO authenticated
  USING (owner_id = auth.uid() OR is_workspace_member(id));

DROP POLICY IF EXISTS "members view members" ON workspace_members;
CREATE POLICY "members view members" ON workspace_members FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR is_workspace_owner(workspace_id));
