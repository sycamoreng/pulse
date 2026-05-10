<template>
  <div>
    <h1>Predictive audiences</h1>
    <p>Predictive audiences score every customer on three dimensions: <strong>churn risk</strong>, <strong>purchase propensity</strong>, and <strong>LTV bucket</strong>. Use these scores as segment conditions, journey branches, or reporting dimensions.</p>

    <h2>Scores</h2>
    <table>
      <thead><tr><th>Score</th><th>Range</th><th>Interpretation</th></tr></thead>
      <tbody>
        <tr><td>Churn risk</td><td>0.0 – 1.0</td><td>Probability the customer will lapse in the next 30 days.</td></tr>
        <tr><td>Purchase propensity</td><td>0.0 – 1.0</td><td>Probability of a purchase event in the next 14 days.</td></tr>
        <tr><td>LTV bucket</td><td>low / medium / high</td><td>Predicted lifetime-value quintile relative to your workspace.</td></tr>
      </tbody>
    </table>

    <h2>How scoring works</h2>
    <p>The baseline algorithm uses:</p>
    <ul>
      <li>Recency of last event (<code>last_seen_at</code>).</li>
      )
      <li>Count and recency of purchase events.</li>
      <li>Total monetary value of purchases.</li>
    </ul>
    <p>Scores are updated on demand from the Predictive audiences tab of <strong>Trust &amp; Premium</strong>, or nightly for Business-plan workspaces.</p>

    <h2>Worked example</h2>
    <ul>
      <li>A customer who ordered 3 times in the last 30 days → low churn, high propensity, medium or high LTV.</li>
      <li>A one-time buyer last seen 90 days ago → high churn, low propensity, low LTV.</li>
    </ul>

    <h2>Using predictions</h2>
    <ul>
      <li><strong>Suppress discounts</strong> from high-propensity customers ("they'll buy anyway").</li>
      <li><strong>Focus win-back</strong> on high-LTV + high-churn combinations ("can't lose them").</li>
      <li><strong>Report ROI</strong> segmented by predicted LTV bucket.</li>
    </ul>

    <div class="callout callout-info">
      <div>Predictions are directional, not guarantees. Use them as tie-breakers between lookalike cohorts, not as the sole gate on critical sends.</div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Predictive audiences · Pulse Docs' })
</script>
