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
