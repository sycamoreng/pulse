<template>
  <div>
    <h1>Quickstart</h1>
    <p>Go from an empty account to a live campaign in under 10 minutes.</p>

    <h2>1. Create your account</h2>
    <p>Sign up at <NuxtLink to="/signup">/signup</NuxtLink> with your work email and password. Pulse will automatically create a default workspace named after you, seed it with demo data (3 segments, 3 campaigns, 3 journeys, sample customers and events) so you can explore the UI immediately.</p>
    <div class="callout callout-info">
      <div>The demo data only seeds once per workspace and can be deleted at any time from <strong>Settings → Data</strong>.</div>
    </div>

    <h2>2. Configure your workspace</h2>
    <ol>
      <li>Go to <strong>Settings → Workspace</strong>.</li>
      <li>Set a friendly name, slug, industry, and timezone.</li>
      <li>Upload a logo and pick your brand colors. These flow through to composer previews and transactional email templates.</li>
      <li>Under <strong>Feature modules</strong>, enable <em>Commerce</em> only if you run a store.</li>
    </ol>

    <h2>3. Authenticate your sending domain</h2>
    <p>Before sending real email, add and verify the domain you send from:</p>
    <ol>
      <li>Go to <strong>Settings → Domains</strong> and add a domain (e.g. <code>yourbrand.com</code>).</li>
      <li>Pulse shows the SPF, DKIM, and DMARC records to publish at your DNS provider.</li>
      <li>Click <em>Verify</em> — the <code>verify-domain</code> edge function polls DNS and marks records as pass/fail.</li>
    </ol>
    <p>See <NuxtLink to="/docs/deliverability/domains">Domain authentication</NuxtLink> for full details.</p>

    <h2>4. Install the SDK (optional)</h2>
    <p>If you want to track events from your web or mobile app, see <NuxtLink to="/docs/getting-started/install-sdk">Install the SDK</NuxtLink>. You can also skip this and start by importing customers via CSV.</p>

    <h2>5. Send your first campaign</h2>
    <ol>
      <li>Go to <strong>Campaigns → + New campaign</strong>.</li>
      <li>Pick a channel (email is a safe default), target audience (a segment or list), and a template.</li>
      <li>Use the <em>Deliverability score</em> panel on the right to catch spammy copy before send.</li>
      <li>Click <em>Send preview</em> to yourself first, then <em>Send now</em> or <em>Schedule</em>.</li>
    </ol>

    <h2>What's next</h2>
    <div class="card-row">
      <NuxtLink to="/docs/engagement/journeys" class="card-link">
        <div class="title">Build your first journey</div>
        <div class="desc">Welcome flows, abandoned cart, win-back — all on a drag-and-drop canvas.</div>
      </NuxtLink>
      <NuxtLink to="/docs/api/track" class="card-link">
        <div class="title">Track custom events</div>
        <div class="desc">The Track API accepts real-time behavioural events from any stack.</div>
      </NuxtLink>
      <NuxtLink to="/docs/analytics/predictive" class="card-link">
        <div class="title">Enable predictive audiences</div>
        <div class="desc">Churn risk, purchase propensity, and LTV scores per customer.</div>
      </NuxtLink>
      <NuxtLink to="/docs/trust/roles" class="card-link">
        <div class="title">Invite your team</div>
        <div class="desc">Custom roles, approval workflows, audit log.</div>
      </NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Quickstart · Pulse Docs' })
</script>
