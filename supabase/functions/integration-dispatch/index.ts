import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};
const json = (d: unknown, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });

async function deriveKey(): Promise<CryptoKey> {
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const salt = new TextEncoder().encode("pulse.integration_credentials.v1");
  const ikm = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), "HKDF", false, ["deriveKey"]);
  return await crypto.subtle.deriveKey(
    { name: "HKDF", hash: "SHA-256", salt, info: new TextEncoder().encode("aes-gcm-256") },
    ikm, { name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]
  );
}
function fromBase64(s: string): Uint8Array {
  const bin = atob(s); const out = new Uint8Array(bin.length);
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

async function loadConnection(sb: any, workspaceId: string, provider: string, connectionId?: string) {
  let q = sb.from("integration_connections").select("*")
    .eq("workspace_id", workspaceId).eq("provider", provider).eq("is_active", true);
  if (connectionId) q = q.eq("id", connectionId);
  const { data } = await q.order("created_at", { ascending: false }).limit(1).maybeSingle();
  if (!data) return null;
  if (!data.has_credentials) return { ...data, secrets: {} };
  const { data: sec } = await sb.schema("pulse_secrets" as any).from("integration_credentials").select("payload").eq("connection_id", data.id).maybeSingle();
  let secrets: any = {};
  if (sec?.payload) {
    try { secrets = await decryptJson(sec.payload); } catch { secrets = {}; }
  }
  return { ...data, secrets };
}

// ---------- provider adapters ----------
async function sendSlack(conn: any, payload: any): Promise<{ ok: boolean; error?: string }> {
  const url = conn.secrets?.webhook_url;
  if (!url) return { ok: false, error: "Slack webhook_url missing" };
  const channel = payload.channel || conn.config?.default_channel;
  const body: any = { text: payload.text || payload.message || "" };
  if (channel) body.channel = channel;
  if (payload.blocks) body.blocks = payload.blocks;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) return { ok: false, error: `Slack HTTP ${res.status}: ${await res.text()}` };
  return { ok: true };
}

async function sendMixpanel(conn: any, payload: any): Promise<{ ok: boolean; error?: string }> {
  const projectId = conn.config?.project_id;
  const user = conn.secrets?.service_account_user;
  const pass = conn.secrets?.service_account_password;
  if (!projectId || !user || !pass) return { ok: false, error: "Mixpanel credentials incomplete" };
  const events = Array.isArray(payload.events) ? payload.events : [payload];
  const body = events.map((e: any) => ({
    event: e.name || e.event || "pulse_event",
    properties: { ...(e.properties || {}), time: e.time || Math.floor(Date.now() / 1000), distinct_id: e.distinct_id || e.customer_id, token: projectId },
  }));
  const res = await fetch("https://api.mixpanel.com/import?strict=1", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Basic ${btoa(`${user}:${pass}`)}`,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) return { ok: false, error: `Mixpanel HTTP ${res.status}: ${await res.text()}` };
  return { ok: true };
}

async function sendAdjust(conn: any, payload: any): Promise<{ ok: boolean; error?: string }> {
  const appToken = conn.config?.app_token;
  const envMap = conn.secrets?.event_token_map || {};
  const env = conn.secrets?.environment || "production";
  if (!appToken) return { ...{ ok: false, error: "Adjust app_token missing" } };
  const eventToken = envMap[payload.name || ""] || payload.event_token;
  if (!eventToken) return { ok: false, error: `No Adjust event_token mapped for "${payload.name}"` };
  const form = new URLSearchParams({
    s2s: "1",
    app_token: appToken,
    event_token: eventToken,
    environment: env,
    adid: payload.adid || "",
    idfa: payload.idfa || "",
    gps_adid: payload.gps_adid || "",
    created_at_unix: String(payload.time || Math.floor(Date.now() / 1000)),
  });
  if (payload.revenue) form.set("revenue", String(payload.revenue));
  if (payload.currency) form.set("currency", String(payload.currency));
  const res = await fetch(`https://s2s.adjust.com/event?${form.toString()}`, { method: "POST" });
  if (!res.ok) return { ok: false, error: `Adjust HTTP ${res.status}` };
  return { ok: true };
}

async function sendMetabase(conn: any, payload: any): Promise<{ ok: boolean; error?: string; data?: any }> {
  const baseUrl = (conn.config?.base_url || "").replace(/\/$/, "");
  const apiKey = conn.secrets?.api_key;
  if (!baseUrl || !apiKey) return { ok: false, error: "Metabase base_url / api_key missing" };
  const cardId = payload.card_id || payload.question_id;
  if (!cardId) return { ok: false, error: "Metabase card_id required" };
  const res = await fetch(`${baseUrl}/api/card/${cardId}/query/json`, {
    method: "POST",
    headers: { "x-api-key": apiKey, "Content-Type": "application/json" },
  });
  if (!res.ok) return { ok: false, error: `Metabase HTTP ${res.status}` };
  const data = await res.json().catch(() => []);
  return { ok: true, data };
}

async function sendSheets(conn: any, payload: any): Promise<{ ok: boolean; error?: string }> {
  const sa = conn.secrets?.service_account_json;
  const spreadsheetId = conn.config?.spreadsheet_id;
  const worksheet = conn.config?.worksheet || "Sheet1";
  if (!sa || !spreadsheetId) return { ok: false, error: "Sheets config incomplete" };
  const rows = Array.isArray(payload.rows) ? payload.rows : [payload];
  const token = await googleAccessToken(sa, "https://www.googleapis.com/auth/spreadsheets");
  if (!token) return { ok: false, error: "Google auth failed" };
  const res = await fetch(`https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${encodeURIComponent(worksheet)}:append?valueInputOption=RAW`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ values: rows.map((r: any) => Array.isArray(r) ? r : Object.values(r)) }),
  });
  if (!res.ok) return { ok: false, error: `Sheets HTTP ${res.status}: ${await res.text()}` };
  return { ok: true };
}

async function sendGcs(conn: any, payload: any): Promise<{ ok: boolean; error?: string }> {
  const sa = conn.secrets?.service_account_json;
  const bucket = conn.config?.bucket;
  const prefix = conn.config?.prefix || "";
  if (!sa || !bucket) return { ok: false, error: "GCS config incomplete" };
  const token = await googleAccessToken(sa, "https://www.googleapis.com/auth/devstorage.read_write");
  if (!token) return { ok: false, error: "Google auth failed" };
  const filename = payload.filename || `pulse-${Date.now()}.json`;
  const objectName = prefix ? `${prefix.replace(/\/$/, "")}/${filename}` : filename;
  const contentType = payload.content_type || "application/json";
  const body = typeof payload.content === "string" ? payload.content : JSON.stringify(payload.content ?? payload);
  const res = await fetch(`https://storage.googleapis.com/upload/storage/v1/b/${bucket}/o?uploadType=media&name=${encodeURIComponent(objectName)}`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${token}`, "Content-Type": contentType },
    body,
  });
  if (!res.ok) return { ok: false, error: `GCS HTTP ${res.status}: ${await res.text()}` };
  return { ok: true };
}

async function sendS3(conn: any, payload: any): Promise<{ ok: boolean; error?: string }> {
  const { access_key_id, secret_access_key } = conn.secrets || {};
  const region = conn.config?.region || "us-east-1";
  const bucket = conn.config?.bucket;
  const prefix = conn.config?.prefix || "";
  if (!access_key_id || !secret_access_key || !bucket) return { ok: false, error: "S3 config incomplete" };
  const filename = payload.filename || `pulse-${Date.now()}.json`;
  const objectName = prefix ? `${prefix.replace(/\/$/, "")}/${filename}` : filename;
  const contentType = payload.content_type || "application/json";
  const body = typeof payload.content === "string" ? payload.content : JSON.stringify(payload.content ?? payload);
  const url = `https://${bucket}.s3.${region}.amazonaws.com/${objectName}`;
  const signed = await sigV4(access_key_id, secret_access_key, region, "s3", "PUT", url, body, contentType);
  const res = await fetch(url, { method: "PUT", headers: signed, body });
  if (!res.ok) return { ok: false, error: `S3 HTTP ${res.status}: ${await res.text()}` };
  return { ok: true };
}

// ---------- google service-account JWT -> access token ----------
function b64urlEncode(bytes: Uint8Array | string): string {
  const arr = typeof bytes === "string" ? new TextEncoder().encode(bytes) : bytes;
  let s = ""; for (let i = 0; i < arr.length; i++) s += String.fromCharCode(arr[i]);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----BEGIN [A-Z ]+-----/, "").replace(/-----END [A-Z ]+-----/, "").replace(/\s+/g, "");
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}
async function googleAccessToken(serviceAccount: string | any, scope: string): Promise<string> {
  const sa = typeof serviceAccount === "string" ? JSON.parse(serviceAccount) : serviceAccount;
  const key = await crypto.subtle.importKey("pkcs8", pemToDer(sa.private_key), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const now = Math.floor(Date.now() / 1000);
  const header = b64urlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64urlEncode(JSON.stringify({ iss: sa.client_email, scope, aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600 }));
  const input = `${header}.${claims}`;
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "RSASSA-PKCS1-v1_5" }, key, new TextEncoder().encode(input)));
  const jwt = `${input}.${b64urlEncode(sig)}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const data = await res.json().catch(() => ({}));
  return data.access_token || "";
}

// ---------- AWS SigV4 for S3 PutObject ----------
async function hmac(key: ArrayBuffer | Uint8Array, data: string): Promise<ArrayBuffer> {
  const k = await crypto.subtle.importKey("raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(data));
}
async function sha256Hex(data: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(data));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}
function hex(buf: ArrayBuffer): string {
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}
async function sigV4(accessKey: string, secretKey: string, region: string, service: string, method: string, url: string, body: string, contentType: string): Promise<Record<string, string>> {
  const u = new URL(url);
  const now = new Date();
  const amzDate = now.toISOString().replace(/[:\-]|\.\d{3}/g, "");
  const dateStamp = amzDate.slice(0, 8);
  const host = u.host;
  const payloadHash = await sha256Hex(body);
  const canonicalUri = u.pathname || "/";
  const canonicalQuery = u.search.slice(1);
  const canonicalHeaders = `content-type:${contentType}\nhost:${host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${amzDate}\n`;
  const signedHeaders = "content-type;host;x-amz-content-sha256;x-amz-date";
  const canonicalRequest = `${method}\n${canonicalUri}\n${canonicalQuery}\n${canonicalHeaders}\n${signedHeaders}\n${payloadHash}`;
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const stringToSign = `AWS4-HMAC-SHA256\n${amzDate}\n${credentialScope}\n${await sha256Hex(canonicalRequest)}`;
  const kDate = await hmac(new TextEncoder().encode(`AWS4${secretKey}`), dateStamp);
  const kRegion = await hmac(kDate, region);
  const kService = await hmac(kRegion, service);
  const kSigning = await hmac(kService, "aws4_request");
  const signature = hex(await hmac(kSigning, stringToSign));
  return {
    "Authorization": `AWS4-HMAC-SHA256 Credential=${accessKey}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`,
    "x-amz-date": amzDate,
    "x-amz-content-sha256": payloadHash,
    "Content-Type": contentType,
  };
}

// ---------- orchestrator ----------
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
    const body = await req.json().catch(() => ({}));
    const { workspace_id, provider, connection_id, payload } = body || {};
    if (!workspace_id || !provider) return json({ ok: false, error: "workspace_id and provider required" }, 400);

    const authz = await authorize(req, workspace_id);
    if (!authz.ok) return json({ ok: false, error: authz.error }, authz.status || 401);

    const conn = await loadConnection(sb, workspace_id, provider, connection_id);
    if (!conn) return json({ ok: false, error: `No active ${provider} connection` }, 404);

    let result: { ok: boolean; error?: string; data?: any };
    switch (provider) {
      case "slack":    result = await sendSlack(conn, payload || {}); break;
      case "mixpanel": result = await sendMixpanel(conn, payload || {}); break;
      case "adjust":   result = await sendAdjust(conn, payload || {}); break;
      case "metabase": result = await sendMetabase(conn, payload || {}); break;
      case "sheets":   result = await sendSheets(conn, payload || {}); break;
      case "gcs":      result = await sendGcs(conn, payload || {}); break;
      case "s3":       result = await sendS3(conn, payload || {}); break;
      default: return json({ ok: false, error: `Unsupported provider "${provider}"` }, 400);
    }

    await sb.from("integration_connections").update({
      last_synced_at: result.ok ? new Date().toISOString() : conn.last_synced_at,
      last_error: result.ok ? "" : (result.error || ""),
    }).eq("id", conn.id);

    return json({ ok: result.ok, error: result.error, data: result.data, provider });
  } catch (e) {
    return json({ ok: false, error: (e as Error).message }, 500);
  }
});
