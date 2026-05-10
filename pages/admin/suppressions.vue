<template>
  <div>
    <PageHeader title="Suppressions" subtitle="Platform-wide view of bounces, complaints, and manual blocks."/>
    <div class="p-8 space-y-4">
      <div class="card p-4 flex items-center gap-3">
        <input v-model="q" class="input flex-1" placeholder="Search email"/>
        <select v-model="reasonFilter" class="input !w-48">
          <option value="">All reasons</option>
          <option value="hard_bounce">Hard bounce</option>
          <option value="soft_bounce">Soft bounce</option>
          <option value="complaint">Complaint</option>
          <option value="unsubscribe">Unsubscribe</option>
        </select>
      </div>
      <div class="card">
        <table class="w-full text-sm">
          <thead class="text-left text-xs text-ink-500 uppercase tracking-wider border-b border-ink-100">
            <tr><th class="px-4 py-3">Email</th><th class="px-4 py-3">Workspace</th><th class="px-4 py-3">Reason</th><th class="px-4 py-3">Source</th><th class="px-4 py-3">Date</th><th></th></tr>
          </thead>
          <tbody>
            <tr v-if="!filtered.length"><td colspan="6" class="text-center py-12 text-sm text-ink-500">No suppressions.</td></tr>
            <tr v-for="s in filtered" :key="s.id" class="border-b border-ink-100 last:border-0 hover:bg-ink-50">
              <td class="px-4 py-3 font-mono text-ink-900">{{ s.email }}</td>
              <td class="px-4 py-3 text-ink-700">{{ wsName(s.workspace_id) }}</td>
              <td class="px-4 py-3"><span class="chip bg-ink-100 text-ink-700">{{ s.reason }}</span></td>
              <td class="px-4 py-3 text-xs text-ink-500">{{ s.source }}</td>
              <td class="px-4 py-3 text-xs text-ink-500">{{ new Date(s.created_at).toLocaleString() }}</td>
              <td class="px-4 py-3 text-right"><button @click="remove(s)" class="text-ink-500 hover:text-red-600"><Icon name="trash"/></button></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })
const { $supabase } = useNuxtApp()
const list = ref<any[]>([])
const workspaces = ref<any[]>([])
const q = ref('')
const reasonFilter = ref('')
async function load() {
  const [s, ws] = await Promise.all([
    $supabase.from('email_suppressions').select('*').order('created_at', { ascending: false }).limit(500),
    $supabase.from('workspaces').select('id, name'),
  ])
  list.value = s.data || []
  workspaces.value = ws.data || []
}
function wsName(id: string) { return workspaces.value.find((w: any) => w.id === id)?.name || '—' }
const filtered = computed(() => list.value.filter((s: any) => {
  const matchQ = !q.value || s.email.toLowerCase().includes(q.value.toLowerCase())
  const matchR = !reasonFilter.value || s.reason === reasonFilter.value
  return matchQ && matchR
}))
async function remove(s: any) {
  const ok = await useConfirm().ask({ title: 'Remove suppression?', body: `${s.email} will be eligible to receive mail again.`, confirmText: 'Remove', tone: 'danger' })
  if (!ok) return
  await $supabase.from('email_suppressions').delete().eq('id', s.id)
  await load()
}
onMounted(load)
</script>
