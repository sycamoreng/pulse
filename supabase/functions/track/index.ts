import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey, X-Api-Key",
};

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const apiKey = req.headers.get("X-Api-Key") || new URL(req.url).searchParams.get("key");
    if (!apiKey) return json({ error: "missing X-Api-Key" }, 401);

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: keyRow } = await supabase.from("api_keys").select("workspace_id").eq("key", apiKey).maybeSingle();
    if (!keyRow) return json({ error: "invalid api key" }, 401);
    const workspaceId = keyRow.workspace_id;

    const url = new URL(req.url);
    const path = url.pathname.replace(/\/+$/, "").split("/").pop();
    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};

    if (path === "identify") {
      const { external_id, traits = {} } = body;
      if (!external_id) return json({ error: "external_id required" }, 400);
      const rec: Record<string, unknown> = { workspace_id: workspaceId, external_id, last_seen_at: new Date().toISOString() };
      const defaults = ["email", "phone", "first_name", "last_name", "country", "city", "device", "platform"];
      const attrs: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(traits)) {
        if (defaults.includes(k)) rec[k] = v;
        else attrs[k] = v;
      }
      if (Object.keys(attrs).length) rec.attributes = attrs;
      const { data, error } = await supabase.from("customers").upsert(rec, { onConflict: "workspace_id,external_id" }).select().maybeSingle();
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true, customer: data });
    }

    if (path === "track") {
      const { external_id, name, properties = {} } = body;
      if (!external_id || !name) return json({ error: "external_id and name required" }, 400);
      const { data: customer } = await supabase.from("customers").upsert(
        { workspace_id: workspaceId, external_id, last_seen_at: new Date().toISOString() },
        { onConflict: "workspace_id,external_id" }
      ).select("id").maybeSingle();
      await supabase.from("event_definitions").upsert(
        { workspace_id: workspaceId, name, category: "custom" },
        { onConflict: "workspace_id,name" }
      );
      const { error } = await supabase.from("events").insert({
        workspace_id: workspaceId, customer_id: customer?.id, name, properties,
      });
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    return json({ error: "unknown route" }, 404);
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
