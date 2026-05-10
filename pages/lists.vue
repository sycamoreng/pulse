<template>
  <div>
    <PageHeader title="Lists" subtitle="Static lists of customers for targeting.">
      <template #actions>
        <button @click="openNew = true" class="btn-primary"><Icon name="plus"/>New list</button>
      </template>
    </PageHeader>

    <div class="p-8 grid lg:grid-cols-3 gap-6">
      <div class="card p-4 lg:col-span-1 max-h-[70vh] overflow-y-auto">
        <div class="space-y-1">
          <button v-for="l in lists" :key="l.id" @click="select(l)" class="w-full text-left px-3 py-2.5 rounded-lg flex items-center justify-between hover:bg-ink-50" :class="selected?.id === l.id && 'bg-brand-100/30'">
            <div>
              <div class="font-medium text-ink-900 text-sm">{{ l.name }}</div>
              <div class="text-xs text-ink-500">{{ l._count }} members</div>
            </div>
            <Icon name="chevronRight" class="text-ink-300"/>
          </button>
          <EmptyState v-if="!lists.length" icon="list" title="No lists yet"/>
        </div>
      </div>

      <div class="card lg:col-span-2 overflow-hidden" v-if="selected">
        <div class="px-5 py-4 border-b border-ink-100 flex items-center justify-between">
          <div>
            <div class="font-semibold text-ink-900">{{ selected.name }}</div>
            <div class="text-xs text-ink-500">{{ selected.description || 'No description' }}</div>
          </div>
          <div class="flex gap-2">
            <button @click="openAdd = true" class="btn-secondary"><Icon name="plus"/>Add members</button>
            <button @click="removeList" class="btn-ghost text-red-600"><Icon name="trash"/></button>
          </div>
        </div>
        <table class="w-full">
          <thead><tr><th class="table-th">Customer</th><th class="table-th">Email</th><th class="table-th">Added</th><th class="table-th"></th></tr></thead>
          <tbody>
            <tr v-for="m in members" :key="m.id">
              <td class="table-td">{{ m.customer?.first_name }} {{ m.customer?.last_name }}</td>
              <td class="table-td">{{ m.customer?.email }}</td>
              <td class="table-td text-xs text-ink-500">{{ timeAgo(m.added_at) }}</td>
              <td class="table-td text-right"><button @click="removeMember(m)" class="text-ink-500 hover:text-red-600"><Icon name="x"/></button></td>
            </tr>
          </tbody>
        </table>
        <EmptyState v-if="!members.length" icon="users" title="No members" subtitle="Add customers to this list."/>
      </div>
      <div v-else class="card p-12 text-center text-ink-500 lg:col-span-2">Select a list to view members.</div>
    </div>

    <Modal v-model="openNew" title="New list">
      <form id="nlf" @submit.prevent="create" class="space-y-3">
        <div><label class="label">Name *</label><input v-model="form.name" class="input" required/></div>
        <div><label class="label">Description</label><input v-model="form.description" class="input"/></div>
      </form>
      <template #footer>
        <button @click="openNew = false" class="btn-secondary">Cancel</button>
        <button form="nlf" type="submit" class="btn-primary">Create</button>
      </template>
    </Modal>

    <Modal v-model="openAdd" title="Add members" subtitle="Pick customers to add to this list." size="lg">
      <input v-model="addQuery" class="input mb-3" placeholder="Search customers…"/>
      <div class="max-h-80 overflow-y-auto space-y-1">
        <label v-for="c in candidates" :key="c.id" class="flex items-center gap-3 p-2 rounded-lg hover:bg-ink-50 cursor-pointer">
          <input type="checkbox" :value="c.id" v-model="toAdd"/>
          <div class="flex-1">
            <div class="text-sm font-medium">{{ c.first_name }} {{ c.last_name }}</div>
            <div class="text-xs text-ink-500">{{ c.email }}</div>
          </div>
        </label>
      </div>
      <template #footer>
        <button @click="openAdd = false" class="btn-secondary">Cancel</button>
        <button @click="addMembers" class="btn-primary">Add {{ toAdd.length }}</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const lists = ref<any[]>([])
const selected = ref<any>(null)
const members = ref<any[]>([])
const openNew = ref(false)
const openAdd = ref(false)
const form = reactive({ name: '', description: '' })
const addQuery = ref('')
const candidates = ref<any[]>([])
const toAdd = ref<string[]>([])

async function load() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('lists').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false })
  const withCounts = await Promise.all((data || []).map(async (l: any) => {
    const { count } = await supabase.from('list_members').select('id', { count: 'exact', head: true }).eq('list_id', l.id)
    return { ...l, _count: count || 0 }
  }))
  lists.value = withCounts
  if (!selected.value && lists.value.length) select(lists.value[0])
}
async function select(l: any) {
  selected.value = l
  const { data } = await supabase.from('list_members').select('*, customer:customers(first_name,last_name,email)').eq('list_id', l.id).order('added_at', { ascending: false })
  members.value = data || []
}
async function create() {
  const { data } = await supabase.from('lists').insert({ ...form, workspace_id: workspaceId.value }).select().maybeSingle()
  openNew.value = false; Object.assign(form, { name: '', description: '' })
  await load(); if (data) select({ ...data, _count: 0 })
}
async function removeList() {
  const ok = await useConfirm().ask({ title: 'Delete this list?', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await supabase.from('lists').delete().eq('id', selected.value.id)
  useToast().success('List deleted')
  selected.value = null; await load()
}
async function removeMember(m: any) {
  await supabase.from('list_members').delete().eq('id', m.id)
  await select(selected.value); await load()
}
async function loadCandidates() {
  let q = supabase.from('customers').select('id,first_name,last_name,email').eq('workspace_id', workspaceId.value).limit(50)
  if (addQuery.value) q = q.or(`email.ilike.%${addQuery.value}%,first_name.ilike.%${addQuery.value}%`)
  const { data } = await q
  candidates.value = data || []
}
async function addMembers() {
  if (!toAdd.value.length) return
  await supabase.from('list_members').upsert(toAdd.value.map(id => ({ list_id: selected.value.id, customer_id: id })), { onConflict: 'list_id,customer_id' })
  toAdd.value = []; openAdd.value = false
  await select(selected.value); await load()
}
watch(openAdd, v => { if (v) loadCandidates() })
watch(addQuery, loadCandidates)
watch(workspaceId, load, { immediate: true })
</script>
