import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};
const json = (d: unknown, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });

async function sha256Hex(s: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}
function randomToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return "scim_" + Array.from(bytes).map(b => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const auth = req.headers.get("Authorization") || "";
    if (!auth.startsWith("Bearer ")) return json({ ok: false, error: "Unauthorized" }, 401);

    const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: auth } } });
    const { data: u } = await userClient.auth.getUser();
    const user = u?.user;
    if (!user) return json({ ok: false, error: "Unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const { workspace_id, name } = body || {};
    if (!workspace_id) return json({ ok: false, error: "workspace_id required" }, 400);

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: member } = await admin.from("workspace_members").select("role")
      .eq("workspace_id", workspace_id).eq("user_id", user.id).maybeSingle();
    if (!member || !["owner", "admin"].includes(member.role)) return json({ ok: false, error: "Forbidden" }, 403);

    const raw = randomToken();
    const token_hash = await sha256Hex(raw);
    const token_prefix = raw.slice(0, 10);

    const { data, error } = await admin.from("scim_tokens")
      .insert({ workspace_id, name: name || "SCIM token", token_prefix, token_hash, created_by: user.id })
      .select("id, name, token_prefix, created_at").maybeSingle();
    if (error || !data) return json({ ok: false, error: error?.message || "Insert failed" }, 500);

    // Return plaintext once
    return json({ ok: true, token: raw, record: data });
  } catch (e) {
    return json({ ok: false, error: (e as Error).message }, 500);
  }
});
