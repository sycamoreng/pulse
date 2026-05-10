<template>
  <div>
    <h1>Journeys</h1>
    <p>Journeys are visual, multi-step flows that react to customer behaviour in near-real-time. Each journey is a directed graph of nodes connected by edges; customers enter at the top and traverse nodes until they hit an exit.</p>

    <h2>Node types</h2>
    <table>
      <thead><tr><th>Node</th><th>Purpose</th></tr></thead>
      <tbody>
        <tr><td><strong>Entry</strong></td><td>How customers enter: on event, on segment entry, on schedule, or manual list enrollment.</td></tr>
        <tr><td><strong>Send</strong></td><td>Send a template on a chosen channel.</td></tr>
        <tr><td><strong>Wait</strong></td><td>Delay for a fixed duration, until a specific time, or until an event.</td></tr>
        <tr><td><strong>Condition</strong></td><td>Branch based on attribute or event properties.</td></tr>
        <tr><td><strong>A/B split</strong></td><td>Probabilistic split into variants for experimentation.</td></tr>
        <tr><td><strong>Webhook</strong></td><td>Fire an outbound webhook (e.g. to Slack, HubSpot, or your backend).</td></tr>
        <tr><td><strong>Update attribute</strong></td><td>Set or increment a customer attribute inline.</td></tr>
        <tr><td><strong>Exit</strong></td><td>End the run.</td></tr>
      </tbody>
    </table>

    <h2>Canvas UX</h2>
    <ul>
      <li>Drag nodes from the palette; snap to an 8px grid.</li>
      <li>Click an edge to toggle condition (<em>yes</em> / <em>no</em>).</li>
      <li>Hold <kbd>Space</kbd> + drag to pan; scroll to zoom.</li>
      <li>Toggle <em>Show stats</em> to overlay per-node entered / completed / drop% numbers and A/B variant breakdowns.</li>
    </ul>

    <h2>Example: abandoned cart</h2>
    <ol>
      <li><strong>Entry</strong>: event <code>item_added_to_cart</code>.</li>
      <li><strong>Wait</strong>: 1 hour.</li>
      <li><strong>Condition</strong>: did the customer fire <code>purchase_completed</code>? If yes → exit.</li>
      <li><strong>Send</strong>: email — "Still thinking about it?"</li>
      <li><strong>Wait</strong>: 24 hours, with exit condition <code>purchase_completed</code>.</li>
      <li><strong>A/B split</strong>: 50% get an SMS reminder, 50% skip.</li>
    </ol>

    <h2>Safety rails</h2>
    <ul>
      <li><strong>One active run per customer per journey</strong> unless you explicitly enable re-entry.</li>
      <li><strong>Frequency cap</strong> (see <NuxtLink to="/docs/deliverability/safeguards">Safeguards</NuxtLink>) applies across all journeys and campaigns.</li>
      <li><strong>Sending paused</strong> flag immediately halts all journey sends.</li>
    </ul>

    <h2>Analytics</h2>
    <p>The per-node stats overlay reads from <code>journey_node_stats</code> (entered / completed / exited) and <code>journey_variant_stats</code> (per-variant conversions). These tables are updated as runs progress, so the canvas reflects live performance, not a snapshot.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Journeys · Pulse Docs' })
</script>
