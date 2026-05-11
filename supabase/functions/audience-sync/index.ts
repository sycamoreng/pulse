import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

interface RunPayload {
  workspace_id: string;
  destination_id: string;
  source_type: "list" | "segment" | "all";
  source_id?: string | null;
  operation?: "add" | "remove" | "replace";
}

async function sha256Hex(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}

async function deriveVaultKey(): Promise<CryptoKey> {
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const salt = new TextEncoder().encode("pulse.ad_destination_credentials.v1");
  const ikm = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), "HKDF", false, ["deriveKey"]);
  return await crypto.subtle.deriveKey(
    { name: "HKDF", hash: "SHA-256", salt, info: new TextEncoder().encode("aes-gcm-256") },
    ikm,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"]
  );
}

async function decryptCredentials(payload: string): Promise<any> {
  const bin = Uint8Array.from(atob(payload), c => c.charCodeAt(0));
  const iv = bin.slice(0, 12);
  const ct = bin.slice(12);
  const key = await deriveVaultKey();
  const pt = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, ct);
  return JSON.parse(new TextDecoder().decode(pt));
}

async function loadDestinationCredentials(sb: any, destination_id: string): Promise<any | null> {
  const { data } = await sb
    .schema("pulse_secrets")
    .from("ad_destination_credentials")
    .select("payload")
    .eq("destination_id", destination_id)
    .maybeSingle();
  if (!data?.payload) return null;
  try { return await decryptCredentials(data.payload); } catch { return null; }
}

function normaliseEmail(email: string): string {
  return (email || "").trim().toLowerCase();
}

function normalisePhone(phone: string): string {
  return (phone || "").replace(/[^0-9+]/g, "");
}

function normaliseName(v: string): string {
  return (v || "").trim().toLowerCase().replace(/[^a-z]/g, "");
}

async function hashRecord(r: {email?: string; phone?: string; first_name?: string; last_name?: string}) {
  const out: Record<string, string> = {};
  if (r.email) out.email = await sha256Hex(normaliseEmail(r.email));
  if (r.phone) out.phone = await sha256Hex(normalisePhone(r.phone));
  if (r.first_name) out.first_name = await sha256Hex(normaliseName(r.first_name));
  if (r.last_name) out.last_name = await sha256Hex(normaliseName(r.last_name));
  return out;
}

async function pushToFacebook(token: string, audienceId: string, rows: any[], operation: string) {
  // Meta Marketing API v19 users endpoint.
  // schema: EMAIL_SHA256, PHONE_SHA256, FN, LN.
  const schema = ["EMAIL_SHA256", "PHONE_SHA256", "FN", "LN"];
  const data = rows.map(r => [r.email || "", r.phone || "", r.first_name || "", r.last_name || ""]);
  const endpoint = `https://graph.facebook.com/v19.0/${audienceId}/users`;
  const method = operation === "remove" ? "DELETE" : "POST";
  const body = new URLSearchParams({
    access_token: token,
    payload: JSON.stringify({ schema, data }),
  });
  const res = await fetch(endpoint, { method, body });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(JSON.stringify(json));
  return json;
}

async function pushToGoogle(developerToken: string, accessToken: string, customerId: string, userListResource: string, rows: any[], operation: string) {
  // Google Ads OfflineUserDataJob (CUSTOMER_MATCH_USER_LIST).
  const api = "https://googleads.googleapis.com/v17";
  const createJob = await fetch(`${api}/customers/${customerId}/offlineUserDataJobs:create`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${accessToken}`, "developer-token": developerToken, "Content-Type": "application/json" },
    body: JSON.stringify({ job: { type: "CUSTOMER_MATCH_USER_LIST", customerMatchUserListMetadata: { userList: userListResource } } }),
  });
  const createJson = await createJob.json().catch(() => ({}));
  if (!createJob.ok) throw new Error("Create job: " + JSON.stringify(createJson));
  const jobName = createJson.resourceName;

  const userOp = operation === "remove" ? "remove" : "create";
  const operations = rows.map(r => ({
    [userOp]: {
      userIdentifiers: [
        ...(r.email ? [{ hashedEmail: r.email }] : []),
        ...(r.phone ? [{ hashedPhoneNumber: r.phone }] : []),
        ...(r.first_name || r.last_name ? [{ addressInfo: { hashedFirstName: r.first_name, hashedLastName: r.last_name } }] : []),
      ],
    },
  })).filter(op => Object.values(op)[0]!.userIdentifiers.length > 0);

  const add = await fetch(`${api}/${jobName}:addOperations`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${accessToken}`, "developer-token": developerToken, "Content-Type": "application/json" },
    body: JSON.stringify({ operations, enablePartialFailure: true }),
  });
  const addJson = await add.json().catch(() => ({}));
  if (!add.ok) throw new Error("Add ops: " + JSON.stringify(addJson));

  const run = await fetch(`${api}/${jobName}:run`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${accessToken}`, "developer-token": developerToken, "Content-Type": "application/json" },
    body: "{}",
  });
  if (!run.ok) {
    const runJson = await run.json().catch(() => ({}));
    throw new Error("Run job: " + JSON.stringify(runJson));
  }
  return { jobName };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }
  try {
    const payload: RunPayload = await req.json();
    if (!payload.workspace_id || !payload.destination_id) {
      return new Response(JSON.stringify({ error: "workspace_id and destination_id required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    const { data: dest } = await sb.from("ad_audience_destinations").select("*").eq("id", payload.destination_id).eq("workspace_id", payload.workspace_id).maybeSingle();
    if (!dest) {
      return new Response(JSON.stringify({ error: "destination not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const { data: sync } = await sb.from("ad_audience_syncs").insert({
      workspace_id: payload.workspace_id,
      destination_id: dest.id,
      source_type: payload.source_type,
      source_id: payload.source_id || null,
      operation: payload.operation || "add",
      status: "running",
      started_at: new Date().toISOString(),
    }).select().maybeSingle();

    // Resolve customer set
    let customers: any[] = [];
    if (payload.source_type === "list" && payload.source_id) {
      const { data } = await sb
        .from("list_members")
        .select("customer:customers(id,email,phone,first_name,last_name)")
        .eq("list_id", payload.source_id)
        .limit(100000);
      customers = (data || []).map((r: any) => r.customer).filter(Boolean);
    } else if (payload.source_type === "segment" && payload.source_id) {
      // Segments are rule-based; we fetch precomputed membership table if present, else fall back to all.
      const { data: sm } = await sb
        .from("segment_members")
        .select("customer:customers(id,email,phone,first_name,last_name)")
        .eq("segment_id", payload.source_id)
        .limit(100000);
      if (sm && sm.length) {
        customers = sm.map((r: any) => r.customer).filter(Boolean);
      } else {
        const { data } = await sb.from("customers").select("id,email,phone,first_name,last_name").eq("workspace_id", payload.workspace_id).limit(100000);
        customers = data || [];
      }
    } else {
      const { data } = await sb.from("customers").select("id,email,phone,first_name,last_name").eq("workspace_id", payload.workspace_id).limit(100000);
      customers = data || [];
    }

    const total = customers.length;
    const usable = customers.filter(c => c?.email || c?.phone);
    const unmatched = total - usable.length;

    const hashed = await Promise.all(usable.map(c => hashRecord(c)));

    const op = payload.operation || "add";
    let errorText = "";
    let matched = usable.length;

    try {
      const creds = await loadDestinationCredentials(sb, dest.id);

      if (dest.provider === "facebook") {
        const token = creds?.access_token || "";
        if (!token) throw new Error("Missing Facebook access token. Connect your credentials in Integrations.");
        for (let i = 0; i < hashed.length; i += 5000) {
          const chunk = hashed.slice(i, i + 5000);
          await pushToFacebook(token, dest.external_audience_id, chunk, op);
        }
      } else if (dest.provider === "google") {
        const devToken = creds?.developer_token || "";
        const accessToken = creds?.access_token || "";
        if (!devToken || !accessToken) throw new Error("Missing Google Ads credentials. Connect your developer token and OAuth access token in Integrations.");
        const customerId = dest.account_id || dest.config?.customer_id || "";
        const userList = dest.external_audience_id;
        if (!customerId || !userList) throw new Error("Google destination missing customer_id or user list resource");
        for (let i = 0; i < hashed.length; i += 5000) {
          const chunk = hashed.slice(i, i + 5000);
          await pushToGoogle(devToken, accessToken, customerId, userList, chunk, op);
        }
      } else {
        throw new Error(`Unsupported provider: ${dest.provider}`);
      }
    } catch (err) {
      errorText = String(err?.message || err);
      matched = 0;
    }

    const finalStatus = errorText ? "failed" : "completed";
    await sb.from("ad_audience_syncs").update({
      status: finalStatus,
      matched_count: matched,
      unmatched_count: unmatched,
      total_count: total,
      error: errorText,
      finished_at: new Date().toISOString(),
    }).eq("id", sync!.id);

    await sb.from("ad_audience_destinations").update({
      last_synced_at: new Date().toISOString(),
      last_status: finalStatus,
      last_error: errorText,
    }).eq("id", dest.id);

    return new Response(JSON.stringify({ ok: !errorText, sync_id: sync?.id, matched, unmatched, total, error: errorText }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
