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

    <div class="p-8 grid lg:grid-cols-3 gap-6">
      <div class="card p-6 lg:col-span-1">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-14 h-14 rounded-full bg-brand-500 text-white flex items-center justify-center font-bold text-xl">{{ initials }}</div>
          <div>
            <div class="font-semibold text-ink-900">{{ customer.first_name }} {{ customer.last_name }}</div>
            <div class="text-xs text-ink-500 font-mono">{{ customer.external_id }}</div>
          </div>
        </div>
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

const initials = computed(() => ((customer.value?.first_name?.[0] || '') + (customer.value?.last_name?.[0] || '')).toUpperCase() || 'U')
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
