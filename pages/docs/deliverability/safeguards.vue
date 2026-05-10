<template>
  <div>
    <h1>Safeguards</h1>
    <p>Pulse enforces several send-time safeguards that stop you from damaging your sender reputation or annoying your customers.</p>

    <h2>Frequency caps</h2>
    <p>Set a maximum number of marketing sends per customer per 24 hours and per 7 days. Transactional kinds (OTP, password reset, receipts) bypass the cap.</p>
    <pre><code>{
  "max_per_24h": 3,
  "max_per_7d": 10,
  "apply_to": ["email", "sms", "push"]
}</code></pre>

    <h2>Quiet hours</h2>
    <p>A window during which marketing sends are held. Pulse uses the workspace timezone by default, or the customer's own timezone if their <code>attributes.timezone</code> is set.</p>

    <h2>Auto-suspend</h2>
    <p>If the <strong>24-hour complaint rate exceeds 0.3%</strong> or the <strong>bounce rate exceeds 5%</strong> (and at least 100 sends have been made in that window), Pulse flips the workspace's <code>sending_paused</code> flag and halts all outbound mail.</p>
    <p>The incident is logged with the triggering metric, and workspace owners and admins are notified. Resume sending from <strong>Settings → Deliverability safeguards</strong> once you've diagnosed the cause.</p>

    <h2>Unsubscribe enforcement</h2>
    <ul>
      <li>Every email template is required to include an unsubscribe link; sends are blocked otherwise.</li>
      <li>Clicks on the link flip the relevant consent to <code>opted_out</code> and propagate to a suppression row.</li>
      <li>The suppression list is consulted on every send; matching addresses are skipped.</li>
    </ul>

    <h2>Configuring safeguards</h2>
    <p>Go to <strong>Settings → Policies → Deliverability safeguards</strong>. Caps and thresholds are per-workspace and editable by owners and admins.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Safeguards · Pulse Docs' })
</script>
