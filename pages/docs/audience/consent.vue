<template>
  <div>
    <h1>Consent states</h1>
    <p>Pulse tracks consent <strong>per customer, per channel</strong>. This is the source of truth Pulse consults before every send, and the record you reference during a regulator or customer request.</p>

    <h2>States</h2>
    <table>
      <thead><tr><th>State</th><th>Meaning</th></tr></thead>
      <tbody>
        <tr><td><code>opted_in</code></td><td>Positive, explicit consent. Pulse will send.</td></tr>
        <tr><td><code>opted_out</code></td><td>Explicit refusal (unsubscribe, STOP reply). Pulse will not send.</td></tr>
        <tr><td><code>pending</code></td><td>Awaiting confirmation (double opt-in). Not yet sendable.</td></tr>
        <tr><td><code>unknown</code></td><td>No record. Treat as not sendable unless legitimate interest applies.</td></tr>
      </tbody>
    </table>

    <h2>Channels</h2>
    <p>Consent is recorded separately for each of: <code>email</code>, <code>sms</code>, <code>push</code>, and <code>marketing</code> (a combined marketing umbrella for regions that require an aggregate opt-in).</p>

    <h2>How consent is captured</h2>
    <ul>
      <li><strong>Signup form</strong> — call the Track API's identify endpoint with a consent record.</li>
      <li><strong>Preference center</strong> — Pulse hosts a per-customer URL signed with a token.</li>
      <li><strong>Unsubscribe link</strong> — one-click, always flips the matching channel to <code>opted_out</code>.</li>
      <li><strong>SMS STOP keyword</strong> — the inbound webhook records an opt-out.</li>
      <li><strong>Manual</strong> — record under <strong>Trust &amp; Premium → Consent</strong>.</li>
    </ul>

    <h2>Retrieving consent history</h2>
    <p>Every change inserts a new row (rather than overwriting) so the complete history is available for audit. Query via the API or view on the customer's profile page.</p>

    <div class="callout callout-warn">
      <div>Pulse blocks sends to customers missing positive consent for the channel being used. Transactional kinds (OTP, password reset, receipts) bypass marketing consent but still respect the blacklist and suppression list.</div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Consent · Pulse Docs' })
</script>
