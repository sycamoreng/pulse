import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};
const json = (d: unknown, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });

type Insight = { journey_id: string; node_id: string; insight_kind: string; severity: string; summary: string; suggestion: string };

async function callClaude(apiKey: string, ctx: unknown): Promise<Array<{ node_id: string; summary: string; suggestion: string; severity?: string; insight_kind?: string }> | null> {
  const system = `You are a lifecycle optimisation analyst. Given a journey's structure and per-node traffic counts, identify up to 4 concrete optimisation opportunities.

Output STRICT JSON: an array of objects with:
{
  "node_id": string (the id of the node the insight applies to, or "" for a whole-journey observation),
  "insight_kind": "drop_off" | "slow_step" | "dead_end" | "path_merge" | "channel_switch" | "copy",
  "severity": "info" | "warning" | "critical",
  "summary": string (under 160 chars, plain),
  "suggestion": string (under 240 chars, actionable)
}

Rules:
- Base every insight on the provided stats; do not invent traffic you cannot see.
- Prefer suggestions a marketer can implement: change copy, shorten a wait, add a branch, swap channel.`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": apiKey, "anthropic-version": "2023-06-01" },
    body: JSON.stringify({
      model: "claude-sonnet-4-5",
      max_tokens: 1200,
      system,
      messages: [{ role: "user", content: `Context:\n${JSON.stringify(ctx, null, 2)}\n\nReturn ONLY the JSON array.` }],
    }),
  });
  if (!res.ok) return null;
  const data = await res.json();
  const text = (data?.content?.[0]?.text || "").trim();
  const match = text.match(/\[[\s\S]*\]/);
  if (!match) return null;
  try { return JSON.parse(match[0]); } catch { return null; }
}

function heuristic(journey: any, stats: Record<string, { entered: number; completed: number }>): Insight[] {
  const out: Insight[] = [];
  const nodes = Array.isArray(journey.nodes) ? journey.nodes : [];
  for (const n of nodes) {
    const s = stats[n.id];
    if (!s) continue;
    if (s.entered > 20 && s.completed / s.entered < 0.4) {
      out.push({
        journey_id: journey.id, node_id: n.id,
        insight_kind: "drop_off",
        severity: s.completed / s.entered < 0.2 ? "critical" : "warning",
        summary: `Only ${Math.round((s.completed / s.entered) * 100)}% of customers complete this step (${s.completed}/${s.entered}).`,
        suggestion: n.type === "send" ? "Revisit the copy and subject — try a tighter headline and a single clear CTA." : "Shorten this step or add a branch so not everyone has to take it.",
      });
    }
  }
  return out;
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
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY") || "";
    const body = await req.json().catch(() => ({}));
    const journeyId: string | undefined = body.journey_id;
    if (!journeyId) return json({ ok: false, error: "journey_id required" }, 400);

    const { data: journey } = await sb.from("journeys").select("*").eq("id", journeyId).maybeSingle();
    if (!journey) return json({ ok: false, error: "journey not found" }, 404);

    const authz = await authorize(req, journey.workspace_id);
    if (!authz.ok) return json({ ok: false, error: authz.error }, authz.status || 401);

    const { data: statRows } = await sb.from("journey_node_stats")
      .select("node_id, entered, completed").eq("journey_id", journeyId);
    const stats: Record<string, { entered: number; completed: number }> = {};
    for (const r of statRows || []) stats[r.node_id] = { entered: r.entered || 0, completed: r.completed || 0 };

    let insights: Insight[] = [];
    if (apiKey) {
      const claude = await callClaude(apiKey, { journey: { id: journey.id, name: journey.name, nodes: journey.nodes, edges: journey.edges }, stats });
      if (claude) {
        insights = claude.map(c => ({
          journey_id: journey.id,
          node_id: c.node_id || "",
          insight_kind: c.insight_kind || "drop_off",
          severity: c.severity || "info",
          summary: (c.summary || "").slice(0, 240),
          suggestion: (c.suggestion || "").slice(0, 400),
        }));
      }
    }
    if (!insights.length) insights = heuristic(journey, stats);

    if (!insights.length) return json({ ok: true, created: 0 });

    const rows = insights.map(i => ({ ...i, workspace_id: journey.workspace_id }));
    const { error } = await sb.from("ai_path_insights").insert(rows);
    if (error) return json({ ok: false, error: error.message }, 500);

    return json({ ok: true, created: rows.length, used_model: apiKey ? "claude" : "heuristic" });
  } catch (e) {
    return json({ ok: false, error: (e as Error).message }, 500);
  }
});
