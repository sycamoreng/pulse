<template>
  <div>
    <h1>Cohorts</h1>
    <p>A <strong>cohort</strong> is a group of customers bucketed by a shared event — usually their first action (signup, first purchase). Cohort analysis shows how each bucket's retention evolves over time.</p>

    <h2>Building a cohort</h2>
    <ol>
      <li>Go to <strong>Cohorts → + New cohort</strong>.</li>
      <li>Pick the <em>qualifying event</em> (e.g. <code>signup_completed</code>).</li>
      <li>Pick the <em>return event</em> (e.g. <code>session_started</code>, <code>purchase_completed</code>).</li>
      <li>Choose bucket granularity: day, week, or month.</li>
    </ol>

    <h2>The retention grid</h2>
    <p>Rows are cohorts (each row = customers who qualified during that bucket). Columns are periods after qualification. Cells show the % of the cohort that fired the return event in each later period.</p>

    <h2>Spotting patterns</h2>
    <ul>
      <li><strong>Vertical gradient</strong> — later cohorts retaining better or worse than earlier ones. Indicates product or acquisition changes.</li>
      <li><strong>Horizontal gradient</strong> — typical decay; measure the slope to spot when your product becomes "sticky".</li>
      <li><strong>Plateau</strong> — a healthy long-tail indicates PMF.</li>
    </ul>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Cohorts · Pulse Docs' })
</script>
