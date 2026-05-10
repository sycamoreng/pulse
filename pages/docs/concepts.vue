<template>
  <div>
    <h1>Core concepts</h1>
    <p>A small glossary of the objects you'll interact with across the product and API.</p>

    <h2>Workspace</h2>
    <p>Every account is scoped to one or more <strong>workspaces</strong>. All customer records, events, campaigns, journeys, and settings live inside a workspace. Access is enforced at the database layer via Supabase Row Level Security (RLS) — users can only read or write data in workspaces they belong to.</p>
    <p>Key workspace-level settings:</p>
    <ul>
      <li><strong>Plan</strong> (free, growth, business) — caps quotas and gates premium features.</li>
      <li><strong>Industry</strong> — informs onboarding defaults and which modules are suggested.</li>
      <li><strong>Feature modules</strong> — e.g. <code>commerce_enabled</code>. Turn individual capabilities on/off per workspace.</li>
      <li><strong>Branding</strong> — name, logo, primary and accent colors applied to composer previews and transactional emails.</li>
      <li><strong>Timezone</strong> — used for quiet hours, send-time optimization, and cohort bucketing.</li>
    </ul>

    <h2>Customer</h2>
    <p>A <strong>customer</strong> is the canonical record of a user. Each row has a workspace-unique <code>external_id</code>, an optional email and phone, basic identity attributes (<code>first_name</code>, <code>last_name</code>, <code>country</code>, <code>city</code>), and a JSON <code>attributes</code> blob for arbitrary traits (plan, wallet balance, subscription tier, etc.).</p>
    <p>Customers are created three ways:</p>
    <ol>
      <li>Directly via the app (manual add or CSV import).</li>
      <li>Automatically the first time the Track API sees an unknown <code>external_id</code>.</li>
      <li>On commerce webhook ingest, matched by email.</li>
    </ol>

    <h2>Event</h2>
    <p>An <strong>event</strong> is a timestamped action taken by (or about) a customer. Pulse treats everything as an event: page views, signups, purchases, custom actions, email opens/clicks, journey enter/exit, and more.</p>
    <pre><code>{
  "name": "item_added_to_cart",
  "customer_id": "cust_123",
  "occurred_at": "2026-05-10T14:03:00Z",
  "properties": { "sku": "SKU-42", "price": 29.00, "currency": "USD" }
}</code></pre>
    <p>Events power segments ("anyone who did X in the last 7 days"), funnels, journeys (as triggers or waits), and revenue attribution.</p>

    <h2>Attribute</h2>
    <p>Attributes are <strong>stateful traits</strong> about a customer (<code>plan=premium</code>, <code>is_trial=true</code>). Unlike events, attributes persist until explicitly updated. Define types in the Attributes registry to get validation, segment auto-complete, and consistent filter UIs.</p>

    <h2>Segment</h2>
    <p>A <strong>segment</strong> is a named, reusable audience definition — a list of conditions over attributes, events, lists, and RFM buckets. Segments are computed on read, so membership reflects the latest data without any sync step.</p>

    <h2>List</h2>
    <p>A <strong>list</strong> is a static, manually curated audience (e.g. "Beta wave 3 invitees"). Lists support CSV import/export and can be combined with segments in journey entry conditions.</p>

    <h2>Template</h2>
    <p>A reusable message body with a channel, subject (email), preview text, Liquid variables, and optional AMP HTML. Templates decouple creative from delivery logic so the same template can be used by campaigns and journeys.</p>

    <h2>Campaign</h2>
    <p>A one-shot or scheduled broadcast. Campaigns target an audience (segment or list), pick a channel and template, and optionally include an A/B test or send-time optimization. Each campaign produces rows in <code>campaign_messages</code> for every recipient.</p>

    <h2>Journey</h2>
    <p>A visual, multi-step flow. Nodes include <em>entry</em>, <em>send</em>, <em>wait</em>, <em>condition</em>, <em>A/B split</em>, and <em>exit</em>. Each run is tracked against the journey instance so you can see drop-off at any node.</p>

    <h2>Identity resolution</h2>
    <p>Pulse uses <code>external_id</code> as the primary key. When two touchpoints report the same <code>external_id</code>, they are merged into a single customer. Email and phone are secondary identifiers used by imports, commerce ingest, and suppression lists.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Core concepts · Pulse Docs' })
</script>
