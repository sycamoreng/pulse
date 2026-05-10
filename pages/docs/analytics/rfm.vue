<template>
  <div>
    <h1>RFM analysis</h1>
    <p>RFM buckets customers by <strong>Recency</strong>, <strong>Frequency</strong>, and <strong>Monetary value</strong>. Each dimension is scored 1–5 and combined into a single bucket.</p>

    <h2>The 11 buckets</h2>
    <table>
      <thead><tr><th>Bucket</th><th>Who they are</th></tr></thead>
      <tbody>
        <tr><td>Champions</td><td>Recent, frequent, high-spend. Your most valuable.</td></tr>
        <tr><td>Loyal</td><td>Frequent but not always recent. Reward to keep them.</td></tr>
        <tr><td>Potential loyalists</td><td>Recent and frequent but low spend. Encourage upgrades.</td></tr>
        <tr><td>New customers</td><td>Recent, infrequent. Onboard aggressively.</td></tr>
        <tr><td>Promising</td><td>Recent, low frequency, low spend. Nurture.</td></tr>
        <tr><td>Need attention</td><td>Average on all dimensions. At risk of slipping.</td></tr>
        <tr><td>About to sleep</td><td>Recency starting to slip.</td></tr>
        <tr><td>At risk</td><td>Previously strong customers falling off.</td></tr>
        <tr><td>Can't lose them</td><td>High value, long since last seen. Win-back priority.</td></tr>
        <tr><td>Hibernating</td><td>Infrequent, low-value, long-inactive.</td></tr>
        <tr><td>Lost</td><td>Lapsed; unlikely to return without strong incentive.</td></tr>
      </tbody>
    </table>

    <h2>How scores are computed</h2>
    <p>For each customer, Pulse computes:</p>
    <ul>
      <li><strong>R</strong> — days since last qualifying event (default: <code>purchase_completed</code>).</li>
      <li><strong>F</strong> — count of qualifying events over the analysis window.</li>
      <li><strong>M</strong> — sum of <code>total</code> property on qualifying events.</li>
    </ul>
    <p>Each dimension is quintile-bucketed against the workspace population.</p>

    <h2>Using RFM</h2>
    <ul>
      <li>Filter any segment by RFM bucket.</li>
      <li>Trigger win-back journeys on <em>At risk</em> → <em>Hibernating</em> transitions.</li>
      <li>Reward <em>Champions</em> and <em>Loyal</em> with early access or referrals.</li>
    </ul>

    <h2>Refresh schedule</h2>
    <p>RFM is recomputed nightly. You can trigger a recompute manually from the RFM page.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'RFM · Pulse Docs' })
</script>
