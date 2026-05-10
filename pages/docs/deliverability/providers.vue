<template>
  <div>
    <h1>Email providers</h1>
    <p>By default, Pulse sends through a managed sending account so you can start sending immediately. Workspaces on Business plans can connect their own provider credentials for full control and IP reputation ownership.</p>

    <h2>Supported providers</h2>
    <ul>
      <li><strong>AWS SES</strong> — primary. SigV4 authenticated via your access key / secret key.</li>
      <li><strong>SendGrid</strong> — API key.</li>
      <li><strong>Mailgun</strong> — API key, region-aware.</li>
      <li><strong>Postmark</strong> — server token.</li>
      <li><strong>Custom SMTP</strong> — host, port, username, password.</li>
    </ul>

    <h2>Connecting your own provider</h2>
    <ol>
      <li>Go to <strong>Settings → Deliverability → Providers → + Add provider</strong> (available to workspace owners and admins on Business plans).</li>
      <li>Select the provider and stream (<em>transactional</em> or <em>marketing</em>).</li>
      <li>Enter credentials. Keys are stored encrypted at rest.</li>
      <li>Click <em>Test send</em> to verify the credentials by dispatching a sample message.</li>
    </ol>

    <h2>Streams</h2>
    <p>Pulse uses two streams:</p>
    <ul>
      <li><strong>Transactional</strong> — OTPs, receipts, password resets. Bypasses marketing consent, has its own sender reputation.</li>
      <li><strong>Marketing</strong> — campaigns and journeys. Respects consent, unsubscribes, and frequency caps.</li>
    </ul>
    <p>Mixing streams on the same IP can contaminate your transactional deliverability. Keep them separate whenever possible.</p>

    <h2>Failover</h2>
    <p>If a send fails due to a transient provider error, Pulse retries up to 3 times with exponential backoff. After 3 failures the message is marked <em>bounced</em> and the standard complaint/bounce counters increment.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Providers · Pulse Docs' })
</script>
