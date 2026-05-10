<template>
  <div>
    <div class="relative overflow-hidden rounded-2xl mb-8 bg-gradient-to-br from-brand-900 via-brand-700 to-brand-500 text-white not-prose">
      <img src="https://images.pexels.com/photos/3184465/pexels-photo-3184465.jpeg?auto=compress&cs=tinysrgb&w=1600" class="absolute inset-0 w-full h-full object-cover opacity-25" alt=""/>
      <div class="absolute -right-16 -top-16 w-72 h-72 rounded-full bg-accent-500/30 blur-3xl"></div>
      <div class="relative px-8 py-10">
        <div class="text-[11px] font-semibold uppercase tracking-[0.2em] text-white/70">Documentation</div>
        <h1 class="!text-white !mt-2">Pulse Engagement Cloud</h1>
        <p class="!text-white/85 max-w-2xl">A unified customer engagement platform that combines audience management, multichannel messaging, journey orchestration, deliverability, and commerce analytics in one workspace.</p>
      </div>
    </div>

    <div class="callout callout-info">
      <div>
        <strong>New here?</strong> Start with the <NuxtLink to="/docs/getting-started">Quickstart</NuxtLink> to provision your workspace and send your first campaign in under 10 minutes.
      </div>
    </div>

    <h2>What Pulse does</h2>
    <p>Pulse is built for product, lifecycle, CRM, and growth teams who need a single source of truth for customer data and a safe place to act on it. The platform is organized around five pillars:</p>

    <div class="card-row">
      <NuxtLink to="/docs/audience/customers" class="card-link">
        <div class="title">Audience</div>
        <div class="desc">Unify customers across channels. Real-time events, attributes, segments, lists, and consent tracking.</div>
      </NuxtLink>
      <NuxtLink to="/docs/engagement/campaigns" class="card-link">
        <div class="title">Engagement</div>
        <div class="desc">Email, SMS, push, WhatsApp, on-site messages, in-app banners, and surveys from one composer.</div>
      </NuxtLink>
      <NuxtLink to="/docs/engagement/journeys" class="card-link">
        <div class="title">Journeys</div>
        <div class="desc">Visual canvas for multi-step, multi-channel flows with branching, waits, and A/B splits.</div>
      </NuxtLink>
      <NuxtLink to="/docs/analytics/funnels" class="card-link">
        <div class="title">Analytics</div>
        <div class="desc">Funnels, cohorts, RFM, revenue attribution, and predictive audiences.</div>
      </NuxtLink>
      <NuxtLink to="/docs/deliverability/domains" class="card-link">
        <div class="title">Deliverability</div>
        <div class="desc">SPF / DKIM / DMARC verification, complaint rate monitoring, and seed inbox placement tests.</div>
      </NuxtLink>
      <NuxtLink to="/docs/commerce/overview" class="card-link">
        <div class="title">Commerce (opt-in)</div>
        <div class="desc">Shopify / WooCommerce ingest, product catalog, abandoned-cart flows, last-touch revenue attribution.</div>
      </NuxtLink>
    </div>

    <h2>Who it's for</h2>
    <ul>
      <li><strong>Consumer brands & retail</strong> — full commerce stack with product sync, recommendations, and revenue attribution.</li>
      <li><strong>Fintech & SaaS</strong> — commerce module stays off; focus is on transactional messaging, lifecycle journeys, and compliance primitives.</li>
      <li><strong>Media & gaming</strong> — high-volume event ingestion, segmentation, push and in-app messaging.</li>
    </ul>

    <h2>Platform at a glance</h2>
    <table>
      <thead><tr><th>Capability</th><th>Highlights</th></tr></thead>
      <tbody>
        <tr><td>Channels</td><td>Email (AWS SES), SMS, Push, WhatsApp, On-site, In-app banners, Surveys</td></tr>
        <tr><td>Targeting</td><td>Real-time segments, RFM, predictive churn / propensity / LTV</td></tr>
        <tr><td>Orchestration</td><td>Drag-and-drop journey canvas with A/B splits and live per-node analytics</td></tr>
        <tr><td>Deliverability</td><td>Domain verification, frequency caps, quiet hours, auto-suspend, inbox placement</td></tr>
        <tr><td>Governance</td><td>Custom roles, approvals, audit log, data retention, consent states</td></tr>
        <tr><td>Developer surface</td><td>Event Track API, outbound signed webhooks, scoped API keys, edge functions</td></tr>
      </tbody>
    </table>

    <h2>Where to go next</h2>
    <div class="card-row">
      <NuxtLink to="/docs/concepts" class="card-link">
        <div class="title">Core concepts</div>
        <div class="desc">Understand workspaces, customers, events, attributes, and identity resolution.</div>
      </NuxtLink>
      <NuxtLink to="/docs/architecture" class="card-link">
        <div class="title">Architecture</div>
        <div class="desc">How Nuxt, Supabase Postgres, RLS, and edge functions fit together.</div>
      </NuxtLink>
      <NuxtLink to="/docs/api" class="card-link">
        <div class="title">API reference</div>
        <div class="desc">REST endpoints, authentication, rate limits, and payload shapes.</div>
      </NuxtLink>
      <NuxtLink to="/docs/getting-started" class="card-link">
        <div class="title">Quickstart</div>
        <div class="desc">Step-by-step setup for a new workspace: SDK, domain, first campaign.</div>
      </NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Pulse Docs' })
</script>
