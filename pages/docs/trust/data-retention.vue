<template>
  <div>
    <h1>Data retention</h1>
    <p>Pulse respects the retention policy you configure. Data older than the threshold is deleted by a nightly background job.</p>

    <h2>What is retained vs. deleted</h2>
    <table>
      <thead><tr><th>Data</th><th>Behaviour</th></tr></thead>
      <tbody>
        <tr><td>Events</td><td>Deleted after <code>data_retention_days</code> (default 365).</td></tr>
        <tr><td>Campaign messages</td><td>Deleted after retention window; aggregate campaign stats remain.</td></tr>
        <tr><td>Journey runs</td><td>Deleted after retention window; per-node stats preserved.</td></tr>
        <tr><td>Customers</td><td>Never auto-deleted; delete explicitly on request.</td></tr>
        <tr><td>Audit log</td><td>Retained indefinitely unless a compliance window is set.</td></tr>
        <tr><td>Suppression list</td><td>Retained indefinitely. Contains only hashed identifiers.</td></tr>
      </tbody>
    </table>

    <h2>Setting retention</h2>
    <p>Under <strong>Settings → Data → Retention</strong>, set the event retention window (30 – 3650 days). Shorter windows reduce storage and speed up segment evaluation but limit how far back your analytics can look.</p>

    <h2>Right to erasure</h2>
    <p>For GDPR / CCPA / NDPR requests:</p>
    <ol>
      <li>Open the customer's profile page.</li>
      <li>Click <em>Delete permanently</em>.</li>
      <li>Confirm. Pulse cascades the delete across events, list memberships, attributions, journey runs, and consent records.</li>
    </ol>
    <p>An audit log entry is created capturing the actor and timestamp. The suppression list hash is preserved to prevent re-contact.</p>

    <h2>Data residency</h2>
    <p>Data is stored in the Supabase region configured for your project. For EU residency, provision the project in <code>eu-central-1</code>. For multiple regions, operate separate workspaces in separate projects.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Retention · Pulse Docs' })
</script>
