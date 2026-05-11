import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};
const json = (d: unknown, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });

type Node = { id: string; type: "trigger" | "wait" | "send" | "branch" | "goal"; kind?: string; x: number; y: number; data: Record<string, any> };
type Edge = { from: string; to: string; label?: string };
type Draft = { name: string; description: string; trigger_event: string; nodes: Node[]; edges: Edge[]; rationale: string };

async function callClaude(apiKey: string, ctx: unknown): Promise<Draft | null> {
  const system = `You are a lifecycle architect for a customer engagement platform.
Given a business goal, trigger event, and workspace context, design a 3-6 step journey.

Output STRICT JSON matching:
{
  "name": string (under 80 chars),
  "description": string (under 240 chars),
  "trigger_event": string (a single event name in snake_case),
  "nodes": [{"id": string, "type": "trigger"|"wait"|"send"|"branch"|"goal", "kind": "email"|"push"|"sms"|"in_app"|null, "x": number, "y": number, "data": { "title"?: string, "body"?: string, "wait_hours"?: number, "condition"?: string }}],
  "edges": [{"from": string, "to": string, "label"?: string}],
  "rationale": string (under 240 chars)
}

Rules:
- Start with exactly one trigger node. End with one goal node.
- Use short, warm, plain copy. No emojis. No exaggerated claims.
- Wait steps should be realistic (minutes/hours/days, encoded as wait_hours).
- Keep it tight: 3-6 nodes.`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": apiKey, "anthropic-version": "2023-06-01" },
    body: JSON.stringify({
      model: "claude-sonnet-4-5",
      max_tokens: 1500,
      system,
      messages: [{ role: "user", content: `Context:\n${JSON.stringify(ctx, null, 2)}\n\nReturn ONLY the JSON object.` }],
    }),
  });
  if (!res.ok) return null;
  const data = await res.json();
  const text = (data?.content?.[0]?.text || "").trim();
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) return null;
  try { return JSON.parse(match[0]) as Draft; } catch { return null; }
}

function heuristic(goal: string, trigger: string): Draft {
  const t = trigger || "user_signed_up";
  const nodes: Node[] = [
    { id: "n1", type: "trigger", x: 80, y: 120, data: { event: t } },
    { id: "n2", type: "send", kind: "email", x: 280, y: 120, data: { title: "Welcome", body: "Thanks for joining — here is a 90-second tour to get value fast." } },
    { id: "n3", type: "wait", x: 480, y: 120, data: { wait_hours: 48 } },
    { id: "n4", type: "send", kind: "push", x: 680, y: 120, data: { title: "Quick win", body: "Finish setup to unlock the rest of the experience." } },
    { id: "n5", type: "goal", x: 880, y: 120, data: { event: "core_action_completed" } },
  ];
  const edges: Edge[] = [
    { from: "n1", to: "n2" },
    { from: "n2", to: "n3" },
    { from: "n3", to: "n4" },
    { from: "n4", to: "n5" },
  ];
  return {
    name: goal ? `Journey for ${goal}` : "Activation journey",
    description: "A short welcome → nudge → goal sequence.",
    trigger_event: t,
    nodes,
    edges,
    rationale: "Standard activation pattern: warm welcome, polite wait, targeted nudge, goal.",
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
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY") || "";
    const body = await req.json().catch(() => ({}));
    const workspaceId: string | undefined = body.workspace_id;
    const goal: string = (body.goal || "").toString().slice(0, 200);
    const trigger: string = (body.trigger_event || "").toString().slice(0, 80);
    if (!workspaceId || !goal) return json({ ok: false, error: "workspace_id and goal required" }, 400);

    const authz = await authorize(req, workspaceId);
    if (!authz.ok) return json({ ok: false, error: authz.error }, authz.status || 401);

    const { data: ws } = await sb.from("workspaces").select("name, industry, commerce_enabled").eq("id", workspaceId).maybeSingle();
    const { data: evDefs } = await sb.from("event_definitions").select("name, category").eq("workspace_id", workspaceId).limit(50);
    const ctx = {
      brand: { name: ws?.name, industry: ws?.industry, commerce_enabled: ws?.commerce_enabled },
      goal,
      trigger_candidates: (evDefs || []).map((e: any) => e.name),
      preferred_trigger: trigger || null,
    };

    let draft: Draft | null = null;
    if (apiKey) draft = await callClaude(apiKey, ctx);
    if (!draft) draft = heuristic(goal, trigger);

    const row = {
      workspace_id: workspaceId,
      goal,
      trigger_event: draft.trigger_event || trigger,
      name: (draft.name || "AI journey draft").slice(0, 120),
      description: (draft.description || "").slice(0, 400),
      nodes: draft.nodes || [],
      edges: draft.edges || [],
      rationale: (draft.rationale || "").slice(0, 600),
      model: apiKey ? "claude-sonnet-4-5" : "heuristic",
      status: "pending",
    };
    const { data, error } = await sb.from("ai_journey_drafts").insert(row).select().maybeSingle();
    if (error) return json({ ok: false, error: error.message }, 500);

    return json({ ok: true, draft: data, used_model: apiKey ? "claude" : "heuristic" });
  } catch (e) {
    return json({ ok: false, error: (e as Error).message }, 500);
  }
});
