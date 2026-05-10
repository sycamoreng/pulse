<template>
  <div>
    <h1>API keys</h1>
    <p>API keys authenticate server-to-server calls into Pulse. Each key is scoped to specific operations, tied to one workspace, and revocable.</p>

    <h2>Key format</h2>
    <pre><code>pk_1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z7a8b9c0d1e2f</code></pre>
    <p>The <code>pk_</code> prefix identifies it as a Pulse key. The full value is shown <strong>once</strong> when created; only a SHA-256 hash and the first 8 characters are stored in the database.</p>

    <h2>Scopes</h2>
    <table>
      <thead><tr><th>Scope</th><th>Grants</th></tr></thead>
      <tbody>
        <tr><td><code>track:write</code></td><td>POST events and identify calls.</td></tr>
        <tr><td><code>track:read</code></td><td>Read back recently ingested events.</td></tr>
        <tr><td><code>customers:read</code></td><td>List / fetch customer records.</td></tr>
        <tr><td><code>customers:write</code></td><td>Upsert customers and their attributes.</td></tr>
        <tr><td><code>events:read</code></td><td>Query the events explorer API.</td></tr>
        <tr><td><code>campaigns:read</code></td><td>List campaigns and read their stats.</td></tr>
      </tbody>
    </table>

    <h2>Creating a key</h2>
    <ol>
      <li>Go to <strong>Integrations → API keys → + New key</strong>.</li>
      <li>Pick a name and check the scopes you need.</li>
      <li>Optionally set an expiry date.</li>
      <li>Copy the value immediately — you won't see it again.</li>
    </ol>

    <h2>Rotating a key</h2>
    <p>Create a new key with the same scopes, deploy it to your systems, confirm traffic on the new key, then revoke the old one. Keys cannot be edited in place.</p>

    <h2>Revoking</h2>
    <p>Click <em>Revoke</em> next to any key. Revocation is immediate; subsequent requests return HTTP 401.</p>

    <div class="callout callout-warn">
      <div>Never commit API keys to source control. Store them in a secrets manager (AWS Secrets Manager, HashiCorp Vault, Doppler, 1Password, etc.) and inject via environment variables.</div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'API keys · Pulse Docs' })
</script>
