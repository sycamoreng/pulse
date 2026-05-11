import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};
const json = (d: unknown, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });

async function authorizeAdmin(req: Request, workspaceId: string): Promise<{ ok: boolean; status?: number; error?: string }> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const auth = req.headers.get("Authorization") || "";
  if (!auth.startsWith("Bearer ")) return { ok: false, status: 401, error: "Unauthorized" };
  const token = auth.slice(7).trim();
  if (token === serviceKey) return { ok: true };
  const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: auth } } });
  const { data: u } = await userClient.auth.getUser();
  const user = u?.user;
  if (!user) return { ok: false, status: 401, error: "Unauthorized" };
  const admin = createClient(supabaseUrl, serviceKey);
  const { data: member } = await admin.from("workspace_members").select("role")
    .eq("workspace_id", workspaceId).eq("user_id", user.id).maybeSingle();
  if (!member || !["owner", "admin"].includes(member.role)) return { ok: false, status: 403, error: "Forbidden" };
  return { ok: true };
}

function isServiceRole(req: Request): boolean {
  const auth = req.headers.get("Authorization") || "";
  return auth.slice(7).trim() === (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const body = await req.json().catch(() => ({}));
    const { workspace_id, entity, retain_days, run_all } = body || {};

    if (workspace_id && entity) {
      const authz = await authorizeAdmin(req, workspace_id);
      if (!authz.ok) return json({ ok: false, error: authz.error }, authz.status || 401);
      const days = Number(retain_days) > 0 ? Number(retain_days) : 90;
      const { data, error } = await sb.rpc("retention_run", {
        p_workspace: workspace_id, p_entity: entity, p_days: days,
      });
      if (error) return json({ ok: false, error: error.message }, 500);
      return json({ ok: true, deleted: data || 0, entity });
    }

    if (run_all) {
      if (!isServiceRole(req)) return json({ ok: false, error: "Unauthorized" }, 401);
      const { data: policies } = await sb.from("retention_policies").select("*").eq("is_active", true);
      const results: any[] = [];
      for (const p of policies || []) {
        const { data, error } = await sb.rpc("retention_run", {
          p_workspace: p.workspace_id, p_entity: p.entity, p_days: p.retain_days || 90,
        });
        results.push({ workspace_id: p.workspace_id, entity: p.entity, deleted: data || 0, error: error?.message });
      }
      return json({ ok: true, processed: results.length, results });
    }

    return json({ ok: false, error: "Provide workspace_id+entity, or run_all:true" }, 400);
  } catch (e) {
    return json({ ok: false, error: (e as Error).message }, 500);
  }
});
