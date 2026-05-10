<template>
  <div>
    <h1>Architecture</h1>
    <p>Pulse is a single-tenant-per-workspace SaaS. The frontend is a Nuxt 3 (Vue 3, Pinia) SPA. Persistence, auth, RLS, and serverless compute are provided by Supabase.</p>

    <h2>High-level diagram</h2>
    <pre><code>  ┌─────────────────────────────┐       ┌───────────────────────────────┐
  │  Browser (Nuxt SPA)         │──────▶│  Supabase PostgREST (auto API)│
  │  Pinia store · Tailwind UI  │       │  RLS policies per workspace   │
  └─────────────┬───────────────┘       └─────────────┬─────────────────┘
                │                                     │
                │ JWT (Supabase Auth)                 │
                ▼                                     ▼
  ┌─────────────────────────────┐       ┌───────────────────────────────┐
  │  Edge Functions (Deno)      │──────▶│  Postgres + pgvector          │
  │  notify · track · webhooks  │       │  customers · events · journeys│
  │  verify-domain · commerce   │       │  campaign_messages · orders   │
  └─────────────┬───────────────┘       └───────────────────────────────┘
                │
                ▼
  External: AWS SES · SNS · Stripe · Shopify / Woo · downstream webhooks</code></pre>

    <h2>Tech stack</h2>
    <table>
      <thead><tr><th>Layer</th><th>Choice</th><th>Why</th></tr></thead>
      <tbody>
        <tr><td>Frontend</td><td>Nuxt 3 (Vue 3 + Pinia)</td><td>File-based routing, SSR-capable, strong TS support.</td></tr>
        <tr><td>UI</td><td>Tailwind CSS</td><td>Design tokens live in <code>tailwind.config.js</code>. Consistent 8px spacing and 6-ramp color system.</td></tr>
        <tr><td>Auth</td><td>Supabase Auth (email/password)</td><td>Built-in JWT, session refresh, RLS integration.</td></tr>
        <tr><td>Database</td><td>Postgres 15 (Supabase)</td><td>JSONB attributes, full-text for search, triggers for audit.</td></tr>
        <tr><td>Serverless</td><td>Supabase Edge Functions (Deno)</td><td>Proximity to Postgres, JS/TS only, Web APIs.</td></tr>
        <tr><td>Email transport</td><td>AWS SES (SigV4)</td><td>Scalable, pay-per-send, SPF/DKIM/DMARC control.</td></tr>
        <tr><td>Feedback loop</td><td>AWS SNS → <code>email-webhook</code></td><td>Bounce and complaint notifications, auto-suppression.</td></tr>
      </tbody>
    </table>

    <h2>Data model</h2>
    <p>The schema is organized into clusters that mirror the product pillars.</p>
    <h3>Identity & audience</h3>
    <ul>
      <li><code>workspaces</code>, <code>workspace_members</code>, <code>workspace_roles</code></li>
      <li><code>customers</code>, <code>attributes</code>, <code>customer_lists</code>, <code>customer_list_members</code></li>
      <li><code>segments</code>, <code>blacklist</code>, <code>customer_consents</code></li>
    </ul>
    <h3>Behaviour</h3>
    <ul>
      <li><code>events</code> (partitioned by <code>workspace_id</code>, indexed on <code>(customer_id, occurred_at)</code>)</li>
      <li><code>funnels</code>, <code>cohorts</code>, <code>rfm_scores</code>, <code>predictive_scores</code></li>
    </ul>
    <h3>Engagement</h3>
    <ul>
      <li><code>templates</code>, <code>campaigns</code>, <code>campaign_messages</code>, <code>campaign_attributions</code></li>
      <li><code>journeys</code>, <code>journey_nodes</code>, <code>journey_edges</code>, <code>journey_runs</code>, <code>journey_node_stats</code>, <code>journey_variant_stats</code></li>
      <li><code>onsite_messages</code>, <code>banners</code>, <code>surveys</code>, <code>survey_responses</code></li>
    </ul>
    <h3>Deliverability</h3>
    <ul>
      <li><code>email_domains</code>, <code>email_providers</code>, <code>suppression_list</code></li>
      <li><code>sending_policies</code>, <code>sending_suspensions</code>, <code>email_domain_health_v</code></li>
      <li><code>seed_inbox_addresses</code>, <code>seed_inbox_tests</code></li>
    </ul>
    <h3>Commerce (opt-in)</h3>
    <ul>
      <li><code>commerce_orders</code>, <code>commerce_products</code>, <code>campaign_attributions</code></li>
    </ul>
    <h3>Developer surface</h3>
    <ul>
      <li><code>api_keys</code>, <code>webhook_destinations</code>, <code>webhook_deliveries</code>, <code>data_exports_scheduled</code></li>
    </ul>
    <h3>Governance</h3>
    <ul>
      <li><code>audit_logs</code>, <code>approvals</code>, <code>notifications</code>, <code>platform_admins</code></li>
    </ul>

    <h2>Row Level Security</h2>
    <p>Every workspace-scoped table has RLS enabled with the following default pattern:</p>
    <ul>
      <li><strong>SELECT</strong>: row is visible if the requester is a <code>workspace_member</code>.</li>
      <li><strong>INSERT / UPDATE</strong>: requester must be a member with role <code>owner</code>, <code>admin</code>, or <code>editor</code>.</li>
      <li><strong>DELETE</strong>: reserved to <code>owner</code> or <code>admin</code>.</li>
    </ul>
    <p>Sensitive tables (<code>api_keys</code>, <code>sending_policies</code>, <code>workspace_roles</code>) further restrict writes to owners/admins only.</p>

    <h2>Edge functions</h2>
    <table>
      <thead><tr><th>Function</th><th>Purpose</th></tr></thead>
      <tbody>
        <tr><td><code>track</code></td><td>Public event ingestion. Authenticates with scoped API key, writes to <code>events</code>, upserts unknown customers.</td></tr>
        <tr><td><code>notify</code></td><td>Sends transactional and marketing messages. Enforces suppression, frequency caps, quiet hours, and pause flag.</td></tr>
        <tr><td><code>email-webhook</code></td><td>Receives AWS SNS notifications for bounces and complaints. Auto-suspends sending on threshold breach.</td></tr>
        <tr><td><code>verify-domain</code></td><td>Polls DNS for SPF, DKIM, DMARC records and updates <code>email_domains</code> health.</td></tr>
        <tr><td><code>commerce-webhook</code></td><td>Accepts Shopify and WooCommerce order webhooks, normalizes, upserts orders, emits events, and attributes revenue.</td></tr>
        <tr><td><code>webhook-dispatch</code></td><td>Delivers signed outbound webhooks to tenant destinations with retry accounting.</td></tr>
      </tbody>
    </table>

    <h2>Secrets & configuration</h2>
    <p>Edge functions read configuration from environment variables managed through the Supabase dashboard. The frontend exposes only <code>VITE_SUPABASE_URL</code> and <code>VITE_SUPABASE_ANON_KEY</code>. The service-role key is used exclusively by edge functions and is never sent to the browser.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Architecture · Pulse Docs' })
</script>
