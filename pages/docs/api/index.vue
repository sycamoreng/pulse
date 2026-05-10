<template>
  <div>
    <h1>API reference</h1>
    <p>Pulse exposes two HTTP surfaces:</p>
    <ul>
      <li><strong>Edge Functions</strong> under <code>/functions/v1/*</code> — event ingestion, notifications, webhooks, domain verification.</li>
      <li><strong>PostgREST</strong> under <code>/rest/v1/*</code> — direct authenticated access to database tables, constrained by RLS.</li>
    </ul>

    <h2>Base URL</h2>
    <pre><code>https://&lt;your-supabase-project&gt;.supabase.co</code></pre>

    <h2>Authentication</h2>
    <p>All endpoints require one of:</p>
    <ul>
      <li><strong>Supabase JWT</strong> from a logged-in user session — for PostgREST and authenticated edge functions.</li>
      <li><strong>Scoped API key</strong> (prefix <code>pk_</code>) — for the Track API and anywhere else you need server-to-server access.</li>
      <li><strong>Anon key</strong> — for webhook callbacks that shouldn't require authentication (Shopify, SNS). These functions authenticate the payload itself (HMAC / signing secret).</li>
    </ul>

    <h3>Sending a request</h3>
    <pre><code>curl https://&lt;project&gt;.supabase.co/functions/v1/track \
  -H "Authorization: Bearer pk_..." \
  -H "Content-Type: application/json" \
  -d '{"external_id":"u1","name":"signup_completed"}'</code></pre>

    <h2>Rate limits</h2>
    <ul>
      <li>Track API: <strong>1,000 requests / second / workspace</strong>.</li>
      <li>PostgREST: <strong>100 requests / second / user</strong>.</li>
      <li>Outbound webhooks: no rate limit from Pulse; destination's own limits apply.</li>
    </ul>

    <h2>Error format</h2>
    <pre><code>{ "error": "human readable message" }</code></pre>
    <p>Status codes follow standard HTTP conventions: 400 for bad input, 401 for missing auth, 403 for insufficient scope, 404 for unknown entity, 429 for rate limiting, 5xx for server errors.</p>

    <h2>Endpoints</h2>
    <div class="card-row">
      <NuxtLink to="/docs/api/track" class="card-link">
        <div class="title">Track API</div>
        <div class="desc">Ingest events and identify customers.</div>
      </NuxtLink>
      <NuxtLink to="/docs/api/webhooks" class="card-link">
        <div class="title">Outbound webhooks</div>
        <div class="desc">Subscribe to Pulse events and deliver them to your stack.</div>
      </NuxtLink>
      <NuxtLink to="/docs/api/api-keys" class="card-link">
        <div class="title">API keys</div>
        <div class="desc">Manage, scope, rotate, and revoke keys.</div>
      </NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'API · Pulse Docs' })
</script>
