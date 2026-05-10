<template>
  <div>
    <PageHeader title="RFM Analysis" subtitle="Score customers by Recency, Frequency, and Monetary value.">
      <template #actions>
        <button @click="compute" :disabled="computing" class="btn-primary"><Icon name="trending"/>{{ computing ? 'Computing…' : 'Recompute' }}</button>
      </template>
    </PageHeader>

    <div class="p-8 space-y-6">
      <div class="card p-5">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="label">Monetary event</label>
            <select v-model="config.monetary_event" @change="save" class="input">
              <option v-for="d in eventDefs" :key="d.id" :value="d.name">{{ d.name }}</option>
            </select>
          </div>
          <div>
            <label class="label">Monetary property (on event)</label>
            <input v-model="config.monetary_property" @change="save" class="input font-mono"/>
          </div>
          <div>
            <label class="label">Window</label>
            <select v-model.number="config.window_days" @change="save" class="input">
              <option :value="30">30 days</option><option :value="60">60 days</option>
              <option :value="90">90 days</option><option :value="180">180 days</option><option :value="365">365 days</option>
            </select>
          </div>
        </div>
        <div v-if="config.last_computed_at" class="text-xs text-ink-500 mt-3">Last computed {{ timeAgo(config.last_computed_at) }}</div>
      </div>

      <div v-if="segmentsList.length" class="grid md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div v-for="s in segmentsList" :key="s.name" class="card p-5">
          <div class="flex items-center justify-between">
            <div class="text-xs font-semibold uppercase tracking-wider" :class="s.color">{{ s.name }}</div>
            <div class="text-xs text-ink-500">{{ s.hint }}</div>
          </div>
          <div class="text-3xl font-bold mt-2">{{ s.count }}</div>
          <div class="text-xs text-ink-500">customers</div>
          <div class="h-1.5 bg-ink-100 rounded-full mt-3">
            <div class="h-full rounded-full" :class="s.bar" :style="{ width: `${totalCustomers ? (s.count / totalCustomers) * 100 : 0}%` }"></div>
          </div>
        </div>
      </div>

      <div v-if="rfmData.length" class="card overflow-hidden">
        <div class="px-5 py-3 border-b border-ink-100 font-semibold text-ink-900">Top customers by score</div>
        <table class="w-full text-sm">
          <thead><tr>
            <th class="table-th">Customer</th><th class="table-th">R</th><th class="table-th">F</th><th class="table-th">M</th>
            <th class="table-th">Score</th><th class="table-th">Segment</th>
          </tr></thead>
          <tbody>
            <tr v-for="r in rfmData.slice(0, 25)" :key="r.customer.id" class="hover:bg-ink-50">
              <td class="table-td">
                <div class="font-medium">{{ r.customer.first_name }} {{ r.customer.last_name }}</div>
                <div class="text-xs text-ink-500">{{ r.customer.email }}</div>
              </td>
              <td class="table-td"><span class="chip bg-brand-100/40 text-brand-700">{{ r.R }}</span></td>
              <td class="table-td"><span class="chip bg-brand-100/40 text-brand-700">{{ r.F }}</span></td>
              <td class="table-td"><span class="chip bg-brand-100/40 text-brand-700">{{ r.M }}</span></td>
              <td class="table-td font-bold">{{ r.score }}</td>
              <td class="table-td"><span class="chip" :class="segmentStyle(r.segment)">{{ r.segment }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
      <div v-else-if="!computing" class="card">
        <EmptyState icon="trending" title="No RFM data yet" subtitle="Click Recompute to score your customers."/>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const config = ref<any>({ monetary_event: 'purchase_completed', monetary_property: 'value', window_days: 90 })
const eventDefs = ref<any[]>([])
const rfmData = ref<any[]>([])
const computing = ref(false)

const segmentColors: Record<string, { color: string; bar: string; hint: string }> = {
  'Champions': { color: 'text-accent-500', bar: 'bg-accent-500', hint: 'Best customers' },
  'Loyal': { color: 'text-brand-500', bar: 'bg-brand-500', hint: 'Buy often' },
  'Potential': { color: 'text-brand-700', bar: 'bg-brand-700', hint: 'Recent buyers' },
  'New': { color: 'text-ink-700', bar: 'bg-ink-700', hint: 'Just started' },
  'At Risk': { color: 'text-yellow-600', bar: 'bg-yellow-500', hint: 'Fading away' },
  'Hibernating': { color: 'text-ink-500', bar: 'bg-ink-300', hint: 'Long inactive' },
  'Lost': { color: 'text-red-600', bar: 'bg-red-500', hint: 'Gone' },
  'Cannot Lose': { color: 'text-red-700', bar: 'bg-red-600', hint: 'Big spender drifting' },
}
const segmentStyle = (s: string) => {
  const c = segmentColors[s]?.bar?.replace('bg-', '') || 'ink-100'
  return `bg-${c}/10 ${segmentColors[s]?.color || 'text-ink-700'}`
}

const totalCustomers = computed(() => rfmData.value.length)
const segmentsList = computed(() => {
  const counts: Record<string, number> = {}
  for (const r of rfmData.value) counts[r.segment] = (counts[r.segment] || 0) + 1
  return Object.keys(segmentColors).map(name => ({
    name, count: counts[name] || 0, ...segmentColors[name]
  })).filter(s => s.count > 0)
})

function classify(R: number, F: number, M: number): string {
  if (R >= 4 && F >= 4 && M >= 4) return 'Champions'
  if (R >= 3 && F >= 4) return 'Loyal'
  if (R >= 4 && F <= 2) return 'New'
  if (R >= 3 && F <= 3 && M <= 3) return 'Potential'
  if (R <= 2 && F >= 4 && M >= 4) return 'Cannot Lose'
  if (R <= 2 && F >= 3) return 'At Risk'
  if (R <= 2 && F <= 2 && M <= 2) return 'Lost'
  return 'Hibernating'
}

function quintile(sorted: number[], v: number): number {
  if (sorted.length === 0) return 1
  const rank = sorted.findIndex(x => x >= v)
  const pct = rank === -1 ? 1 : rank / sorted.length
  return Math.min(5, Math.max(1, Math.ceil(pct * 5) || 1))
}

async function load() {
  if (!workspaceId.value) return
  const [cfg, ed] = await Promise.all([
    supabase.from('rfm_configs').select('*').eq('workspace_id', workspaceId.value).order('created_at').limit(1).maybeSingle(),
    supabase.from('event_definitions').select('id,name').eq('workspace_id', workspaceId.value),
  ])
  eventDefs.value = ed.data || []
  if (cfg.data) config.value = cfg.data
  else {
    const { data } = await supabase.from('rfm_configs').insert({ workspace_id: workspaceId.value, name: 'Default RFM' }).select().maybeSingle()
    if (data) config.value = data
  }
}

async function save() {
  if (!config.value?.id) return
  await supabase.from('rfm_configs').update({
    monetary_event: config.value.monetary_event,
    monetary_property: config.value.monetary_property,
    window_days: config.value.window_days,
  }).eq('id', config.value.id)
}

async function compute() {
  computing.value = true
  const wid = workspaceId.value
  const since = new Date(Date.now() - (config.value.window_days || 90) * 24 * 3600 * 1000).toISOString()
  const { data: events } = await supabase.from('events').select('customer_id, occurred_at, properties').eq('workspace_id', wid).eq('name', config.value.monetary_event).gte('occurred_at', since)
  const { data: customers } = await supabase.from('customers').select('id, first_name, last_name, email').eq('workspace_id', wid)
  const byCust: Record<string, { recent: number; freq: number; monetary: number }> = {}
  for (const e of events || []) {
    if (!e.customer_id) continue
    const t = new Date(e.occurred_at).getTime()
    const amt = Number(e.properties?.[config.value.monetary_property] || 0)
    const x = byCust[e.customer_id] = byCust[e.customer_id] || { recent: 0, freq: 0, monetary: 0 }
    x.recent = Math.max(x.recent, t)
    x.freq += 1
    x.monetary += amt
  }
  const now = Date.now()
  const recArr = Object.values(byCust).map(v => (now - v.recent) / (24 * 3600 * 1000)).sort((a, b) => a - b)
  const freqArr = Object.values(byCust).map(v => v.freq).sort((a, b) => b - a)
  const monArr = Object.values(byCust).map(v => v.monetary).sort((a, b) => b - a)

  const scored: any[] = []
  for (const cust of customers || []) {
    const v = byCust[cust.id]
    if (!v) continue
    const daysAgo = (now - v.recent) / (24 * 3600 * 1000)
    const R = 6 - quintile(recArr, daysAgo)
    const F = 6 - quintile(freqArr.slice().sort((a, b) => a - b), v.freq)
    const M = 6 - quintile(monArr.slice().sort((a, b) => a - b), v.monetary)
    const score = R * 100 + F * 10 + M
    scored.push({ customer: cust, R, F, M, score, segment: classify(R, F, M) })
  }
  scored.sort((a, b) => b.score - a.score)
  rfmData.value = scored

  if (config.value.id) {
    await supabase.from('rfm_configs').update({ last_computed_at: new Date().toISOString() }).eq('id', config.value.id)
    config.value.last_computed_at = new Date().toISOString()
  }
  computing.value = false
}

watch(workspaceId, load, { immediate: true })
</script>
