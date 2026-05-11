import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

type Node = {
  id: string;
  type: string;
  kind: string;
  data?: Record<string, any>;
};
type Edge = { from: string; to: string; branch?: string };
type Journey = {
  id: string;
  workspace_id: string;
  nodes: Node[];
  edges: Edge[];
  goal?: { event?: string; window_days?: number };
};

function nextEdge(edges: Edge[], fromId: string, branch?: string): Edge | undefined {
  if (branch) {
    const match = edges.find(e => e.from === fromId && (e.branch === branch));
    if (match) return match;
  }
  return edges.find(e => e.from === fromId && (!e.branch || e.branch === "default" || e.branch === "next"));
}

function addDuration(value: number, unit: string): Date {
  const ms = unit === "minutes" ? value * 60_000
    : unit === "hours" ? value * 3_600_000
    : unit === "days" ? value * 86_400_000
    : value * 3_600_000;
  return new Date(Date.now() + ms);
}

function compareValues(a: any, op: string, b: any): boolean {
  const na = Number(a), nb = Number(b);
  if (!Number.isNaN(na) && !Number.isNaN(nb) && (op === "gt" || op === "gte" || op === "lt" || op === "lte")) {
    if (op === "gt") return na > nb;
    if (op === "gte") return na >= nb;
    if (op === "lt") return na < nb;
    if (op === "lte") return na <= nb;
  }
  const sa = String(a ?? "").toLowerCase();
  const sb = String(b ?? "").toLowerCase();
  if (op === "eq") return sa === sb;
  if (op === "neq") return sa !== sb;
  if (op === "contains") return sa.includes(sb);
  if (op === "not_contains") return !sa.includes(sb);
  if (op === "exists") return a !== null && a !== undefined && a !== "";
  if (op === "not_exists") return a === null || a === undefined || a === "";
  return false;
}

function resolveField(customer: any, field: string): any {
  if (!field) return undefined;
  if (field.startsWith("attributes.")) {
    const key = field.slice("attributes.".length);
    return customer?.attributes?.[key];
  }
  return customer?.[field];
}

async function processNode(
  sb: any,
  journey: Journey,
  enrollment: any,
  node: Node,
  customer: any,
): Promise<{ next?: string; wait_until?: string | null; waiting_for_event?: string | null; branch_taken?: string | null; status?: string; error?: string }> {
  const data = node.data || {};

  if (node.type === "exit" || node.kind === "exit") {
    return { status: "completed" };
  }

  if (node.type === "trigger") {
    const edge = nextEdge(journey.edges, node.id);
    return { next: edge?.to };
  }

  if (node.kind === "wait") {
    const existing = enrollment.wait_until ? new Date(enrollment.wait_until) : null;
    if (existing && existing.getTime() > Date.now()) {
      return { wait_until: enrollment.wait_until };
    }
    if (!existing) {
      const until = addDuration(Number(data.value) || 1, data.unit || "hours");
      return { wait_until: until.toISOString() };
    }
    const edge = nextEdge(journey.edges, node.id);
    return { next: edge?.to, wait_until: null };
  }

  if (node.kind === "wait_for_event") {
    if (enrollment.waiting_for_event === data.event) {
      // Check whether the event has since arrived.
      const { data: e } = await sb.from("events").select("id")
        .eq("workspace_id", journey.workspace_id)
        .eq("customer_id", enrollment.customer_id)
        .eq("name", data.event)
        .gte("created_at", enrollment.last_advanced_at || enrollment.entered_at)
        .limit(1).maybeSingle();
      if (e) {
        const edge = nextEdge(journey.edges, node.id, "yes") || nextEdge(journey.edges, node.id);
        return { next: edge?.to, waiting_for_event: null };
      }
      if (data.timeout_hours && enrollment.last_advanced_at) {
        const expiry = new Date(new Date(enrollment.last_advanced_at).getTime() + Number(data.timeout_hours) * 3_600_000);
        if (expiry.getTime() <= Date.now()) {
          const edge = nextEdge(journey.edges, node.id, "no") || nextEdge(journey.edges, node.id);
          return { next: edge?.to, waiting_for_event: null };
        }
      }
      return { waiting_for_event: data.event };
    }
    return { waiting_for_event: data.event };
  }

  if (node.kind === "update_attribute") {
    const key = (data.attribute || "").trim();
    if (!key) return { error: "update_attribute: no attribute set" };
    const rawValue = data.value;
    const op = data.op || "set";
    const current = { ...(customer.attributes || {}) };
    let next = current[key];
    if (op === "set") next = rawValue;
    else if (op === "increment") next = Number(current[key] || 0) + Number(rawValue || 1);
    else if (op === "decrement") next = Number(current[key] || 0) - Number(rawValue || 1);
    else if (op === "append") next = [...(Array.isArray(current[key]) ? current[key] : []), rawValue];
    else if (op === "clear") next = null;
    current[key] = next;
    await sb.from("customers").update({ attributes: current }).eq("id", customer.id);
    customer.attributes = current;
    const edge = nextEdge(journey.edges, node.id);
    return { next: edge?.to };
  }

  if (node.kind === "attribute" || (node.type === "condition" && !node.kind)) {
    const val = resolveField(customer, data.field || "country");
    const matched = compareValues(val, data.op || "eq", data.value);
    const branch = matched ? "yes" : "no";
    const edge = nextEdge(journey.edges, node.id, branch) || nextEdge(journey.edges, node.id);
    return { next: edge?.to, branch_taken: branch };
  }

  if (node.kind === "event_done") {
    const evt = data.event;
    if (!evt) return { error: "event_done: no event configured" };
    const withinHours = Number(data.within_hours) || 24;
    const since = new Date(Date.now() - withinHours * 3_600_000).toISOString();
    const { data: hit } = await sb.from("events").select("id")
      .eq("workspace_id", journey.workspace_id)
      .eq("customer_id", enrollment.customer_id)
      .eq("name", evt)
      .gte("created_at", since)
      .limit(1).maybeSingle();
    const branch = hit ? "yes" : "no";
    const edge = nextEdge(journey.edges, node.id, branch) || nextEdge(journey.edges, node.id);
    return { next: edge?.to, branch_taken: branch };
  }

  if (node.kind === "ab_split") {
    const splitA = Number(data.split_a) || 50;
    const branch = Math.random() * 100 < splitA ? "a" : "b";
    const edge = nextEdge(journey.edges, node.id, branch) || nextEdge(journey.edges, node.id);
    return { next: edge?.to, branch_taken: branch };
  }

  if (["email", "push", "sms", "whatsapp"].includes(node.kind)) {
    // Enqueue a real delivery. Test-mode workspaces skip.
    const { data: ws } = await sb.from("workspaces").select("environment").eq("id", journey.workspace_id).maybeSingle();
    if (ws?.environment !== "test") {
      await sb.from("delivery_queue").insert({
        workspace_id: journey.workspace_id,
        channel: node.kind === "whatsapp" ? "sms" : node.kind,
        journey_id: journey.id,
        customer_id: customer.id,
        status: "queued",
        next_attempt_at: new Date().toISOString(),
        payload: {
          kind: "journey",
          title: data.subject || data.body?.slice(0, 40) || "Message",
          body: data.body || "",
          to_email: node.kind === "email" ? customer.email : undefined,
          to_user_id: customer.id,
        },
      });
    }
    const edge = nextEdge(journey.edges, node.id);
    return { next: edge?.to };
  }

  // Unknown kind — try to advance anyway
  const edge = nextEdge(journey.edges, node.id);
  return { next: edge?.to };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const body = await req.json().catch(() => ({}));
    const limit = Math.min(Math.max(Number(body?.limit || 50), 1), 500);
    const nowIso = new Date().toISOString();

    const { data: enrolls } = await sb
      .from("journey_enrollments")
      .select("*")
      .in("status", ["active", "waiting"])
      .or(`wait_until.is.null,wait_until.lte.${nowIso}`)
      .order("last_advanced_at", { ascending: true, nullsFirst: true })
      .limit(limit);

    if (!enrolls?.length) {
      return new Response(JSON.stringify({ ok: true, advanced: 0 }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const journeyIds = Array.from(new Set(enrolls.map((e: any) => e.journey_id)));
    const { data: journeys } = await sb.from("journeys").select("id, workspace_id, nodes, edges, goal, status").in("id", journeyIds);
    const journeyMap = new Map<string, Journey>();
    for (const j of (journeys || [])) {
      if (j.status === "active") journeyMap.set(j.id, j);
    }

    const customerIds = Array.from(new Set(enrolls.map((e: any) => e.customer_id)));
    const { data: customers } = await sb.from("customers").select("id, email, phone, country, city, platform, device, attributes").in("id", customerIds);
    const custMap = new Map<string, any>();
    for (const c of (customers || [])) custMap.set(c.id, c);

    let advanced = 0, completed = 0, errored = 0;

    for (const en of enrolls) {
      const journey = journeyMap.get(en.journey_id);
      const customer = custMap.get(en.customer_id);
      if (!journey || !customer) continue;

      let currentId: string | null = en.current_node_id || (journey.nodes.find(n => n.type === "trigger")?.id ?? null);
      if (!currentId) continue;

      // Advance at most 10 nodes per pass to avoid runaway loops.
      let hopped = 0;
      let lastNode: Node | null = null;
      let pending: any = {};
      while (hopped < 10 && currentId) {
        const node: Node | undefined = journey.nodes.find(n => n.id === currentId);
        if (!node) { pending = { status: "completed" }; break; }
        lastNode = node;
        const result = await processNode(sb, journey, en, node, customer);
        pending = result;
        if (result.status === "completed") break;
        if (result.wait_until || result.waiting_for_event) break;
        if (!result.next) { pending = { status: "completed" }; break; }
        currentId = result.next;
        hopped++;
        en.current_node_id = currentId;
      }

      const update: any = {
        current_node_id: pending?.status === "completed" ? null : currentId,
        wait_until: pending?.wait_until ?? null,
        waiting_for_event: pending?.waiting_for_event ?? null,
        branch_taken: pending?.branch_taken ?? en.branch_taken ?? null,
        last_advanced_at: new Date().toISOString(),
        steps_done: (en.steps_done || 0) + hopped,
        last_error: pending?.error || "",
      };
      if (pending?.status === "completed") {
        update.status = "completed";
        update.completed_at = new Date().toISOString();
        completed++;
      } else if (pending?.waiting_for_event) {
        update.status = "waiting";
      } else {
        update.status = "active";
      }
      if (pending?.error) errored++;
      await sb.from("journey_enrollments").update(update).eq("id", en.id);
      advanced++;

      // Track node stats
      if (lastNode) {
        await sb.rpc("increment_journey_node_stat", { p_journey: journey.id, p_node: lastNode.id }).catch(() => {});
      }
    }

    return new Response(JSON.stringify({ ok: true, advanced, completed, errored }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
