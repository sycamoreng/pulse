<template>
  <div>
    <PageHeader title="Events" subtitle="Track behaviour across your apps. Define events no-code, then send from the SDK or from here.">
      <template #actions>
        <button @click="newDef" class="btn-primary"><Icon name="plus"/>Define event</button>
      </template>
    </PageHeader>

    <div class="p-8 space-y-4">
      <TestModeStrip what="Events" message="Events shown here are sandboxed. Tracking calls from test SDK keys land in this workspace and will not affect your production analytics."/>
    </div>
    <div class="px-8 pb-8 grid lg:grid-cols-3 gap-6">
      <div class="card overflow-hidden lg:col-span-1">
        <div class="px-5 py-3 border-b border-ink-100 dark:border-[color:var(--border-subtle)] flex items-center justify-between">
          <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">Defined events</div>
          <span class="text-[10px] text-ink-500 dark:text-[color:var(--text-tertiary)]">{{ defs.length }} total</span>
        </div>
        <div class="divide-y divide-ink-100 dark:divide-[color:var(--border-subtle)]">
          <div v-for="d in defs" :key="d.id" class="p-4 hover:bg-ink-50 dark:hover:bg-[color:var(--surface-muted)] group">
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0">
                <div class="flex items-center gap-2 flex-wrap">
                  <div class="font-mono text-sm font-medium text-ink-900 dark:text-[color:var(--text-primary)] truncate">{{ d.name }}</div>
                  <span class="chip text-[10px] capitalize" :class="categoryClass(d.category)">{{ d.category || 'custom' }}</span>
                  <span v-if="d.source === 'sdk'" class="chip bg-ink-100 text-ink-700 dark:bg-[color:var(--surface-muted)] dark:text-[color:var(--text-secondary)] text-[10px]">auto-discovered</span>
                </div>
                <div v-if="d.description" class="text-xs text-ink-500 dark:text-[color:var(--text-tertiary)] mt-1 line-clamp-2">{{ d.description }}</div>
                <div v-if="(d.schema || []).length" class="flex flex-wrap gap-1 mt-2">
                  <span v-for="p in d.schema" :key="p.key" class="text-[10px] font-mono px-1.5 py-0.5 rounded bg-ink-50 dark:bg-[color:var(--surface-muted)] text-ink-700 dark:text-[color:var(--text-secondary)]">
                    {{ p.key }}<span class="text-ink-400">:{{ p.type }}</span><span v-if="p.required" class="text-red-500">*</span>
                  </span>
                </div>
              </div>
              <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition">
                <button @click="openSend(d)" class="btn-ghost !py-1 !px-2 !text-xs"><Icon name="send" class="w-3 h-3"/></button>
                <button @click="editDef(d)" class="btn-ghost !py-1 !px-2 !text-xs"><Icon name="edit" class="w-3 h-3"/></button>
                <button @click="removeDef(d)" class="btn-ghost !py-1 !px-2 !text-xs text-ink-400 hover:text-red-600"><Icon name="trash" class="w-3 h-3"/></button>
              </div>
            </div>
          </div>
          <EmptyState v-if="!defs.length" icon="activity" title="No events yet" subtitle="Define your first event to start tracking."/>
        </div>
      </div>

      <div class="card overflow-hidden lg:col-span-2">
        <div class="px-4 py-3 border-b border-ink-100 dark:border-[color:var(--border-subtle)] flex items-center justify-between">
          <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">Live event stream</div>
          <span class="chip bg-accent-500/10 text-accent-500"><span class="w-1.5 h-1.5 rounded-full bg-accent-500 animate-pulse"></span>Live</span>
        </div>
        <table class="w-full">
          <thead><tr><th class="table-th">Event</th><th class="table-th">Customer</th><th class="table-th">Properties</th><th class="table-th">When</th></tr></thead>
          <tbody>
            <tr v-for="e in events" :key="e.id">
              <td class="table-td font-mono text-xs font-medium">{{ e.name }}</td>
              <td class="table-td text-xs text-ink-500 dark:text-[color:var(--text-tertiary)]">{{ e.customer?.email || '—' }}</td>
              <td class="table-td"><code class="text-[10px] bg-ink-50 dark:bg-[color:var(--surface-muted)] px-1.5 py-0.5 rounded">{{ JSON.stringify(e.properties) }}</code></td>
              <td class="table-td text-xs text-ink-500 dark:text-[color:var(--text-tertiary)]">{{ timeAgo(e.occurred_at) }}</td>
            </tr>
          </tbody>
        </table>
        <EmptyState v-if="!events.length" icon="activity" title="No events tracked yet" subtitle="Use the dashboard to generate demo data, or connect an SDK."/>
        <Pagination v-model:page="eventsPage" v-model:pageSize="eventsPageSize" :total="eventsTotal"/>
      </div>
    </div>

    <Modal v-model="openDef" :title="form.id ? 'Edit event' : 'Define event'" size="lg">
      <form id="evf" @submit.prevent="saveDef" class="space-y-4">
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="label">Event name *</label>
            <input v-model="form.name" class="input font-mono" required pattern="[a-z][a-z0-9_]*" title="lowercase letters, numbers, underscores; must start with a letter" placeholder="order_completed"/>
            <div class="text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)] mt-1">Snake case. e.g. <span class="font-mono">checkout_started</span></div>
          </div>
          <div>
            <label class="label">Category</label>
            <select v-model="form.category" class="input">
              <option value="behavior">Behavior</option>
              <option value="conversion">Conversion</option>
              <option value="system">System</option>
              <option value="custom">Custom</option>
            </select>
          </div>
        </div>
        <div>
          <label class="label">Description</label>
          <input v-model="form.description" class="input" placeholder="Fired when a user finishes checkout"/>
        </div>

        <div class="pt-2 border-t border-ink-100 dark:border-[color:var(--border-subtle)]">
          <div class="flex items-center justify-between mb-2">
            <div>
              <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)] text-sm">Property schema</div>
              <div class="text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)]">Document the shape of each event's properties so segments, journeys, and reports can reference them without guessing.</div>
            </div>
            <button type="button" @click="addProp" class="btn-ghost !py-1 !text-xs"><Icon name="plus" class="w-3 h-3"/>Add property</button>
          </div>
          <div v-if="!form.schema.length" class="text-xs text-ink-500 dark:text-[color:var(--text-tertiary)] py-6 text-center border border-dashed border-ink-200 dark:border-[color:var(--border-subtle)] rounded-lg">No properties defined — events of this kind can still carry properties; this just documents what to expect.</div>
          <div v-for="(p, i) in form.schema" :key="i" class="grid grid-cols-[1.2fr_0.8fr_1.5fr_auto_auto] gap-2 items-center mb-2">
            <input v-model="p.key" class="input !py-1.5 !text-xs font-mono" placeholder="order_id" pattern="[a-z][a-z0-9_]*"/>
            <select v-model="p.type" class="input !py-1.5 !text-xs">
              <option value="string">string</option>
              <option value="number">number</option>
              <option value="boolean">boolean</option>
              <option value="date">date</option>
            </select>
            <input v-model="p.description" class="input !py-1.5 !text-xs" placeholder="Short description"/>
            <label class="flex items-center gap-1 text-[11px] text-ink-700 dark:text-[color:var(--text-secondary)] whitespace-nowrap"><input type="checkbox" v-model="p.required"/>Required</label>
            <button type="button" @click="form.schema.splice(i, 1)" class="btn-ghost !py-1 !text-xs"><Icon name="trash" class="w-3 h-3"/></button>
          </div>
        </div>
      </form>
      <template #footer>
        <button v-if="form.id" @click="deleteDef" class="btn-ghost text-red-600 dark:text-red-400 mr-auto">Delete</button>
        <button @click="openDef = false" class="btn-secondary">Cancel</button>
        <button form="evf" type="submit" class="btn-primary">{{ form.id ? 'Save changes' : 'Create event' }}</button>
      </template>
    </Modal>

    <Modal v-model="openSendModal" title="Send a sample event">
      <form id="sendf" @submit.prevent="sendSample" class="space-y-3">
        <div class="text-xs text-ink-500 dark:text-[color:var(--text-tertiary)]">This writes one event of type <span class="font-mono text-ink-700 dark:text-[color:var(--text-secondary)]">{{ sendForm.name }}</span> to your stream so you can verify downstream segments, journeys, and reports.</div>
        <div>
          <label class="label">Customer</label>
          <select v-model="sendForm.customer_id" class="input" required>
            <option value="">Choose a customer…</option>
            <option v-for="c in sampleCustomers" :key="c.id" :value="c.id">{{ c.email || c.first_name || c.id.slice(0, 8) }}</option>
          </select>
        </div>
        <div v-if="sendDef?.schema?.length" class="space-y-2 pt-2 border-t border-ink-100 dark:border-[color:var(--border-subtle)]">
          <div class="label !mb-0">Properties</div>
          <div v-for="p in sendDef.schema" :key="p.key" class="grid grid-cols-[140px_1fr] gap-2 items-center">
            <label class="text-xs font-mono text-ink-700 dark:text-[color:var(--text-secondary)] truncate">{{ p.key }}<span v-if="p.required" class="text-red-500">*</span></label>
            <input v-if="p.type === 'number'" v-model.number="sendForm.properties[p.key]" type="number" class="input !py-1.5 !text-xs" :required="p.required"/>
            <label v-else-if="p.type === 'boolean'" class="flex items-center gap-2 text-xs"><input type="checkbox" v-model="sendForm.properties[p.key]"/>{{ sendForm.properties[p.key] ? 'true' : 'false' }}</label>
            <input v-else-if="p.type === 'date'" v-model="sendForm.properties[p.key]" type="datetime-local" class="input !py-1.5 !text-xs" :required="p.required"/>
            <input v-else v-model="sendForm.properties[p.key]" class="input !py-1.5 !text-xs" :placeholder="p.description || p.key" :required="p.required"/>
          </div>
        </div>
        <div v-else class="text-xs text-ink-500 dark:text-[color:var(--text-tertiary)]">This event has no documented properties — it will be sent with an empty payload.</div>
      </form>
      <template #footer>
        <button @click="openSendModal = false" class="btn-secondary">Cancel</button>
        <button form="sendf" type="submit" class="btn-primary" :disabled="sendSaving">{{ sendSaving ? 'Sending…' : 'Send event' }}</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const defs = ref<any[]>([])
const events = ref<any[]>([])
const eventsPage = ref(1)
const eventsPageSize = ref(50)
const eventsTotal = ref(0)
const sampleCustomers = ref<any[]>([])

const openDef = ref(false)
const form = reactive<any>({ id: '', name: '', description: '', category: 'custom', schema: [] as any[] })

const openSendModal = ref(false)
const sendSaving = ref(false)
const sendDef = ref<any>(null)
const sendForm = reactive<any>({ name: '', customer_id: '', properties: {} as Record<string, any> })

function categoryClass(c: string) {
  switch (c) {
    case 'conversion': return 'bg-accent-500/10 text-accent-500'
    case 'behavior': return 'bg-brand-100/40 text-brand-700 dark:text-brand-400'
    case 'system': return 'bg-ink-100 text-ink-700 dark:bg-[color:var(--surface-muted)] dark:text-[color:var(--text-secondary)]'
    default: return 'bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-400'
  }
}

function newDef() {
  Object.assign(form, { id: '', name: '', description: '', category: 'custom', schema: [] })
  openDef.value = true
}
function editDef(d: any) {
  Object.assign(form, {
    id: d.id, name: d.name, description: d.description || '', category: d.category || 'custom',
    schema: Array.isArray(d.schema) ? JSON.parse(JSON.stringify(d.schema)) : [],
  })
  openDef.value = true
}
function addProp() {
  form.schema.push({ key: '', type: 'string', description: '', required: false })
}

async function load() {
  if (!workspaceId.value) return
  const from = (eventsPage.value - 1) * eventsPageSize.value
  const to = from + eventsPageSize.value - 1
  const [d, e, c] = await Promise.all([
    supabase.from('event_definitions').select('*').eq('workspace_id', workspaceId.value).order('name'),
    supabase.from('events').select('*, customer:customers(email)', { count: 'exact' }).eq('workspace_id', workspaceId.value).order('occurred_at', { ascending: false }).range(from, to),
    supabase.from('customers').select('id, email, first_name').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }).limit(25),
  ])
  defs.value = d.data || []
  events.value = e.data || []
  eventsTotal.value = e.count || 0
  sampleCustomers.value = c.data || []
}
async function saveDef() {
  const cleanSchema = (form.schema || []).filter((p: any) => (p.key || '').trim()).map((p: any) => ({
    key: p.key.trim(), type: p.type || 'string',
    description: p.description || '', required: !!p.required,
  }))
  const payload: any = {
    name: form.name.trim(), description: form.description || '', category: form.category || 'custom',
    schema: cleanSchema, source: 'ui', workspace_id: workspaceId.value,
  }
  const { error } = form.id
    ? await supabase.from('event_definitions').update(payload).eq('id', form.id)
    : await supabase.from('event_definitions').insert(payload)
  if (error) { useToast().error('Save failed', error.message); return }
  openDef.value = false; await load(); useToast().success('Event saved')
}
async function deleteDef() {
  if (!form.id) return
  const ok = await useConfirm().ask({ title: 'Remove this event definition?', body: 'Past events keep flowing; only the schema documentation is deleted.', tone: 'danger', confirmText: 'Remove' })
  if (!ok) return
  const { error } = await supabase.from('event_definitions').delete().eq('id', form.id)
  if (error) { useToast().error('Delete failed', error.message); return }
  openDef.value = false; await load()
}
async function removeDef(d: any) {
  const ok = await useConfirm().ask({ title: 'Remove this event definition?', tone: 'danger', confirmText: 'Remove' })
  if (!ok) return
  await supabase.from('event_definitions').delete().eq('id', d.id)
  useToast().success('Event definition removed'); await load()
}

function openSend(d: any) {
  sendDef.value = d
  sendForm.name = d.name
  sendForm.customer_id = sampleCustomers.value[0]?.id || ''
  sendForm.properties = {}
  for (const p of (d.schema || [])) {
    if (p.type === 'number') sendForm.properties[p.key] = 0
    else if (p.type === 'boolean') sendForm.properties[p.key] = false
    else sendForm.properties[p.key] = ''
  }
  openSendModal.value = true
}

async function sendSample() {
  if (!sendForm.customer_id || !sendForm.name) return
  sendSaving.value = true
  try {
    const props: Record<string, any> = {}
    for (const [k, v] of Object.entries(sendForm.properties)) {
      if (v === '' || v === null || v === undefined) continue
      props[k] = v
    }
    const { error } = await supabase.from('events').insert({
      workspace_id: workspaceId.value,
      customer_id: sendForm.customer_id,
      name: sendForm.name,
      properties: props,
      occurred_at: new Date().toISOString(),
    })
    if (error) { useToast().error('Send failed', error.message); return }
    openSendModal.value = false
    useToast().success('Sample event sent', sendForm.name)
    await load()
  } finally {
    sendSaving.value = false
  }
}

function timeAgo(iso: string) {
  if (!iso) return ''
  const diff = Date.now() - new Date(iso).getTime()
  const s = Math.floor(diff / 1000)
  if (s < 60) return `${s}s ago`
  const m = Math.floor(s / 60); if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60); if (h < 24) return `${h}h ago`
  const d = Math.floor(h / 24); return `${d}d ago`
}

watch(eventsPageSize, () => { eventsPage.value = 1 })
watch([workspaceId, eventsPage, eventsPageSize], load, { immediate: true })
</script>
