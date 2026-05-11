import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

// Minimal SCIM 2.0 surface for workspace member provisioning.
// Path layout: /scim/<route>
//   GET  /scim/ServiceProviderConfig
//   GET  /scim/Schemas
//   GET  /scim/Users                -> list
//   POST /scim/Users                -> create (invite)
//   GET  /scim/Users/:id
//   PATCH/PUT /scim/Users/:id       -> update role / active
//   DELETE /scim/Users/:id

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};
const scimJson = (d: unknown, s = 200) => new Response(JSON.stringify(d), {
  status: s,
  headers: { ...corsHeaders, "Content-Type": "application/scim+json" },
});
const scimError = (detail: string, status = 400) => scimJson({
  schemas: ["urn:ietf:params:scim:api:messages:2.0:Error"],
  detail,
  status: String(status),
}, status);

async function sha256Hex(s: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}

function memberToScim(m: any) {
  return {
    schemas: ["urn:ietf:params:scim:schemas:core:2.0:User"],
    id: m.id,
    userName: m.email || "",
    emails: m.email ? [{ value: m.email, primary: true }] : [],
    active: true,
    roles: m.role ? [{ value: m.role, primary: true }] : [],
    meta: { resourceType: "User", created: m.created_at, lastModified: m.created_at },
  };
}

async function authenticate(req: Request, sb: any): Promise<{ workspace_id: string } | null> {
  const auth = req.headers.get("Authorization") || "";
  if (!auth.startsWith("Bearer ")) return null;
  const raw = auth.slice(7).trim();
  if (!raw) return null;
  const hash = await sha256Hex(raw);
  const { data } = await sb.from("scim_tokens").select("id, workspace_id, is_active")
    .eq("token_hash", hash).eq("is_active", true).maybeSingle();
  if (!data) return null;
  sb.from("scim_tokens").update({ last_used_at: new Date().toISOString() }).eq("id", data.id).then(() => {});
  return { workspace_id: data.workspace_id };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const url = new URL(req.url);
    const parts = url.pathname.replace(/^\/+/, "").split("/").filter(Boolean);
    // parts[0] is always "scim" when deployed at /functions/v1/scim/...
    if (parts[0] !== "scim") return scimError("Not found", 404);

    const resource = parts[1] || "";
    const resourceId = parts[2] || "";

    if (req.method === "GET" && resource === "ServiceProviderConfig") {
      return scimJson({
        schemas: ["urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig"],
        patch: { supported: true },
        bulk: { supported: false, maxOperations: 0, maxPayloadSize: 0 },
        filter: { supported: true, maxResults: 200 },
        changePassword: { supported: false },
        sort: { supported: false },
        etag: { supported: false },
        authenticationSchemes: [{ type: "oauthbearertoken", name: "Bearer", description: "SCIM bearer token" }],
      });
    }

    if (req.method === "GET" && resource === "Schemas") {
      return scimJson({
        schemas: ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
        totalResults: 1,
        Resources: [{ id: "urn:ietf:params:scim:schemas:core:2.0:User" }],
      });
    }

    const actor = await authenticate(req, sb);
    if (!actor) return scimError("Unauthorized", 401);

    if (resource !== "Users") return scimError("Resource not supported", 404);

    if (req.method === "GET" && !resourceId) {
      const filter = url.searchParams.get("filter") || "";
      const m = filter.match(/userName\s+eq\s+"([^"]+)"/i);
      let q = sb.from("workspace_members").select("id, email, role, created_at").eq("workspace_id", actor.workspace_id);
      if (m) q = q.eq("email", m[1]);
      const { data } = await q.order("created_at", { ascending: false }).limit(200);
      return scimJson({
        schemas: ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
        totalResults: (data || []).length,
        Resources: (data || []).map(memberToScim),
      });
    }

    if (req.method === "GET" && resourceId) {
      const { data } = await sb.from("workspace_members").select("id, email, role, created_at")
        .eq("workspace_id", actor.workspace_id).eq("id", resourceId).maybeSingle();
      if (!data) return scimError("User not found", 404);
      return scimJson(memberToScim(data));
    }

    if (req.method === "POST" && !resourceId) {
      const body = await req.json().catch(() => ({}));
      const email = body.userName || body.emails?.[0]?.value;
      if (!email) return scimError("userName or emails required", 400);
      const role = body.roles?.[0]?.value || "member";
      const { data, error } = await sb.from("workspace_members")
        .insert({ workspace_id: actor.workspace_id, email, role })
        .select("id, email, role, created_at").maybeSingle();
      if (error || !data) return scimError(error?.message || "Create failed", 409);
      return scimJson(memberToScim(data), 201);
    }

    if ((req.method === "PATCH" || req.method === "PUT") && resourceId) {
      const body = await req.json().catch(() => ({}));
      const patch: Record<string, any> = {};
      if (req.method === "PUT") {
        if (body.roles?.[0]?.value) patch.role = body.roles[0].value;
        if (body.userName) patch.email = body.userName;
      } else {
        const ops = Array.isArray(body.Operations) ? body.Operations : [];
        for (const op of ops) {
          const path = (op.path || "").toLowerCase();
          if (path === "active" && op.value === false) patch.__deactivate = true;
          if (path === "roles" || path === "roles[primary eq true].value") patch.role = Array.isArray(op.value) ? op.value[0]?.value : op.value;
          if (path === "username") patch.email = op.value;
        }
      }
      if (patch.__deactivate) {
        const { error } = await sb.from("workspace_members")
          .delete().eq("workspace_id", actor.workspace_id).eq("id", resourceId);
        if (error) return scimError(error.message, 500);
        return new Response(null, { status: 204, headers: corsHeaders });
      }
      delete patch.__deactivate;
      if (!Object.keys(patch).length) return scimError("Nothing to update", 400);
      const { data, error } = await sb.from("workspace_members")
        .update(patch).eq("workspace_id", actor.workspace_id).eq("id", resourceId)
        .select("id, email, role, created_at").maybeSingle();
      if (error || !data) return scimError(error?.message || "User not found", 404);
      return scimJson(memberToScim(data));
    }

    if (req.method === "DELETE" && resourceId) {
      const { error } = await sb.from("workspace_members")
        .delete().eq("workspace_id", actor.workspace_id).eq("id", resourceId);
      if (error) return scimError(error.message, 500);
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    return scimError("Method not allowed", 405);
  } catch (e) {
    return scimError((e as Error).message || "Server error", 500);
  }
});
