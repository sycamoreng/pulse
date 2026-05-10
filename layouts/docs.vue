<template>
  <div class="min-h-screen bg-white dark:bg-[color:var(--surface-app)]">
    <header class="sticky top-0 z-40 border-b border-ink-100 dark:border-[color:var(--border-subtle)] bg-white/90 dark:bg-[color:var(--surface-card)]/90 backdrop-blur">
      <div class="max-w-[1400px] mx-auto flex items-center gap-4 px-6 h-14">
        <NuxtLink to="/docs" class="flex items-center gap-2">
          <div class="w-7 h-7 rounded-lg bg-brand-500 flex items-center justify-center">
            <svg class="w-4 h-4 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M2 12h3l2-8 4 16 3-10 2 5h6"/></svg>
          </div>
          <div class="font-bold text-ink-900 dark:text-[color:var(--text-primary)]">Pulse Docs</div>
        </NuxtLink>
        <nav class="hidden md:flex items-center gap-1 ml-4 text-sm">
          <NuxtLink to="/docs" class="px-3 py-1.5 rounded-md hover:bg-ink-50 dark:hover:bg-[color:var(--surface-muted)] text-ink-700 dark:text-[color:var(--text-secondary)]">Product</NuxtLink>
          <NuxtLink to="/docs/getting-started" class="px-3 py-1.5 rounded-md hover:bg-ink-50 dark:hover:bg-[color:var(--surface-muted)] text-ink-700 dark:text-[color:var(--text-secondary)]">Guides</NuxtLink>
          <NuxtLink to="/docs/api" class="px-3 py-1.5 rounded-md hover:bg-ink-50 dark:hover:bg-[color:var(--surface-muted)] text-ink-700 dark:text-[color:var(--text-secondary)]">API</NuxtLink>
          <NuxtLink to="/docs/architecture" class="px-3 py-1.5 rounded-md hover:bg-ink-50 dark:hover:bg-[color:var(--surface-muted)] text-ink-700 dark:text-[color:var(--text-secondary)]">Architecture</NuxtLink>
        </nav>
        <div class="ml-auto flex items-center gap-3">
          <input v-model="search" placeholder="Search docs..." class="hidden md:block input !py-1.5 !text-sm max-w-xs"/>
          <button @click="theme.toggle()" class="w-9 h-9 rounded-lg border border-ink-100 dark:border-[color:var(--border-subtle)] text-ink-700 dark:text-[color:var(--text-secondary)] hover:bg-ink-50 dark:hover:bg-[color:var(--surface-muted)] flex items-center justify-center" :title="theme.theme.value === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'">
            <svg v-if="theme.theme.value === 'dark'" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>
            <svg v-else class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
          </button>
          <NuxtLink to="/login" class="btn-primary !py-1.5 !text-sm">Open app</NuxtLink>
        </div>
      </div>
    </header>

    <div class="max-w-[1400px] mx-auto grid grid-cols-1 lg:grid-cols-[260px_1fr_220px] gap-8 px-6 py-8">
      <aside class="hidden lg:block">
        <nav class="sticky top-20 text-sm space-y-6">
          <div v-for="group in visibleGroups" :key="group.title">
            <div class="text-[11px] font-semibold text-ink-500 uppercase tracking-wider mb-2">{{ group.title }}</div>
            <ul class="space-y-0.5">
              <li v-for="item in group.items" :key="item.to">
                <NuxtLink :to="item.to"
                  class="block px-2.5 py-1.5 rounded-md text-ink-700 dark:text-[color:var(--text-secondary)] hover:bg-ink-50 dark:hover:bg-[color:var(--surface-muted)]"
                  active-class="bg-brand-100/30 dark:bg-[color:var(--brand-100-tinted)] text-brand-500 font-semibold">{{ item.label }}</NuxtLink>
              </li>
            </ul>
          </div>
        </nav>
      </aside>

      <article class="min-w-0 prose-docs">
        <slot/>
      </article>

      <aside class="hidden xl:block">
        <div class="sticky top-20 text-xs">
          <div class="text-[11px] font-semibold text-ink-500 uppercase tracking-wider mb-2">On this page</div>
          <div class="text-ink-500">Use the in-page anchors to jump between sections.</div>
        </div>
      </aside>
    </div>

    <footer class="border-t border-ink-100 dark:border-[color:var(--border-subtle)] mt-16">
      <div class="max-w-[1400px] mx-auto px-6 py-8 text-xs text-ink-500 dark:text-[color:var(--text-tertiary)] flex items-center justify-between">
        <div>Pulse Engagement Cloud — Documentation</div>
        <div>Last updated 2026-05-10</div>
      </div>
    </footer>
  </div>
</template>

<script setup lang="ts">
const search = ref('')
const theme = useTheme()

const groups = [
  {
    title: 'Overview',
    items: [
      { to: '/docs', label: 'Introduction' },
      { to: '/docs/concepts', label: 'Core concepts' },
      { to: '/docs/architecture', label: 'Architecture' },
    ],
  },
  {
    title: 'Getting started',
    items: [
      { to: '/docs/getting-started', label: 'Quickstart' },
      { to: '/docs/getting-started/workspace', label: 'Create a workspace' },
      { to: '/docs/getting-started/install-sdk', label: 'Install the SDK' },
    ],
  },
  {
    title: 'Audience',
    items: [
      { to: '/docs/audience/customers', label: 'Customers' },
      { to: '/docs/audience/events', label: 'Events' },
      { to: '/docs/audience/segments', label: 'Segments' },
      { to: '/docs/audience/lists', label: 'Lists & blacklist' },
      { to: '/docs/audience/consent', label: 'Consent states' },
    ],
  },
  {
    title: 'Engagement',
    items: [
      { to: '/docs/engagement/campaigns', label: 'Campaigns' },
      { to: '/docs/engagement/journeys', label: 'Journeys' },
      { to: '/docs/engagement/templates', label: 'Templates' },
      { to: '/docs/engagement/amp-email', label: 'AMP for Email' },
      { to: '/docs/engagement/onsite-banners', label: 'On-site & banners' },
      { to: '/docs/engagement/surveys', label: 'Surveys & NPS' },
    ],
  },
  {
    title: 'Analytics',
    items: [
      { to: '/docs/analytics/funnels', label: 'Funnels' },
      { to: '/docs/analytics/cohorts', label: 'Cohorts' },
      { to: '/docs/analytics/rfm', label: 'RFM analysis' },
      { to: '/docs/analytics/predictive', label: 'Predictive audiences' },
    ],
  },
  {
    title: 'Deliverability',
    items: [
      { to: '/docs/deliverability/domains', label: 'Domain authentication' },
      { to: '/docs/deliverability/providers', label: 'Email providers' },
      { to: '/docs/deliverability/safeguards', label: 'Safeguards' },
      { to: '/docs/deliverability/inbox-placement', label: 'Inbox placement' },
    ],
  },
  {
    title: 'Commerce',
    items: [
      { to: '/docs/commerce/overview', label: 'Overview' },
      { to: '/docs/commerce/shopify', label: 'Shopify integration' },
      { to: '/docs/commerce/woocommerce', label: 'WooCommerce' },
      { to: '/docs/commerce/attribution', label: 'Revenue attribution' },
    ],
  },
  {
    title: 'Developers',
    items: [
      { to: '/docs/api', label: 'API reference' },
      { to: '/docs/api/track', label: 'Track events' },
      { to: '/docs/api/webhooks', label: 'Outbound webhooks' },
      { to: '/docs/api/api-keys', label: 'API keys' },
    ],
  },
  {
    title: 'SDKs',
    items: [
      { to: '/docs/sdks', label: 'Overview' },
      { to: '/docs/sdks/node', label: 'Node.js' },
      { to: '/docs/sdks/browser', label: 'Browser' },
      { to: '/docs/sdks/nuxt', label: 'Nuxt' },
      { to: '/docs/sdks/react', label: 'React' },
      { to: '/docs/sdks/react-native', label: 'React Native' },
    ],
  },
  {
    title: 'Trust & admin',
    items: [
      { to: '/docs/trust/audit-log', label: 'Audit log' },
      { to: '/docs/trust/roles', label: 'Roles & approvals' },
      { to: '/docs/trust/data-retention', label: 'Data retention' },
    ],
  },
]

const visibleGroups = computed(() => {
  const q = search.value.toLowerCase().trim()
  if (!q) return groups
  return groups
    .map(g => ({ ...g, items: g.items.filter(i => i.label.toLowerCase().includes(q)) }))
    .filter(g => g.items.length)
})
</script>

<style>
.prose-docs h1 { color: var(--text-primary); @apply text-3xl font-bold mt-2 mb-3 leading-tight; }
.prose-docs h2 { color: var(--text-primary); border-bottom-color: var(--border-subtle); @apply text-xl font-bold mt-10 mb-3 pb-2 border-b leading-tight; }
.prose-docs h3 { color: var(--text-primary); @apply text-base font-semibold mt-6 mb-2; }
.prose-docs p { color: var(--text-secondary); @apply text-sm leading-[1.7] my-3; }
.prose-docs ul { color: var(--text-secondary); @apply list-disc pl-6 my-3 text-sm space-y-1.5; }
.prose-docs ol { color: var(--text-secondary); @apply list-decimal pl-6 my-3 text-sm space-y-1.5; }
.prose-docs li { @apply leading-[1.7]; }
.prose-docs code { background: var(--code-bg); border-color: var(--border-subtle); @apply border rounded px-1.5 py-0.5 text-[12.5px] font-mono text-brand-500; }
.prose-docs pre { background: var(--pre-bg); color: var(--pre-text); @apply rounded-xl p-4 my-4 overflow-x-auto text-[12.5px] leading-relaxed; }
.prose-docs pre code { background: transparent; color: var(--pre-text); border: 0; @apply p-0; }
.prose-docs a { @apply text-brand-500 hover:underline; }
.prose-docs table { @apply w-full my-4 text-sm border-collapse; }
.prose-docs th { background: var(--surface-muted); border-color: var(--border-subtle); color: var(--text-primary); @apply text-left font-semibold px-3 py-2 border; }
.prose-docs td { border-color: var(--border-subtle); color: var(--text-secondary); @apply px-3 py-2 border align-top; }
.prose-docs blockquote { @apply border-l-4 border-brand-500 bg-brand-100/20 dark:bg-[color:var(--brand-100-tinted)] pl-4 py-2 my-4 text-sm rounded-r-lg; color: var(--text-secondary); }
.prose-docs .callout { @apply rounded-lg border p-4 my-4 text-sm flex gap-3; }
.prose-docs .callout-info { @apply bg-brand-100/20 dark:bg-[color:var(--brand-100-tinted)] border-brand-100 dark:border-[color:var(--border-subtle)]; color: var(--text-primary); }
.prose-docs .callout-warn { @apply bg-yellow-50 dark:bg-yellow-500/10 border-yellow-200 dark:border-yellow-500/30; color: var(--text-primary); }
.prose-docs .callout-danger { @apply bg-red-50 dark:bg-red-500/10 border-red-200 dark:border-red-500/30; color: var(--text-primary); }
.prose-docs .card-row { @apply grid md:grid-cols-2 gap-4 my-4; }
.prose-docs .card-link { border-color: var(--border-subtle); @apply block rounded-xl border p-5 hover:shadow-md hover:border-brand-500 transition; }
.prose-docs .card-link .title { color: var(--text-primary); @apply font-semibold text-base; }
.prose-docs .card-link .desc { color: var(--text-tertiary); @apply text-xs mt-1 leading-relaxed; }
</style>
