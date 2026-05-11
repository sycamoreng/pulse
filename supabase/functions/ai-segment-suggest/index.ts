import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};
const json = (d: unknown, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });

type Suggestion = {
  name: string;
  description: string;
  rules: { conditions: Array<{ field: string; op: string; value: any }> };
  rationale: string;
  expected_count?: number;
};

async function callClaude(apiKey: string, context: unknown): Promise<Suggestion[] | null> {
  const system = `You are a customer-segmentation strategist for a customer engagement platform.
Given a workspace's recent signals, events, and industry context, propose 3-5 high-value segments.

Output STRICT JSON: an array of objects matching:
{
  "name": string (under 60 chars, specific),
  "description": string (under 180 chars),
  "rules": { "conditions": [{ "field": string, "op": "eq"|"neq"|"gt"|"lt"|"gte"|"lte"|"contains"|"in"|"not_in"|"exists"|"not_exists", "value": any }] },
  "rationale": string (under 240 chars, why this segment now)
}

Rules:
- Use fields like attributes.<key>, last_seen_at, events.<event_name>.count, events.<event_name>.last_at, signals.<signal_key>.
- Never fabricate fields that do not appear in the provided context.
- Segments must be actionable: ship a campaign or a journey from them.`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": apiKey, "anthropic-version": "2023-06-01" },
    body: JSON.stringify({
      model: "claude-sonnet-4-5",
      max_tokens: 1400,
      system,
      messages: [{ role: "user", content: `Context:\n${JSON.stringify(context, null, 2)}\n\nReturn ONLY the JSON array.` }],
    }),
  });
  if (!res.ok) return null;
  const data = await res.json();
  const text = (data?.content?.[0]?.text || "").trim();
  const match = text.match(/\[[\s\S]*\]/);
  if (!match) return null;
  try { return JSON.parse(match[0]) as Suggestion[]; } catch { return null; }
}

function heuristics(industry: string, signalKeys: string[]): Suggestion[] {
  const out: Suggestion[] = [];
  if (signalKeys.includes("cart_abandoned") || industry === "commerce") {
    out.push({
      name: "Recent cart abandoners",
      description: "Customers with an open cart signal in the last 3 days.",
      rules: { conditions: [{ field: "signals.cart_abandoned", op: "exists", value: true }] },
      rationale: "High-intent, recoverable revenue. Good for a short email + push sequence.",
    });
  }
  if (industry === "fintech" || signalKeys.includes("first_deposit_pending")) {
    out.push({
      name: "Onboarded, no deposit",
      description: "Accounts created but no funding event yet.",
      rules: { conditions: [{ field: "events.account_opened.count", op: "gte", value: 1 }, { field: "events.deposit_made.count", op: "eq", value: 0 }] },
      rationale: "Unlocks the core product and activates the lifetime value curve.",
    });
  }
  out.push({
    name: "Quiet for 14+ days",
    description: "Customers that have not engaged in the last two weeks.",
    rules: { conditions: [{ field: "last_seen_at", op: "lt", value: "now-14d" }] },
    rationale: "Reactivation window — cheaper than acquiring new ones.",
  });
  out.push({
    name: "Power users",
    description: "Highly active this week across multiple events.",
    rules: { conditions: [{ field: "events.total.count_7d", op: "gte", value: 25 }] },
    rationale: "Ripe for referral, review, and advocacy programs.",
  });
  return out;
}

async function estimate(sb: any, workspaceId: string): Promise<number> {
  const { count } = await sb.from("customers").select("id", { count: "exact", head: true }).eq("workspace_id", workspaceId);
  return count || 0;
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
    const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY") || "";
    const body = await req.json().catch(() => ({}));
    const workspaceId: string | undefined = body.workspace_id;
    if (!workspaceId) return json({ ok: false, error: "workspace_id required" }, 400);

    const authz = await authorize(req, workspaceId);
    if (!authz.ok) return json({ ok: false, error: authz.error }, authz.status || 401);

    const { data: ws } = await sb.from("workspaces").select("name, industry, commerce_enabled").eq("id", workspaceId).maybeSingle();
    const industry: string = (ws?.industry as string) || "generic";

    const [{ data: eventDefs }, { data: signalDefs }, { data: recentSignals }] = await Promise.all([
      sb.from("event_definitions").select("name, category").eq("workspace_id", workspaceId).limit(40),
      sb.from("signal_definitions").select("signal_key, category").eq("workspace_id", workspaceId).limit(40),
      sb.from("customer_signals").select("signal_key, category").eq("workspace_id", workspaceId).is("consumed_at", null).limit(200),
    ]);

    const signalKeys = Array.from(new Set((recentSignals || []).map((r: any) => r.signal_key).filter(Boolean)));
    const context = {
      brand: { name: ws?.name, industry, commerce_enabled: ws?.commerce_enabled },
      events: (eventDefs || []).map((e: any) => ({ name: e.name, category: e.category })),
      signals: (signalDefs || []).map((s: any) => ({ key: s.signal_key, category: s.category })),
      recent_signal_keys: signalKeys,
    };

    let suggestions: Suggestion[] | null = null;
    if (anthropicKey) suggestions = await callClaude(anthropicKey, context);
    if (!suggestions || !suggestions.length) suggestions = heuristics(industry, signalKeys);

    const total = await estimate(sb, workspaceId);
    const rows = suggestions.slice(0, 6).map(s => ({
      workspace_id: workspaceId,
      name: s.name.slice(0, 120),
      description: (s.description || "").slice(0, 400),
      rules: s.rules || { conditions: [] },
      expected_count: s.expected_count ?? Math.max(0, Math.round(total * 0.1)),
      rationale: (s.rationale || "").slice(0, 600),
      model: anthropicKey ? "claude-sonnet-4-5" : "heuristic",
      status: "pending",
    }));

    if (!rows.length) return json({ ok: true, created: 0 });
    const { error } = await sb.from("ai_segment_suggestions").insert(rows);
    if (error) return json({ ok: false, error: error.message }, 500);

    return json({ ok: true, created: rows.length, used_model: anthropicKey ? "claude" : "heuristic" });
  } catch (e) {
    return json({ ok: false, error: (e as Error).message }, 500);
  }
});
