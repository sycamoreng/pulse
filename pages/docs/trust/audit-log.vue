<template>
  <div>
    <h1>Audit log</h1>
    <p>Every meaningful change in the workspace — create, update, delete — is recorded in the audit log. The log is append-only and visible to owners, admins, and any custom role with the <code>audit:read</code> permission.</p>

    <h2>What is captured</h2>
    <ul>
      <li><strong>Actor</strong> — user ID and email at time of action.</li>
      <li><strong>Action</strong> — <code>create</code>, <code>update</code>, <code>delete</code>, <code>approve</code>, <code>reject</code>, etc.</li>
      <li><strong>Entity type and ID</strong> — e.g. <code>campaign</code> + UUID.</li>
      <li><strong>Entity name</strong> — at the time of action, for human readability.</li>
      <li><strong>Diff</strong> — JSON of changed fields (old → new).</li>
      <li><strong>Timestamp</strong>.</li>
    </ul>

    <h2>Viewing the log</h2>
    <p>Open <strong>Trust &amp; Premium → Audit log</strong>. You can filter by:</p>
    <ul>
      <li>Free-text search across action, entity name, and actor.</li>
      <li>Entity type (campaign, template, journey, segment, workspace, member, role).</li>
    </ul>
    <p>Click any row to expand the diff.</p>

    <h2>Exporting</h2>
    <p>Schedule a recurring export of the audit log under <strong>Integrations → Scheduled exports</strong> to feed a data warehouse or SIEM.</p>

    <h2>Retention</h2>
    <p>Audit rows are retained indefinitely by default. If your compliance policy requires periodic purging, configure a retention window in <strong>Settings → Data</strong>.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Audit log · Pulse Docs' })
</script>
