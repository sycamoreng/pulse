<template>
  <div>
    <h1>Shopify integration</h1>
    <p>Ingest Shopify orders into Pulse in real time by pointing a pair of webhooks at the <code>commerce-webhook</code> function.</p>

    <h2>Webhook URL</h2>
    <p>Under <strong>Integrations → Shopify / Woo</strong>, copy the Shopify URL. It looks like:</p>
    <pre><code>https://&lt;your-supabase&gt;.functions.supabase.co/commerce-webhook?workspace_id=&lt;id&gt;&amp;source=shopify</code></pre>

    <h2>In Shopify admin</h2>
    <ol>
      <li>Go to <strong>Settings → Notifications → Webhooks</strong>.</li>
      <li>Add a webhook for <em>Order creation</em>. Format: JSON. URL: the Pulse URL above.</li>
      <li>Add another for <em>Order payment</em> with the same URL.</li>
      <li>Optionally add <em>Product update</em> to sync catalog changes.</li>
    </ol>

    <h2>What happens on receipt</h2>
    <ol>
      <li>Pulse normalizes the Shopify payload into the canonical order shape.</li>
      <li>It upserts <code>commerce_orders</code> using <code>(workspace_id, source, external_id)</code>.</li>
      <li>It upserts the customer by email, creating one if needed.</li>
      <li>It emits an event: <code>order_created</code> for new orders, <code>order_completed</code> when the order becomes <code>paid</code>.</li>
      <li>It runs last-touch attribution against campaigns sent in the last 7 days.</li>
    </ol>

    <h2>HMAC verification</h2>
    <p>Shopify signs every webhook with an HMAC-SHA256 header. Pulse validates the signature using your store's shared secret. If verification fails, the request is rejected with HTTP 401.</p>

    <h2>Backfilling history</h2>
    <p>The webhook only captures new orders from the moment it's configured. To import historical orders, export a CSV from Shopify and upload it under <strong>Imports → Orders</strong>.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Shopify · Pulse Docs' })
</script>
