<template>
  <div>
    <h1>Segments</h1>
    <p>A <strong>segment</strong> is a saved audience definition composed of attribute, event, list, and RFM conditions. Segments are evaluated on-read so membership always reflects the latest data.</p>

    <h2>Creating a segment</h2>
    <ol>
      <li>Go to <strong>Segments → + New segment</strong>.</li>
      <li>Give it a name and optional description.</li>
      <li>Add conditions. Groups of conditions can be combined with <code>AND</code> / <code>OR</code>, and nested.</li>
      <li>Click <em>Preview</em> to see the estimated count and a sample of 20 matching customers.</li>
    </ol>

    <h2>Condition types</h2>
    <table>
      <thead><tr><th>Type</th><th>Example</th></tr></thead>
      <tbody>
        <tr><td>Attribute</td><td><code>plan = 'premium'</code>, <code>wallet_balance_ngn &gt; 10000</code>, <code>country IN ('NG','KE','GH')</code></td></tr>
        <tr><td>Event</td><td>Performed <code>purchase_completed</code> at least 2 times in the last 30 days where <code>total &gt; 50</code>.</td></tr>
        <tr><td>No event</td><td>Has not performed <code>app_opened</code> in the last 14 days.</td></tr>
        <tr><td>List membership</td><td>Is on list <em>VIP</em> but not on list <em>Churned</em>.</td></tr>
        <tr><td>RFM</td><td>RFM bucket IN <em>Champions</em>, <em>Loyal</em>.</td></tr>
        <tr><td>Consent</td><td>Consent for channel <em>email</em> is <code>opted_in</code>.</td></tr>
      </tbody>
    </table>

    <h2>Live preview</h2>
    <p>As you edit conditions the preview count updates automatically (400ms debounce) so you can feel your way to the right size of audience without saving.</p>

    <h2>Using segments</h2>
    <ul>
      <li>As a campaign audience (one-shot or scheduled).</li>
      <li>As a journey entry trigger ("whenever a customer enters this segment").</li>
      <li>As a journey exit condition ("stop the flow when they leave this segment").</li>
      <li>As a filter in analytics (funnels, cohorts, revenue attribution).</li>
    </ul>

    <h2>Performance notes</h2>
    <p>Segments are cached for 60 seconds inside the segment preview endpoint. For very large workspaces (&gt; 5M customers), use RFM buckets or pre-computed attributes where possible — they index better than deeply nested event counts.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Segments · Pulse Docs' })
</script>
