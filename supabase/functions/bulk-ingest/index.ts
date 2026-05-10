import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

type CustomerInput = {
  external_id?: string;
  email?: string;
  phone?: string;
  first_name?: string;
  last_name?: string;
  country?: string;
  city?: string;
  device?: string;
  platform?: string;
  timezone?: string;
  locale?: string;
  last_seen_at?: string;
  attributes?: Record<string, unknown>;
};

type EventInput = {
  external_id?: string;
  customer_id?: string;
  name: string;
  properties?: Record<string, unknown>;
  occurred_at?: string;
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { ok: false, error: "method_not_allowed" });
  }

  try {
    const authHeader = req.headers.get("Authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) return json(401, { ok: false, error: "missing_auth" });

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser(token);
    if (userErr || !userData?.user) return json(401, { ok: false, error: "invalid_auth" });
    const userId = userData.user.id;

    const body = await req.json().catch(() => null) as
      | { workspace_id: string; customers?: CustomerInput[]; events?: EventInput[] }
      | null;
    if (!body?.workspace_id) return json(400, { ok: false, error: "missing_workspace_id" });

    const admin = createClient(supabaseUrl, serviceKey);

    const { data: memberCheck } = await admin
      .from("workspace_members")
      .select("role")
      .eq("workspace_id", body.workspace_id)
      .eq("user_id", userId)
      .maybeSingle();
    if (!memberCheck) return json(403, { ok: false, error: "not_a_member" });
    if (!["owner", "admin", "editor"].includes(memberCheck.role)) {
      return json(403, { ok: false, error: "insufficient_role" });
    }

    const summary = {
      customers_upserted: 0,
      customers_failed: 0,
      events_inserted: 0,
      events_failed: 0,
      errors: [] as { stage: string; message: string }[],
    };

    if (Array.isArray(body.customers) && body.customers.length) {
      const MAX = 10_000;
      if (body.customers.length > MAX) {
        return json(413, { ok: false, error: `too_many_customers_max_${MAX}` });
      }
      const records = body.customers
        .filter((c) => c && (c.external_id || c.email || c.phone))
        .map((c) => ({
          ...c,
          workspace_id: body.workspace_id,
          external_id: c.external_id || c.email || c.phone,
          attributes: c.attributes || {},
        }));
      const CHUNK = 500;
      for (let i = 0; i < records.length; i += CHUNK) {
        const slice = records.slice(i, i + CHUNK);
        const { data, error } = await admin
          .from("customers")
          .upsert(slice, { onConflict: "workspace_id,external_id" })
          .select("id");
        if (error) {
          summary.customers_failed += slice.length;
          summary.errors.push({ stage: "customers", message: error.message });
        } else {
          summary.customers_upserted += data?.length || slice.length;
        }
      }
    }

    if (Array.isArray(body.events) && body.events.length) {
      const MAX = 50_000;
      if (body.events.length > MAX) {
        return json(413, { ok: false, error: `too_many_events_max_${MAX}` });
      }

      const externalIds = Array.from(new Set(
        body.events
          .map((e) => e.external_id)
          .filter((v): v is string => typeof v === "string" && v.length > 0)
      ));
      const extToId = new Map<string, string>();
      if (externalIds.length) {
        const LOOKUP = 1000;
        for (let i = 0; i < externalIds.length; i += LOOKUP) {
          const { data } = await admin
            .from("customers")
            .select("id, external_id")
            .eq("workspace_id", body.workspace_id)
            .in("external_id", externalIds.slice(i, i + LOOKUP));
          for (const row of data || []) extToId.set(row.external_id, row.id);
        }
      }

      const eventRecords = body.events
        .map((e) => {
          const customerId = e.customer_id || (e.external_id ? extToId.get(e.external_id) : undefined);
          if (!e.name) return null;
          return {
            workspace_id: body.workspace_id,
            customer_id: customerId || null,
            name: e.name,
            properties: e.properties || {},
            occurred_at: e.occurred_at || new Date().toISOString(),
          };
        })
        .filter(Boolean) as Array<Record<string, unknown>>;

      const CHUNK = 2000;
      for (let i = 0; i < eventRecords.length; i += CHUNK) {
        const slice = eventRecords.slice(i, i + CHUNK);
        const { error } = await admin.from("events").insert(slice);
        if (error) {
          summary.events_failed += slice.length;
          summary.errors.push({ stage: "events", message: error.message });
        } else {
          summary.events_inserted += slice.length;
        }
      }
    }

    await admin.rpc("increment_usage", {
      p_workspace_id: body.workspace_id,
      p_events: summary.events_inserted,
    });

    return json(200, { ok: true, ...summary });
  } catch (e) {
    return json(500, { ok: false, error: String(e) });
  }
});
