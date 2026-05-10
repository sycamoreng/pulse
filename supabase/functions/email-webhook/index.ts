import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

// Accepts webhook payloads from SES (via SNS), Postmark, and Resend.
// Records bounces/complaints to email_suppressions scoped to workspace.
// Workspace is matched by the sender domain of the original send.

async function lookupWorkspaceByEmail(supabase: any, emailOrDomain: string): Promise<string | null> {
  const domain = emailOrDomain.split("@").pop()?.toLowerCase() || emailOrDomain.toLowerCase();
  const { data } = await supabase.from("email_domains").select("workspace_id").eq("domain", domain).maybeSingle();
  return data?.workspace_id || null;
}

async function record(supabase: any, workspaceId: string, email: string, reason: string, source: string, details: any) {
  if (!workspaceId || !email) return;
  await supabase.from("email_suppressions").upsert({
    workspace_id: workspaceId,
    email: email.toLowerCase(),
    reason, source, details,
  }, { onConflict: "workspace_id,email" });
  if (reason === "complaint" || reason === "hard_bounce") {
    await checkAndMaybeSuspend(supabase, workspaceId, reason);
  }
}

async function checkAndMaybeSuspend(supabase: any, workspaceId: string, reason: string) {
  const { data: policy } = await supabase.from("sending_policies").select("*").eq("workspace_id", workspaceId).maybeSingle();
  if (!policy?.auto_suspend_on_breach) return;
  const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
  const { count: sentCount } = await supabase.from("transactional_sends").select("id", { count: "exact", head: true })
    .eq("workspace_id", workspaceId).eq("status", "sent").gte("sent_at", since);
  if (!sentCount || sentCount < 100) return;

  const metric = reason === "complaint" ? "complaint_rate_24h" : "bounce_rate_24h";
  const threshold = reason === "complaint" ? Number(policy.complaint_rate_threshold) : Number(policy.bounce_rate_threshold);
  const suppressReason = reason === "complaint" ? "complaint" : "hard_bounce";
  const { count: badCount } = await supabase.from("email_suppressions").select("email", { count: "exact", head: true })
    .eq("workspace_id", workspaceId).eq("reason", suppressReason).gte("created_at", since);
  const rate = (badCount || 0) / sentCount;
  if (rate < threshold) return;

  await supabase.from("workspaces").update({
    sending_paused: true,
    sending_paused_reason: `Auto-suspended: ${metric} ${(rate * 100).toFixed(3)}% >= ${(threshold * 100).toFixed(3)}%`,
  }).eq("id", workspaceId);
  await supabase.from("sending_suspensions").insert({
    workspace_id: workspaceId, reason: "auto_suspend", metric, metric_value: rate, threshold,
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const url = new URL(req.url);
    const source = url.searchParams.get("source") || "ses";
    const body = await req.text();

    // SNS subscription confirmation for SES
    if (source === "ses") {
      let msg: any;
      try { msg = JSON.parse(body); } catch { msg = {}; }
      if (msg.Type === "SubscriptionConfirmation" && msg.SubscribeURL) {
        await fetch(msg.SubscribeURL);
        return new Response("subscribed", { headers: corsHeaders });
      }
      const notif = msg.Message ? JSON.parse(msg.Message) : msg;
      const senderEmail = notif?.mail?.source || "";
      const workspaceId = await lookupWorkspaceByEmail(supabase, senderEmail);
      if (!workspaceId) return new Response("no workspace", { headers: corsHeaders });

      if (notif.notificationType === "Bounce") {
        const hard = (notif.bounce?.bounceType || "").toLowerCase() === "permanent";
        for (const r of (notif.bounce?.bouncedRecipients || [])) {
          await record(supabase, workspaceId, r.emailAddress, hard ? "hard_bounce" : "soft_bounce", "ses", r);
        }
      } else if (notif.notificationType === "Complaint") {
        for (const r of (notif.complaint?.complainedRecipients || [])) {
          await record(supabase, workspaceId, r.emailAddress, "complaint", "ses", r);
        }
      }
      return new Response("ok", { headers: corsHeaders });
    }

    if (source === "postmark") {
      const evt = JSON.parse(body);
      const from = evt?.From || "";
      const workspaceId = await lookupWorkspaceByEmail(supabase, from);
      if (!workspaceId) return new Response("no workspace", { headers: corsHeaders });
      const type = (evt?.RecordType || "").toLowerCase();
      const email = evt?.Email || evt?.Recipient || "";
      if (type === "bounce" && evt?.TypeCode === 1) await record(supabase, workspaceId, email, "hard_bounce", "postmark", evt);
      else if (type === "spamcomplaint") await record(supabase, workspaceId, email, "complaint", "postmark", evt);
      return new Response("ok", { headers: corsHeaders });
    }

    if (source === "resend") {
      const evt = JSON.parse(body);
      const type = evt?.type || "";
      const email = evt?.data?.to?.[0] || evt?.data?.email || "";
      const from = evt?.data?.from || "";
      const workspaceId = await lookupWorkspaceByEmail(supabase, from);
      if (!workspaceId) return new Response("no workspace", { headers: corsHeaders });
      if (type === "email.bounced") await record(supabase, workspaceId, email, "hard_bounce", "resend", evt.data);
      else if (type === "email.complained") await record(supabase, workspaceId, email, "complaint", "resend", evt.data);
      return new Response("ok", { headers: corsHeaders });
    }

    return new Response("unknown source", { status: 400, headers: corsHeaders });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
