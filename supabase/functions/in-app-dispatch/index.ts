import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const body = await req.json().catch(() => ({}));

    const workspace_id: string | undefined = body.workspace_id;
    if (!workspace_id) {
      return new Response(JSON.stringify({ ok: false, error: "workspace_id required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const to_user_id: string | undefined = body.to_user_id;
    const external_id: string | undefined = body.external_id;

    let customerId = to_user_id || null;
    if (!customerId && external_id) {
      const { data } = await sb.from("customers").select("id")
        .eq("workspace_id", workspace_id).eq("external_id", external_id).maybeSingle();
      customerId = data?.id || null;
    }
    if (!customerId) {
      return new Response(JSON.stringify({ ok: false, error: "no customer resolved" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const placement = body.placement || "inbox";
    const payload = body.payload && typeof body.payload === "object" ? body.payload : {};
    const expiresAt = body.expires_at ||
      (body.ttl_hours ? new Date(Date.now() + Number(body.ttl_hours) * 3_600_000).toISOString() : null);

    const { data: row, error } = await sb.from("in_app_messages").insert({
      workspace_id,
      customer_id: customerId,
      placement,
      title: body.title || "",
      body: body.body || "",
      image_url: body.image_url || "",
      cta_label: body.cta_label || "",
      cta_url: body.cta_url || "",
      payload,
      journey_id: body.journey_id || null,
      campaign_id: body.campaign_id || null,
      expires_at: expiresAt,
    }).select("id").maybeSingle();

    if (error) {
      return new Response(JSON.stringify({ ok: false, error: error.message }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ ok: true, id: row?.id }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
