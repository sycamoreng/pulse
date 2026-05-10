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

    <div class="p-8 pt-6 grid lg:grid-cols-3 gap-6">
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
</template>

<script setup lang="ts">
const route = useRoute()
const { supabase } = useWorkspace()
const customer = ref<any>(null)
const events = ref<any[]>([])

const { auth } = useWorkspace()
const initials = computed(() => ((customer.value?.first_name?.[0] || '') + (customer.value?.last_name?.[0] || '')).toUpperCase() || 'U')
const brandPrimary = computed(() => auth.workspace?.brand_primary || '#3087B9')
const brandAccent = computed(() => auth.workspace?.brand_accent || '#0E7490')
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
  const { data: ev } = await supabase.from('events').select('*').eq('customer_id', route.params.id).order('occurred_at', { ascending: false }).limit(50)
  events.value = ev || []
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
