<template>
  <div>
    <h1>On-site messages &amp; in-app banners</h1>
    <p>Reach customers inside your product itself. On-site messages target web visitors; in-app banners target mobile app sessions.</p>

    <h2>On-site messages</h2>
    <p>A lightweight overlay rendered by the Pulse JS SDK on your website. Common formats:</p>
    <ul>
      <li><strong>Floating bar</strong> — announcement bar at the top or bottom.</li>
      <li><strong>Modal</strong> — center-of-screen, for higher-intent actions.</li>
      <li><strong>Slide-in</strong> — bottom-right, discreet.</li>
    </ul>
    <p>Target by URL pattern, segment, time-on-page, scroll depth, or exit intent.</p>

    <h2>In-app banners</h2>
    <p>Rendered natively by the Pulse mobile SDK (iOS / Android / React Native). Variants include sticky top / bottom bar, full-screen takeover, and a dismissable card. Target by app version, locale, subscription state, or feature-flag eligibility.</p>

    <h2>Frequency rules</h2>
    <p>Both on-site and in-app messages honour the workspace frequency cap and each message's own rules (<em>show once</em>, <em>show once per session</em>, <em>show up to N times per week</em>).</p>

    <h2>Analytics</h2>
    <ul>
      <li>Impressions, dismissals, and click-through automatically flow back as <code>onsite_impressed</code>, <code>onsite_dismissed</code>, <code>onsite_clicked</code> events.</li>
      <li>Tie revenue back to a message using the standard last-touch attribution window.</li>
    </ul>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'On-site & banners · Pulse Docs' })
</script>
