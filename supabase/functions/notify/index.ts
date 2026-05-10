import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

interface NotifyPayload {
  workspace_id: string;
  to_email?: string;
  to_user_id?: string | null;
  kind: string;
  title: string;
  body?: string;
  link?: string;
  send_email?: boolean;
  stream_override?: "bulk" | "transactional";
}

const TRANSACTIONAL_KINDS = new Set([
  "invite", "approval_approved", "approval_rejected",
  "export_ready", "password_reset", "otp", "receipt",
]);

function renderEmail(title: string, body: string, link?: string, brand = "#3087B9") {
  return `<!doctype html><html><body style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;background:#F4F6F8;padding:32px">
    <div style="max-width:560px;margin:0 auto;background:white;border-radius:12px;overflow:hidden;border:1px solid #E5E9EF">
      <div style="background:${brand};padding:20px 24px;color:white;font-weight:700;font-size:16px">Pulse Engagement Cloud</div>
      <div style="padding:24px">
        <h2 style="margin:0 0 12px;font-size:18px;color:#0E1726">${title}</h2>
        <div style="color:#4B5768;font-size:14px;line-height:1.6">${body.replace(/\n/g, "<br>")}</div>
        ${link ? `<a href="${link}" style="display:inline-block;margin-top:20px;padding:10px 18px;background:${brand};color:white;border-radius:8px;text-decoration:none;font-weight:600;font-size:14px">Open</a>` : ""}
      </div>
      <div style="padding:16px 24px;color:#8491A3;font-size:11px;border-top:1px solid #F0F3F6">You're receiving this because you're a member of this workspace.</div>
    </div>
  </body></html>`;
}

async function sendViaResend(apiKey: string, from: string, to: string, subject: string, html: string) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from, to, subject, html }),
  });
  const data = await res.json().catch(() => ({}));
  return { ok: res.ok, id: data?.id || "", error: res.ok ? "" : JSON.stringify(data) };
}

async function sendViaPostmark(token: string, from: string, to: string, subject: string, html: string, stream: string) {
  const res = await fetch("https://api.postmarkapp.com/email", {
    method: "POST",
    headers: { "X-Postmark-Server-Token": token, "Accept": "application/json", "Content-Type": "application/json" },
    body: JSON.stringify({ From: from, To: to, Subject: subject, HtmlBody: html, MessageStream: stream || "outbound" }),
  });
  const data = await res.json().catch(() => ({}));
  return { ok: res.ok, id: data?.MessageID || "", error: res.ok ? "" : JSON.stringify(data) };
}

// AWS SigV4 signing for SES SendEmail (v2 API)
async function hmac(key: ArrayBuffer | Uint8Array, data: string) {
  const k = await crypto.subtle.importKey("raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(data)));
}
async function sha256Hex(s: string) {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(h)).map(b => b.toString(16).padStart(2, "0")).join("");
}
function toHex(buf: Uint8Array) { return Array.from(buf).map(b => b.toString(16).padStart(2, "0")).join(""); }

async function sendViaSes(accessKey: string, secretKey: string, region: string, configSet: string, from: string, to: string, subject: string, html: string) {
  const host = `email.${region}.amazonaws.com`;
  const path = "/v2/email/outbound-emails";
  const body = JSON.stringify({
    FromEmailAddress: from,
    Destination: { ToAddresses: [to] },
    Content: { Simple: { Subject: { Data: subject, Charset: "UTF-8" }, Body: { Html: { Data: html, Charset: "UTF-8" } } } },
    ...(configSet ? { ConfigurationSetName: configSet } : {}),
  });

  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, "");
  const dateStamp = amzDate.slice(0, 8);
  const service = "ses";
  const payloadHash = await sha256Hex(body);
  const canonicalHeaders = `content-type:application/json\nhost:${host}\nx-amz-date:${amzDate}\n`;
  const signedHeaders = "content-type;host;x-amz-date";
  const canonicalRequest = `POST\n${path}\n\n${canonicalHeaders}\n${signedHeaders}\n${payloadHash}`;
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const stringToSign = `AWS4-HMAC-SHA256\n${amzDate}\n${credentialScope}\n${await sha256Hex(canonicalRequest)}`;

  const kDate = await hmac(new TextEncoder().encode("AWS4" + secretKey), dateStamp);
  const kRegion = await hmac(kDate, region);
  const kService = await hmac(kRegion, service);
  const kSigning = await hmac(kService, "aws4_request");
  const signature = toHex(await hmac(kSigning, stringToSign));

  const authHeader = `AWS4-HMAC-SHA256 Credential=${accessKey}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  const res = await fetch(`https://${host}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Amz-Date": amzDate, "Authorization": authHeader },
    body,
  });
  const data = await res.json().catch(() => ({}));
  return { ok: res.ok, id: data?.MessageId || "", error: res.ok ? "" : JSON.stringify(data) };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const payload: NotifyPayload = await req.json();
    if (!payload.workspace_id || !payload.title) {
      return new Response(JSON.stringify({ error: "workspace_id and title required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: ws } = await supabase.from("workspaces").select("*").eq("id", payload.workspace_id).maybeSingle();
    const brand = ws?.brand_primary || "#3087B9";

    await supabase.from("notifications").insert({
      workspace_id: payload.workspace_id,
      user_id: payload.to_user_id || null,
      user_email: payload.to_email || "",
      kind: payload.kind,
      title: payload.title,
      body: payload.body || "",
      link: payload.link || "",
    });

    let emailResult: any = { sent: false };
    if (payload.send_email && payload.to_email) {
      // Paused?
      if (ws?.sending_paused) {
        await supabase.from("transactional_sends").insert({
          workspace_id: payload.workspace_id, to_email: payload.to_email,
          kind: payload.kind, status: "paused", error: ws.sending_paused_reason || "Sending paused",
        });
        return new Response(JSON.stringify({ ok: true, email: { sent: false, status: "paused", error: ws.sending_paused_reason } }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const { data: policy } = await supabase.from("sending_policies").select("*").eq("workspace_id", payload.workspace_id).maybeSingle();
      const isTransactional = TRANSACTIONAL_KINDS.has(payload.kind);

      // Frequency caps (skip for transactional kinds)
      if (policy && !isTransactional) {
        const emailLower = payload.to_email.toLowerCase();
        const since24 = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
        const since7d = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString();
        const [{ count: c24 }, { count: c7d }] = await Promise.all([
          supabase.from("transactional_sends").select("id", { count: "exact", head: true })
            .eq("workspace_id", payload.workspace_id).eq("to_email", emailLower).eq("status", "sent").gte("sent_at", since24),
          supabase.from("transactional_sends").select("id", { count: "exact", head: true })
            .eq("workspace_id", payload.workspace_id).eq("to_email", emailLower).eq("status", "sent").gte("sent_at", since7d),
        ]);
        if ((c24 || 0) >= policy.max_messages_per_contact_24h || (c7d || 0) >= policy.max_messages_per_contact_7d) {
          await supabase.from("transactional_sends").insert({
            workspace_id: payload.workspace_id, to_email: payload.to_email,
            kind: payload.kind, status: "rate_limited",
            error: `Cap hit (24h:${c24}/${policy.max_messages_per_contact_24h}, 7d:${c7d}/${policy.max_messages_per_contact_7d})`,
          });
          return new Response(JSON.stringify({ ok: true, email: { sent: false, status: "rate_limited" } }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
      }

      // Quiet hours
      if (policy?.respect_quiet_hours && !isTransactional) {
        const tz = ws?.timezone || "UTC";
        const hour = parseInt(new Intl.DateTimeFormat("en-US", { hour: "2-digit", hour12: false, timeZone: tz }).format(new Date()), 10);
        const qs = policy.quiet_hours_start, qe = policy.quiet_hours_end;
        const inQuiet = qs > qe ? (hour >= qs || hour < qe) : (hour >= qs && hour < qe);
        if (inQuiet) {
          await supabase.from("transactional_sends").insert({
            workspace_id: payload.workspace_id, to_email: payload.to_email,
            kind: payload.kind, status: "quiet_hours", error: `In quiet window ${qs}:00-${qe}:00 ${tz}`,
          });
          return new Response(JSON.stringify({ ok: true, email: { sent: false, status: "quiet_hours" } }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
      }

      // Suppression check
      const { data: suppressed } = await supabase
        .from("email_suppressions")
        .select("email")
        .eq("workspace_id", payload.workspace_id)
        .eq("email", payload.to_email.toLowerCase())
        .maybeSingle();
      if (suppressed) {
        await supabase.from("transactional_sends").insert({
          workspace_id: payload.workspace_id, to_email: payload.to_email,
          kind: payload.kind, status: "suppressed", error: "Recipient on suppression list",
        });
        return new Response(JSON.stringify({ ok: true, email: { sent: false, status: "suppressed" } }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Decide stream: transactional for critical kinds, bulk otherwise
      const stream = payload.stream_override
        || (TRANSACTIONAL_KINDS.has(payload.kind) ? "transactional" : "bulk");

      // Find provider row for this workspace+stream (fallback to any active)
      let { data: provider } = await supabase
        .from("email_providers")
        .select("*")
        .eq("workspace_id", payload.workspace_id)
        .eq("stream", stream)
        .eq("is_active", true)
        .maybeSingle();
      if (!provider) {
        const r = await supabase.from("email_providers").select("*")
          .eq("workspace_id", payload.workspace_id).eq("is_active", true).limit(1).maybeSingle();
        provider = r.data;
      }

      const { data: sender } = await supabase
        .from("email_senders")
        .select("*, domain:email_domains(domain,status)")
        .eq("workspace_id", payload.workspace_id)
        .eq("is_default", true)
        .maybeSingle();

      const platformFromEmail = Deno.env.get("PULSE_DEFAULT_FROM_EMAIL") || "";
      const platformFromName = Deno.env.get("PULSE_DEFAULT_FROM_NAME") || "Pulse";
      const from = sender?.from_email
        ? `${sender.from_name || ws?.name || "Pulse"} <${sender.from_email}>`
        : platformFromEmail
          ? `${platformFromName} <${platformFromEmail}>`
          : "";
      const subject = payload.title;
      const html = renderEmail(payload.title, payload.body || "", payload.link, brand);

      let status = "queued";
      let provider_message_id = "";
      let errorText = "";
      const domainOk = !sender?.domain_id || sender?.domain?.status === "verified";

      if (!domainOk) {
        status = "skipped"; errorText = "Sending domain not verified";
      } else if (!from) {
        status = "skipped";
        errorText = "No sender configured. Set a default sender in workspace settings, or set PULSE_DEFAULT_FROM_EMAIL for platform-originated mail.";
      } else if (!provider) {
        // Platform default: Pulse-owned SES account handles all tenants.
        const key = Deno.env.get("SES_CLIENT_A") || "";
        const secret = Deno.env.get("SES_CLIENT_A_SECRET") || "";
        const region = Deno.env.get("PULSE_SES_REGION") || "us-east-1";
        const configSet = Deno.env.get("PULSE_SES_CONFIG_SET") || "";
        if (!key || !secret) {
          status = "logged";
          errorText = "Platform SES credentials not configured (SES_CLIENT_A / SES_CLIENT_A_SECRET)";
        } else {
          const r = await sendViaSes(key, secret, region, configSet, from, payload.to_email, subject, html);
          status = r.ok ? "sent" : "failed";
          provider_message_id = r.id; errorText = r.error;
        }
      } else {
        const secretName = provider.credentials_secret_name || "";
        if (provider.provider === "ses") {
          const key = Deno.env.get(secretName || "AWS_ACCESS_KEY_ID") || "";
          const secret = Deno.env.get((secretName || "AWS") + "_SECRET") || Deno.env.get("AWS_SECRET_ACCESS_KEY") || "";
          if (!key || !secret) { status = "failed"; errorText = `SES credentials missing (secret: ${secretName})`; }
          else {
            const r = await sendViaSes(key, secret, provider.region || "us-east-1", provider.config?.configuration_set || "", from, payload.to_email, subject, html);
            status = r.ok ? "sent" : "failed"; provider_message_id = r.id; errorText = r.error;
          }
        } else if (provider.provider === "postmark") {
          const token = Deno.env.get(secretName || "POSTMARK_SERVER_TOKEN") || "";
          if (!token) { status = "failed"; errorText = `Postmark token missing (secret: ${secretName})`; }
          else {
            const r = await sendViaPostmark(token, from, payload.to_email, subject, html, provider.config?.message_stream || "outbound");
            status = r.ok ? "sent" : "failed"; provider_message_id = r.id; errorText = r.error;
          }
        } else if (provider.provider === "resend") {
          const apiKey = Deno.env.get(secretName || "RESEND_API_KEY") || "";
          if (!apiKey) { status = "failed"; errorText = `Resend key missing (secret: ${secretName})`; }
          else {
            const r = await sendViaResend(apiKey, from, payload.to_email, subject, html);
            status = r.ok ? "sent" : "failed"; provider_message_id = r.id; errorText = r.error;
          }
        } else {
          status = "failed"; errorText = `Unsupported provider: ${provider.provider}`;
        }
      }

      await supabase.from("transactional_sends").insert({
        workspace_id: payload.workspace_id,
        to_email: payload.to_email,
        from_email: sender?.from_email || "",
        subject, body: html,
        kind: payload.kind,
        status,
        provider_message_id,
        error: errorText,
        sent_at: status === "sent" ? new Date().toISOString() : null,
      });

      emailResult = { sent: status === "sent", status, error: errorText, provider: provider?.provider || "fallback", stream };
    }

    return new Response(JSON.stringify({ ok: true, email: emailResult }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
