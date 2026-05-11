/*
  # Drop workspace_online_members RPC

  1. Changes
    - Removes the `workspace_online_members(uuid, integer)` function.
  2. Reason
    - No longer used. The "users online" metric is now derived from
      recent customer events directly in the client.
*/

drop function if exists public.workspace_online_members(uuid, integer);