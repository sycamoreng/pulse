<template>
  <div>
    <h1>Surveys &amp; NPS</h1>
    <p>Collect structured feedback via email or in-app surveys, and track NPS over time.</p>

    <h2>Survey types</h2>
    <ul>
      <li><strong>NPS</strong> — 0–10 scale, open-text follow-up for detractors and promoters.</li>
      <li><strong>CSAT</strong> — 1–5 scale after specific events.</li>
      <li><strong>Custom</strong> — multiple choice, single choice, rating, or open text.</li>
    </ul>

    <h2>Distribution</h2>
    <ul>
      <li>Email — responses tracked via signed link.</li>
      <li>In-app — rendered by the mobile SDK; responses sent via <code>survey_responded</code> event.</li>
      <li>Journey node — drop a survey into any flow.</li>
    </ul>

    <h2>Analysis</h2>
    <p>The survey detail page shows response count, average score, NPS category mix (<em>promoter</em> / <em>passive</em> / <em>detractor</em>), trend over time, and segment breakdowns (e.g. NPS by plan tier). Individual responses are downloadable as CSV.</p>
    )
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Surveys · Pulse Docs' })
</script>
