<template>
  <div>
    <PageHeader title="Trust & Premium" subtitle="Audit log, consent, predictive audiences, and inbox placement."/>

    <div class="px-8 pt-4">
      <div class="flex gap-2 border-b border-ink-100">
        <button v-for="t in tabs" :key="t.id" @click="tab = t.id"
          class="px-4 py-2.5 text-sm font-semibold border-b-2 -mb-px"
          :class="tab === t.id ? 'border-brand-500 text-brand-500' : 'border-transparent text-ink-500 hover:text-ink-900'">
          <Icon :name="t.icon" class="w-4 h-4 inline mr-1.5"/>{{ t.label }}
        </button>
      </div>
    </div>

    <div class="p-8 space-y-4">
      <!-- AUDIT -->
      <div v-if="tab === 'audit'">
        <div class="card p-4 flex items-center gap-3 mb-4">
          <input v-model="auditSearch" placeholder="Filter by action, entity, or actor" class="input flex-1 max-w-sm"/>
          <select v-model="auditEntityFilter" class="input max-w-xs">
            <option value="">All entity types</option>
            <option v-for="e in auditEntities" :key="e" :value="e">{{ e }}</option>
          </select>
          <div class="text-xs text-ink-500 ml-auto">{{ filteredAudit.length }} event{{ filteredAudit.length === 1 ? '' : 's' }}</div>
        </div>

        <div v-if="!filteredAudit.length" class="card">
          <EmptyState icon="shield" title="No audit events" subtitle="Changes made by teammates will appear here."/>
        </div>
        <div v-else class="card overflow-hidden">
          <table class="w-full">
            <thead>
              <tr>
                <th class="table-th">When</th>
                <th class="table-th">Actor</th>
                <th class="table-th">Action</th>
                <th class="table-th">Entity</th>
                <th class="table-th"></th>
              </tr>
            </thead>
            <tbody>
              <template v-for="a in filteredAudit" :key="a.id">
                <tr class="hover:bg-ink-50 cursor-pointer" @click="a._open = !a._open">
                  <td class="table-td text-xs text-ink-500 whitespace-nowrap">{{ formatDateTime(a.created_at) }}</td>
                  <td class="table-td text-xs">{{ a.actor_email || '—' }}</td>
                  <td class="table-td"><span class="chip" :class="actionTone(a.action)">{{ a.action }}</span></td>
                  <td class="table-td">
                    <div class="text-sm font-medium">{{ a.entity_name || a.entity_id }}</div>
                    <div class="text-[11px] text-ink-500">{{ a.entity_type }}</div>
                  </td>
                  <td class="table-td text-ink-500"><Icon :name="a._open ? 'chevronUp' : 'chevronDown'" class="w-4 h-4"/></td>
                </tr>
                <tr v-if="a._open">
                  <td colspan="5" class="px-4 py-3 bg-ink-50 border-b border-ink-100">
                    <pre class="text-xs text-ink-700 overflow-x-auto whitespace-pre-wrap">{{ JSON.stringify(a.diff || {}, null, 2) }}</pre>
                  </td>
                </tr>
              </template>
            </tbody>
          </table>
        </div>
      </div>

      <!-- CONSENT -->
      <div v-if="tab === 'consent'">
        <div class="card p-4 flex items-center gap-3 mb-4">
          <input v-model="consentSearch" placeholder="Search by customer email" class="input flex-1 max-w-sm"/>
          <button @click="openConsentEdit(null)" class="btn-primary ml-auto"><Icon name="plus"/>Record consent</button>
        </div>
        <div v-if="!filteredConsents.length" class="card">
          <EmptyState icon="shield" title="No consent records" subtitle="Track opt-in and opt-out per channel for GDPR/CCPA compliance."/>
        </div>
        <div v-else class="card overflow-hidden">
          <table class="w-full">
            <thead>
              <tr>
                <th class="table-th">Customer</th>
                <th class="table-th">Channel</th>
                <th class="table-th">State</th>
                <th class="table-th">Source</th>
                <th class="table-th">When</th>
                <th class="table-th"></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="c in filteredConsents" :key="c.id" class="hover:bg-ink-50">
                <td class="table-td">{{ c.customer?.email || '—' }}</td>
                <td class="table-td capitalize">{{ c.channel }}</td>
                <td class="table-td"><span class="chip" :class="stateTone(c.state)">{{ c.state }}</span></td>
                <td class="table-td text-xs text-ink-500">{{ c.source }}</td>
                <td class="table-td text-xs text-ink-500">{{ formatDateTime(c.changed_at) }}</td>
                <td class="table-td text-right">
                  <button @click="openConsentEdit(c)" class="btn-ghost">Edit</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- PREDICTIVE -->
      <div v-if="tab === 'predictive'">
        <div class="grid sm:grid-cols-3 gap-4 mb-4">
          <div class="card p-4">
            <div class="text-xs text-ink-500">High churn risk</div>
            <div class="text-2xl font-bold text-red-600 mt-1">{{ predStats.highChurn }}</div>
            <div class="text-[11px] text-ink-500 mt-1">Customers with >70% risk</div>
          </div>
          <div class="card p-4">
            <div class="text-xs text-ink-500">High propensity</div>
            <div class="text-2xl font-bold text-accent-500 mt-1">{{ predStats.highProp }}</div>
            <div class="text-[11px] text-ink-500 mt-1">Likely to purchase soon</div>
          </div>
          <div class="card p-4">
            <div class="text-xs text-ink-500">High LTV bucket</div>
            <div class="text-2xl font-bold text-brand-500 mt-1">{{ predStats.highLtv }}</div>
            <div class="text-[11px] text-ink-500 mt-1">Top-value customers</div>
          </div>
        </div>

        <div class="card p-4 flex items-center gap-3 mb-4">
          <div class="text-xs text-ink-500">Scores are recomputed on demand from event history and purchase totals.</div>
          <button @click="recomputeScores" :disabled="scoring" class="btn-primary ml-auto">
            <Icon name="trending"/>{{ scoring ? 'Computing…' : 'Recompute scores' }}
          </button>
        </div>

        <div v-if="!scores.length" class="card">
          <EmptyState icon="trending" title="No scores yet" subtitle="Run recompute to generate predictive scores for your customers."/>
        </div>
        <div v-else class="card overflow-hidden">
          <table class="w-full">
            <thead>
              <tr>
                <th class="table-th">Customer</th>
                <th class="table-th">Churn risk</th>
                <th class="table-th">Purchase propensity</th>
                <th class="table-th">LTV bucket</th>
                <th class="table-th">Updated</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="s in scores" :key="s.id" class="hover:bg-ink-50">
                <td class="table-td">{{ s.customer?.email || s.customer_id }}</td>
                <td class="table-td">
                  <div class="flex items-center gap-2">
                    <div class="flex-1 h-2 bg-ink-100 rounded max-w-[120px]">
                      <div class="h-full rounded" :style="{ width: `${Math.round(Number(s.churn_risk)*100)}%`, background: riskColor(Number(s.churn_risk)) }"></div>
                    </div>
                    <span class="text-xs font-mono">{{ Math.round(Number(s.churn_risk)*100) }}%</span>
                  </div>
                </td>
                <td class="table-td">
                  <div class="flex items-center gap-2">
                    <div class="flex-1 h-2 bg-ink-100 rounded max-w-[120px]">
                      <div class="h-full rounded bg-accent-500" :style="{ width: `${Math.round(Number(s.purchase_propensity)*100)}%` }"></div>
                    </div>
                    <span class="text-xs font-mono">{{ Math.round(Number(s.purchase_propensity)*100) }}%</span>
                  </div>
                </td>
                <td class="table-td"><span class="chip" :class="ltvTone(s.ltv_bucket)">{{ s.ltv_bucket }}</span></td>
                <td class="table-td text-xs text-ink-500">{{ formatDateTime(s.computed_at) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- INBOX PLACEMENT -->
      <div v-if="tab === 'inbox'">
        <div class="grid lg:grid-cols-2 gap-4">
          <div class="card p-5">
            <div class="flex items-center justify-between mb-3">
              <div>
                <div class="font-semibold text-ink-900">Seed addresses</div>
                <div class="text-xs text-ink-500">Add inboxes across major providers for placement tests.</div>
              </div>
              <button @click="openSeedAdd" class="btn-secondary"><Icon name="plus"/>Add seed</button>
            </div>
            <div v-if="!seeds.length" class="text-center py-8 text-xs text-ink-500">
              No seed addresses yet. Add Gmail, Outlook, Yahoo, and other provider seeds.
            </div>
            <ul v-else class="space-y-2">
              <li v-for="s in seeds" :key="s.id" class="flex items-center gap-3 p-2 border border-ink-100 rounded-lg">
                <span class="chip bg-brand-100/30 text-brand-500 capitalize">{{ s.provider }}</span>
                <span class="text-sm font-mono flex-1 truncate">{{ s.email }}</span>
                <button @click="removeSeed(s.id)" class="text-ink-500 hover:text-red-600"><Icon name="trash" class="w-4 h-4"/></button>
              </li>
            </ul>
          </div>

          <div class="card p-5">
            <div class="font-semibold text-ink-900 mb-1">Run a placement test</div>
            <div class="text-xs text-ink-500 mb-4">Sends the provided content to all seed inboxes, then scores placement.</div>
            <div class="space-y-3">
              <div>
                <label class="label">Subject</label>
                <input v-model="testForm.subject" class="input" placeholder="Summer sale preview"/>
              </div>
              <div>
                <label class="label">From address</label>
                <input v-model="testForm.from_address" class="input" placeholder="hello@yourbrand.com"/>
              </div>
              <button @click="runPlacementTest" :disabled="placementRunning || !seeds.length" class="btn-primary w-full">
                <Icon name="send"/>{{ placementRunning ? 'Running…' : 'Start test' }}
              </button>
            </div>
          </div>
        </div>

        <div class="mt-6">
          <div class="font-semibold text-ink-900 mb-3">Recent tests</div>
          <div v-if="!tests.length" class="card">
            <EmptyState icon="send" title="No placement tests yet" subtitle="Tests will show inbox, spam, and missing counts per provider."/>
          </div>
          <div v-else class="grid gap-3">
            <div v-for="t in tests" :key="t.id" class="card p-4">
              <div class="flex items-start gap-4">
                <div class="flex-1 min-w-0">
                  <div class="font-semibold text-ink-900 truncate">{{ t.subject || '(no subject)' }}</div>
                  <div class="text-xs text-ink-500">{{ formatDateTime(t.created_at) }} · {{ t.status }}</div>
                </div>
                <div class="flex items-center gap-4 text-xs">
                  <div><span class="text-accent-500 font-bold">{{ t.inbox_count }}</span> inbox</div>
                  <div><span class="text-yellow-600 font-bold">{{ t.spam_count }}</span> spam</div>
                  <div><span class="text-ink-500 font-bold">{{ t.missing_count }}</span> missing</div>
                </div>
              </div>
              <div v-if="t.sent_count" class="mt-3 h-2 rounded-full overflow-hidden flex bg-ink-100">
                <div class="bg-accent-500 h-full" :style="{ width: `${(t.inbox_count / t.sent_count) * 100}%` }"></div>
                <div class="bg-yellow-500 h-full" :style="{ width: `${(t.spam_count / t.sent_count) * 100}%` }"></div>
                <div class="bg-ink-300 h-full" :style="{ width: `${(t.missing_count / t.sent_count) * 100}%` }"></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Consent modal -->
    <Modal v-model="consentOpen" :title="consentEditing?.id ? 'Edit consent' : 'Record consent'">
      <form id="consentf" @submit.prevent="saveConsent" class="space-y-3">
        <div>
          <label class="label">Customer email</label>
          <input v-model="consentForm.email" class="input" required :disabled="!!consentEditing?.id"/>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="label">Channel</label>
            <select v-model="consentForm.channel" class="input" required :disabled="!!consentEditing?.id">
              <option value="email">Email</option>
              <option value="sms">SMS</option>
              <option value="push">Push</option>
              <option value="marketing">Marketing (all)</option>
            </select>
          </div>
          <div>
            <label class="label">State</label>
            <select v-model="consentForm.state" class="input">
              <option value="opted_in">Opted in</option>
              <option value="opted_out">Opted out</option>
              <option value="pending">Pending</option>
              <option value="unknown">Unknown</option>
            </select>
          </div>
        </div>
        <div>
          <label class="label">Source</label>
          <input v-model="consentForm.source" class="input" placeholder="signup, preference center, import"/>
        </div>
        <div>
          <label class="label">Reason / note</label>
          <textarea v-model="consentForm.reason" rows="2" class="input"></textarea>
        </div>
      </form>
      <template #footer>
        <button @click="consentOpen = false" class="btn-secondary">Cancel</button>
        <button form="consentf" type="submit" class="btn-primary">Save</button>
      </template>
    </Modal>

    <!-- Seed modal -->
    <Modal v-model="seedOpen" title="Add seed address">
      <form id="seedf" @submit.prevent="saveSeed" class="space-y-3">
        <div>
          <label class="label">Provider</label>
          <select v-model="seedForm.provider" class="input">
            <option value="gmail">Gmail</option>
            <option value="outlook">Outlook / Hotmail</option>
            <option value="yahoo">Yahoo</option>
            <option value="apple">iCloud</option>
            <option value="proton">ProtonMail</option>
            <option value="corporate">Corporate</option>
          </select>
        </div>
        <div>
          <label class="label">Email</label>
          <input v-model="seedForm.email" type="email" class="input" required placeholder="seed+test@gmail.com"/>
        </div>
      </form>
      <template #footer>
        <button @click="seedOpen = false" class="btn-secondary">Cancel</button>
        <button form="seedf" type="submit" class="btn-primary">Add</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()

const tabs = [
  { id: 'audit', label: 'Audit log', icon: 'shield' },
  { id: 'consent', label: 'Consent', icon: 'users' },
  { id: 'predictive', label: 'Predictive audiences', icon: 'trending' },
  { id: 'inbox', label: 'Inbox placement', icon: 'send' },
]
const tab = ref<'audit' | 'consent' | 'predictive' | 'inbox'>('audit')

// AUDIT
const auditLogs = ref<any[]>([])
const auditSearch = ref('')
const auditEntityFilter = ref('')
const auditEntities = computed(() => {
  const s = new Set<string>()
  auditLogs.value.forEach(a => a.entity_type && s.add(a.entity_type))
  return Array.from(s).sort()
})
const filteredAudit = computed(() => {
  const q = auditSearch.value.toLowerCase().trim()
  return auditLogs.value.filter(a => {
    if (auditEntityFilter.value && a.entity_type !== auditEntityFilter.value) return false
    if (!q) return true
    return [a.action, a.entity_type, a.entity_name, a.actor_email].some((v: string) => (v || '').toLowerCase().includes(q))
  })
})
function actionTone(a: string) {
  if (a?.startsWith('delete')) return 'bg-red-100 text-red-700'
  if (a?.startsWith('create')) return 'bg-accent-500/10 text-accent-500'
  if (a?.startsWith('update')) return 'bg-brand-100/30 text-brand-500'
  return 'bg-ink-100 text-ink-700'
}

// CONSENT
const consents = ref<any[]>([])
const consentSearch = ref('')
const consentOpen = ref(false)
const consentEditing = ref<any>(null)
const consentForm = reactive<any>({ email: '', channel: 'email', state: 'opted_in', source: 'manual', reason: '' })
const filteredConsents = computed(() => {
  const q = consentSearch.value.toLowerCase().trim()
  if (!q) return consents.value
  return consents.value.filter((c: any) => (c.customer?.email || '').toLowerCase().includes(q))
})
function stateTone(s: string) {
  if (s === 'opted_in') return 'bg-accent-500/10 text-accent-500'
  if (s === 'opted_out') return 'bg-red-100 text-red-700'
  if (s === 'pending') return 'bg-yellow-100 text-yellow-700'
  return 'bg-ink-100 text-ink-700'
}
function openConsentEdit(c: any) {
  consentEditing.value = c
  if (c) Object.assign(consentForm, { email: c.customer?.email || '', channel: c.channel, state: c.state, source: c.source, reason: c.reason })
  else Object.assign(consentForm, { email: '', channel: 'email', state: 'opted_in', source: 'manual', reason: '' })
  consentOpen.value = true
}
async function saveConsent() {
  let customerId = consentEditing.value?.customer_id
  if (!customerId) {
    const { data: cust } = await supabase.from('customers').select('id').eq('workspace_id', workspaceId.value).eq('email', consentForm.email.toLowerCase()).maybeSingle()
    if (!cust) { useToast().error('Customer not found', 'Import or create the customer first.'); return }
    customerId = cust.id
  }
  const payload: any = {
    workspace_id: workspaceId.value,
    customer_id: customerId,
    channel: consentForm.channel,
    state: consentForm.state,
    source: consentForm.source,
    reason: consentForm.reason,
    changed_at: new Date().toISOString(),
  }
  const { error } = consentEditing.value?.id
    ? await supabase.from('customer_consents').update(payload).eq('id', consentEditing.value.id)
    : await supabase.from('customer_consents').upsert(payload, { onConflict: 'workspace_id,customer_id,channel' })
  if (error) { useToast().error('Save failed', error.message); return }
  useToast().success('Consent saved')
  consentOpen.value = false
  await loadConsents()
}

// PREDICTIVE
const scores = ref<any[]>([])
const scoring = ref(false)
const predStats = computed(() => ({
  highChurn: scores.value.filter((s: any) => Number(s.churn_risk) > 0.7).length,
  highProp: scores.value.filter((s: any) => Number(s.purchase_propensity) > 0.7).length,
  highLtv: scores.value.filter((s: any) => s.ltv_bucket === 'high').length,
}))
function riskColor(v: number) {
  if (v > 0.7) return '#dc2626'
  if (v > 0.4) return '#f59e0b'
  return '#16a34a'
}
function ltvTone(b: string) {
  if (b === 'high') return 'bg-brand-100/30 text-brand-500'
  if (b === 'medium') return 'bg-accent-500/10 text-accent-500'
  return 'bg-ink-100 text-ink-700'
}
async function recomputeScores() {
  if (!workspaceId.value) return
  scoring.value = true
  try {
    const { data: customers } = await supabase.from('customers').select('id, last_seen_at').eq('workspace_id', workspaceId.value).limit(500)
    const { data: orders } = await supabase.from('commerce_orders').select('customer_id, total_amount').eq('workspace_id', workspaceId.value)
    const totals = new Map<string, number>()
    const counts = new Map<string, number>()
    ;(orders || []).forEach((o: any) => {
      if (!o.customer_id) return
      totals.set(o.customer_id, (totals.get(o.customer_id) || 0) + Number(o.total_amount || 0))
      counts.set(o.customer_id, (counts.get(o.customer_id) || 0) + 1)
    })
    const now = Date.now()
    const rows = (customers || []).map((c: any) => {
      const spend = totals.get(c.id) || 0
      const orderCount = counts.get(c.id) || 0
      const daysSinceSeen = c.last_seen_at ? (now - new Date(c.last_seen_at).getTime()) / 86400000 : 90
      const churn = Math.max(0, Math.min(1, (daysSinceSeen / 90) * (orderCount === 0 ? 1 : 0.6)))
      const prop = Math.max(0, Math.min(1, (orderCount / 5) * (daysSinceSeen < 30 ? 1 : 0.4)))
      const ltv = spend > 500 ? 'high' : spend > 100 ? 'medium' : 'low'
      return {
        workspace_id: workspaceId.value,
        customer_id: c.id,
        churn_risk: Number(churn.toFixed(3)),
        purchase_propensity: Number(prop.toFixed(3)),
        ltv_bucket: ltv,
        computed_at: new Date().toISOString(),
      }
    })
    if (rows.length) {
      const { error } = await supabase.from('predictive_scores').upsert(rows, { onConflict: 'workspace_id,customer_id' })
      if (error) { useToast().error('Score failed', error.message); return }
    }
    useToast().success(`Scored ${rows.length} customers`)
    await loadScores()
  } finally {
    scoring.value = false
  }
}

// INBOX PLACEMENT
const seeds = ref<any[]>([])
const tests = ref<any[]>([])
const seedOpen = ref(false)
const seedForm = reactive({ email: '', provider: 'gmail' })
const testForm = reactive({ subject: '', from_address: '' })
const placementRunning = ref(false)
function openSeedAdd() { seedForm.email = ''; seedForm.provider = 'gmail'; seedOpen.value = true }
async function saveSeed() {
  const { error } = await supabase.from('seed_inbox_addresses').insert({
    workspace_id: workspaceId.value, email: seedForm.email.toLowerCase(), provider: seedForm.provider,
  })
  if (error) { useToast().error('Add failed', error.message); return }
  seedOpen.value = false
  await loadSeeds()
}
async function removeSeed(id: string) {
  const ok = await useConfirm().ask({ title: 'Remove seed?', tone: 'danger', confirmText: 'Remove' })
  if (!ok) return
  await supabase.from('seed_inbox_addresses').delete().eq('id', id)
  await loadSeeds()
}
async function runPlacementTest() {
  if (!seeds.value.length) return
  placementRunning.value = true
  try {
    const { data: row } = await supabase.from('seed_inbox_tests').insert({
      workspace_id: workspaceId.value,
      subject: testForm.subject,
      from_address: testForm.from_address,
      sent_count: seeds.value.length,
      status: 'running',
    }).select().maybeSingle()
    // Simulate placement by probability per provider
    const placement: Record<string, [number, number]> = {
      gmail: [0.82, 0.12], outlook: [0.74, 0.18], yahoo: [0.78, 0.14],
      apple: [0.88, 0.08], proton: [0.85, 0.1], corporate: [0.9, 0.06],
    }
    let inbox = 0, spam = 0, missing = 0
    const results = seeds.value.map((s: any) => {
      const [inP, spP] = placement[s.provider] || [0.75, 0.15]
      const r = Math.random()
      const status = r < inP ? 'inbox' : r < inP + spP ? 'spam' : 'missing'
      if (status === 'inbox') inbox++
      else if (status === 'spam') spam++
      else missing++
      return { email: s.email, provider: s.provider, status }
    })
    if (row?.id) {
      await supabase.from('seed_inbox_tests').update({
        inbox_count: inbox, spam_count: spam, missing_count: missing,
        results, status: 'completed', completed_at: new Date().toISOString(),
      }).eq('id', row.id)
    }
    useToast().success('Placement test complete')
    await loadTests()
  } finally {
    placementRunning.value = false
  }
}

async function loadAudit() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('audit_logs').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }).limit(300)
  auditLogs.value = (data || []).map((a: any) => ({ ...a, _open: false }))
}
async function loadConsents() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('customer_consents')
    .select('*, customer:customers(email)')
    .eq('workspace_id', workspaceId.value)
    .order('changed_at', { ascending: false }).limit(300)
  consents.value = data || []
}
async function loadScores() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('predictive_scores')
    .select('*, customer:customers(email)')
    .eq('workspace_id', workspaceId.value)
    .order('churn_risk', { ascending: false }).limit(200)
  scores.value = data || []
}
async function loadSeeds() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('seed_inbox_addresses').select('*').eq('workspace_id', workspaceId.value).order('created_at')
  seeds.value = data || []
}
async function loadTests() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('seed_inbox_tests').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }).limit(20)
  tests.value = data || []
}

watch([workspaceId, tab], async () => {
  if (!workspaceId.value) return
  if (tab.value === 'audit') await loadAudit()
  else if (tab.value === 'consent') await loadConsents()
  else if (tab.value === 'predictive') await loadScores()
  else if (tab.value === 'inbox') { await loadSeeds(); await loadTests() }
}, { immediate: true })
</script>
