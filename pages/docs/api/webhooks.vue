<template>
  <div>
    <h1>Outbound webhooks</h1>
    <p>Outbound webhooks push Pulse events to your own systems in near-real-time. Use them to sync customer data to your warehouse, notify Slack on campaign completion, or trigger downstream automation.</p>

    <h2>Adding a destination</h2>
    <ol>
      <li>Go to <strong>Integrations → Outbound webhooks → + New destination</strong>.</li>
      <li>Give the destination a name and URL.</li>
      <li>Pick the events to subscribe to (or <code>*</code> for all).</li>
      )
      <li>Copy the generated signing secret — you'll use it to verify deliveries.</li>
    </ol>

    <h2>Delivery format</h2>
    <pre><code>POST https://your-endpoint.com/pulse
Content-Type: application/json
X-Pulse-Event: order_completed
X-Pulse-Signature: hmac-sha256 of body using your secret

{
  "event_type": "order_completed",
  "workspace_id": "uuid",
  "payload": { ... },
  "sent_at": "2026-05-10T14:03:05Z"
}</code></pre>

    <h2>Signature verification</h2>
    <p>Compute HMAC-SHA256 over the raw request body using the destination's secret, then compare to the <code>X-Pulse-Signature</code> header.</p>
    <pre><code>import crypto from 'node:crypto'

function verify(body, signature, secret) {
  const expected = crypto
    .createHmac('sha256', secret)
    .update(body)
    .digest('hex')
  return crypto.timingSafeEqual(
    Buffer.from(signature, 'hex'),
    Buffer.from(expected, 'hex')
  )
}</code></pre>

    <h2>Delivery log</h2>
    <p>Every attempt is recorded in <code>webhook_deliveries</code> with the HTTP status, response snippet, and timestamp. Failures increment the destination's <code>failure_count</code>; Pulse does not retry automatically in the MVP — use the <em>Replay</em> button on a failed row.</p>

    <h2>Testing</h2>
    <p>Click <em>Test</em> on any destination to deliver a synthetic <code>ping</code> event through the same pipeline.</p>

    <h2>Common event types</h2>
    <ul>
      <li><code>customer.created</code>, <code>customer.updated</code></li>
      <li><code>campaign.sent</code>, <code>campaign.completed</code></li>
      <li><code>journey.entered</code>, <code>journey.exited</code></li>
      <li><code>order_created</code>, <code>order_completed</code>, <code>order_refunded</code></li>
      <li><code>email_bounced</code>, <code>email_complained</code>, <code>unsubscribed</code></li>
    </ul>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Webhooks · Pulse Docs' })
</script>
