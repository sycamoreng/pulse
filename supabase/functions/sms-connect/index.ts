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
  const salt = new TextEncoder().encode("pulse.sms_provider_credentials.v1");
  const ikm = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), "HKDF", false, ["deriveKey"]);
  return await crypto.subtle.deriveKey(
    { name: "HKDF", hash: "SHA-256", salt, info: new TextEncoder().encode("aes-gcm-256") },
    ikm, { name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]
  );
}

function toBase64(bytes: Uint8Array): string {
  let s = ""; for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s);
}

async function encryptJson(obj: unknown): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveKey();
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, new TextEncoder().encode(JSON.stringify(obj))));
  const combined = new Uint8Array(iv.length + ct.length);
  combined.set(iv, 0); combined.set(ct, iv.length);
  return toBase64(combined);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
    const auth = req.headers.get("Authorization") || "";
    if (!auth.startsWith("Bearer ")) return json({ error: "Unauthorized" }, 401);

    const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: auth } } });
    const { data: userData } = await userClient.auth.getUser();
    const user = userData?.user;
    if (!user) return json({ error: "Unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const { provider_id, workspace_id, credentials } = body || {};
    if (!provider_id || !workspace_id || !credentials || typeof credentials !== "object") {
      return json({ error: "provider_id, workspace_id, credentials required" }, 400);
    }
    if (!credentials.account_sid || !credentials.auth_token) {
      return json({ error: "credentials.account_sid and credentials.auth_token required" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: member } = await admin.from("workspace_members").select("role")
      .eq("workspace_id", workspace_id).eq("user_id", user.id).maybeSingle();
    if (!member || !["owner", "admin"].includes(member.role)) return json({ error: "Forbidden" }, 403);

    const { data: provider } = await admin.from("sms_providers").select("id, workspace_id")
      .eq("id", provider_id).maybeSingle();
    if (!provider || provider.workspace_id !== workspace_id) return json({ error: "Provider not found" }, 404);

    const payload = await encryptJson({
      account_sid: String(credentials.account_sid),
      auth_token: String(credentials.auth_token),
    });

    const { error: upErr } = await admin
      .schema("pulse_secrets")
      .from("sms_provider_credentials")
      .upsert({ provider_id, payload, updated_at: new Date().toISOString() });
    if (upErr) throw upErr;

    await admin.from("sms_providers").update({ has_credentials: true }).eq("id", provider_id);

    return json({ ok: true });
  } catch (e: any) {
    return json({ error: e?.message || String(e) }, 500);
  }
});
