import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey, X-Shopify-Topic, X-Shopify-Hmac-Sha256, X-WC-Webhook-Topic, X-WC-Webhook-Signature",
};

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

function normalizeShopifyOrder(body: any) {
  const items = (body.line_items || []).map((li: any) => ({
    product_id: String(li.product_id || ""),
    title: li.title || "",
    quantity: Number(li.quantity || 0),
    price: Number(li.price || 0),
    image_url: li.image?.src || "",
  }));
  return {
    external_id: String(body.id),
    email: String(body.email || body.contact_email || "").toLowerCase(),
    currency: body.currency || "USD",
    total_amount: Number(body.total_price || 0),
    subtotal: Number(body.subtotal_price || 0),
    tax: Number(body.total_tax || 0),
    shipping: Number(body.total_shipping_price_set?.shop_money?.amount || 0),
    discount: Number(body.total_discounts || 0),
    status: body.financial_status || "pending",
    items,
    occurred_at: body.created_at || new Date().toISOString(),
    raw: body,
  };
}

function normalizeWooOrder(body: any) {
  const items = (body.line_items || []).map((li: any) => ({
    product_id: String(li.product_id || ""),
    title: li.name || "",
    quantity: Number(li.quantity || 0),
    price: Number(li.price || 0),
    image_url: li.image?.src || "",
  }));
  return {
    external_id: String(body.id),
    email: String(body.billing?.email || "").toLowerCase(),
    currency: body.currency || "USD",
    total_amount: Number(body.total || 0),
    subtotal: Number(body.total || 0) - Number(body.total_tax || 0) - Number(body.shipping_total || 0),
    tax: Number(body.total_tax || 0),
    shipping: Number(body.shipping_total || 0),
    discount: Number(body.discount_total || 0),
    status: body.status || "pending",
    items,
    occurred_at: body.date_created || new Date().toISOString(),
    raw: body,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const url = new URL(req.url);
    const source = (url.searchParams.get("source") || "shopify").toLowerCase();
    const workspaceId = url.searchParams.get("workspace_id");
    if (!workspaceId) return json({ error: "workspace_id query param required" }, 400);

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const body = await req.json().catch(() => ({}));

    const norm = source === "woocommerce" ? normalizeWooOrder(body) : normalizeShopifyOrder(body);
    if (!norm.external_id) return json({ error: "missing order id" }, 400);

    let customer_id: string | null = null;
    if (norm.email) {
      const { data: cust } = await supabase.from("customers")
        .select("id").eq("workspace_id", workspaceId).eq("email", norm.email).maybeSingle();
      customer_id = cust?.id || null;
      if (!customer_id) {
        const { data: created } = await supabase.from("customers")
          .insert({ workspace_id: workspaceId, email: norm.email, external_id: norm.email })
          .select().maybeSingle();
        customer_id = created?.id || null;
      }
    }

    const { data: order, error } = await supabase.from("commerce_orders")
      .upsert({ workspace_id: workspaceId, customer_id, source, ...norm }, { onConflict: "workspace_id,source,external_id" })
      .select().maybeSingle();
    if (error) return json({ error: error.message }, 400);

    // Emit a Pulse event so journeys/segments can react
    await supabase.from("events").insert({
      workspace_id: workspaceId,
      customer_id,
      name: norm.status === "paid" || norm.status === "completed" ? "order_completed" : "order_created",
      properties: { order_id: order?.id, source, total: norm.total_amount, currency: norm.currency, items: norm.items },
      occurred_at: norm.occurred_at,
    });

    // Last-touch attribution: find the last campaign message sent to this customer within 7 days
    if (customer_id && order?.id) {
      const since = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString();
      const { data: lastMsg } = await supabase.from("campaign_messages")
        .select("campaign_id, sent_at")
        .eq("workspace_id", workspaceId)
        .eq("customer_id", customer_id)
        .gte("sent_at", since)
        .order("sent_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (lastMsg?.campaign_id) {
        await supabase.from("campaign_attributions").insert({
          workspace_id: workspaceId,
          campaign_id: lastMsg.campaign_id,
          customer_id,
          order_id: order.id,
          revenue: norm.total_amount,
          currency: norm.currency,
          model: "last_touch",
          window_hours: 168,
        });
      }
    }

    return json({ ok: true, order_id: order?.id });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
