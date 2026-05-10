<template>
  <div>
    <h1>Funnels</h1>
    <p>Funnels measure conversion through an ordered sequence of events. They answer: "Of the customers who did A, how many went on to do B, then C, within a time window?"</p>

    <h2>Building a funnel</h2>
    <ol>
      <li>Go to <strong>Funnels → + New funnel</strong>.</li>
      <li>Add 2–8 ordered steps, each pointing at an event (with optional property filter).</li>
      <li>Pick a conversion window (e.g. 24 hours, 7 days, 30 days).</li>
      <li>Optionally filter the starting cohort by segment.</li>
    </ol>

    <h2>Reading results</h2>
    <p>Each step shows:</p>
    <ul>
      <li>Count of customers who reached that step.</li>
      <li>Drop-off relative to the previous step.</li>
      <li>Conversion rate from step 1.</li>
      <li>Median time-to-convert from the previous step.</li>
    </ul>

    <h2>Segmenting the funnel</h2>
    <p>Break the funnel down by device, country, plan, UTM source, or any other attribute to spot where specific cohorts stall.</p>

    <h2>Use with journeys</h2>
    <p>Funnels are often the <em>question</em> that a journey is the <em>answer</em> to. Build the funnel first, identify the step with the steepest drop-off, then design a journey to nudge customers through it.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Funnels · Pulse Docs' })
</script>
