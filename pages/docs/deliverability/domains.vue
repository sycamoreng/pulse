<template>
  <div>
    <h1>Domain authentication</h1>
    <p>Before you can send mail from your own domain, you need SPF, DKIM, and DMARC records published at your DNS provider. Pulse verifies each record automatically and reports pass/fail in near-real-time.</p>

    <h2>Add a domain</h2>
    <ol>
      <li>Go to <strong>Settings → Domains → + Add domain</strong>.</li>
      <li>Enter the apex domain you will send from (e.g. <code>yourbrand.com</code>).</li>
      )
      <li>Pulse generates the three records below. Copy each to your DNS zone.</li>
    </ol>

    <h2>Records</h2>
    <h3>SPF</h3>
    <pre><code>TXT  @    v=spf1 include:amazonses.com ~all</code></pre>
    <p>Tells receiving servers which IPs are authorized to send for your domain.</p>

    <h3>DKIM</h3>
    <p>Three CNAME records of the form:</p>
    <pre><code>CNAME  abc._domainkey.yourbrand.com → abc.dkim.amazonses.com</code></pre>
    <p>Cryptographically signs each outbound message so receivers can verify it wasn't tampered with.</p>

    <h3>DMARC</h3>
    <pre><code>TXT  _dmarc   v=DMARC1; p=none; rua=mailto:dmarc@yourbrand.com</code></pre>
    <p>Tells receiving servers what to do when SPF or DKIM fails, and where to send aggregate reports. Start with <code>p=none</code>, graduate to <code>p=quarantine</code>, then <code>p=reject</code> once reports are clean.</p>

    <h2>Verification</h2>
    <p>Click <em>Verify</em> after publishing records. The <code>verify-domain</code> edge function queries DNS and updates the status. DNS propagation can take up to 24 hours; Pulse re-checks every few minutes until it succeeds.</p>

    <h2>Domain health dashboard</h2>
    <p>The main dashboard shows a summary card with SPF, DKIM, and DMARC pass counts across all your domains. Red means action required — click through to the Domains settings page for details.</p>

    <div class="callout callout-warn">
      <div>Sending from a sub-domain (e.g. <code>mail.yourbrand.com</code>) insulates your corporate mail reputation from marketing activity. Pulse supports both apex and sub-domain setups.</div>
      )
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Domain authentication · Pulse Docs' })
</script>
