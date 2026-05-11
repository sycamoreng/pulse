import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const BACKOFF_SECONDS = [30, 120, 600, 1800, 7200];

function nextBackoff(attempts: number): string {
  const idx = Math.min(attempts, BACKOFF_SECONDS.length - 1);
  return new Date(Date.now() + BACKOFF_SECONDS[idx] * 1000).toISOString();
}

// Returns an ISO timestamp when the quiet window ends, or null if not currently in quiet hours.
function quietDeferUntil(tz: string, qs: number, qe: number): string | null {
  try {
    const now = new Date();
    const hourStr = new Intl.DateTimeFormat("en-US", { hour: "2-digit", hour12: false, timeZone: tz || "UTC" }).format(now);
    const hour = parseInt(hourStr, 10);
    const inQuiet = qs > qe ? (hour >= qs || hour < qe) : (hour >= qs && hour < qe);
    if (!inQuiet) return null;
    let hoursUntil = (qe - hour + 24) % 24;
    if (hoursUntil === 0) hoursUntil = 24;
    return new Date(now.getTime() + hoursUntil * 3600 * 1000).toISOString();
  } catch { return null; }
}

async function invoke(sb: any, fn: string, body: any): Promise<{ok: boolean; error?: string}> {
  const url = `${Deno.env.get("SUPABASE_URL")}/functions/v1/${fn}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) return { ok: false, error: JSON.stringify(json) };
  if (json?.email?.status && json.email.status !== "sent" && json.email.status !== "queued") {
    return { ok: false, error: json.email.error || json.email.status };
  }
  return { ok: true };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const body = await req.json().catch(() => ({}));
    const limit = Math.min(Math.max(Number(body?.limit || 25), 1), 200);

    const { data: batch } = await sb
      .from("delivery_queue")
      .select("*")
      .eq("status", "queued")
      .lte("next_attempt_at", new Date().toISOString())
      .order("next_attempt_at", { ascending: true })
      .limit(limit);

    if (!batch?.length) {
      return new Response(JSON.stringify({ ok: true, picked: 0 }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Quiet-hours deferral: per workspace+channel, reschedule instead of sending.
    const wsIds = Array.from(new Set(batch.map((r: any) => r.workspace_id)));
    const { data: wsRows } = await sb.from("workspaces").select("id,timezone").in("id", wsIds);
    const { data: polRows } = await sb.from("messaging_policies").select("workspace_id,channel,quiet_start,quiet_end").in("workspace_id", wsIds);
    const tzByWs = new Map<string, string>((wsRows || []).map((w: any) => [w.id, w.timezone || "UTC"]));
    const polByKey = new Map<string, any>((polRows || []).map((p: any) => [`${p.workspace_id}::${p.channel}`, p]));

    const deferred: string[] = [];
    const runnable: any[] = [];
    for (const item of batch) {
      const pol = polByKey.get(`${item.workspace_id}::${item.channel}`);
      if (pol?.quiet_start && pol?.quiet_end) {
        const qs = parseInt(String(pol.quiet_start).split(":")[0], 10);
        const qe = parseInt(String(pol.quiet_end).split(":")[0], 10);
        if (!Number.isNaN(qs) && !Number.isNaN(qe)) {
          const defer = quietDeferUntil(tzByWs.get(item.workspace_id) || "UTC", qs, qe);
          if (defer) {
            await sb.from("delivery_queue").update({ status: "queued", next_attempt_at: defer, last_error: "deferred_quiet_hours" }).eq("id", item.id);
            deferred.push(item.id);
            continue;
          }
        }
      }
      runnable.push(item);
    }

    if (!runnable.length) {
      return new Response(JSON.stringify({ ok: true, picked: batch.length, deferred: deferred.length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const ids = runnable.map((r: any) => r.id);
    await sb.from("delivery_queue").update({ status: "running" }).in("id", ids);

    let sent = 0, failed = 0, retried = 0;

    for (const item of runnable) {
      const attempts = (item.attempts || 0) + 1;
      let ok = false;
      let err = "";

      try {
        if (item.channel === "email") {
          const r = await invoke(sb, "notify", { ...(item.payload || {}), workspace_id: item.workspace_id, send_email: true });
          ok = r.ok; err = r.error || "";
        } else if (item.channel === "push") {
          const r = await invoke(sb, "push-dispatch", { ...(item.payload || {}), workspace_id: item.workspace_id });
          ok = r.ok; err = r.error || "";
        } else if (item.channel === "webhook") {
          const r = await invoke(sb, "webhook-dispatch", { ...(item.payload || {}), workspace_id: item.workspace_id });
          ok = r.ok; err = r.error || "";
        } else if (item.channel === "sms" || item.channel === "whatsapp" || item.channel === "rcs") {
          const r = await invoke(sb, "sms-dispatch", { ...(item.payload || {}), workspace_id: item.workspace_id, channel: item.channel });
          ok = r.ok; err = r.error || "";
        } else {
          ok = false; err = `Unsupported channel: ${item.channel}`;
        }
      } catch (e) {
        ok = false; err = String(e);
      }

      if (ok) {
        await sb.from("delivery_queue").update({
          status: "sent", attempts, sent_at: new Date().toISOString(), last_error: "",
        }).eq("id", item.id);
        sent++;
      } else if (attempts >= (item.max_attempts || 5)) {
        await sb.from("delivery_queue").update({
          status: "failed", attempts, last_error: err,
        }).eq("id", item.id);
        failed++;
      } else {
        await sb.from("delivery_queue").update({
          status: "queued", attempts, last_error: err, next_attempt_at: nextBackoff(attempts),
        }).eq("id", item.id);
        retried++;
      }
    }

    return new Response(JSON.stringify({ ok: true, picked: batch.length, sent, failed, retried, deferred: deferred.length }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
