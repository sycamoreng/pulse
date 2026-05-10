<template>
  <div>
    <h1>Track API</h1>
    <p>The Track API is the primary way to feed customer behaviour into Pulse. It accepts <em>event</em>, <em>identify</em>, and <em>alias</em> calls.</p>

    <h2>Endpoint</h2>
    <pre><code>POST /functions/v1/track</code></pre>

    <h2>Authorization</h2>
    <pre><code>Authorization: Bearer pk_&lt;your-scoped-key&gt;</code></pre>
    <p>The key must include the <code>track:write</code> scope.</p>

    <h2>Event payload</h2>
    <pre><code>{
  "external_id": "user_123",
  "name": "item_added_to_cart",
  "occurred_at": "2026-05-10T14:03:00Z",
  "properties": {
    "sku": "SKU-42",
    "price": 29.00,
    "currency": "USD"
  },
  "context": {
    "ip": "203.0.113.12",
    "ua": "Mozilla/5.0…"
  }
}</code></pre>

    <h2>Identify payload</h2>
    <pre><code>{
  "type": "identify",
  "external_id": "user_123",
  "email": "sara@example.com",
  "phone": "+234801xxxxxxx",
  "first_name": "Sara",
  "last_name": "Okafor",
  "country": "NG",
  "attributes": {
    "plan": "premium",
    "signup_source": "referral",
    "wallet_balance_ngn": 125000
  }
}</code></pre>
    <p>Identify calls are <strong>merged</strong> into the customer record — fields not included in the call are left untouched.</p>

    <h2>Alias payload</h2>
    <pre><code>{
  "type": "alias",
  "external_id": "user_123",
  "previous_id": "anon-abc"
}</code></pre>
    <p>Use <em>alias</em> to connect an anonymous visitor (identified only by a device ID) to a known user once they sign up. Pulse rewrites historic events to the new <code>external_id</code>.</p>

    <h2>Response</h2>
    <pre><code>{ "ok": true, "event_id": "uuid", "customer_id": "uuid" }</code></pre>

    <h2>Bulk ingest</h2>
    <p>Wrap up to 500 events in a single request by posting <code>{ "events": [...] }</code>. Each is validated independently; the response includes per-event success or error.</p>

    <h2>Idempotency</h2>
    <p>Include a stable <code>idempotency_key</code> to prevent duplicate events (e.g. on retry). Pulse keeps keys for 24 hours.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Track API · Pulse Docs' })
</script>
