import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

type Bucket = { name: string; window_hours: number; baseline_days: number };

function severityFor(delta: number): string {
  const a = Math.abs(delta);
  if (a >= 0.6) return "critical";
  if (a >= 0.3) return "warning";
  return "info";
}

function summarise(metric: string, dim: string, baseline: number, current: number, delta: number): string {
  const pct = Math.round(delta * 100);
  const direction = delta >= 0 ? "up" : "down";
  const dimText = dim ? ` for ${dim}` : "";
  return `${metric}${dimText} is ${direction} ${Math.abs(pct)}% vs. the prior baseline (${Math.round(baseline)} → ${Math.round(current)}).`;
}

async function countEvents(sb: any, workspaceId: string, sinceIso: string, untilIso: string, name?: string) {
  let q = sb.from("events").select("id", { count: "exact", head: true })
    .eq("workspace_id", workspaceId)
    .gte("occurred_at", sinceIso).lt("occurred_at", untilIso);
  if (name) q = q.eq("name", name);
  const { count } = await q;
  return count || 0;
}

async function countMessages(sb: any, workspaceId: string, sinceIso: string, untilIso: string, field: "opened_at" | "clicked_at" | "sent_at") {
  const { count } = await sb.from("campaign_messages")
    .select("id", { count: "exact", head: true })
    .eq("workspace_id", workspaceId)
    .gte(field, sinceIso)
    .lt(field, untilIso);
  return count || 0;
}

async function countSignals(sb: any, workspaceId: string, sinceIso: string, untilIso: string, key?: string) {
  let q = sb.from("customer_signals").select("id", { count: "exact", head: true })
    .eq("workspace_id", workspaceId)
    .gte("detected_at", sinceIso).lt("detected_at", untilIso);
  if (key) q = q.eq("signal_key", key);
  const { count } = await q;
  return count || 0;
}

async function analyse(sb: any, workspaceId: string, bucket: Bucket, metric: string, dim: string,
  fetcher: (sinceIso: string, untilIso: string) => Promise<number>) {
  const now = Date.now();
  const currentStart = new Date(now - bucket.window_hours * 3600 * 1000).toISOString();
  const currentEnd = new Date(now).toISOString();
  const baselineEnd = currentStart;
  const baselineStart = new Date(now - (bucket.window_hours + bucket.baseline_days * 24) * 3600 * 1000).toISOString();

  const current = await fetcher(currentStart, currentEnd);
  const baselineTotal = await fetcher(baselineStart, baselineEnd);
  const windows = Math.max(1, (bucket.baseline_days * 24) / bucket.window_hours);
  const baselineAvg = baselineTotal / windows;

  if (baselineAvg < 5 && current < 5) return null;
  const delta = baselineAvg === 0 ? (current > 0 ? 1 : 0) : (current - baselineAvg) / baselineAvg;
  if (Math.abs(delta) < 0.2) return null;

  const severity = severityFor(delta);
  return {
    workspace_id: workspaceId,
    kind: metric,
    metric,
    dimension: dim,
    baseline: Math.round(baselineAvg * 100) / 100,
    current,
    delta_pct: Math.round(delta * 1000) / 10,
    severity,
    summary: summarise(metric, dim, baselineAvg, current, delta),
    status: "open",
  };
}

async function authorize(req: Request, workspaceId: string): Promise<{ ok: boolean; status?: number; error?: string }> {
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
  if (!member) return { ok: false, status: 403, error: "Forbidden" };
  return { ok: true };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const body = await req.json().catch(() => ({}));
    const workspaceId: string | undefined = body.workspace_id;
    if (!workspaceId) return json({ ok: false, error: "workspace_id required" }, 400);

    const authz = await authorize(req, workspaceId);
    if (!authz.ok) return json({ ok: false, error: authz.error }, authz.status || 401);

    const bucket: Bucket = { name: "24h", window_hours: 24, baseline_days: 7 };
    const findings: any[] = [];

    const eventsFinding = await analyse(sb, workspaceId, bucket, "events_total", "",
      (s, u) => countEvents(sb, workspaceId, s, u));
    if (eventsFinding) findings.push(eventsFinding);

    const { data: topDefs } = await sb.from("event_definitions")
      .select("name").eq("workspace_id", workspaceId).limit(8);
    for (const d of topDefs || []) {
      if (!d.name) continue;
      const f = await analyse(sb, workspaceId, bucket, "event_volume", d.name,
        (s, u) => countEvents(sb, workspaceId, s, u, d.name));
      if (f) findings.push(f);
    }

    const openFinding = await analyse(sb, workspaceId, bucket, "email_opens", "",
      (s, u) => countMessages(sb, workspaceId, s, u, "opened_at"));
    if (openFinding) findings.push(openFinding);
    const clickFinding = await analyse(sb, workspaceId, bucket, "email_clicks", "",
      (s, u) => countMessages(sb, workspaceId, s, u, "clicked_at"));
    if (clickFinding) findings.push(clickFinding);

    const { data: sigDefs } = await sb.from("signal_definitions")
      .select("signal_key").eq("workspace_id", workspaceId).eq("enabled", true).limit(8);
    for (const s of sigDefs || []) {
      if (!s.signal_key) continue;
      const f = await analyse(sb, workspaceId, bucket, "signal_fires", s.signal_key,
        (a, b) => countSignals(sb, workspaceId, a, b, s.signal_key));
      if (f) findings.push(f);
    }

    const { data: existing } = await sb.from("ai_anomalies")
      .select("metric, dimension, detected_at, status")
      .eq("workspace_id", workspaceId)
      .eq("status", "open")
      .gte("detected_at", new Date(Date.now() - 12 * 3600 * 1000).toISOString());
    const dedup = new Set((existing || []).map((r: any) => `${r.metric}::${r.dimension}`));

    const toInsert = findings.filter(f => !dedup.has(`${f.metric}::${f.dimension}`));
    let created = 0;
    if (toInsert.length) {
      const { error, count } = await sb.from("ai_anomalies").insert(toInsert, { count: "exact" });
      if (error) return json({ ok: false, error: error.message }, 500);
      created = count || toInsert.length;
    }

    return json({ ok: true, scanned: findings.length, created, deduped: findings.length - toInsert.length });
  } catch (e) {
    return json({ ok: false, error: (e as Error).message }, 500);
  }
});
