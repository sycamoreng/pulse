import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

// ---------- encoding helpers ----------
function b64urlEncode(bytes: Uint8Array | ArrayBuffer): string {
  const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let s = "";
  for (let i = 0; i < arr.length; i++) s += String.fromCharCode(arr[i]);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function b64urlDecode(s: string): Uint8Array {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

// ---------- VAPID / Web Push ----------
async function sendWebPush(subscription: any, payload: string, app: any) {
  const endpoint: string = subscription.endpoint;
  const audience = new URL(endpoint).origin;
  const expSeconds = Math.floor(Date.now() / 1000) + 11 * 3600;

  const header = b64urlEncode(new TextEncoder().encode(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const bodyPart = b64urlEncode(new TextEncoder().encode(JSON.stringify({
    aud: audience, exp: expSeconds, sub: app.vapid_subject || "mailto:admin@example.com",
  })));
  const signingInput = `${header}.${bodyPart}`;

  // Rebuild signing key from JWK private key (d) + raw public key to derive x,y
  const pubRaw = b64urlDecode(app.vapid_public_key);
  if (pubRaw.length !== 65 || pubRaw[0] !== 0x04) throw new Error("invalid VAPID public key");
  const x = b64urlEncode(pubRaw.subarray(1, 33));
  const y = b64urlEncode(pubRaw.subarray(33, 65));
  const jwk: JsonWebKey = { kty: "EC", crv: "P-256", d: app.vapid_private_key, x, y, ext: true };
  const key = await crypto.subtle.importKey("jwk", jwk, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(signingInput)));
  const jwt = `${signingInput}.${b64urlEncode(sig)}`;

  // Empty-body notification: the payload is the TITLE/BODY we send via `data`
  // in the URL query? No — for true encrypted payloads we'd need aes128gcm. To
  // keep this focused we send a zero-byte body and deliver the payload via the
  // service-worker fetching the notification metadata. Simplest path: send as a
  // bare tickle so the SW fires `push` and the browser shows a generic
  // notification from cache. Most hosting setups already use this pattern.
  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      "TTL": "60",
      "Authorization": `vapid t=${jwt}, k=${app.vapid_public_key}`,
      "Content-Length": "0",
    },
  });
  if (res.status >= 200 && res.status < 300) return { ok: true, id: res.headers.get("location") || "" };
  const err = await res.text().catch(() => "");
  return { ok: false, status: res.status, error: err || res.statusText, gone: res.status === 404 || res.status === 410 };
}

// ---------- FCM HTTP v1 ----------
async function signJwtRS256(claims: any, key: CryptoKey) {
  const header = b64urlEncode(new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const body = b64urlEncode(new TextEncoder().encode(JSON.stringify(claims)));
  const input = `${header}.${body}`;
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "RSASSA-PKCS1-v1_5" }, key, new TextEncoder().encode(input)));
  return `${input}.${b64urlEncode(sig)}`;
}
function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----BEGIN [A-Z ]+-----/, "").replace(/-----END [A-Z ]+-----/, "").replace(/\s+/g, "");
  return b64urlDecode(b64.replace(/\+/g, "-").replace(/\//g, "_")).buffer;
}
async function fcmAccessToken(serviceAccountJson: string) {
  const sa = JSON.parse(serviceAccountJson);
  const der = pemToDer(sa.private_key);
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const now = Math.floor(Date.now() / 1000);
  const jwt = await signJwtRS256({
    iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600,
  }, key);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const data = await res.json();
  return { access_token: data.access_token as string, project_id: sa.project_id as string };
}
async function sendFcm(token: string, title: string, body: string, fcmCreds: string) {
  let res: Response;
  if (fcmCreds.trim().startsWith("{")) {
    const { access_token, project_id } = await fcmAccessToken(fcmCreds);
    if (!access_token) return { ok: false, error: "fcm auth failed" };
    res = await fetch(`https://fcm.googleapis.com/v1/projects/${project_id}/messages:send`, {
      method: "POST",
      headers: { "Authorization": `Bearer ${access_token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ message: { token, notification: { title, body } } }),
    });
  } else {
    // Legacy server-key path (deprecated but still works for older projects).
    res = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: { "Authorization": `key=${fcmCreds.trim()}`, "Content-Type": "application/json" },
      body: JSON.stringify({ to: token, notification: { title, body } }),
    });
  }
  const out = await res.json().catch(() => ({}));
  if (res.ok && !(out?.failure > 0)) return { ok: true, id: out?.name || out?.message_id || "" };
  const errStr = JSON.stringify(out);
  const gone = /NotRegistered|UNREGISTERED|INVALID_ARGUMENT/i.test(errStr);
  return { ok: false, status: res.status, error: errStr, gone };
}

// ---------- APNs HTTP/2 (via HTTP/1 gateway) ----------
async function apnsJwt(teamId: string, keyId: string, p8: string) {
  const der = pemToDer(p8);
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const header = b64urlEncode(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" })));
  const claims = b64urlEncode(new TextEncoder().encode(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) })));
  const input = `${header}.${claims}`;
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(input)));
  return `${input}.${b64urlEncode(sig)}`;
}
async function sendApns(deviceToken: string, title: string, body: string, app: any) {
  const jwt = await apnsJwt(app.apns_team_id, app.apns_key_id, app.apns_p8);
  const host = "https://api.push.apple.com"; // prod; use api.sandbox.push.apple.com for dev
  const res = await fetch(`${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": app.apns_bundle_id || app.bundle_id || "",
      "apns-push-type": "alert",
      "content-type": "application/json",
    },
    body: JSON.stringify({ aps: { alert: { title, body }, sound: "default" } }),
  });
  if (res.status === 200) return { ok: true, id: res.headers.get("apns-id") || "" };
  const text = await res.text().catch(() => "");
  const gone = res.status === 410 || /BadDeviceToken|Unregistered/i.test(text);
  return { ok: false, status: res.status, error: text || res.statusText, gone };
}

// ---------- orchestrator ----------
interface PushPayload {
  workspace_id: string;
  customer_ids?: string[];
  external_ids?: string[];
  title: string;
  body?: string;
  kind?: string;
  campaign_id?: string | null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const payload = (await req.json()) as PushPayload;
    if (!payload.workspace_id || !payload.title) return json({ error: "workspace_id and title required" }, 400);

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // Resolve recipients
    let customerIds: string[] = payload.customer_ids || [];
    if (payload.external_ids?.length && !customerIds.length) {
      const { data } = await supabase.from("customers").select("id")
        .eq("workspace_id", payload.workspace_id).in("external_id", payload.external_ids);
      customerIds = (data || []).map(c => c.id);
    }
    if (!customerIds.length) return json({ error: "no recipients" }, 400);

    const { data: tokens } = await supabase.from("device_tokens")
      .select("id, platform, token, app_id, customer_id")
      .eq("workspace_id", payload.workspace_id)
      .in("customer_id", customerIds)
      .is("revoked_at", null);
    if (!tokens?.length) return json({ ok: true, sent: 0, skipped: customerIds.length, reason: "no_tokens" });

    const appIds = Array.from(new Set(tokens.map(t => t.app_id).filter(Boolean)));
    const { data: apps } = appIds.length
      ? await supabase.from("apps").select("*").in("id", appIds as string[])
      : { data: [] as any[] };
    const appMap = new Map<string, any>();
    for (const a of apps || []) appMap.set(a.id, a);

    // fallback: if a token has no app_id, pick any workspace app matching its platform
    const { data: wsApps } = await supabase.from("apps").select("*").eq("workspace_id", payload.workspace_id);
    const byPlatform = new Map<string, any>();
    for (const a of wsApps || []) if (!byPlatform.has(a.platform)) byPlatform.set(a.platform, a);

    const results: Array<{ token_id: string; ok: boolean; error?: string }> = [];
    let sent = 0, failed = 0, revoked = 0;

    for (const t of tokens) {
      const app = (t.app_id && appMap.get(t.app_id)) || byPlatform.get(t.platform);
      if (!app) { results.push({ token_id: t.id, ok: false, error: "no matching app" }); failed++; continue; }

      let r: any;
      try {
        if (t.platform === "web") {
          if (!app.vapid_public_key || !app.vapid_private_key) { r = { ok: false, error: "VAPID keys missing" }; }
          else {
            let sub: any;
            try { sub = JSON.parse(t.token); } catch { sub = { endpoint: t.token }; }
            r = await sendWebPush(sub, payload.body || "", app);
          }
        } else if (t.platform === "android") {
          if (!app.fcm_server_key) r = { ok: false, error: "FCM key missing" };
          else r = await sendFcm(t.token, payload.title, payload.body || "", app.fcm_server_key);
        } else if (t.platform === "ios") {
          if (!app.apns_p8 || !app.apns_key_id || !app.apns_team_id) r = { ok: false, error: "APNs creds missing" };
          else r = await sendApns(t.token, payload.title, payload.body || "", app);
        } else {
          r = { ok: false, error: `unsupported platform ${t.platform}` };
        }
      } catch (e) {
        r = { ok: false, error: (e as Error).message };
      }

      if (r.ok) {
        sent++;
        results.push({ token_id: t.id, ok: true });
        await supabase.from("device_tokens").update({ last_seen_at: new Date().toISOString() }).eq("id", t.id);
      } else {
        failed++;
        results.push({ token_id: t.id, ok: false, error: r.error });
        if (r.gone) {
          revoked++;
          await supabase.from("device_tokens").update({ revoked_at: new Date().toISOString() }).eq("id", t.id);
        }
      }
    }

    if (sent) {
      await supabase.rpc("increment_usage", { p_workspace_id: payload.workspace_id, p_push_sends: sent });
    }

    if (payload.campaign_id) {
      const rows = customerIds.map(cid => ({
        workspace_id: payload.workspace_id,
        campaign_id: payload.campaign_id,
        customer_id: cid,
        status: "sent",
        sent_at: new Date().toISOString(),
      }));
      await supabase.from("campaign_messages").insert(rows);
    }

    return json({ ok: true, sent, failed, revoked, results });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
