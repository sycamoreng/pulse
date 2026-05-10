<template>
  <div>
    <h1>WooCommerce integration</h1>
    <p>Connect a WooCommerce store by creating webhooks pointed at Pulse's <code>commerce-webhook</code> endpoint.</p>

    <h2>Webhook URL</h2>
    <pre><code>https://&lt;your-supabase&gt;.functions.supabase.co/commerce-webhook?workspace_id=&lt;id&gt;&amp;source=woocommerce</code></pre>

    <h2>In WooCommerce admin</h2>
    <ol>
      <li>Go to <strong>WooCommerce → Settings → Advanced → Webhooks</strong>.</li>
      <li>Click <em>Add webhook</em>.</li>
      <li>Set Topic: <em>Order created</em>. Delivery URL: the Pulse URL above.</li>
      <li>Copy the generated Secret; it's used for signature verification.</li>
      <li>Repeat for <em>Order updated</em> so paid-state transitions flow in.</li>
    </ol>

    <h2>Payload normalization</h2>
    <p>WooCommerce's JSON structure differs from Shopify's. Pulse's <code>normalizeWooOrder</code> maps fields like <code>billing.email</code>, <code>line_items[*].name</code>, and <code>shipping_total</code> into the canonical shape before writing to <code>commerce_orders</code>.</p>

    <h2>Refunds</h2>
    <p>Configure a webhook for the <em>Refund created</em> topic as well. Pulse emits <code>order_refunded</code> events and subtracts the refunded amount from attributed revenue on reporting.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'WooCommerce · Pulse Docs' })
</script>
