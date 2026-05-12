import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey, X-Api-Key, X-Pulse-Bundle-Id, X-Idempotency-Key, Idempotency-Key",
};

const json = (data: unknown, status = 200, extra: Record<string, string> = {}) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", ...extra },
  });

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

const DEFAULT_RATE = 600;

async function checkRate(supabase: any, workspaceId: string, keyId: string, limit: number) {
  const now = new Date();
  const windowStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), now.getUTCHours(), now.getUTCMinutes())).toISOString();
  const bucketKey = `ingest:${keyId}`;
  const { data } = await supabase.from("rate_limits")
    .select("count")
    .eq("workspace_id", workspaceId)
    .eq("key", bucketKey)
    .eq("window_start", windowStart)
    .maybeSingle();
  const current = Number(data?.count || 0);
  if (current >= limit) return { ok: false, current, limit, retryAfter: 60 - now.getUTCSeconds() };
  await supabase.from("rate_limits").upsert(
    { workspace_id: workspaceId, key: bucketKey, window_start: windowStart, count: current + 1 },
    { onConflict: "workspace_id,key,window_start" },
  );
  return { ok: true, current: current + 1, limit };
}

const nowIso = () => new Date().toISOString();

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
      .select("id, workspace_id, key_type, scopes, allowed_origins, allowed_bundle_ids, revoked_at, expires_at")
      .eq("key", apiKey)
      .maybeSingle();
    if (!keyRow) return json({ error: "invalid api key" }, 401);
    if (keyRow.revoked_at) return json({ error: "key revoked" }, 401);
    if (keyRow.expires_at && new Date(keyRow.expires_at) < new Date()) return json({ error: "key expired" }, 401);
    supabase.rpc("touch_api_key", { p_key_id: keyRow.id }).then(() => {}, () => {});

    if (keyRow.key_type === "publishable") {
      const host = originHost(req.headers.get("Origin") || req.headers.get("Referer"));
      const bundleId = req.headers.get("X-Pulse-Bundle-Id");
      const originsOk = originAllowed(keyRow.allowed_origins, host);
      const bundlesOk = !bundleId || originAllowed(keyRow.allowed_bundle_ids, bundleId);
      if (!originsOk && !bundlesOk) return json({ error: "origin not allowed" }, 403);
      const scopes: string[] = Array.isArray(keyRow.scopes) ? keyRow.scopes : [];
      if (scopes.length && !scopes.includes("track:write")) return json({ error: "insufficient scope" }, 403);
    }

    const workspaceId = keyRow.workspace_id;
    const url = new URL(req.url);
    const path = url.pathname.replace(/\/+$/, "").split("/").pop();

    const rate = await checkRate(supabase, workspaceId, keyRow.id, DEFAULT_RATE);
    if (!rate.ok) {
      return json(
        { error: "rate limited", limit: rate.limit, retry_after_seconds: rate.retryAfter },
        429,
        { "Retry-After": String(rate.retryAfter), "X-RateLimit-Limit": String(rate.limit) },
      );
    }

    const idempotencyKey = req.headers.get("X-Idempotency-Key") || req.headers.get("Idempotency-Key") || "";
    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};

    if (path === "identify") {
      const { external_id, anon_id, traits = {} } = body;
      const eid = external_id || anon_id;
      if (!eid) return json({ error: "external_id or anon_id required" }, 400);
      const defaults = ["email", "phone", "first_name", "last_name", "country", "city", "device", "platform"];
      const rec: Record<string, unknown> = { workspace_id: workspaceId, external_id: eid, last_seen_at: nowIso() };
      const attrs: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(traits)) {
        if (defaults.includes(k)) rec[k] = v;
        else attrs[k] = v;
      }
      if (Object.keys(attrs).length) rec.attributes = attrs;
      const { data, error } = await supabase.from("customers").upsert(rec, { onConflict: "workspace_id,external_id" }).select().maybeSingle();
      if (error) return json({ error: error.message }, 400);

      // Anonymous → identified merge: move anon events onto the identified row
      if (anon_id && external_id && anon_id !== external_id) {
        const { data: anonRow } = await supabase.from("customers").select("id")
          .eq("workspace_id", workspaceId).eq("external_id", anon_id).maybeSingle();
        if (anonRow && data && anonRow.id !== data.id) {
          await supabase.from("events").update({ customer_id: data.id }).eq("customer_id", anonRow.id);
          await supabase.from("device_tokens").update({ customer_id: data.id }).eq("customer_id", anonRow.id);
          await supabase.from("customers").delete().eq("id", anonRow.id);
        }
      }
      return json({ ok: true, customer: data });
    }

    if (path === "alias") {
      const { external_id, previous_id } = body;
      if (!external_id || !previous_id) return json({ error: "external_id and previous_id required" }, 400);
      if (external_id === previous_id) return json({ ok: true, merged: false });

      await supabase.from("customers").upsert(
        { workspace_id: workspaceId, external_id, last_seen_at: nowIso() },
        { onConflict: "workspace_id,external_id" },
      );
      const [{ data: prior }, { data: target }] = await Promise.all([
        supabase.from("customers").select("id").eq("workspace_id", workspaceId).eq("external_id", previous_id).maybeSingle(),
        supabase.from("customers").select("id").eq("workspace_id", workspaceId).eq("external_id", external_id).maybeSingle(),
      ]);
      if (prior && target && prior.id !== target.id) {
        await supabase.from("events").update({ customer_id: target.id }).eq("customer_id", prior.id);
        await supabase.from("device_tokens").update({ customer_id: target.id }).eq("customer_id", prior.id);
        await supabase.from("customers").delete().eq("id", prior.id);
        return json({ ok: true, merged: true });
      }
      return json({ ok: true, merged: false });
    }

    if (path === "track" || path === "batch") {
      const events: any[] = path === "batch" ? (body.events || []) : [body];
      if (!Array.isArray(events) || events.length === 0) return json({ error: "no events" }, 400);
      if (events.length > 500) return json({ error: "max 500 events per batch" }, 413);

      if (idempotencyKey) {
        const { data: existing } = await supabase.from("events").select("id")
          .eq("workspace_id", workspaceId).eq("idempotency_key", idempotencyKey).limit(1).maybeSingle();
        if (existing) return json({ ok: true, deduped: true, count: 0 });
      }

      const valid = events.filter(e => e?.external_id && e?.name);
      if (!valid.length) return json({ error: "external_id and name required" }, 400);

      const externalIds = Array.from(new Set(valid.map(e => e.external_id)));
      const eventNames = Array.from(new Set(valid.map(e => e.name)));
      const stamp = nowIso();

      const custRows = externalIds.map(id => ({ workspace_id: workspaceId, external_id: id, last_seen_at: stamp }));
      const { error: custErr } = await supabase.from("customers").upsert(custRows, { onConflict: "workspace_id,external_id" });
      if (custErr) return json({ error: `customers: ${custErr.message}` }, 400);

      const { data: customers } = await supabase.from("customers")
        .select("id, external_id").eq("workspace_id", workspaceId).in("external_id", externalIds);
      const customerMap = new Map<string, string>();
      for (const c of customers || []) customerMap.set(c.external_id, c.id);

      const defRows = eventNames.map(n => ({ workspace_id: workspaceId, name: n, category: "custom" }));
      await supabase.from("event_definitions").upsert(defRows, { onConflict: "workspace_id,name" });

      const rows = valid
        .filter(e => customerMap.has(e.external_id))
        .map(e => ({
          workspace_id: workspaceId,
          customer_id: customerMap.get(e.external_id),
          name: e.name,
          properties: e.properties || {},
          occurred_at: e.occurred_at || stamp,
          idempotency_key: idempotencyKey || null,
        }));
      const { error: evErr } = await supabase.from("events").insert(rows);
      if (evErr) return json({ error: `events: ${evErr.message}` }, 400);

      await supabase.rpc("increment_usage", { p_workspace_id: workspaceId, p_events: rows.length });
      return json({ ok: true, count: rows.length, rate: { used: rate.current, limit: rate.limit } });
    }

    if (path === "devices" && req.method === "POST") {
      const { external_id, platform, token, app_id, bundle_id } = body;
      if (!external_id || !platform || !token) return json({ error: "external_id, platform, token required" }, 400);
      if (!["web", "ios", "android"].includes(platform)) return json({ error: "platform must be web|ios|android" }, 400);

      await supabase.from("customers").upsert(
        { workspace_id: workspaceId, external_id, last_seen_at: nowIso() },
        { onConflict: "workspace_id,external_id" },
      );
      const { data: customer } = await supabase.from("customers").select("id")
        .eq("workspace_id", workspaceId).eq("external_id", external_id).maybeSingle();
      if (!customer) return json({ error: "could not resolve customer" }, 400);

      const { error } = await supabase.from("device_tokens").upsert({
        workspace_id: workspaceId,
        customer_id: customer.id,
        platform,
        token: typeof token === "string" ? token : JSON.stringify(token),
        app_id: app_id || null,
        bundle_id: bundle_id || "",
        last_seen_at: nowIso(),
        revoked_at: null,
      }, { onConflict: "workspace_id,token" });
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    if (path === "messages" && req.method === "GET") {
      const externalId = url.searchParams.get("external_id") || "";
      const placement = url.searchParams.get("placement") || "";
      if (!externalId) return json({ error: "external_id required" }, 400);

      const { data: customer } = await supabase.from("customers").select("id")
        .eq("workspace_id", workspaceId).eq("external_id", externalId).maybeSingle();
      if (!customer) return json({ ok: true, messages: [] });

      let q = supabase.from("in_app_messages")
        .select("id, placement, title, body, image_url, cta_label, cta_url, payload, seen_at, dismissed_at, clicked_at, expires_at, created_at")
        .eq("workspace_id", workspaceId)
        .eq("customer_id", customer.id)
        .is("dismissed_at", null)
        .or(`expires_at.is.null,expires_at.gt.${nowIso()}`)
        .order("created_at", { ascending: false })
        .limit(50);
      if (placement) q = q.eq("placement", placement);

      const { data: messages, error } = await q;
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true, messages: messages || [] });
    }

    if (path === "messages" && (req.method === "POST" || req.method === "PATCH")) {
      const { id, external_id, action } = body as { id?: string; external_id?: string; action?: string };
      if (!id || !external_id || !action) return json({ error: "id, external_id, action required" }, 400);
      if (!["seen", "clicked", "dismissed"].includes(action)) return json({ error: "action must be seen|clicked|dismissed" }, 400);

      const { data: customer } = await supabase.from("customers").select("id")
        .eq("workspace_id", workspaceId).eq("external_id", external_id).maybeSingle();
      if (!customer) return json({ error: "unknown customer" }, 404);

      const patch: Record<string, string> = {};
      if (action === "seen") patch.seen_at = nowIso();
      if (action === "clicked") patch.clicked_at = nowIso();
      if (action === "dismissed") patch.dismissed_at = nowIso();

      const { error } = await supabase.from("in_app_messages")
        .update(patch)
        .eq("id", id)
        .eq("workspace_id", workspaceId)
        .eq("customer_id", customer.id);
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    if (path === "devices" && req.method === "DELETE") {
      const token = url.searchParams.get("token") || body.token;
      if (!token) return json({ error: "token required" }, 400);
      await supabase.from("device_tokens").update({ revoked_at: nowIso() })
        .eq("workspace_id", workspaceId).eq("token", token);
      return json({ ok: true });
    }

    return json({ error: "unknown route" }, 404);
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
