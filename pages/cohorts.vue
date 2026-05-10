<template>
  <div>
    <PageHeader title="Cohorts" subtitle="Retention analysis by signup week or month.">
      <template #actions>
        <button @click="edit(null)" class="btn-primary"><Icon name="plus"/>New cohort</button>
      </template>
    </PageHeader>

    <div class="p-8 space-y-6">
      <div v-if="!cohorts.length" class="card">
        <EmptyState icon="layers" title="No cohorts yet" subtitle="Create a cohort to analyze retention over time.">
          <button @click="edit(null)" class="btn-primary"><Icon name="plus"/>New cohort</button>
        </EmptyState>
      </div>

      <div v-for="c in cohorts" :key="c.id" class="card p-6">
        <div class="flex items-center justify-between mb-4">
          <div>
            <div class="font-semibold text-ink-900 text-lg">{{ c.name }}</div>
            <div class="text-xs text-ink-500">Retention by {{ c.period }}, measured by <span class="font-mono">{{ c.retention_event }}</span></div>
          </div>
          <div class="flex gap-2">
            <button @click="compute(c)" class="btn-secondary"><Icon name="trending"/>Recompute</button>
            <button @click="edit(c)" class="btn-ghost"><Icon name="edit"/></button>
          </div>
        </div>

        <div v-if="matrices[c.id]" class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead>
              <tr>
                <th class="table-th">Cohort</th>
                <th class="table-th text-right">Users</th>
                <th v-for="i in periodCount" :key="i" class="table-th text-center">{{ c.period[0].toUpperCase() }}{{ i - 1 }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, i) in matrices[c.id]" :key="i">
                <td class="table-td whitespace-nowrap font-medium">{{ row.label }}</td>
                <td class="table-td text-right">{{ row.size }}</td>
                <td v-for="(v, j) in row.pcts" :key="j" class="table-td text-center"
                  :style="{ background: `rgba(48, 135, 185, ${v / 100 * 0.6})`, color: v > 50 ? 'white' : '#0B1E27' }">
                  {{ v.toFixed(0) }}%
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-else class="text-sm text-ink-500 text-center py-8">Click Recompute to generate the heatmap.</div>
      </div>
    </div>

    <Modal v-model="open" :title="editing?.id ? 'Edit cohort' : 'New cohort'">
      <form id="cf" @submit.prevent="save" class="space-y-3">
        <div><label class="label">Name *</label><input v-model="form.name" class="input" required/></div>
        <div><label class="label">Description</label><input v-model="form.description" class="input"/></div>
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">Cohort by</label>
            <select v-model="form.cohort_type" class="input"><option value="signup">Signup date</option><option value="first_event">First event</option></select>
          </div>
          <div><label class="label">Period</label>
            <select v-model="form.period" class="input"><option value="day">Day</option><option value="week">Week</option><option value="month">Month</option></select>
          </div>
        </div>
        <div><label class="label">Retention event</label>
          <select v-model="form.retention_event" class="input">
            <option v-for="d in eventDefs" :key="d.id" :value="d.name">{{ d.name }}</option>
          </select>
        </div>
      </form>
      <template #footer>
        <button v-if="editing?.id" @click="remove" class="btn-ghost text-red-600"><Icon name="trash"/></button>
        <button @click="open = false" class="btn-secondary">Cancel</button>
        <button form="cf" type="submit" class="btn-primary">Save</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const cohorts = ref<any[]>([])
const eventDefs = ref<any[]>([])
const matrices = ref<Record<string, any[]>>({})
const open = ref(false)
const editing = ref<any>(null)
const form = reactive({ name: '', description: '', cohort_type: 'signup', retention_event: 'app_opened', period: 'week' })
const periodCount = 6

async function load() {
  if (!workspaceId.value) return
  const [c, e] = await Promise.all([
    supabase.from('cohorts').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('event_definitions').select('id,name').eq('workspace_id', workspaceId.value),
  ])
  cohorts.value = c.data || []; eventDefs.value = e.data || []
  for (const co of cohorts.value) await compute(co)
}

function bucketStart(d: Date, period: string): Date {
  const x = new Date(d)
  x.setHours(0, 0, 0, 0)
  if (period === 'week') { const day = x.getDay(); x.setDate(x.getDate() - day) }
  if (period === 'month') { x.setDate(1) }
  return x
}
function addPeriods(d: Date, n: number, period: string): Date {
  const x = new Date(d)
  if (period === 'day') x.setDate(x.getDate() + n)
  if (period === 'week') x.setDate(x.getDate() + n * 7)
  if (period === 'month') x.setMonth(x.getMonth() + n)
  return x
}
function labelFor(d: Date, period: string) {
  if (period === 'month') return d.toLocaleDateString('en-US', { month: 'short', year: 'numeric' })
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

async function compute(c: any) {
  const wid = workspaceId.value
  const since = addPeriods(new Date(), -(periodCount - 1), c.period)
  const { data: customers } = await supabase.from('customers').select('id, created_at').eq('workspace_id', wid).gte('created_at', since.toISOString())
  const { data: events } = await supabase.from('events').select('customer_id, occurred_at').eq('workspace_id', wid).eq('name', c.retention_event).gte('occurred_at', since.toISOString())

  const bucketMap: Record<string, { label: string; date: Date; ids: Set<string> }> = {}
  for (let i = 0; i < periodCount; i++) {
    const d = addPeriods(bucketStart(since, c.period), i, c.period)
    bucketMap[d.toISOString()] = { label: labelFor(d, c.period), date: d, ids: new Set() }
  }
  for (const cust of customers || []) {
    const b = bucketStart(new Date(cust.created_at), c.period).toISOString()
    if (bucketMap[b]) bucketMap[b].ids.add(cust.id)
  }
  const eventByUser: Record<string, Date[]> = {}
  for (const ev of events || []) {
    if (!ev.customer_id) continue
    eventByUser[ev.customer_id] = eventByUser[ev.customer_id] || []
    eventByUser[ev.customer_id].push(new Date(ev.occurred_at))
  }

  const rows: any[] = []
  const keys = Object.keys(bucketMap).sort()
  for (const k of keys) {
    const b = bucketMap[k]
    const size = b.ids.size
    const pcts: number[] = []
    for (let i = 0; i < periodCount; i++) {
      const start = addPeriods(b.date, i, c.period)
      const end = addPeriods(start, 1, c.period)
      let retained = 0
      for (const uid of b.ids) {
        const evs = eventByUser[uid] || []
        if (evs.some(e => e >= start && e < end)) retained++
      }
      pcts.push(size ? (retained / size) * 100 : 0)
    }
    rows.push({ label: b.label, size, pcts })
  }
  matrices.value = { ...matrices.value, [c.id]: rows }
}

function edit(c: any) {
  editing.value = c
  if (c) Object.assign(form, { name: c.name, description: c.description, cohort_type: c.cohort_type, retention_event: c.retention_event, period: c.period })
  else Object.assign(form, { name: '', description: '', cohort_type: 'signup', retention_event: eventDefs.value[0]?.name || 'app_opened', period: 'week' })
  open.value = true
}
async function save() {
  const payload = { ...form, workspace_id: workspaceId.value }
  if (editing.value?.id) await supabase.from('cohorts').update(payload).eq('id', editing.value.id)
  else await supabase.from('cohorts').insert(payload)
  open.value = false; await load()
}
async function remove() {
  const ok = await useConfirm().ask({ title: 'Delete this cohort?', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await supabase.from('cohorts').delete().eq('id', editing.value.id)
  useToast().success('Cohort deleted')
  open.value = false; await load()
}
watch(workspaceId, load, { immediate: true })
</script>
