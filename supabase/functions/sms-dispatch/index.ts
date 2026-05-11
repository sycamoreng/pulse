import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

type Payload = {
  workspace_id: string;
  to_user_id?: string;
  to_phone?: string;
  body?: string;
  title?: string;
  channel?: "sms" | "whatsapp" | "rcs";
  media_url?: string;
  kind?: string;
};

async function deriveKey(): Promise<CryptoKey> {
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const salt = new TextEncoder().encode("pulse.sms_provider_credentials.v1");
  const ikm = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), "HKDF", false, ["deriveKey"]);
  return await crypto.subtle.deriveKey(
    { name: "HKDF", hash: "SHA-256", salt, info: new TextEncoder().encode("aes-gcm-256") },
    ikm, { name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]
  );
}

function fromBase64(s: string): Uint8Array {
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function decryptJson(payload: string): Promise<any> {
  const data = fromBase64(payload);
  const iv = data.subarray(0, 12);
  const ct = data.subarray(12);
  const key = await deriveKey();
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, ct);
  return JSON.parse(new TextDecoder().decode(plain));
}

async function sendViaTwilio(
  accountSid: string,
  authToken: string,
  from: string,
  messagingServiceSid: string,
  to: string,
  body: string,
  channel: "sms" | "whatsapp" | "rcs",
  mediaUrl?: string,
): Promise<{ ok: boolean; id?: string; error?: string }> {
  const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
  const form = new URLSearchParams();
  const toFormatted = channel === "whatsapp" ? `whatsapp:${to}` : to;
  form.set("To", toFormatted);
  if (messagingServiceSid) form.set("MessagingServiceSid", messagingServiceSid);
  else if (from) form.set("From", channel === "whatsapp" ? `whatsapp:${from}` : from);
  else return { ok: false, error: "No Twilio sender configured" };
  form.set("Body", body);
  if (mediaUrl) form.set("MediaUrl", mediaUrl);

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Basic ${btoa(`${accountSid}:${authToken}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: form.toString(),
    });
    const j = await res.json().catch(() => ({}));
    if (!res.ok) return { ok: false, error: j?.message || `HTTP ${res.status}` };
    return { ok: true, id: j?.sid };
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const payload = (await req.json().catch(() => ({}))) as Payload;
    if (!payload.workspace_id) {
      return new Response(JSON.stringify({ ok: false, error: "workspace_id required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const channel = payload.channel || "sms";

    let toPhone = payload.to_phone || "";
    if (!toPhone && payload.to_user_id) {
      const { data: c } = await sb.from("customers").select("phone").eq("id", payload.to_user_id).maybeSingle();
      toPhone = c?.phone || "";
    }
    if (!toPhone) {
      return new Response(JSON.stringify({ ok: false, status: "skipped", error: "No destination phone" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: provider } = await sb.from("sms_providers")
      .select("*")
      .eq("workspace_id", payload.workspace_id)
      .eq("channel", channel)
      .eq("is_active", true)
      .order("created_at", { ascending: false })
      .limit(1).maybeSingle();

    let status: "sent" | "failed" | "skipped" | "logged" = "logged";
    let providerMessageId = "";
    let errorText = "";
    const body = payload.body || payload.title || "";
    let providerLabel = "platform";

    if (provider && provider.has_credentials) {
      const { data: secret } = await sb
        .schema("pulse_secrets" as any)
        .from("sms_provider_credentials")
        .select("payload")
        .eq("provider_id", provider.id)
        .maybeSingle();
      if (!secret?.payload) {
        status = "failed";
        errorText = "Encrypted credentials missing for provider";
      } else {
        try {
          const creds = await decryptJson(secret.payload);
          const r = await sendViaTwilio(
            creds.account_sid, creds.auth_token,
            provider.from_number || "", provider.messaging_service_sid || "",
            toPhone, body, channel, payload.media_url,
          );
          status = r.ok ? "sent" : "failed";
          providerMessageId = r.id || "";
          errorText = r.error || "";
          providerLabel = provider.provider || "twilio";
        } catch (e) {
          status = "failed";
          errorText = `Credential decrypt failed: ${(e as Error).message}`;
        }
      }
    } else {
      const sid = Deno.env.get("PLATFORM_TWILIO_ACCOUNT_SID") || "";
      const token = Deno.env.get("PLATFORM_TWILIO_AUTH_TOKEN") || "";
      const from = Deno.env.get("PLATFORM_TWILIO_FROM_NUMBER") || "";
      const mss = Deno.env.get("PLATFORM_TWILIO_MESSAGING_SERVICE_SID") || "";
      if (!sid || !token || (!from && !mss)) {
        status = "logged";
        errorText = provider
          ? "Provider has no credentials connected — ask an admin to reconnect on Integrations."
          : "No workspace provider configured.";
      } else {
        const r = await sendViaTwilio(sid, token, from, mss, toPhone, body, channel, payload.media_url);
        status = r.ok ? "sent" : "failed";
        providerMessageId = r.id || "";
        errorText = r.error || "";
      }
    }

    await sb.from("transactional_sends").insert({
      workspace_id: payload.workspace_id,
      to_email: toPhone,
      from_email: provider?.from_number || "",
      subject: payload.title || "",
      body,
      kind: payload.kind || channel,
      status,
      provider_message_id: providerMessageId,
      error: errorText,
      sent_at: status === "sent" ? new Date().toISOString() : null,
    }).catch(() => {});

    return new Response(JSON.stringify({ ok: status === "sent", status, error: errorText, provider: providerLabel, channel }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
