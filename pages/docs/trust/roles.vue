<template>
  <div>
    <h1>Roles &amp; approvals</h1>
    <p>Pulse ships with four system roles and supports unlimited custom roles. Every sensitive action (sending a large campaign, deleting a journey, rotating a key) can optionally require approval from a teammate.</p>

    <h2>System roles</h2>
    <table>
      <thead><tr><th>Role</th><th>Capabilities</th></tr></thead>
      <tbody>
        <tr><td><strong>Owner</strong></td><td>Everything, including billing, team management, and workspace deletion.</td></tr>
        <tr><td><strong>Admin</strong></td><td>Everything except billing and workspace deletion.</td></tr>
        <tr><td><strong>Editor</strong></td><td>Create / edit / send campaigns, journeys, templates, segments; cannot manage team or delete data.</td></tr>
        <tr><td><strong>Viewer</strong></td><td>Read-only access to customers, analytics, and campaign history.</td></tr>
      </tbody>
    </table>

    <h2>Custom roles</h2>
    <p>Under <strong>Settings → Roles → + Custom role</strong>, pick a name and check the specific permissions the role should have. Permissions are grouped by entity — e.g. <code>campaigns:create</code>, <code>campaigns:send</code>, <code>segments:delete</code>, <code>audit:read</code>.</p>

    <h2>Approval workflow</h2>
    <p>Enable approvals under <strong>Settings → Approvals</strong>. You can require approval for:</p>
    <ul>
      <li>Campaigns with audience size over a threshold.</li>
      <li>Sending to specific high-value segments.</li>
      <li>Deleting journeys or segments.</li>
      <li>Changing deliverability policies.</li>
    </ul>
    <p>When a request is submitted, eligible approvers (owners, admins, or any custom role with <code>approvals:review</code>) receive a notification. Pending requests cannot progress until approved.</p>
    )

    <h2>Impersonation</h2>
    <p>Platform admins can impersonate a workspace user for support purposes. Every impersonation session is recorded in the audit log and automatically expires after 1 hour.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Roles · Pulse Docs' })
</script>
