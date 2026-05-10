<template>
  <div>
    <h1>Events</h1>
    <p>Events are the behavioural spine of Pulse. Everything you do — segmentation, journeys, funnels, attribution — ultimately reads from the <code>events</code> table.</p>

    <h2>Shape</h2>
    <pre><code>{
  "id": "uuid",
  "workspace_id": "uuid",
  "customer_id": "uuid | null",
  "name": "purchase_completed",
  "properties": { "order_id": "o_1", "total": 99.90, "currency": "USD" },
  "occurred_at": "2026-05-10T12:34:56Z",
  "received_at": "2026-05-10T12:35:01Z",
  "context": { "ip": "203.0.113.5", "ua": "Mozilla/5.0…" }
}</code></pre>

    <h2>Naming conventions</h2>
    <ul>
      <li>Use <strong>snake_case</strong> and <strong>past tense</strong>: <code>signup_completed</code>, <code>item_added_to_cart</code>, <code>subscription_cancelled</code>.</li>
      <li>Reserve a small set of standard names for common actions (<code>page_viewed</code>, <code>session_started</code>).</li>
      <li>Avoid embedding values in event names. Prefer <code>plan_upgraded</code> with <code>properties.to = 'premium'</code> over <code>upgraded_to_premium</code>.</li>
    </ul>

    <h2>Properties</h2>
    <p>Properties are free-form JSON. Pulse indexes common shapes (strings, numbers, booleans) and surfaces them in the segment builder. Use consistent keys and types across events; mixing <code>total: "99.90"</code> and <code>total: 99.90</code> will split your segment buckets in unexpected ways.</p>

    <h2>Standard events emitted by Pulse</h2>
    <table>
      <thead><tr><th>Event</th><th>Emitted when</th></tr></thead>
      <tbody>
        <tr><td><code>email_sent</code></td><td>Notify function dispatches an email via AWS SES.</td></tr>
        <tr><td><code>email_delivered</code></td><td>SES reports successful delivery (SNS).</td></tr>
        <tr><td><code>email_opened</code> / <code>email_clicked</code></td><td>Open pixel / click tracker fires.</td></tr>
        <tr><td><code>email_bounced</code> / <code>email_complained</code></td><td>SNS feedback loop.</td></tr>
        <tr><td><code>unsubscribed</code></td><td>Customer uses the one-click unsubscribe link.</td></tr>
        <tr><td><code>journey_entered</code> / <code>journey_exited</code></td><td>Any journey run starts or ends.</td></tr>
        <tr><td><code>order_created</code> / <code>order_completed</code></td><td>Commerce webhook receives a new/paid order.</td></tr>
      </tbody>
    </table>

    <h2>Events explorer</h2>
    <p>Under <strong>Events</strong> you can:</p>
    <ul>
      <li>Filter by name, customer, and date range.</li>
      <li>Inspect raw JSON payloads.</li>
      <li>Pivot counts over time (hourly / daily / weekly buckets).</li>
    </ul>

    <h2>Retention</h2>
    <p>Events older than the workspace's <code>data_retention_days</code> (default 365) are deleted by a nightly job. Set this in <strong>Settings → Data</strong> to meet your compliance policy.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Events · Pulse Docs' })
</script>
