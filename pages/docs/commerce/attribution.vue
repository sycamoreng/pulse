<template>
  <div>
    <h1>Revenue attribution</h1>
    <p>Pulse automatically assigns revenue from incoming orders back to the campaign (and in future, journey) most likely to have driven them.</p>

    <h2>Model</h2>
    <p>The default model is <strong>last-touch</strong> with a <strong>168-hour (7-day) window</strong>. When an order arrives:</p>
    <ol>
      <li>Pulse resolves the customer by email.</li>
      <li>It finds the most recent <code>campaign_messages</code> row for that customer with <code>sent_at</code> within the last 7 days.</li>
      <li>It inserts a <code>campaign_attributions</code> row linking the campaign, the customer, the order, the revenue, and the currency.</li>
    </ol>

    <h2>Reporting</h2>
    <p>The <code>campaign_revenue_v</code> view aggregates attributed revenue per campaign. The Campaigns list page uses this view to show total revenue, average order value, and ROI (if campaign cost is recorded).</p>

    <h2>Multi-touch (roadmap)</h2>
    <p>In a future release you will be able to pick alternative models per workspace:</p>
    <ul>
      <li><strong>First-touch</strong> — credit the earliest message in the window.</li>
      <li><strong>Linear</strong> — split credit evenly across all messages in the window.</li>
      <li><strong>Time-decay</strong> — weight recent messages more heavily.</li>
    </ul>

    <h2>Excluding transactional messages</h2>
    <p>Transactional messages (receipts, OTP) are excluded from the attribution candidate set. They're operational touches, not marketing ones.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Attribution · Pulse Docs' })
</script>
