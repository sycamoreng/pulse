import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

async function hmacSha256(secret: string, body: string) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  return Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const { workspace_id, event_type, payload, destination_id } = await req.json();
    if (!workspace_id || !event_type) return json({ error: "workspace_id and event_type required" }, 400);

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    let query = supabase.from("webhook_destinations").select("*")
      .eq("workspace_id", workspace_id).eq("is_active", true);
    if (destination_id) query = query.eq("id", destination_id);

    const { data: dests } = await query;
    if (!dests?.length) return json({ ok: true, delivered: 0 });

    let delivered = 0;
    for (const dest of dests) {
      const filters: string[] = dest.event_filters || [];
      if (filters.length && !filters.includes(event_type) && !filters.includes("*")) continue;

      const body = JSON.stringify({ event_type, workspace_id, payload, sent_at: new Date().toISOString() });
      const signature = dest.secret ? await hmacSha256(dest.secret, body) : "";

      const MAX_ATTEMPTS = 3;
      let ok = false;
      let status = 0;
      let responseText = "";
      let attempt = 0;
      for (attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
        try {
          const res = await fetch(dest.url, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-Pulse-Signature": signature,
              "X-Pulse-Event": event_type,
              "X-Pulse-Attempt": String(attempt),
            },
            body,
          });
          status = res.status;
          ok = res.ok;
          responseText = (await res.text()).slice(0, 500);
        } catch (e) {
          responseText = String(e).slice(0, 500);
          status = 0;
          ok = false;
        }
        if (ok) break;
        if (attempt < MAX_ATTEMPTS) {
          const delay = Math.min(4000, 250 * Math.pow(2, attempt - 1));
          await new Promise(r => setTimeout(r, delay));
        }
      }

      await supabase.from("webhook_deliveries").insert({
        workspace_id, destination_id: dest.id, event_type, status_code: status,
        ok, payload, response: responseText, attempt,
      });
      if (ok) {
        await supabase.from("webhook_destinations").update({
          last_success_at: new Date().toISOString(), failure_count: 0,
        }).eq("id", dest.id);
        delivered++;
      } else {
        await supabase.from("webhook_destinations").update({
          last_failure_at: new Date().toISOString(), failure_count: (dest.failure_count || 0) + 1,
        }).eq("id", dest.id);
        await supabase.from("webhook_dlq").insert({
          workspace_id, destination_id: dest.id, event_type, payload,
          last_error: responseText, last_status: status, attempts: attempt,
        });
      }
    }
    return json({ ok: true, delivered });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
