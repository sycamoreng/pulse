import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};
const json = (d: unknown, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });

// Shape per provider: which fields are required, which are config (visible) vs secret (encrypted).
const PROVIDER_SCHEMA: Record<string, { config: string[]; secret: string[]; label: string }> = {
  slack:    { config: ["default_channel"],     secret: ["webhook_url"],                     label: "Slack" },
  adjust:   { config: ["app_token"],           secret: ["event_token_map", "environment"],  label: "Adjust" },
  mixpanel: { config: ["project_id"],          secret: ["service_account_user", "service_account_password"], label: "Mixpanel" },
  metabase: { config: ["base_url"],            secret: ["api_key"],                         label: "Metabase" },
  gcs:      { config: ["bucket", "prefix"],    secret: ["service_account_json"],            label: "Google Cloud Storage" },
  s3:       { config: ["bucket", "region", "prefix"], secret: ["access_key_id", "secret_access_key"], label: "Amazon S3" },
  sheets:   { config: ["spreadsheet_id", "worksheet"], secret: ["service_account_json"],    label: "Google Sheets" },
};

async function deriveKey(): Promise<CryptoKey> {
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const salt = new TextEncoder().encode("pulse.integration_credentials.v1");
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
    const { workspace_id, provider, name, config, secrets, connection_id } = body || {};
    if (!workspace_id || !provider) return json({ error: "workspace_id and provider required" }, 400);

    const schema = PROVIDER_SCHEMA[provider];
    if (!schema) return json({ error: `Unknown provider "${provider}"` }, 400);

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: member } = await admin.from("workspace_members").select("role")
      .eq("workspace_id", workspace_id).eq("user_id", user.id).maybeSingle();
    if (!member || !["owner", "admin"].includes(member.role)) return json({ error: "Forbidden" }, 403);

    // upsert the connection row with ONLY the non-secret config
    const cleanConfig: Record<string, any> = {};
    for (const f of schema.config) if (config && config[f] !== undefined) cleanConfig[f] = config[f];

    let connectionId = connection_id as string | undefined;
    if (connectionId) {
      const { error } = await admin.from("integration_connections")
        .update({ name: name || schema.label, config: cleanConfig })
        .eq("id", connectionId).eq("workspace_id", workspace_id);
      if (error) throw error;
    } else {
      const { data: created, error } = await admin.from("integration_connections")
        .insert({ workspace_id, provider, name: name || schema.label, config: cleanConfig })
        .select("id").maybeSingle();
      if (error || !created) throw error || new Error("insert failed");
      connectionId = created.id;
    }

    // Store secrets only if provided (allow editing config without retyping secrets)
    if (secrets && typeof secrets === "object" && Object.keys(secrets).length) {
      const cleanSecrets: Record<string, any> = {};
      for (const f of schema.secret) if (secrets[f] !== undefined && secrets[f] !== "") cleanSecrets[f] = secrets[f];
      if (Object.keys(cleanSecrets).length) {
        const payload = await encryptJson(cleanSecrets);
        const { error: upErr } = await admin
          .schema("pulse_secrets" as any)
          .from("integration_credentials")
          .upsert({ connection_id: connectionId, payload, updated_at: new Date().toISOString() });
        if (upErr) throw upErr;
        await admin.from("integration_connections").update({ has_credentials: true }).eq("id", connectionId);
      }
    }

    return json({ ok: true, connection_id: connectionId });
  } catch (e: any) {
    return json({ error: e?.message || String(e) }, 500);
  }
});
