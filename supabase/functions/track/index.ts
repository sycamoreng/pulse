import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey, X-Api-Key, X-Pulse-Bundle-Id",
};

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

function originHost(origin: string | null): string | null {
  if (!origin) return null;
  try { return new URL(origin).host; } catch { return null; }
}

function originAllowed(allowed: string[] | null, host: string | null): boolean {
  if (!allowed || allowed.length === 0) return true;
  if (!host) return false;
  return allowed.some((a) => {
    const pat = a.trim().toLowerCase();
    if (!pat) return false;
    if (pat === "*") return true;
    if (pat.startsWith("*.")) return host.endsWith(pat.slice(1));
    return host === pat;
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const authHeader = req.headers.get("Authorization") || "";
    const bearer = authHeader.toLowerCase().startsWith("bearer ") ? authHeader.slice(7).trim() : "";
    const apiKey = req.headers.get("X-Api-Key") || bearer || new URL(req.url).searchParams.get("key");
    if (!apiKey) return json({ error: "missing api key" }, 401);

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: keyRow } = await supabase
      .from("api_keys")
      .select("workspace_id, key_type, scopes, allowed_origins, allowed_bundle_ids, revoked_at, expires_at")
      .eq("key", apiKey)
      .maybeSingle();
    if (!keyRow) return json({ error: "invalid api key" }, 401);
    if (keyRow.revoked_at) return json({ error: "key revoked" }, 401);
    if (keyRow.expires_at && new Date(keyRow.expires_at) < new Date()) return json({ error: "key expired" }, 401);

    if (keyRow.key_type === "publishable") {
      const host = originHost(req.headers.get("Origin") || req.headers.get("Referer"));
      const bundleId = req.headers.get("X-Pulse-Bundle-Id");
      const originsOk = originAllowed(keyRow.allowed_origins, host);
      const bundlesOk = !bundleId || originAllowed(keyRow.allowed_bundle_ids, bundleId);
      if (!originsOk && !bundlesOk) return json({ error: "origin not allowed" }, 403);
      const scopes: string[] = keyRow.scopes || [];
      if (!scopes.includes("track:write")) return json({ error: "insufficient scope" }, 403);
    }

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

    if (path === "track" || path === "batch") {
      const events = path === "batch" ? (body.events || []) : [body];
      if (!Array.isArray(events) || events.length === 0) return json({ error: "no events" }, 400);
      const results: Array<{ ok: boolean; error?: string }> = [];
      for (const ev of events) {
        const { external_id, name, properties = {}, occurred_at } = ev;
        if (!external_id || !name) { results.push({ ok: false, error: "external_id and name required" }); continue; }
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
          occurred_at: occurred_at || new Date().toISOString(),
        });
        results.push(error ? { ok: false, error: error.message } : { ok: true });
      }
      return json({ ok: true, results });
    }

    return json({ error: "unknown route" }, 404);
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
