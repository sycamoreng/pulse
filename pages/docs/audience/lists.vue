<template>
  <div>
    <h1>Lists & blacklist</h1>

    <h2>Lists</h2>
    <p><strong>Lists</strong> are static audiences — curated, manually managed, or imported from CSV. Use lists when membership is determined outside Pulse (event waitlists, beta groups, VIP tiers maintained in a spreadsheet).</p>

    <h3>Creating a list</h3>
    <ol>
      <li>Go to <strong>Lists → + New list</strong>.</li>
      <li>Give it a name and optional tag.</li>
      <li>Add members by searching existing customers, or upload a CSV of <code>external_id</code> or <code>email</code>.</li>
    </ol>

    <h3>Using lists</h3>
    <p>Lists are first-class audiences in campaigns and journeys, and they are filterable in segments (<code>is on list</code> / <code>is not on list</code>). Lists can be combined with segments inside a journey entry condition.</p>
    )

    <h2>Blacklist</h2>
    <p>The <strong>blacklist</strong> is a hard stop. Any customer on it is excluded from every channel and every campaign / journey, regardless of consent state or segment membership.</p>
    <p>Use cases:</p>
    <ul>
      <li>Internal staff test accounts you never want to accidentally message.</li>
      <li>Users flagged for abuse or fraud.</li>
      <li>Temporary blocks during an incident.</li>
    </ul>

    <h3>Blacklist vs. consent vs. suppression</h3>
    <table>
      <thead><tr><th>Mechanism</th><th>Scope</th><th>Reversible</th></tr></thead>
      <tbody>
        <tr><td><strong>Blacklist</strong></td><td>All channels, all sends</td><td>Yes, by removing the flag</td></tr>
        <tr><td><strong>Consent state</strong></td><td>Per channel</td><td>Yes, by recording a new consent</td></tr>
        <tr><td><strong>Suppression list</strong></td><td>Email / phone only</td><td>Manual, after review</td></tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Lists & blacklist · Pulse Docs' })
</script>
