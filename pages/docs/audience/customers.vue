<template>
  <div>
    <h1>Customers</h1>
    <p>The <strong>Customers</strong> module is the canonical place to view, search, and manage individual users in your workspace.</p>

    <h2>Customer record</h2>
    <p>Each row consists of:</p>
    <table>
      <thead><tr><th>Field</th><th>Type</th><th>Notes</th></tr></thead>
      <tbody>
        <tr><td><code>external_id</code></td><td>text</td><td>Unique per workspace. Your internal user ID.</td></tr>
        <tr><td><code>email</code></td><td>text</td><td>Lowercased on write. Used for email channels and as a soft identity hint.</td></tr>
        <tr><td><code>phone</code></td><td>text</td><td>E.164 format preferred. Used for SMS and WhatsApp.</td></tr>
        <tr><td><code>first_name</code>, <code>last_name</code></td><td>text</td><td>Used for Liquid personalization.</td></tr>
        <tr><td><code>country</code>, <code>city</code>, <code>device</code>, <code>platform</code></td><td>text</td><td>Auto-populated from Track API context where possible.</td></tr>
        <tr><td><code>attributes</code></td><td>jsonb</td><td>Arbitrary traits. Register schema in Attributes for autocomplete.</td></tr>
        <tr><td><code>is_blacklisted</code></td><td>bool</td><td>When true, the customer is excluded from all sends regardless of channel or campaign.</td></tr>
        <tr><td><code>last_seen_at</code></td><td>timestamp</td><td>Auto-updated on any event ingest.</td></tr>
      </tbody>
    </table>

    <h2>Customer profile page</h2>
    <p>Click any row to open the profile. You'll see the identity card on the left, and a timeline of the 50 most recent events on the right, with full properties displayed inline. From here you can:</p>
    <ul>
      <li>Add or remove the customer from the blacklist.</li>
      <li>Delete the customer permanently (cascades to events, list memberships, attributions).</li>
      <li>Inspect consent states (if Trust module is used).</li>
    </ul>

    <h2>Creating customers</h2>
    <p>Customers are created in four ways:</p>
    <ol>
      <li><strong>Manual add</strong> — Customers → <em>+ Add customer</em>.</li>
      <li><strong>CSV import</strong> — see <NuxtLink to="/docs/audience/customers#csv-import">CSV import</NuxtLink>.</li>
      <li><strong>Track API</strong> — any event with an unknown <code>external_id</code> creates a stub customer.</li>
      <li><strong>Commerce ingest</strong> — Shopify / Woo webhooks upsert by email.</li>
    </ol>

    <h2 id="csv-import">CSV import</h2>
    <p>Go to <strong>Imports → + New import</strong>. Upload a CSV with headers that match known fields (<code>external_id</code>, <code>email</code>, <code>first_name</code>, etc.). Unknown columns land in the <code>attributes</code> JSONB.</p>
    <ul>
      <li>Imports are deduplicated by <code>external_id</code>. Rows without one fall back to <code>email</code>.</li>
      <li>Existing customers are <em>merged</em>, not replaced — blank CSV values don't overwrite existing data.</li>
      <li>Large files are processed in chunks; the Imports page shows progress per file.</li>
    </ul>

    <h2>Exporting customers</h2>
    <p>From the Customers list, use <em>Export CSV</em> to download the current filtered view, or schedule recurring exports under <strong>Integrations → Scheduled exports</strong>.</p>

    <h2>Deleting customer data</h2>
    <p>For GDPR erasure requests, delete the customer from their profile page. Pulse cascades the delete across:</p>
    <ul>
      <li>Events</li>
      <li>List memberships</li>
      <li>Campaign messages & attributions</li>
      <li>Journey runs</li>
      <li>Consent records</li>
    </ul>
    <p>The suppression list retains the email/phone hash so the person is not accidentally re-contacted if they're re-imported.</p>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Customers · Pulse Docs' })
</script>
