<template>
  <div class="min-h-screen bg-white">
    <header class="landing-header sticky top-0 z-40 backdrop-blur-lg border-b border-ink-100/60 dark:border-[color:var(--border-subtle)]">
      <div class="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
        <div class="flex items-center gap-2">
          <img src="/pulse-app-icon.svg" alt="Pulse" class="w-9 h-9 rounded-lg"/>
          <span class="font-bold text-lg text-brand-900 dark:text-white">Pulse</span>
        </div>
        <nav class="hidden md:flex items-center gap-8 text-sm text-ink-700 dark:text-[color:var(--text-secondary)]">
          <a href="#features" class="hover:text-brand-500 dark:hover:text-white transition-colors">Features</a>
          <a href="#channels" class="hover:text-brand-500 dark:hover:text-white transition-colors">Channels</a>
          <a href="#pricing" class="hover:text-brand-500 dark:hover:text-white transition-colors">Pricing</a>
          <a href="#customers" class="hover:text-brand-500 dark:hover:text-white transition-colors">Customers</a>
        </nav>
        <div class="flex items-center gap-3">
          <NuxtLink to="/login" class="btn-ghost">Sign in</NuxtLink>
          <NuxtLink to="/signup" class="btn-primary">Start free</NuxtLink>
        </div>
      </div>
    </header>

    <!-- Hero -->
    <section class="relative overflow-hidden">
      <div class="absolute inset-0 bg-gradient-to-br from-brand-50 via-white to-white"></div>
      <div class="absolute -top-24 -right-24 w-[520px] h-[520px] rounded-full bg-brand-500/10 blur-3xl"></div>
      <div class="absolute top-40 -left-40 w-[400px] h-[400px] rounded-full bg-accent-500/10 blur-3xl"></div>
      <div class="relative max-w-7xl mx-auto px-6 pt-20 pb-28 text-center">
        <div class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-white border border-ink-100 shadow-sm text-brand-700 text-xs font-semibold mb-6">
          <span class="w-1.5 h-1.5 rounded-full bg-accent-500 animate-pulse"></span>
          New: AI send-time optimization + multivariate journeys
        </div>
        <h1 class="text-5xl md:text-7xl font-black text-brand-900 tracking-tight leading-[1.02] max-w-5xl mx-auto">
          Know every user.<br/>
          <span class="bg-gradient-to-r from-brand-500 to-brand-700 bg-clip-text text-transparent">Reach them like you mean it.</span>
        </h1>
        <p class="mt-6 text-lg md:text-xl text-ink-500 max-w-2xl mx-auto leading-relaxed">
          The complete customer engagement platform. Unify your data, build precise segments, and orchestrate journeys across email, push, SMS, in-app, and on-site — all from one place.
        </p>
        <div class="mt-10 flex flex-col sm:flex-row items-center justify-center gap-3">
          <NuxtLink to="/signup" class="btn-primary text-base px-8 py-3.5 shadow-lg shadow-brand-500/30 hover:shadow-brand-500/50 transition-shadow">Start free · No card</NuxtLink>
          <a href="#demo" class="btn-secondary text-base px-8 py-3.5">Watch the 2-min demo</a>
        </div>
        <div class="mt-12 text-xs text-ink-500 font-medium uppercase tracking-[0.2em]">Trusted by teams at growing companies</div>
        <div class="mt-5 flex flex-wrap items-center justify-center gap-x-10 gap-y-3 text-ink-500/80">
          <div class="flex items-center gap-2 text-lg font-bold tracking-tight"><span class="w-6 h-6 rounded-md bg-ink-500/10 flex items-center justify-center"><Icon name="activity" class="w-3.5 h-3.5"/></span>Flicker</div>
          <div class="flex items-center gap-2 text-lg font-bold tracking-tight"><span class="w-6 h-6 rounded-md bg-ink-500/10 flex items-center justify-center"><Icon name="route" class="w-3.5 h-3.5"/></span>Northpeak</div>
          <div class="flex items-center gap-2 text-lg font-bold tracking-tight"><span class="w-6 h-6 rounded-md bg-ink-500/10 flex items-center justify-center"><Icon name="send" class="w-3.5 h-3.5"/></span>Bayside</div>
          <div class="flex items-center gap-2 text-lg font-bold tracking-tight"><span class="w-6 h-6 rounded-md bg-ink-500/10 flex items-center justify-center"><Icon name="segment" class="w-3.5 h-3.5"/></span>Kindred</div>
          <div class="flex items-center gap-2 text-lg font-bold tracking-tight"><span class="w-6 h-6 rounded-md bg-ink-500/10 flex items-center justify-center"><Icon name="shield" class="w-3.5 h-3.5"/></span>Orbit</div>
        </div>

        <div class="mt-16 relative max-w-6xl mx-auto">
          <div class="absolute inset-0 bg-gradient-to-t from-white via-transparent to-transparent z-10 pointer-events-none dark:from-[color:var(--surface-app)]"></div>
          <div class="relative grid grid-cols-1 md:grid-cols-12 gap-4">
            <div class="md:col-span-8 rounded-2xl overflow-hidden border border-ink-100 dark:border-[color:var(--border-subtle)] shadow-2xl shadow-brand-500/10 bg-white">
              <img src="https://images.pexels.com/photos/7567443/pexels-photo-7567443.jpeg?auto=compress&cs=tinysrgb&w=1600" class="w-full h-[440px] object-cover" alt="Dashboard"/>
            </div>
            <div class="md:col-span-4 flex flex-col gap-4">
              <div class="card p-5 flex-1">
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 rounded-lg bg-accent-500/15 text-accent-500 flex items-center justify-center"><Icon name="activity" class="w-5 h-5"/></div>
                  <div>
                    <div class="text-xs text-ink-500">Live campaign</div>
                    <div class="font-semibold text-ink-900">Winter re-engagement</div>
                  </div>
                </div>
                <div class="mt-5 grid grid-cols-3 gap-3 text-center">
                  <div><div class="text-2xl font-black text-brand-900">62%</div><div class="text-[10px] uppercase tracking-wider text-ink-500 mt-0.5">Opens</div></div>
                  <div><div class="text-2xl font-black text-brand-900">18%</div><div class="text-[10px] uppercase tracking-wider text-ink-500 mt-0.5">Clicks</div></div>
                  <div><div class="text-2xl font-black text-accent-500">7.4%</div><div class="text-[10px] uppercase tracking-wider text-ink-500 mt-0.5">Revenue</div></div>
                </div>
                <div class="mt-5 h-1.5 rounded-full bg-ink-100 dark:bg-[color:var(--surface-muted)] overflow-hidden">
                  <div class="h-full bg-gradient-to-r from-brand-500 to-accent-500 w-[72%]"></div>
                </div>
              </div>
              <div class="card p-5 flex-1">
                <div class="flex items-center gap-3 mb-3">
                  <img src="https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?auto=compress&cs=tinysrgb&w=96" class="w-9 h-9 rounded-full object-cover" alt=""/>
                  <div>
                    <div class="font-semibold text-ink-900 text-sm">Kofi Mensah</div>
                    <div class="text-xs text-ink-500">Lagos · iOS · 2m ago</div>
                  </div>
                </div>
                <div class="text-xs text-ink-500 space-y-1.5">
                  <div class="flex items-center gap-2"><span class="w-1.5 h-1.5 rounded-full bg-accent-500"></span>Opened "Winter drop"</div>
                  <div class="flex items-center gap-2"><span class="w-1.5 h-1.5 rounded-full bg-brand-500"></span>Added to cart</div>
                  <div class="flex items-center gap-2"><span class="w-1.5 h-1.5 rounded-full bg-ink-300"></span>Abandoned · queued reminder</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Stats -->
    <section class="max-w-6xl mx-auto px-6 py-20">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-6 text-center">
        <div><div class="text-4xl font-black text-brand-900">2B+</div><div class="text-sm text-ink-500 mt-1">Messages sent</div></div>
        <div><div class="text-4xl font-black text-brand-900">47%</div><div class="text-sm text-ink-500 mt-1">Higher conversions vs batch</div></div>
        <div><div class="text-4xl font-black text-brand-900">99.99%</div><div class="text-sm text-ink-500 mt-1">Uptime SLA</div></div>
        <div><div class="text-4xl font-black text-brand-900">12min</div><div class="text-sm text-ink-500 mt-1">Average time to first campaign</div></div>
      </div>
    </section>

    <!-- Features -->
    <section id="features" class="bg-ink-50 py-24">
      <div class="max-w-7xl mx-auto px-6">
        <div class="max-w-2xl">
          <div class="text-sm text-brand-500 font-semibold uppercase tracking-wider">The platform</div>
          <h2 class="text-4xl md:text-5xl font-black text-brand-900 mt-2 tracking-tight">Everything you need to grow engagement</h2>
          <p class="mt-4 text-lg text-ink-500 leading-relaxed">Stop stitching together five tools. Pulse ships the whole stack — analytics, segmentation, orchestration, and messaging — with the polish of a product that works on day one.</p>
        </div>
        <div class="mt-16 grid md:grid-cols-2 lg:grid-cols-3 gap-4">
          <div v-for="f in features" :key="f.title" class="card p-7 hover:shadow-md transition-shadow group">
            <div class="w-12 h-12 rounded-xl bg-brand-100/60 text-brand-500 flex items-center justify-center mb-5 group-hover:bg-brand-500 group-hover:text-white transition-colors">
              <Icon :name="f.icon" class="w-6 h-6"/>
            </div>
            <div class="font-bold text-ink-900 text-lg mb-2">{{ f.title }}</div>
            <div class="text-sm text-ink-500 leading-relaxed">{{ f.body }}</div>
          </div>
        </div>
      </div>
    </section>

    <!-- Channels -->
    <section id="channels" class="py-24">
      <div class="max-w-7xl mx-auto px-6 grid md:grid-cols-2 gap-16 items-center">
        <div>
          <div class="text-sm text-brand-500 font-semibold uppercase tracking-wider">Omnichannel</div>
          <h2 class="text-4xl md:text-5xl font-black text-brand-900 mt-2 tracking-tight">Reach users where they are</h2>
          <p class="mt-4 text-lg text-ink-500 leading-relaxed">Orchestrate a single journey across every channel. Pulse picks the cheapest path that converts — or you can hard-code the order yourself.</p>
          <div class="mt-8 space-y-3">
            <div v-for="c in channels" :key="c.title" class="flex gap-4 items-start">
              <div class="w-10 h-10 rounded-lg bg-brand-500 text-white flex items-center justify-center shrink-0"><Icon :name="c.icon" class="w-5 h-5"/></div>
              <div>
                <div class="font-semibold text-ink-900">{{ c.title }}</div>
                <div class="text-sm text-ink-500 mt-0.5">{{ c.body }}</div>
              </div>
            </div>
          </div>
        </div>
        <div class="relative">
          <div class="absolute -inset-4 bg-gradient-to-tr from-brand-500/20 to-accent-500/20 blur-3xl rounded-3xl"></div>
          <img src="https://images.pexels.com/photos/6476587/pexels-photo-6476587.jpeg?auto=compress&cs=tinysrgb&w=1200" class="relative rounded-2xl shadow-2xl w-full h-[520px] object-cover" alt="Channels"/>
        </div>
      </div>
    </section>

    <!-- Quote -->
    <section id="customers" class="bg-brand-900 text-white py-24 relative overflow-hidden">
      <div class="absolute inset-0 opacity-10"><div class="absolute top-0 right-0 w-[500px] h-[500px] rounded-full bg-accent-500 blur-3xl"></div></div>
      <div class="relative max-w-4xl mx-auto px-6 text-center">
        <div class="text-5xl text-brand-500 font-serif leading-none mb-6">&ldquo;</div>
        <p class="text-2xl md:text-3xl font-medium leading-relaxed">
          We replaced three tools with Pulse in two weeks. Our onboarding open rates went from 38% to 62% just by running the send-time optimizer.
        </p>
        <div class="mt-8 flex items-center justify-center gap-3">
          <img src="https://images.pexels.com/photos/2381069/pexels-photo-2381069.jpeg?auto=compress&cs=tinysrgb&w=200" class="w-12 h-12 rounded-full object-cover border-2 border-white/20" alt=""/>
          <div class="text-left">
            <div class="font-semibold">Adaeze Okonkwo</div>
            <div class="text-sm text-white/60">Head of Growth, Northpeak</div>
          </div>
        </div>
      </div>
    </section>

    <!-- Pricing -->
    <section id="pricing" class="py-24">
      <div class="max-w-7xl mx-auto px-6">
        <div class="text-center max-w-2xl mx-auto">
          <div class="text-sm text-brand-500 font-semibold uppercase tracking-wider">Pricing</div>
          <h2 class="text-4xl md:text-5xl font-black text-brand-900 mt-2 tracking-tight">Scale-friendly, not scale-punishing</h2>
          <p class="mt-4 text-lg text-ink-500">Every plan includes unlimited users, full RBAC, and every channel. You pay for volume.</p>
        </div>
        <div class="mt-12 grid md:grid-cols-4 gap-4">
          <div v-for="(p, i) in pricing" :key="p.name" class="card p-6 flex flex-col" :class="i === 1 ? 'ring-2 ring-brand-500 relative' : ''">
            <div v-if="i === 1" class="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full bg-brand-500 text-white text-[11px] font-bold uppercase tracking-wider">Popular</div>
            <div class="font-bold text-ink-900 text-lg">{{ p.name }}</div>
            <div class="text-sm text-ink-500 mt-1 min-h-[40px]">{{ p.sub }}</div>
            <div class="text-4xl font-black text-brand-900 mt-5">{{ p.price }}<span v-if="p.price !== 'Custom'" class="text-sm text-ink-500 font-medium">/mo</span></div>
            <ul class="mt-6 space-y-2 text-sm text-ink-700 flex-1">
              <li v-for="item in p.features" :key="item" class="flex items-start gap-2">
                <Icon name="check" class="w-4 h-4 text-accent-500 mt-0.5 shrink-0"/>{{ item }}
              </li>
            </ul>
            <NuxtLink to="/signup" class="mt-6" :class="i === 1 ? 'btn-primary' : 'btn-secondary'">{{ p.cta }}</NuxtLink>
          </div>
        </div>
      </div>
    </section>

    <!-- CTA -->
    <section class="bg-gradient-to-br from-brand-500 to-brand-700 text-white py-20">
      <div class="max-w-5xl mx-auto px-6 text-center">
        <h2 class="text-4xl md:text-5xl font-black tracking-tight">Ready to make every message count?</h2>
        <p class="mt-4 text-lg text-white/80 max-w-2xl mx-auto">Spin up a workspace in under a minute. Import customers, build a segment, and send your first campaign today.</p>
        <div class="mt-8 flex flex-col sm:flex-row items-center justify-center gap-3">
          <NuxtLink to="/signup" class="bg-white !text-brand-500 font-semibold px-8 py-3.5 rounded-lg hover:bg-ink-50 transition-colors dark:!bg-white dark:hover:!bg-ink-50">Start free</NuxtLink>
          <a href="mailto:sales@pulse.app" class="border border-white/30 text-white px-8 py-3.5 rounded-lg hover:bg-white/10 transition-colors">Talk to sales</a>
        </div>
      </div>
    </section>

    <footer class="border-t border-ink-100 py-10">
      <div class="max-w-7xl mx-auto px-6 flex flex-col md:flex-row items-center justify-between gap-4 text-sm text-ink-500">
        <div class="flex items-center gap-2">
          <img src="/pulse-app-icon.svg" alt="Pulse" class="w-7 h-7 rounded-md"/>
          <span class="font-bold text-brand-900">Pulse</span>
          <span class="ml-2">© 2026. Built for modern product teams.</span>
        </div>
        <div class="flex items-center gap-6">
          <a href="#" class="hover:text-brand-500">Privacy</a>
          <a href="#" class="hover:text-brand-500">Terms</a>
          <a href="#" class="hover:text-brand-500">Security</a>
          <a href="#" class="hover:text-brand-500">Status</a>
        </div>
      </div>
    </footer>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: false })

const features = [
  { icon: 'users', title: 'Unified customer profile', body: 'One canonical view of every user across web and mobile — traits, events, devices, journey state, channel preferences.' },
  { icon: 'segment', title: 'Precise segmentation', body: 'Build dynamic segments with attributes and behavior. They update in real time as users act.' },
  { icon: 'route', title: 'Journeys & triggers', body: 'Drag-and-drop canvas with delays, branches, goals, holdout groups, and multivariate experiments.' },
  { icon: 'send', title: 'Smart send-time', body: 'Per-user send-time optimization and timezone-respecting delivery that learns from your data.' },
  { icon: 'activity', title: 'Funnels & cohorts', body: 'Understand where users drop off and what retains them. Share snapshots with your team or exec.' },
  { icon: 'shield', title: 'Enterprise-grade controls', body: 'Granular RBAC, approval workflows, audit logs, quiet hours, and frequency capping out of the box.' },
]

const channels = [
  { icon: 'send', title: 'Email', body: 'Visual drag-and-drop editor, dynamic content, AMP support, and verified-domain authentication.' },
  { icon: 'bell', title: 'Mobile push & in-app', body: 'iOS and Android SDKs, rich media, deeplinks, and banners that match your brand.' },
  { icon: 'monitor', title: 'On-site messages', body: 'Popups, bars, and slide-ins that target any page, segment, or behavior — without a deploy.' },
  { icon: 'message', title: 'SMS & WhatsApp', body: 'Two-way conversations, templates, opt-in tracking, and compliance-safe scheduling.' },
]

const pricing = [
  { name: 'Free', sub: 'For small teams getting started.', price: '$0', features: ['5,000 emails/mo', '10,000 push/mo', '2 seats', 'All channels'], cta: 'Start free' },
  { name: 'Pro', sub: 'For growing teams that need more volume.', price: '$99', features: ['100,000 emails/mo', '1,000 SMS/mo', '5 seats', 'A/B testing', 'Custom domain'], cta: 'Start Pro trial' },
  { name: 'Advanced', sub: 'For teams at serious scale.', price: '$499', features: ['1M emails/mo', '10,000 SMS/mo', '15 seats', 'Dedicated IPs', 'Priority support', 'Advanced RBAC'], cta: 'Start Advanced' },
  { name: 'Enterprise', sub: 'Custom limits, SSO, SLAs.', price: 'Custom', features: ['Unlimited volume', 'SSO + SCIM', 'Dedicated IP pools', 'SLA-backed uptime', 'Onboarding manager'], cta: 'Contact sales' },
]
</script>
