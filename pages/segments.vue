<template>
  <div>
    <PageHeader title="Segments" subtitle="Dynamic groups of customers based on rules.">
      <template #actions>
        <button @click="edit(null)" class="btn-primary"><Icon name="plus"/>New segment</button>
      </template>
    </PageHeader>

    <div class="p-8">
      <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div v-for="s in segments" :key="s.id" class="card p-5 hover:shadow-md transition cursor-pointer" @click="edit(s)">
          <div class="flex items-start justify-between">
            <div class="w-10 h-10 rounded-lg bg-brand-100/40 text-brand-500 flex items-center justify-center"><Icon name="segment"/></div>
            <button @click.stop="remove(s)" class="text-ink-300 hover:text-red-600"><Icon name="trash"/></button>
          </div>
          <div class="mt-4 font-semibold text-ink-900">{{ s.name }}</div>
          <div class="text-xs text-ink-500 mt-1 line-clamp-2">{{ s.description || 'No description' }}</div>
          <div class="mt-4 pt-4 border-t border-ink-100 flex items-center justify-between">
            <div class="text-2xl font-bold text-ink-900">{{ s.estimated_count }}</div>
            <div class="text-xs text-ink-500">customers</div>
          </div>
        </div>
        <button @click="edit(null)" class="card p-5 border-dashed flex flex-col items-center justify-center text-ink-500 hover:text-brand-500 hover:border-brand-500 transition min-h-[180px]">
          <Icon name="plus"/>
          <div class="mt-2 text-sm font-medium">Create segment</div>
        </button>
      </div>
    </div>

    <Modal v-model="open" :title="editing ? editing.name : 'New segment'" size="lg">
      <form id="segf" @submit.prevent="save" class="space-y-4">
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">Name *</label><input v-model="form.name" class="input" required/></div>
          <div><label class="label">Description</label><input v-model="form.description" class="input"/></div>
        </div>
        <div>
          <label class="label">Rules · customers matching ALL of:</label>
          <div class="space-y-2">
            <div v-for="(c, i) in form.conditions" :key="i" class="flex gap-2 items-center">
              <select v-model="c.field" class="input">
                <option value="country">country</option><option value="city">city</option>
                <option value="platform">platform</option><option value="email">email</option>
                <option value="is_blacklisted">is_blacklisted</option>
              </select>
              <select v-model="c.op" class="input w-32">
                <option value="eq">equals</option><option value="ilike">contains</option><option value="neq">not equal</option>
              </select>
              <input v-model="c.value" class="input flex-1" placeholder="value"/>
              <button type="button" @click="form.conditions.splice(i, 1)" class="text-ink-500 hover:text-red-600"><Icon name="x"/></button>
            </div>
            <button type="button" @click="form.conditions.push({ field: 'country', op: 'eq', value: '' })" class="btn-ghost text-sm"><Icon name="plus"/>Add condition</button>
          </div>
        </div>
        <div class="bg-ink-50 rounded-lg p-3 flex items-center justify-between text-sm">
          <span class="text-ink-700">Matching customers</span>
          <button type="button" @click="preview" class="btn-secondary">{{ previewing ? '…' : `Refresh (${estimated})` }}</button>
        </div>
        <div v-if="matches.length" class="border border-ink-100 rounded-lg max-h-48 overflow-y-auto">
          <div v-for="m in matches" :key="m.id" class="px-3 py-2 text-sm border-b border-ink-100 flex justify-between">
            <span>{{ m.first_name }} {{ m.last_name }}</span>
            <span class="text-ink-500 text-xs">{{ m.email }}</span>
          </div>
        </div>
        <div v-if="editing" class="pt-3 border-t border-ink-100">
          <div class="font-semibold text-ink-900 mb-2 text-sm">Actions</div>
          <div class="flex gap-2">
            <select v-model="addToListId" class="input flex-1">
              <option value="">Add matching customers to list…</option>
              <option v-for="l in lists" :key="l.id" :value="l.id">{{ l.name }}</option>
            </select>
            <button type="button" @click="addToList" :disabled="!addToListId || adding" class="btn-secondary">{{ adding ? 'Adding…' : 'Add' }}</button>
          </div>
        </div>
      </form>
      <template #footer>
        <button @click="close" class="btn-secondary">Cancel</button>
        <button form="segf" type="submit" class="btn-primary">{{ editing ? 'Update' : 'Create' }}</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const segments = ref<any[]>([])
const lists = ref<any[]>([])
const open = ref(false)
const editing = ref<any>(null)
const estimated = ref(0)
const matches = ref<any[]>([])
const previewing = ref(false)
const adding = ref(false)
const addToListId = ref('')
const form = reactive({ name: '', description: '', conditions: [] as any[] })

async function load() {
  if (!workspaceId.value) return
  const [s, l] = await Promise.all([
    supabase.from('segments').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('lists').select('id,name').eq('workspace_id', workspaceId.value),
  ])
  segments.value = s.data || []; lists.value = l.data || []
}
function close() { open.value = false; editing.value = null; Object.assign(form, { name: '', description: '', conditions: [] }); estimated.value = 0; matches.value = []; addToListId.value = '' }
function edit(s: any) {
  editing.value = s
  if (s) { Object.assign(form, { name: s.name, description: s.description, conditions: s.rules?.conditions || [] }); estimated.value = s.estimated_count }
  else Object.assign(form, { name: '', description: '', conditions: [] })
  matches.value = []
  open.value = true
  if (s) preview()
}

function applyConds(q: any) {
  for (const c of form.conditions) {
    if (!c.value && c.op !== 'eq') continue
    if (c.op === 'eq') q = q.eq(c.field, c.value === 'true' ? true : c.value === 'false' ? false : c.value)
    else if (c.op === 'neq') q = q.neq(c.field, c.value)
    else if (c.op === 'ilike') q = q.ilike(c.field, `%${c.value}%`)
  }
  return q
}
async function preview() {
  previewing.value = true
  const countQ = applyConds(supabase.from('customers').select('id', { count: 'exact', head: true }).eq('workspace_id', workspaceId.value))
  const { count } = await countQ
  estimated.value = count || 0
  const dataQ = applyConds(supabase.from('customers').select('id,first_name,last_name,email').eq('workspace_id', workspaceId.value).limit(25))
  const { data } = await dataQ
  matches.value = data || []
  previewing.value = false
}
async function save() {
  await preview()
  const payload = { name: form.name, description: form.description, rules: { conditions: form.conditions }, estimated_count: estimated.value, workspace_id: workspaceId.value }
  if (editing.value) await supabase.from('segments').update(payload).eq('id', editing.value.id)
  else await supabase.from('segments').insert(payload)
  close()
  await load()
}
async function addToList() {
  if (!addToListId.value) return
  adding.value = true
  const q = applyConds(supabase.from('customers').select('id').eq('workspace_id', workspaceId.value))
  const { data } = await q
  const rows = (data || []).map((c: any) => ({ list_id: addToListId.value, customer_id: c.id }))
  if (rows.length) await supabase.from('list_members').upsert(rows, { onConflict: 'list_id,customer_id', ignoreDuplicates: true })
  adding.value = false
  addToListId.value = ''
  useToast().success('Added to list', `${rows.length} customers copied to the list.`)
}
async function remove(s: any) {
  const ok = await useConfirm().ask({ title: 'Delete this segment?', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await supabase.from('segments').delete().eq('id', s.id)
  useToast().success('Segment deleted')
  await load()
}
watch(workspaceId, load, { immediate: true })
</script>
