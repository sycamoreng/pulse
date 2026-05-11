<template>
  <div>
    <PageHeader title="Customers" subtitle="Every workspace on Pulse, searchable."/>
    <div class="p-8 space-y-4">
      <div class="card p-4 flex items-center gap-3">
        <input v-model="q" placeholder="Search by name, slug, or industry" class="input flex-1"/>
        <select v-model="planFilter" class="input !w-48"><option value="">All plans</option><option v-for="p in plans" :key="p.id" :value="p.id">{{ p.name }}</option></select>
      </div>
      <div class="card">
        <table class="w-full text-sm">
          <thead class="text-left text-xs text-ink-500 uppercase tracking-wider border-b border-ink-100">
            <tr><th class="px-4 py-3">Workspace</th><th class="px-4 py-3">Plan</th><th class="px-4 py-3">Email used</th><th class="px-4 py-3">Created</th><th></th></tr>
          </thead>
          <tbody>
            <tr v-for="w in paged" :key="w.id" class="border-b border-ink-100 last:border-0 hover:bg-ink-50">
              <td class="px-4 py-3">
                <div class="font-semibold text-ink-900">{{ w.name }}</div>
                <div class="text-xs text-ink-500">{{ w.slug }} · {{ w.industry || '—' }}</div>
              </td>
              <td class="px-4 py-3"><span class="chip bg-brand-100/40 text-brand-700">{{ planName(w.plan_id) }}</span></td>
              <td class="px-4 py-3 text-ink-700">{{ (w.email_used_this_month || 0).toLocaleString() }} / {{ emailCap(w).toLocaleString() }}</td>
              <td class="px-4 py-3 text-xs text-ink-500">{{ new Date(w.created_at).toLocaleDateString() }}</td>
              <td class="px-4 py-3 text-right"><button @click="edit(w)" class="btn-secondary !py-1 !text-xs">Manage</button></td>
            </tr>
          </tbody>
        </table>
        <Pagination v-model:page="page" v-model:pageSize="pageSize" :total="filtered.length"/>
      </div>
    </div>

    <Modal v-model="open" title="Manage workspace" size="lg">
      <div v-if="editing" class="space-y-3">
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">Plan</label>
            <select v-model="form.plan_id" class="input"><option v-for="p in plans" :key="p.id" :value="p.id">{{ p.name }} (${{ p.price_monthly }}/mo)</option></select>
            )
          </div>
          <div><label class="label">Seats</label><div class="input bg-ink-50">{{ (editing.seats || 0) }}</div></div>
          <div><label class="label">Email quota override</label><input v-model.number="form.email_quota_override" type="number" class="input" placeholder="leave blank to use plan"/></div>
          <div><label class="label">SMS quota override</label><input v-model.number="form.sms_quota_override" type="number" class="input" placeholder="leave blank to use plan"/></div>
        </div>
      </div>
      <template #footer>
        <button @click="open = false" class="btn-secondary">Cancel</button>
        <button @click="save" class="btn-primary">Save</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })
const { $supabase } = useNuxtApp()
const workspaces = ref<any[]>([])
const plans = ref<any[]>([])
const q = ref('')
const planFilter = ref('')
const open = ref(false)
const editing = ref<any>(null)
const form = reactive<any>({ plan_id: '', email_quota_override: null, sms_quota_override: null })

onMounted(async () => {
  const [ws, pls] = await Promise.all([
    $supabase.from('workspaces').select('*').order('created_at', { ascending: false }),
    $supabase.from('plans').select('*').order('sort_order'),
  ])
  workspaces.value = ws.data || []
  plans.value = pls.data || []
})

function planName(id: string) {
  return plans.value.find((p: any) => p.id === id)?.name || 'Free'
}
function emailCap(w: any) {
  if (w.email_quota_override != null) return w.email_quota_override
  return plans.value.find((p: any) => p.id === w.plan_id)?.email_monthly_quota || 0
}
const filtered = computed(() => {
  const qq = q.value.toLowerCase()
  return workspaces.value.filter((w: any) => {
    const matchesQ = !qq || w.name?.toLowerCase().includes(qq) || w.slug?.toLowerCase().includes(qq) || w.industry?.toLowerCase().includes(qq)
    const matchesPlan = !planFilter.value || w.plan_id === planFilter.value
    return matchesQ && matchesPlan
  })
})
const page = ref(1)
const pageSize = ref(50)
const paged = computed(() => {
  const start = (page.value - 1) * pageSize.value
  return filtered.value.slice(start, start + pageSize.value)
})
watch([q, planFilter, pageSize], () => { page.value = 1 })
function edit(w: any) {
  editing.value = w
  Object.assign(form, { plan_id: w.plan_id, email_quota_override: w.email_quota_override, sms_quota_override: w.sms_quota_override })
  open.value = true
}
async function save() {
  await $supabase.from('workspaces').update({
    plan_id: form.plan_id,
    email_quota_override: form.email_quota_override || null,
    sms_quota_override: form.sms_quota_override || null,
  }).eq('id', editing.value.id)
  const { data } = await $supabase.from('workspaces').select('*').order('created_at', { ascending: false })
  workspaces.value = data || []
  open.value = false
  useToast().success('Workspace updated')
}
</script>
