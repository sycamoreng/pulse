<template>
  <div>
    <h1>Install the SDK</h1>
    <p>Pulse's Track API is language-agnostic. You can call it from a browser, mobile app, or backend service. The examples below use <code>fetch</code>, but any HTTP client works.</p>

    <h2>Step 1 — Get an API key</h2>
    <p>Go to <strong>Integrations → API keys → + New key</strong>. Give the key a descriptive name and select the scopes you need.</p>
    <ul>
      <li><code>track:write</code> — send events and identify calls.</li>
      <li><code>track:read</code> — read back events (for diagnostics).</li>
      <li><code>customers:read</code> / <code>customers:write</code> — read / upsert customer profiles.</li>
      <li><code>events:read</code> — pull event streams.</li>
      <li><code>campaigns:read</code> — list campaigns and their stats.</li>
    </ul>
    <div class="callout callout-warn">
      <div>Keys are shown <strong>once</strong>. Copy yours to a secrets manager immediately. You can revoke (not recover) a key at any time.</div>
    </div>

    <h2>Step 2 — Track an event</h2>
    <pre><code>await fetch(
  `${'$'}{PULSE_URL}/functions/v1/track`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${'$'}{PULSE_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      external_id: 'user_123',
      name: 'item_added_to_cart',
      properties: { sku: 'SKU-42', price: 29.00, currency: 'USD' },
      context: { ip: '203.0.113.12', ua: navigator.userAgent }
    }),
  }
)</code></pre>

    <h2>Step 3 — Identify a customer</h2>
    <p>Send an <code>identify</code> call whenever you learn new traits about a user (on signup, on subscription change, etc.).</p>
    <pre><code>await fetch(
  `${'$'}{PULSE_URL}/functions/v1/track`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${'$'}{PULSE_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      type: 'identify',
      external_id: 'user_123',
      email: 'sara@example.com',
      first_name: 'Sara',
      attributes: {
        plan: 'premium',
        signup_source: 'referral',
        wallet_balance_ngn: 125000
      }
    }),
  }
)</code></pre>

    <h2>Step 4 — Verify in the UI</h2>
    <p>Open <strong>Events</strong> in the Pulse sidebar. You should see your event arrive within a few seconds. If it doesn't, check:</p>
    <ul>
      <li>The API key has <code>track:write</code> scope and is not revoked.</li>
      <li>The request returns HTTP 200. A 401 means the key is wrong; a 403 means the scope is missing.</li>
      <li>The <code>external_id</code> matches a customer you'd expect (or a new customer is auto-created on first write).</li>
    </ul>

    <h2>Best practices</h2>
    <ul>
      <li>Use <strong>consistent event names</strong>. <code>item_added_to_cart</code> everywhere, not three variants.</li>
      <li>Put <strong>who</strong> in <code>external_id</code>, <strong>what</strong> in <code>name</code>, and <strong>details</strong> in <code>properties</code>.</li>
      <li>Fire events server-side when they involve money or trust. Browser events can be blocked or spoofed.</li>
      <li>Keep <code>properties</code> flat and under 32 keys; arrays and nested objects are allowed but harder to segment on.</li>
    </ul>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Install the SDK · Pulse Docs' })
</script>
