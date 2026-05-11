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

      <!-- IP POOLS -->
      <div v-if="tab === 'ippools'">
        <div class="card p-5 mb-4 flex items-center justify-between">
          <div>
            <div class="font-semibold text-ink-900">Sending IP pools</div>
            <div class="text-xs text-ink-500 mt-1">Segment your traffic across shared, dedicated, transactional, and bulk pools. Warm up new IPs in 6 stages.</div>
          </div>
          <button @click="openPool()" class="btn-primary"><Icon name="plus"/>New pool</button>
        </div>
        <div v-if="!pools.length" class="card">
          <EmptyState icon="layers" title="No IP pools yet" subtitle="Create pools to isolate transactional and bulk traffic for better reputation."/>
        </div>
        <div v-else class="grid md:grid-cols-2 gap-4">
          <div v-for="p in pools" :key="p.id" class="card p-5">
            <div class="flex items-center justify-between mb-2">
              <div>
                <div class="font-semibold text-ink-900">{{ p.name }}</div>
                <div class="text-xs text-ink-500 capitalize">{{ p.pool_type }} pool · cap {{ p.daily_cap.toLocaleString() }}/day</div>
              </div>
              <span v-if="p.is_default" class="chip bg-accent-500/15 text-accent-500">Default</span>
            </div>
            <div class="mt-3">
              <div class="text-[11px] font-semibold text-ink-500 uppercase tracking-wider mb-1">Warmup stage</div>
              <div class="flex gap-1">
                <div v-for="i in 6" :key="i" class="flex-1 h-2 rounded-full" :class="i <= p.warmup_stage ? 'bg-brand-500' : 'bg-ink-100'"></div>
              </div>
              <div class="text-[11px] text-ink-500 mt-1">Stage {{ p.warmup_stage }} / 6</div>
            </div>
            <div class="mt-3 text-xs">
              <div class="text-[11px] font-semibold text-ink-500 uppercase tracking-wider mb-1">IPs</div>
              <div class="font-mono text-[11px] text-ink-700 break-all">{{ (p.ip_addresses || []).join(', ') || '—' }}</div>
            </div>
            <div v-if="p.notes" class="mt-2 text-xs text-ink-500">{{ p.notes }}</div>
            <div class="mt-4 flex justify-end gap-2">
              <button @click="openPool(p)" class="btn-ghost text-xs"><Icon name="edit" class="w-4 h-4"/>Edit</button>
              <button @click="deletePool(p)" class="btn-ghost text-xs text-red-600"><Icon name="trash" class="w-4 h-4"/>Delete</button>
            </div>
          </div>
        </div>
      </div>

      <!-- WEBHOOK DLQ -->
      <div v-if="tab === 'dlq'">
        <div class="card p-5 mb-4 flex items-center justify-between">
          <div>
            <div class="font-semibold text-ink-900">Failed webhook deliveries</div>
            <div class="text-xs text-ink-500 mt-1">Each row exhausted its retries. Resolve after investigating, or replay once the endpoint is healthy.</div>
          </div>
          <div class="text-xs text-ink-500">{{ unresolvedDlq }} unresolved</div>
        </div>
        <div v-if="!dlq.length" class="card">
          <EmptyState icon="check" title="No failed webhooks" subtitle="Permanent delivery failures will land here."/>
        </div>
        <div v-else class="card overflow-hidden">
          <table class="w-full">
            <thead><tr>
              <th class="table-th">Event</th>
              <th class="table-th">Status</th>
              <th class="table-th">Attempts</th>
              <th class="table-th">Failed</th>
              <th class="table-th">Last error</th>
              <th class="table-th"></th>
            </tr></thead>
            <tbody>
              <tr v-for="d in dlq" :key="d.id" class="hover:bg-ink-50">
                <td class="table-td font-mono text-xs">{{ d.event_type || '—' }}</td>
                <td class="table-td"><span class="chip" :class="d.last_status >= 500 ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-700'">{{ d.last_status || 'net error' }}</span></td>
                <td class="table-td text-xs">{{ d.attempts }}</td>
                <td class="table-td text-xs text-ink-500 whitespace-nowrap">{{ formatDateTime(d.failed_at) }}</td>
                <td class="table-td text-xs text-ink-500 truncate max-w-[260px]" :title="d.last_error">{{ d.last_error }}</td>
                <td class="table-td text-right whitespace-nowrap">
                  <span v-if="d.resolved_at" class="chip bg-accent-500/15 text-accent-500">Resolved</span>
                  <template v-else>
                    <button @click="replayDlq(d)" class="btn-ghost text-xs"><Icon name="refresh" class="w-4 h-4"/>Replay</button>
                    <button @click="resolveDlq(d)" class="btn-ghost text-xs"><Icon name="check" class="w-4 h-4"/>Resolve</button>
                  </template>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- IP pool modal -->
    <Modal v-model="poolOpen" :title="poolEditing?.id ? 'Edit IP pool' : 'New IP pool'">
      <form id="poolf" @submit.prevent="savePool" class="space-y-3">
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="label">Name</label>
            <input v-model="poolForm.name" class="input" required placeholder="Transactional"/>
          </div>
          <div>
            <label class="label">Pool type</label>
            <select v-model="poolForm.pool_type" class="input">
              <option value="shared">Shared</option>
              <option value="dedicated">Dedicated</option>
              <option value="transactional">Transactional</option>
              <option value="bulk">Bulk</option>
            </select>
          </div>
          <div>
            <label class="label">Warmup stage (1-6)</label>
            <input v-model.number="poolForm.warmup_stage" type="number" min="1" max="6" class="input"/>
          </div>
          <div>
            <label class="label">Daily cap</label>
            <input v-model.number="poolForm.daily_cap" type="number" min="100" class="input"/>
          </div>
        </div>
        <div>
          <label class="label">IP addresses (one per line)</label>
          <textarea v-model="poolIpsText" rows="3" class="input font-mono text-xs" placeholder="192.0.2.10&#10;192.0.2.11"></textarea>
        </div>
        <div>
          <label class="label">Notes</label>
          <input v-model="poolForm.notes" class="input" placeholder="e.g. ramped to 5k/day on 2026-04-01"/>
        </div>
        <label class="flex items-center gap-2 text-sm">
          <input type="checkbox" v-model="poolForm.is_default" class="w-4 h-4 accent-brand-500"/>
          Use as default pool
        </label>
      </form>
      <template #footer>
        <button @click="poolOpen = false" class="btn-secondary">Cancel</button>
        <button form="poolf" type="submit" class="btn-primary">Save</button>
      </template>
    </Modal>

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
  { id: 'ippools', label: 'IP pools', icon: 'layers' },
  { id: 'dlq', label: 'Webhook DLQ', icon: 'alert' },
]
const tab = ref<'audit' | 'consent' | 'predictive' | 'inbox' | 'ippools' | 'dlq'>('audit')

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

// IP POOLS
const pools = ref<any[]>([])
const poolOpen = ref(false)
const poolEditing = ref<any>(null)
const poolForm = reactive({ name: '', pool_type: 'shared', warmup_stage: 1, daily_cap: 10000, notes: '', is_default: false })
const poolIpsText = ref('')
function openPool(p?: any) {
  poolEditing.value = p || null
  if (p) {
    poolForm.name = p.name
    poolForm.pool_type = p.pool_type
    poolForm.warmup_stage = p.warmup_stage
    poolForm.daily_cap = p.daily_cap
    poolForm.notes = p.notes || ''
    poolForm.is_default = !!p.is_default
    poolIpsText.value = (p.ip_addresses || []).join('\n')
  } else {
    poolForm.name = ''
    poolForm.pool_type = 'shared'
    poolForm.warmup_stage = 1
    poolForm.daily_cap = 10000
    poolForm.notes = ''
    poolForm.is_default = false
    poolIpsText.value = ''
  }
  poolOpen.value = true
}
async function savePool() {
  const ips = poolIpsText.value.split(/[\s,]+/).map(s => s.trim()).filter(Boolean)
  const payload: any = {
    workspace_id: workspaceId.value,
    name: poolForm.name,
    pool_type: poolForm.pool_type,
    warmup_stage: Math.max(1, Math.min(6, poolForm.warmup_stage || 1)),
    daily_cap: Math.max(100, poolForm.daily_cap || 10000),
    ip_addresses: ips,
    notes: poolForm.notes,
    is_default: !!poolForm.is_default,
    updated_at: new Date().toISOString(),
  }
  if (poolEditing.value?.id) {
    if (payload.is_default) await supabase.from('ip_pools').update({ is_default: false }).eq('workspace_id', workspaceId.value).neq('id', poolEditing.value.id)
    const { error } = await supabase.from('ip_pools').update(payload).eq('id', poolEditing.value.id)
    if (error) { useToast().error('Save failed', error.message); return }
  } else {
    if (payload.is_default) await supabase.from('ip_pools').update({ is_default: false }).eq('workspace_id', workspaceId.value)
    const { error } = await supabase.from('ip_pools').insert(payload)
    if (error) { useToast().error('Save failed', error.message); return }
  }
  poolOpen.value = false
  useToast().success('Pool saved')
  await loadPools()
}
async function deletePool(p: any) {
  const ok = await useConfirm().ask({ title: `Delete ${p.name}?`, tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await supabase.from('ip_pools').delete().eq('id', p.id)
  await loadPools()
}
async function loadPools() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('ip_pools').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false })
  pools.value = data || []
}

// WEBHOOK DLQ
const dlq = ref<any[]>([])
const unresolvedDlq = computed(() => dlq.value.filter(d => !d.resolved_at).length)
async function loadDlq() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('webhook_dlq').select('*').eq('workspace_id', workspaceId.value).order('failed_at', { ascending: false }).limit(100)
  dlq.value = data || []
}
async function replayDlq(d: any) {
  const cfg = useRuntimeConfig()
  const { data: { session } } = await supabase.auth.getSession()
  const token = session?.access_token || cfg.public.supabaseAnonKey
  const res = await fetch(`${cfg.public.supabaseUrl}/functions/v1/webhook-dispatch`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
    body: JSON.stringify({ workspace_id: d.workspace_id, event_type: d.event_type, payload: d.payload, destination_id: d.destination_id }),
  }).then(r => r.json()).catch(e => ({ ok: false, error: String(e) }))
  if (res?.delivered || res?.ok) {
    await supabase.from('webhook_dlq').update({ resolved_at: new Date().toISOString() }).eq('id', d.id)
    useToast().success('Replayed')
  } else {
    useToast().error('Replay failed', res?.error || 'Still failing')
  }
  await loadDlq()
}
async function resolveDlq(d: any) {
  await supabase.from('webhook_dlq').update({ resolved_at: new Date().toISOString() }).eq('id', d.id)
  await loadDlq()
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
  else if (tab.value === 'ippools') await loadPools()
  else if (tab.value === 'dlq') await loadDlq()
}, { immediate: true })
</script>
