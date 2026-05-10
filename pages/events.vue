<template>
  <div>
    <PageHeader title="Events" subtitle="Track behavior across your apps.">
      <template #actions>
        <button @click="openNew = true" class="btn-secondary"><Icon name="plus"/>Define event</button>
      </template>
    </PageHeader>

    <div class="p-8 grid lg:grid-cols-3 gap-6">
      <div class="card p-6 lg:col-span-1">
        <div class="font-semibold text-ink-900 mb-4">Defined events</div>
        <div class="space-y-2">
          <div v-for="d in defs" :key="d.id" class="flex items-center justify-between p-3 rounded-lg hover:bg-ink-50">
            <div>
              <div class="font-mono text-sm font-medium text-ink-900">{{ d.name }}</div>
              <div class="text-xs text-ink-500">{{ d.description || d.category }}</div>
            </div>
            <button @click="removeDef(d)" class="text-ink-300 hover:text-red-600"><Icon name="trash"/></button>
          </div>
          <EmptyState v-if="!defs.length" icon="activity" title="No events yet" subtitle="Define events to start tracking."/>
        </div>
      </div>

      <div class="card overflow-hidden lg:col-span-2">
        <div class="px-4 py-3 border-b border-ink-100 flex items-center justify-between">
          <div class="font-semibold text-ink-900">Live event stream</div>
          <span class="chip bg-accent-500/10 text-accent-500"><span class="w-1.5 h-1.5 rounded-full bg-accent-500 animate-pulse"></span>Live</span>
        </div>
        <table class="w-full">
          <thead><tr><th class="table-th">Event</th><th class="table-th">Customer</th><th class="table-th">Properties</th><th class="table-th">When</th></tr></thead>
          <tbody>
            <tr v-for="e in events" :key="e.id">
              <td class="table-td font-mono text-xs font-medium">{{ e.name }}</td>
              <td class="table-td text-xs text-ink-500">{{ e.customer?.email || '—' }}</td>
              <td class="table-td"><code class="text-[10px] bg-ink-50 px-1.5 py-0.5 rounded">{{ JSON.stringify(e.properties) }}</code></td>
              <td class="table-td text-xs text-ink-500">{{ timeAgo(e.occurred_at) }}</td>
            </tr>
          </tbody>
        </table>
        <EmptyState v-if="!events.length" icon="activity" title="No events tracked yet" subtitle="Use the dashboard to generate demo data, or connect an SDK."/>
      </div>
    </div>

    <Modal v-model="openNew" title="Define event">
      <form id="evf" @submit.prevent="saveDef" class="space-y-3">
        <div><label class="label">Event name *</label><input v-model="form.name" class="input" required pattern="[a-z0-9_]+" title="lowercase, underscores"/></div>
        <div><label class="label">Description</label><input v-model="form.description" class="input"/></div>
        <div><label class="label">Category</label>
          <select v-model="form.category" class="input">
            <option>behavior</option><option>conversion</option><option>system</option><option>custom</option>
          </select>
        </div>
      </form>
      <template #footer>
        <button @click="openNew = false" class="btn-secondary">Cancel</button>
        <button form="evf" type="submit" class="btn-primary">Save</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const defs = ref<any[]>([])
const events = ref<any[]>([])
const openNew = ref(false)
const form = reactive({ name: '', description: '', category: 'custom' })

async function load() {
  if (!workspaceId.value) return
  const [d, e] = await Promise.all([
    supabase.from('event_definitions').select('*').eq('workspace_id', workspaceId.value).order('name'),
    supabase.from('events').select('*, customer:customers(email)').eq('workspace_id', workspaceId.value).order('occurred_at', { ascending: false }).limit(50),
  ])
  defs.value = d.data || []
  events.value = e.data || []
}
async function saveDef() {
  await supabase.from('event_definitions').insert({ ...form, workspace_id: workspaceId.value })
  Object.assign(form, { name: '', description: '', category: 'custom' })
  openNew.value = false
  await load()
}
async function removeDef(d: any) {
  const ok = await useConfirm().ask({ title: 'Remove this event definition?', tone: 'danger', confirmText: 'Remove' })
  if (!ok) return
  await supabase.from('event_definitions').delete().eq('id', d.id)
  useToast().success('Event definition removed')
  await load()
}
watch(workspaceId, load, { immediate: true })
</script>
