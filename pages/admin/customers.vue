<template>
  <div>
    <PageHeader title="Customers" subtitle="Every workspace on Pulse, searchable."/>
    <div class="p-8 space-y-4">
      <div class="card p-4 flex items-center gap-3 flex-wrap">
        <input v-model="q" placeholder="Search by name, slug, or industry" class="input flex-1 min-w-[240px]"/>
        <select v-model="planFilter" class="input !w-48">
          <option value="">All plans</option>
          <option v-for="p in plans" :key="p.id" :value="p.id">{{ p.name }}</option>
        </select>
        <select v-model="statusFilter" class="input !w-44">
          <option value="">All statuses</option>
          <option value="trialing">Trialing</option>
          <option value="active">Active</option>
          <option value="past_due">Past due</option>
          <option value="cancelled">Cancelled</option>
          <option value="expired">Expired</option>
        </select>
      </div>
      <div class="card">
        <table class="w-full text-sm">
          <thead class="text-left text-xs text-ink-500 uppercase tracking-wider border-b border-ink-100">
            <tr>
              <th class="px-4 py-3">Workspace</th>
              <th class="px-4 py-3">Plan</th>
              <th class="px-4 py-3">Status</th>
              <th class="px-4 py-3">Email used</th>
              <th class="px-4 py-3">Created</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="w in paged" :key="w.id" class="border-b border-ink-100 last:border-0 hover:bg-ink-50">
              <td class="px-4 py-3">
                <div class="font-semibold text-ink-900">{{ w.name }}</div>
                <div class="text-xs text-ink-500">{{ w.slug }} · {{ w.industry || '—' }}</div>
              </td>
              <td class="px-4 py-3"><span class="chip bg-brand-100/40 text-brand-700">{{ planName(w.plan_id) }}</span></td>
              <td class="px-4 py-3">
                <span class="chip text-xs" :class="statusClass(w)">{{ statusLabel(w) }}</span>
                <div v-if="w.subscription_status === 'trialing' && w.trial_ends_at" class="text-[11px] text-ink-500 mt-1">
                  Ends {{ new Date(w.trial_ends_at).toLocaleDateString() }} ({{ daysLeft(w) }}d)
                </div>
              </td>
              <td class="px-4 py-3 text-ink-700">{{ (w.email_used_this_month || 0).toLocaleString() }} / {{ emailCap(w).toLocaleString() }}</td>
              <td class="px-4 py-3 text-xs text-ink-500">{{ new Date(w.created_at).toLocaleDateString() }}</td>
              <td class="px-4 py-3 text-right"><button @click="edit(w)" class="btn-secondary !py-1 !text-xs">Manage</button></td>
            </tr>
          </tbody>
        </table>
        <Pagination v-model:page="page" v-model:pageSize="pageSize" :total="filtered.length"/>
      </div>
    </div>

    <Modal v-model="open" :title="editing ? `Manage ${editing.name}` : 'Manage workspace'" size="lg">
      <div v-if="editing" class="space-y-4">
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="label">Plan</label>
            <select v-model="form.plan_id" class="input">
              <option v-for="p in plans" :key="p.id" :value="p.id">{{ p.name }}{{ p.contact_sales ? ' (custom)' : ` ($${p.price_monthly}/mo)` }}</option>
            </select>
          </div>
          <div>
            <label class="label">Subscription status</label>
            <select v-model="form.status" class="input">
              <option value="trialing">Trialing</option>
              <option value="active">Active</option>
              <option value="past_due">Past due</option>
              <option value="cancelled">Cancelled</option>
              <option value="expired">Expired</option>
            </select>
          </div>
          <div>
            <label class="label">Start/extend trial</label>
            <div class="flex items-center gap-2">
              <input v-model.number="form.trial_days" type="number" min="0" class="input" placeholder="days"/>
              <button type="button" @click="applyTrial" class="btn-secondary whitespace-nowrap">Set trial end</button>
            </div>
            <div class="text-[11px] text-ink-500 mt-1">Sets trial_ends_at to now + N days.</div>
          </div>
          <div>
            <label class="label">Trial ends at</label>
            <input v-model="form.trial_ends_at" type="datetime-local" class="input"/>
          </div>
          <div><label class="label">Email quota override</label><input v-model.number="form.email_quota_override" type="number" class="input" placeholder="leave blank for plan default"/></div>
          <div><label class="label">SMS quota override</label><input v-model.number="form.sms_quota_override" type="number" class="input" placeholder="leave blank for plan default"/></div>
        </div>

        <div>
          <label class="label">Change note (visible in plan history)</label>
          <input v-model="form.note" class="input" placeholder="e.g. upgraded after sales call"/>
        </div>

        <div v-if="history.length" class="border-t border-ink-100 pt-3">
          <div class="text-xs font-semibold text-ink-700 uppercase tracking-wider mb-2">Plan history</div>
          <ul class="space-y-1.5 text-xs text-ink-600 max-h-40 overflow-auto">
            <li v-for="h in history" :key="h.id" class="flex gap-2">
              <span class="text-ink-400 tabular-nums">{{ new Date(h.created_at).toLocaleDateString() }}</span>
              <span>{{ planName(h.from_plan_id) }} → <strong>{{ planName(h.to_plan_id) }}</strong></span>
              <span v-if="h.note" class="text-ink-500 italic">— {{ h.note }}</span>
            </li>
          </ul>
        </div>
      </div>
      <template #footer>
        <button @click="open = false" type="button" class="btn-secondary">Cancel</button>
        <button @click="save" type="button" class="btn-primary">Save changes</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })
const { $supabase } = useNuxtApp()
const toast = useToast()
const workspaces = ref<any[]>([])
const plans = ref<any[]>([])
const history = ref<any[]>([])
const q = ref('')
const planFilter = ref('')
const statusFilter = ref('')
const open = ref(false)
const editing = ref<any>(null)
const form = reactive<any>({
  plan_id: '', status: 'active', trial_days: 0, trial_ends_at: '',
  email_quota_override: null, sms_quota_override: null, note: '',
  original_plan_id: '',
})

onMounted(loadAll)

async function loadAll() {
  const [ws, pls] = await Promise.all([
    $supabase.from('workspaces').select('*').or('environment.is.null,environment.neq.test').is('parent_workspace_id', null).order('created_at', { ascending: false }),
    $supabase.from('plans').select('*').order('sort_order'),
  ])
  workspaces.value = ws.data || []
  plans.value = pls.data || []
}

function planName(id: string | null) {
  if (!id) return '—'
  return plans.value.find((p: any) => p.id === id)?.name || '—'
}
function emailCap(w: any) {
  if (w.email_quota_override != null) return w.email_quota_override
  return plans.value.find((p: any) => p.id === w.plan_id)?.email_monthly_quota || 0
}
function daysLeft(w: any) {
  if (!w.trial_ends_at) return 0
  return Math.max(0, Math.ceil((new Date(w.trial_ends_at).getTime() - Date.now()) / 86400000))
}
function statusLabel(w: any) {
  const s = w.subscription_status || 'active'
  if (s === 'trialing') return 'Trial'
  return s.charAt(0).toUpperCase() + s.slice(1).replace('_', ' ')
}
function statusClass(w: any) {
  const s = w.subscription_status || 'active'
  if (s === 'trialing') return 'bg-brand-100/50 text-brand-700'
  if (s === 'active') return 'bg-green-100 text-green-700'
  if (s === 'past_due') return 'bg-yellow-100 text-yellow-700'
  return 'bg-red-100 text-red-700'
}

const filtered = computed(() => {
  const qq = q.value.toLowerCase()
  return workspaces.value.filter((w: any) => {
    const matchesQ = !qq || w.name?.toLowerCase().includes(qq) || w.slug?.toLowerCase().includes(qq) || w.industry?.toLowerCase().includes(qq)
    const matchesPlan = !planFilter.value || w.plan_id === planFilter.value
    const matchesStatus = !statusFilter.value || (w.subscription_status || 'active') === statusFilter.value
    return matchesQ && matchesPlan && matchesStatus
  })
})
const page = ref(1)
const pageSize = ref(50)
const paged = computed(() => filtered.value.slice((page.value - 1) * pageSize.value, page.value * pageSize.value))
watch([q, planFilter, statusFilter, pageSize], () => { page.value = 1 })

function toLocalInput(iso: string | null) {
  if (!iso) return ''
  const d = new Date(iso)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

async function edit(w: any) {
  editing.value = w
  Object.assign(form, {
    plan_id: w.plan_id,
    status: w.subscription_status || 'active',
    trial_days: 0,
    trial_ends_at: toLocalInput(w.trial_ends_at),
    email_quota_override: w.email_quota_override,
    sms_quota_override: w.sms_quota_override,
    note: '',
    original_plan_id: w.plan_id,
  })
  const { data } = await $supabase
    .from('plan_changes').select('*').eq('workspace_id', w.id)
    .order('created_at', { ascending: false }).limit(20)
  history.value = data || []
  open.value = true
}

function applyTrial() {
  const days = Number(form.trial_days)
  if (!days || days <= 0) { toast.error('Enter a positive number of trial days'); return }
  const end = new Date(Date.now() + days * 86400000)
  form.trial_ends_at = toLocalInput(end.toISOString())
  form.status = 'trialing'
  toast.success(`Trial set to end on ${end.toLocaleDateString()}`)
}

async function save() {
  if (!editing.value) return
  const wsId = editing.value.id

  if (form.plan_id && form.plan_id !== form.original_plan_id) {
    const { error } = await $supabase.rpc('admin_set_workspace_plan', {
      p_workspace_id: wsId,
      p_plan_id: form.plan_id,
      p_start_trial: form.status === 'trialing',
      p_trial_days_override: form.status === 'trialing' ? (Number(form.trial_days) || null) : null,
      p_note: form.note || '',
    })
    if (error) { toast.error('Plan change failed', error.message); return }
  }

  const trialIso = form.trial_ends_at ? new Date(form.trial_ends_at).toISOString() : null
  if (trialIso || form.status !== (editing.value.subscription_status || 'active')) {
    const { error } = await $supabase.rpc('admin_set_workspace_trial', {
      p_workspace_id: wsId,
      p_trial_ends_at: trialIso,
      p_status: form.status,
    })
    if (error) { toast.error('Trial update failed', error.message); return }
  }

  const { error: upErr } = await $supabase.from('workspaces').update({
    email_quota_override: form.email_quota_override ?? null,
    sms_quota_override: form.sms_quota_override ?? null,
  }).eq('id', wsId)
  if (upErr) { toast.error('Quota update failed', upErr.message); return }

  toast.success('Workspace updated')
  open.value = false
  await loadAll()
}
</script>
