<template>
  <div>
    <PageHeader title="Funnels" subtitle="Visualize conversion from one event to the next.">
      <template #actions>
        <button @click="edit(null)" class="btn-primary"><Icon name="plus"/>New funnel</button>
      </template>
    </PageHeader>

    <div class="p-8 space-y-6">
      <div v-if="!funnels.length" class="card">
        <EmptyState icon="filter" title="No funnels yet" subtitle="Create a funnel to track drop-off between steps.">
          <button @click="edit(null)" class="btn-primary"><Icon name="plus"/>New funnel</button>
        </EmptyState>
      </div>
      <div v-for="f in funnels" :key="f.id" class="card p-6">
        <div class="flex items-center justify-between mb-5">
          <div>
            <div class="font-semibold text-ink-900 text-lg">{{ f.name }}</div>
            <div class="text-xs text-ink-500">{{ f.description || '—' }} · {{ f.window_days }}-day window</div>
          </div>
          <div class="flex gap-2">
            <button @click="compute(f)" class="btn-secondary"><Icon name="trending"/>Recompute</button>
            <button @click="edit(f)" class="btn-ghost"><Icon name="edit"/></button>
          </div>
        </div>

        <div class="space-y-2">
          <div v-for="(s, i) in f.steps" :key="i" class="relative">
            <div class="flex items-center gap-3">
              <div class="w-8 h-8 rounded-full bg-brand-500 text-white text-xs font-bold flex items-center justify-center shrink-0">{{ i + 1 }}</div>
              <div class="flex-1">
                <div class="flex items-center justify-between mb-1">
                  <div class="font-medium text-ink-900">{{ s.event }}</div>
                  <div class="text-sm">
                    <span class="font-bold text-ink-900">{{ (results[f.id]?.[i] || 0).toLocaleString() }}</span>
                    <span v-if="i > 0 && results[f.id]?.[0]" class="text-ink-500 ml-2 text-xs">{{ pct(results[f.id][i], results[f.id][0]) }}%</span>
                  </div>
                </div>
                <div class="h-8 bg-ink-100 rounded-lg overflow-hidden">
                  <div class="h-full bg-gradient-to-r from-brand-500 to-brand-700 transition-all duration-500" :style="{ width: `${barWidth(results[f.id], i)}%` }"></div>
                </div>
                <div v-if="i > 0" class="text-xs text-ink-500 mt-1">
                  Drop-off: {{ ((1 - ((results[f.id]?.[i] || 0) / (results[f.id]?.[i - 1] || 1))) * 100).toFixed(1) }}%
                </div>
              </div>
            </div>
          </div>
        </div>

        <div v-if="results[f.id]" class="mt-5 pt-4 border-t border-ink-100 grid grid-cols-3 gap-4">
          <div><div class="text-xs text-ink-500">Entered</div><div class="text-2xl font-bold">{{ (results[f.id][0] || 0).toLocaleString() }}</div></div>
          <div><div class="text-xs text-ink-500">Completed</div><div class="text-2xl font-bold text-accent-500">{{ (results[f.id][f.steps.length - 1] || 0).toLocaleString() }}</div></div>
          <div><div class="text-xs text-ink-500">Overall conversion</div><div class="text-2xl font-bold text-brand-500">{{ pct(results[f.id][f.steps.length - 1] || 0, results[f.id][0] || 1) }}%</div></div>
        </div>
      </div>
    </div>

    <Modal v-model="open" :title="editing?.id ? 'Edit funnel' : 'New funnel'" size="lg">
      <form id="ff" @submit.prevent="save" class="space-y-3">
        <div class="grid grid-cols-2 gap-3">
          <div class="col-span-2"><label class="label">Name *</label><input v-model="form.name" class="input" required/></div>
          <div class="col-span-2"><label class="label">Description</label><input v-model="form.description" class="input"/></div>
          <div><label class="label">Conversion window</label>
            <select v-model.number="form.window_days" class="input">
              <option :value="1">1 day</option><option :value="7">7 days</option><option :value="14">14 days</option><option :value="30">30 days</option>
            </select>
          </div>
        </div>
        <div>
          <div class="flex items-center justify-between mb-2"><label class="label !mb-0">Steps</label>
            <button type="button" @click="form.steps.push({ event: '' })" class="btn-ghost text-xs"><Icon name="plus"/>Add step</button>
          </div>
          <div class="space-y-2">
            <div v-for="(s, i) in form.steps" :key="i" class="flex items-center gap-2">
              <div class="w-7 h-7 rounded-full bg-brand-500 text-white text-xs flex items-center justify-center">{{ i + 1 }}</div>
              <select v-model="s.event" class="input flex-1">
                <option value="">— pick event —</option>
                <option v-for="d in eventDefs" :key="d.id" :value="d.name">{{ d.name }}</option>
              </select>
              <button type="button" @click="form.steps.splice(i, 1)" class="text-ink-500 hover:text-red-600"><Icon name="x"/></button>
            </div>
          </div>
        </div>
      </form>
      <template #footer>
        <button v-if="editing?.id" @click="remove" class="btn-ghost text-red-600"><Icon name="trash"/></button>
        <button @click="open = false" class="btn-secondary">Cancel</button>
        <button form="ff" type="submit" class="btn-primary">Save</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const funnels = ref<any[]>([])
const eventDefs = ref<any[]>([])
const results = ref<Record<string, number[]>>({})
const open = ref(false)
const editing = ref<any>(null)
const form = reactive({ name: '', description: '', window_days: 7, steps: [{ event: '' }] as any[] })

const pct = (a: number, b: number) => b ? ((a / b) * 100).toFixed(1) : '0.0'
const barWidth = (r: number[] | undefined, i: number) => {
  if (!r || !r[0]) return 0
  return Math.max(2, (r[i] / r[0]) * 100)
}

async function load() {
  if (!workspaceId.value) return
  const [f, e] = await Promise.all([
    supabase.from('funnels').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('event_definitions').select('id,name').eq('workspace_id', workspaceId.value),
  ])
  funnels.value = f.data || []; eventDefs.value = e.data || []
  for (const fn of funnels.value) await compute(fn)
}

async function compute(f: any) {
  const wid = workspaceId.value
  const since = new Date(Date.now() - f.window_days * 24 * 3600 * 1000).toISOString()
  const counts: number[] = []
  let prevSet: Set<string> | null = null
  for (const step of f.steps) {
    if (!step.event) { counts.push(0); continue }
    const { data } = await supabase.from('events').select('customer_id').eq('workspace_id', wid).eq('name', step.event).gte('occurred_at', since)
    const ids = new Set<string>((data || []).map((r: any) => r.customer_id).filter(Boolean))
    const intersected = prevSet ? new Set([...ids].filter(x => prevSet!.has(x))) : ids
    counts.push(intersected.size)
    prevSet = intersected
  }
  results.value = { ...results.value, [f.id]: counts }
}

function edit(f: any) {
  editing.value = f
  if (f) Object.assign(form, { name: f.name, description: f.description, window_days: f.window_days, steps: JSON.parse(JSON.stringify(f.steps)) })
  else Object.assign(form, { name: '', description: '', window_days: 7, steps: [{ event: '' }] })
  open.value = true
}
async function save() {
  const payload = { ...form, workspace_id: workspaceId.value }
  if (editing.value?.id) await supabase.from('funnels').update(payload).eq('id', editing.value.id)
  else await supabase.from('funnels').insert(payload)
  open.value = false; await load()
}
async function remove() {
  const ok = await useConfirm().ask({ title: 'Delete this funnel?', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await supabase.from('funnels').delete().eq('id', editing.value.id)
  useToast().success('Funnel deleted')
  open.value = false; await load()
}
watch(workspaceId, load, { immediate: true })
</script>
