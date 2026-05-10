<template>
  <div>
    <h1>Campaigns</h1>
    <p>A <strong>campaign</strong> is a one-shot or scheduled broadcast to an audience. Use it for launches, newsletters, promotions, and announcements. For behaviour-triggered, multi-step flows use <NuxtLink to="/docs/engagement/journeys">Journeys</NuxtLink>.</p>

    <h2>Anatomy of a campaign</h2>
    <ul>
      <li><strong>Channel</strong> — email, SMS, push, WhatsApp, on-site, in-app banner.</li>
      <li><strong>Audience</strong> — a segment or list.</li>
      <li><strong>Template</strong> — either a saved template or an inline draft.</li>
      <li><strong>Schedule</strong> — send now, specific time, or send-time-optimized per recipient.</li>
      <li><strong>A/B test</strong> — two or more variants split by percentage; Pulse picks the winner automatically on opens or clicks after the decision window.</li>
    </ul>

    <h2>Deliverability score</h2>
    <p>On the right of the composer, Pulse runs a client-side spam linter over your subject and body. Findings are graded <em>error</em> (blocks send), <em>warning</em>, or <em>info</em>. Common checks:</p>
    <ul>
      <li>Subject length and shoutiness (all caps, excessive exclamation).</li>
      <li>Body length and spam phrases.</li>
      <li>Image-to-text ratio.</li>
      <li>Missing unsubscribe link (blocks email sends).</li>
      <li>Too many external links relative to text.</li>
    </ul>

    <h2>Preview & test</h2>
    <p>Use <em>Send preview</em> to deliver to your own address first. The preview uses your transactional stream so it bypasses marketing consent for your email only.</p>

    <h2>Approval workflow</h2>
    <p>Workspaces can enable approvals on campaigns larger than a configurable threshold. An editor creates the campaign and requests approval; a reviewer sees the request in their notifications and either approves or rejects. Only approved campaigns can be sent.</p>

    <h2>Reports</h2>
    <p>After send, a campaign's detail page shows:</p>
    <ul>
      <li>Sent / delivered / opened / clicked / bounced / complained counts and rates.</li>
      <li>A/B variant winner and significance.</li>
      <li>Revenue attributed to this campaign (last-touch, 7-day window by default).</li>
      <li>Unsubscribes triggered, broken out by channel.</li>
    </ul>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Campaigns · Pulse Docs' })
</script>
