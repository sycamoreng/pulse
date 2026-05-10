<template>
  <div>
    <h1>Inbox placement</h1>
    <p>Authenticated domains and low complaint rates get you most of the way, but the final signal is whether your mail actually lands in the inbox — not the spam folder. Pulse includes a seed-list based inbox placement test.</p>

    <h2>Seed lists</h2>
    <p>Add addresses you control across major providers (Gmail, Outlook / Hotmail, Yahoo, iCloud, Proton, corporate). Each provider gives you an independent signal.</p>

    <h2>Running a test</h2>
    <ol>
      <li>Open <strong>Trust &amp; Premium → Inbox placement</strong>.</li>
      <li>Enter the subject and from address of the content you want to test.</li>
      <li>Click <em>Start test</em>. Pulse sends to all seeds, waits for placement signals, and records the result.</li>
    </ol>

    <h2>Reading results</h2>
    <p>Each test reports three counts per provider:</p>
    <ul>
      <li><strong>Inbox</strong> — landed in the primary inbox (or "Promotions" on Gmail).</li>
      <li><strong>Spam</strong> — landed in the spam / junk folder.</li>
      <li><strong>Missing</strong> — not delivered within the test window.</li>
    </ul>
    <p>Missing is often the most concerning — it can indicate hard blocks or content filters dropping the message silently.</p>

    <h2>Remediating poor placement</h2>
    <ul>
      <li>Verify SPF, DKIM, and DMARC alignment (see <NuxtLink to="/docs/deliverability/domains">Domain authentication</NuxtLink>).</li>
      )
      <li>Warm up new sending IPs gradually.</li>
      <li>Prune cold or unengaged addresses — reduced engagement signals depress inbox placement.</li>
      <li>Remove spammy words (see the in-composer deliverability score).</li>
      <li>Set up BIMI with a VMC certificate for brand logo display in supported clients.</li>
    </ul>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Inbox placement · Pulse Docs' })
</script>
