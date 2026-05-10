<template>
  <div>
    <h1>Create a workspace</h1>
    <p>Workspaces are the top-level isolation boundary in Pulse. A single user account can own or belong to multiple workspaces, and each workspace has its own customers, events, campaigns, billing plan, and settings.</p>

    <h2>Why multiple workspaces</h2>
    <ul>
      <li><strong>Brands</strong> — one workspace per brand you operate.</li>
      <li><strong>Environments</strong> — separate <em>staging</em> and <em>production</em> workspaces so you can test journeys without spamming real customers.</li>
      <li><strong>Regions</strong> — split EU and US data to meet residency requirements.</li>
    </ul>

    <h2>Creating a workspace</h2>
    <ol>
      <li>Open the workspace switcher at the top of the sidebar.</li>
      <li>Click <em>Manage workspaces</em>.</li>
      <li>Choose <em>+ Create new workspace</em>, pick a name and slug.</li>
    </ol>
    <p>The creator becomes the <strong>owner</strong>. Owners can invite teammates, assign roles, change billing, and delete the workspace.</p>

    <h2>Inviting teammates</h2>
    <p>Go to <strong>Settings → Team</strong> and send invites by email. Each invite is scoped to a role:</p>
    <ul>
      <li><strong>Owner</strong> — full access, including billing and deletion.</li>
      <li><strong>Admin</strong> — full access except billing.</li>
      <li><strong>Editor</strong> — can create and edit campaigns, templates, segments; cannot manage the team or delete data.</li>
      <li><strong>Viewer</strong> — read-only access to customers and analytics.</li>
      <li><strong>Custom roles</strong> — scope permissions per entity (see <NuxtLink to="/docs/trust/roles">Roles & approvals</NuxtLink>).</li>
    </ul>

    <h2>Switching workspaces</h2>
    <p>The active workspace is persisted in local storage, so switching browsers or devices will reset your selection to the first workspace. Use the switcher to change it at any time; the URL does not change (data queries all key on the active workspace ID).</p>

    <h2>Deleting a workspace</h2>
    <div class="callout callout-danger">
      <div>
        <strong>Destructive.</strong> Deleting a workspace removes every customer, event, campaign, and journey. This cannot be undone. Only workspace owners can perform this action.
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Create a workspace · Pulse Docs' })
</script>
