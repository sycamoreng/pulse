<template>
  <div>
    <h1>Templates</h1>
    <p>Templates decouple creative from delivery. The same template can be used by a campaign today and a journey next month. Any update to the template flows through immediately to every consumer of it.</p>

    <h2>Anatomy</h2>
    <ul>
      <li><strong>Channel</strong> — email, push, SMS, WhatsApp, in-app, on-site.</li>
      <li><strong>Category</strong> — organizational tag (e.g. <em>welcome</em>, <em>transactional</em>, <em>win-back</em>).</li>
      <li><strong>Subject</strong> (email) — supports Liquid variables.</li>
      <li><strong>Preview text</strong> (email) — the snippet shown in inbox lists.</li>
      <li><strong>Content</strong> — HTML for email, plain text for SMS, JSON payload for push.</li>
      <li><strong>AMP HTML</strong> (email, optional) — see <NuxtLink to="/docs/engagement/amp-email">AMP for Email</NuxtLink>.</li>
    </ul>

    <h2>Liquid variables</h2>
    <p>Templates use a Liquid-like syntax for personalization. Pulse exposes:</p>
    <ul v-pre>
      <li>Customer fields: <code>{{first_name}}</code>, <code>{{email}}</code>, <code>{{country}}</code></li>
      <li>Attributes: <code>{{attributes.wallet_balance_ngn}}</code></li>
      <li>Event properties (inside journeys): <code>{{event.properties.sku}}</code></li>
      <li>Workspace branding: <code>{{workspace.name}}</code></li>
      <li>Conditional blocks: <code>{% if attributes.is_premium %}…{% endif %}</code></li>
    </ul>

    <h2>Live preview</h2>
    <p>The composer renders a live preview as you type. Pick a sample customer from the dropdown to see variable substitution applied.</p>

    <h2>Versioning</h2>
    <p>Saves overwrite in place. For stable audit trails, duplicate the template before a major rewrite. Audit log rows record the editing user, timestamp, and a diff of changed fields.</p>

    <h2>Best practices</h2>
    <ul>
      <li>Always include an unsubscribe link in email templates (Pulse blocks sending otherwise).</li>
      <li>Keep subject lines under 70 characters.</li>
      <li>Use preheaders — the preview text is often as impactful as the subject.</li>
      <li>For SMS, keep content under 160 characters to avoid multi-part charges.</li>
    </ul>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Templates · Pulse Docs' })
</script>
