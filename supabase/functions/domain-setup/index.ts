import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};
const json = (d: unknown, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });

function arrToB64(buf: ArrayBuffer | Uint8Array) {
  const arr = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  let s = ""; for (let i = 0; i < arr.length; i++) s += String.fromCharCode(arr[i]);
  return btoa(s);
}
function pem(der: ArrayBuffer, label: string) {
  const b64 = arrToB64(der);
  const lines = b64.match(/.{1,64}/g) || [];
  return `-----BEGIN ${label}-----\n${lines.join("\n")}\n-----END ${label}-----\n`;
}

async function generateDkimKeypair() {
  const kp = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true, ["sign", "verify"],
  );
  const pub = await crypto.subtle.exportKey("spki", kp.publicKey);
  const priv = await crypto.subtle.exportKey("pkcs8", kp.privateKey);
  // DKIM TXT "p=" field is the base64 (NOT url-safe) SPKI DER.
  return { publicDer: arrToB64(pub), privatePem: pem(priv, "PRIVATE KEY") };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const { action, domain_id, sender_id, workspace_id, domain } = await req.json().catch(() => ({}));
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    const spfInclude = Deno.env.get("PULSE_SPF_INCLUDE") || "";

    if (action === "create") {
      if (!workspace_id || !domain) return json({ error: "workspace_id and domain required" }, 400);
      const clean = String(domain).trim().toLowerCase();
      const dkim_selector = "pulse" + Math.floor(Math.random() * 9000 + 1000);
      const { publicDer, privatePem } = await generateDkimKeypair();
      const { data, error } = await supabase.from("email_domains").insert({
        workspace_id, domain: clean, dkim_selector,
        dkim_public_key: publicDer, dkim_private_key: privatePem,
        spf_include: spfInclude,
        return_path: "bounce." + clean,
      }).select().maybeSingle();
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true, domain: data });
    }

    if (action === "rotate-dkim") {
      if (!domain_id) return json({ error: "domain_id required" }, 400);
      const { publicDer, privatePem } = await generateDkimKeypair();
      const { data, error } = await supabase.from("email_domains").update({
        dkim_public_key: publicDer, dkim_private_key: privatePem,
        spf_include: spfInclude,
        dkim_status: "pending", status: "pending", verified_at: null, last_checked_at: null,
      }).eq("id", domain_id).select().maybeSingle();
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true, domain: data });
    }

    if (action === "send-verification") {
      if (!sender_id) return json({ error: "sender_id required" }, 400);
      const { data: sender } = await supabase.from("email_senders").select("*").eq("id", sender_id).maybeSingle();
      if (!sender) return json({ error: "sender not found" }, 404);
      const bytes = crypto.getRandomValues(new Uint8Array(24));
      const token = Array.from(bytes).map(b => b.toString(16).padStart(2, "0")).join("");
      await supabase.from("email_senders").update({
        verification_token: token, verification_sent_at: new Date().toISOString(), verified: false, verified_at: null,
      }).eq("id", sender_id);
      const siteUrl = Deno.env.get("PULSE_SITE_URL") || "";
      const link = `${siteUrl}/settings?verify_sender=${sender_id}&token=${token}`;
      const notifyRes = await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/notify`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}` },
        body: JSON.stringify({
          workspace_id: sender.workspace_id,
          to_email: sender.from_email,
          kind: "sender_verification",
          title: "Verify your sender address",
          body: `Confirm that you own ${sender.from_email} by opening the verification link below. If you didn't request this, you can ignore this email.`,
          link, send_email: true,
        }),
      });
      const n = await notifyRes.json().catch(() => ({}));
      return json({ ok: true, email: n });
    }

    if (action === "confirm-sender") {
      if (!sender_id) return json({ error: "sender_id required" }, 400);
      const { data: sender } = await supabase.from("email_senders")
        .select("id, verification_token")
        .eq("id", sender_id).maybeSingle();
      const expected = sender?.verification_token || "";
      const received = String((req.headers.get("X-Verify-Token") || "")).trim();
      if (!expected || expected !== received) return json({ error: "invalid token" }, 403);
      await supabase.from("email_senders").update({
        verified: true, verified_at: new Date().toISOString(), verification_token: "",
      }).eq("id", sender_id);
      return json({ ok: true });
    }

    if (action === "backfill-spf") {
      const { error, count } = await supabase.from("email_domains")
        .update({ spf_include: spfInclude }, { count: "exact" })
        .or("spf_include.is.null,spf_include.eq.");
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true, updated: count ?? 0, spf_include: spfInclude });
    }

    return json({ error: "unknown action" }, 400);
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
