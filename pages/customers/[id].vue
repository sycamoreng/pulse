<template>
  <div v-if="customer">
    <PageHeader :title="`${customer.first_name} ${customer.last_name}`.trim() || customer.external_id" :subtitle="customer.email" breadcrumb="Customers">
      <template #actions>
        <button @click="toggleBlacklist" class="btn-secondary">
          <Icon name="shield"/>{{ customer.is_blacklisted ? 'Remove from blacklist' : 'Blacklist' }}
        </button>
        <button @click="remove" class="btn-danger"><Icon name="trash"/>Delete</button>
      </template>
    </PageHeader>

    <div class="relative h-40 md:h-48 overflow-hidden" :style="{ background: `linear-gradient(135deg, ${brandPrimary}, ${brandAccent})` }">
      <img src="https://images.pexels.com/photos/3184292/pexels-photo-3184292.jpeg?auto=compress&cs=tinysrgb&w=1600" class="w-full h-full object-cover opacity-25 mix-blend-overlay" alt=""/>
      <div class="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent"></div>
    </div>

    <div class="px-8 -mt-16 relative z-10">
      <div class="flex items-end gap-5 flex-wrap">
        <div class="w-28 h-28 rounded-2xl bg-white dark:bg-[color:var(--surface-card)] p-1.5 shadow-soft">
          <div class="w-full h-full rounded-xl text-white flex items-center justify-center font-bold text-3xl tracking-tight" :style="{ background: brandPrimary }">{{ initials }}</div>
        </div>
        <div class="flex-1 min-w-[260px] pb-2">
          <div class="flex items-center gap-2 flex-wrap">
            <div class="text-xl font-bold text-ink-900">{{ customer.first_name }} {{ customer.last_name }}</div>
            <span v-if="customer.is_blacklisted" class="chip bg-red-100 text-red-700">Blacklisted</span>
            <span v-else class="chip bg-accent-500/10 text-accent-500">Active</span>
          </div>
          <div class="text-sm text-ink-500 mt-0.5">{{ customer.email }} <span v-if="customer.phone" class="mx-1 text-ink-300">·</span> {{ customer.phone }}</div>
        </div>
        <div class="flex gap-3 pb-2">
          <div class="text-center"><div class="text-xl font-bold text-ink-900">{{ events.length }}</div><div class="text-[10px] text-ink-500 uppercase tracking-wider">Events</div></div>
          <div class="w-px bg-ink-100"></div>
          <div class="text-center"><div class="text-xl font-bold text-ink-900">{{ firstSeenLabel }}</div><div class="text-[10px] text-ink-500 uppercase tracking-wider">First seen</div></div>
          <div class="w-px bg-ink-100"></div>
          <div class="text-center"><div class="text-xl font-bold text-ink-900">{{ lastSeenLabel }}</div><div class="text-[10px] text-ink-500 uppercase tracking-wider">Last activity</div></div>
        </div>
      </div>
    </div>

    <div class="p-8 pt-6 space-y-6">
      <div v-if="signals.length || recos.length" class="card p-6 border-l-4 border-brand-500">
        <div class="flex items-center justify-between mb-3 gap-3 flex-wrap">
          <div>
            <div class="flex items-center gap-2">
              <Icon name="flask" class="w-4 h-4 text-brand-500"/>
              <div class="font-semibold text-ink-900">Next best action</div>
            </div>
            <div class="text-xs text-ink-500">Behavioural signals and AI suggestions for this customer.</div>
          </div>
          <button @click="recommendForCustomer" :disabled="nbaBusy" class="btn-secondary text-xs">
            <Icon name="refresh" class="w-3 h-3" :class="nbaBusy ? 'animate-spin' : ''"/>{{ nbaBusy ? 'Thinking…' : 'Refresh suggestion' }}
          </button>
        </div>

        <div v-if="signals.length" class="flex flex-wrap gap-2 mb-4">
          <span v-for="s in signals" :key="s.id" class="chip text-[10px] bg-brand-500/10 text-brand-500">
            {{ s.signal_label || s.signal_key }} · {{ Math.round(Number(s.confidence)*100) }}%
          </span>
        </div>

        <div v-if="topReco" class="rounded-xl border border-ink-100 p-4 bg-gradient-to-br from-white to-brand-50/50">
          <div class="flex items-center gap-2 mb-2">
            <span class="chip text-[10px] bg-brand-500 text-white capitalize">{{ topReco.channel }}</span>
            <span v-if="topReco.signal_key" class="chip text-[10px] bg-ink-100 text-ink-700">{{ topReco.signal_key }}</span>
            <span class="ml-auto text-[10px] text-ink-500">{{ Math.round(Number(topReco.confidence)*100) }}% confidence</span>
          </div>
          <div class="font-semibold text-ink-900">{{ topReco.headline }}</div>
          <div class="text-sm text-ink-700 mt-1">{{ topReco.body }}</div>
          <button v-if="topReco.cta" class="mt-2 chip bg-brand-500 text-white text-[11px]">{{ topReco.cta }}</button>
          <div v-if="topReco.reasoning" class="mt-3 text-[11px] text-ink-500 italic">“{{ topReco.reasoning }}”</div>
          <div class="mt-3 flex items-center gap-2">
            <button class="btn-ghost text-xs" @click="useReco(topReco)"><Icon name="send" class="w-3 h-3"/>Use in campaign</button>
            <button class="btn-ghost text-xs text-ink-500" @click="dismissReco(topReco)"><Icon name="x" class="w-3 h-3"/>Dismiss</button>
          </div>
        </div>
        <div v-else-if="signals.length" class="text-sm text-ink-500">Click <span class="font-medium">Refresh suggestion</span> to generate a recommendation.</div>
      </div>

      <div class="grid lg:grid-cols-3 gap-6">
      <div class="card p-6 lg:col-span-1">
        <div class="font-semibold text-ink-900 mb-3">Profile</div>
        <dl class="space-y-3 text-sm">
          <div v-for="(v, k) in displayAttrs" :key="k" class="flex justify-between gap-4">
            <dt class="text-ink-500 capitalize">{{ String(k).replace(/_/g, ' ') }}</dt>
            <dd class="text-ink-900 font-medium text-right break-all">{{ v || '—' }}</dd>
          </div>
        </dl>
      </div>

      <div class="card p-6 lg:col-span-2">
        <div class="flex items-center justify-between mb-4">
          <div>
            <div class="font-semibold text-ink-900">Activity</div>
            <div class="text-xs text-ink-500">Last {{ events.length }} events</div>
          </div>
        </div>
        <div v-if="!events.length" class="text-sm text-ink-500 py-8 text-center">No events for this customer yet.</div>
        <ol v-else class="relative border-l border-ink-100 ml-3 space-y-5">
          <li v-for="e in events" :key="e.id" class="ml-6 relative">
            <span class="absolute -left-[34px] top-1 w-4 h-4 rounded-full bg-brand-500 border-4 border-white"></span>
            <div class="font-medium text-ink-900">{{ e.name }}</div>
            <div class="text-xs text-ink-500">{{ formatDateTime(e.occurred_at) }}</div>
            <pre v-if="e.properties && Object.keys(e.properties).length" class="mt-1 text-xs bg-ink-50 p-2 rounded-lg">{{ JSON.stringify(e.properties, null, 2) }}</pre>
          </li>
        </ol>
      </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const route = useRoute()
const { supabase, workspaceId } = useWorkspace()
const customer = ref<any>(null)
const events = ref<any[]>([])
const signals = ref<any[]>([])
const recos = ref<any[]>([])
const nbaBusy = ref(false)
const topReco = computed(() => recos.value.find((r: any) => r.status !== 'dismissed'))

const { auth } = useWorkspace()
const initials = computed(() => ((customer.value?.first_name?.[0] || '') + (customer.value?.last_name?.[0] || '')).toUpperCase() || 'U')
const brandPrimary = computed(() => (auth.displayWorkspace?.brand_primary) || '#3087B9')
const brandAccent = computed(() => (auth.displayWorkspace?.brand_accent) || '#0E7490')
const firstSeenLabel = computed(() => {
  const d = customer.value?.created_at
  if (!d) return '—'
  return new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: '2-digit' })
})
const lastSeenLabel = computed(() => {
  const d = events.value[0]?.occurred_at
  if (!d) return '—'
  const days = Math.floor((Date.now() - new Date(d).getTime()) / (24*3600*1000))
  if (days === 0) return 'Today'
  if (days === 1) return '1d ago'
  if (days < 30) return `${days}d ago`
  return new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
})
const displayAttrs = computed(() => {
  if (!customer.value) return {}
  const { id, workspace_id, attributes, ...rest } = customer.value
  return { ...rest, ...(attributes || {}) }
})

async function load() {
  const { data } = await supabase.from('customers').select('*').eq('id', route.params.id).maybeSingle()
  customer.value = data
  const [{ data: ev }, { data: sigs }, { data: rcs }] = await Promise.all([
    supabase.from('events').select('*').eq('customer_id', route.params.id).order('occurred_at', { ascending: false }).limit(50),
    supabase.from('customer_signals').select('*').eq('customer_id', route.params.id).is('consumed_at', null).order('detected_at', { ascending: false }).limit(10),
    supabase.from('ai_recommendations').select('*').eq('customer_id', route.params.id).order('created_at', { ascending: false }).limit(5),
  ])
  events.value = ev || []
  signals.value = sigs || []
  recos.value = rcs || []
}

async function recommendForCustomer() {
  if (!workspaceId.value || !signals.value.length) {
    useToast().info('No open signals', 'Run a detection scan from the Intelligence page first.')
    return
  }
  nbaBusy.value = true
  try {
    const url = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/ai-recommend`
    const { data: { session } } = await supabase.auth.getSession()
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${session?.access_token || import.meta.env.VITE_SUPABASE_ANON_KEY}`,
        'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY,
      },
      body: JSON.stringify({ workspace_id: workspaceId.value, signal_ids: [signals.value[0].id], limit: 1 }),
    })
    const json = await res.json()
    if (!res.ok || !json.ok) throw new Error(json.error || `HTTP ${res.status}`)
    useToast().success('Suggestion ready')
    await load()
  } catch (e: any) {
    useToast().error('Could not generate', e.message)
  } finally {
    nbaBusy.value = false
  }
}

function useReco(r: any) {
  useToast().info('Copied for campaign', 'Open Campaigns to paste this into a new send.')
  if (typeof navigator !== 'undefined' && navigator.clipboard) {
    navigator.clipboard.writeText(`${r.headline}\n\n${r.body}\n\nCTA: ${r.cta}`).catch(() => {})
  }
}

async function dismissReco(r: any) {
  await supabase.from('ai_recommendations').update({ status: 'dismissed', dismissed_at: new Date().toISOString() }).eq('id', r.id)
  recos.value = recos.value.filter(x => x.id !== r.id)
}
async function toggleBlacklist() {
  await supabase.from('customers').update({ is_blacklisted: !customer.value.is_blacklisted }).eq('id', customer.value.id)
  await load()
}
async function remove() {
  const ok = await useConfirm().ask({ title: 'Delete this customer?', message: 'Their events and list memberships will also be deleted.', tone: 'danger', confirmText: 'Delete permanently' })
  if (!ok) return
  await supabase.from('customers').delete().eq('id', customer.value.id)
  useToast().success('Customer deleted')
  navigateTo('/customers')
}
onMounted(load)
</script>
