<template>
  <div>
    <PageHeader title="Customer Attributes" subtitle="Default and custom fields on every customer profile.">
      <template #actions>
        <button @click="edit(null)" class="btn-primary"><Icon name="plus"/>New custom attribute</button>
      </template>
    </PageHeader>
    <div class="p-8 space-y-4">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div v-for="s in stats" :key="s.label" class="card p-4">
          <div class="text-xs text-ink-500 font-semibold uppercase tracking-wider">{{ s.label }}</div>
          <div class="text-2xl font-bold text-ink-900 mt-1">{{ s.value }}</div>
        </div>
      </div>
      <div class="card overflow-hidden">
        <table class="w-full">
          <thead><tr><th class="table-th">Key</th><th class="table-th">Label</th><th class="table-th">Type</th><th class="table-th">Source</th><th class="table-th"></th></tr></thead>
          <tbody>
            <tr v-for="a in attrs" :key="a.id" class="hover:bg-ink-50">
              <td class="table-td font-mono text-xs">{{ a.key }}</td>
              <td class="table-td font-medium">{{ a.label }}</td>
              <td class="table-td">
                <span class="chip" :class="typeStyle(a.data_type)">
                  <Icon :name="typeIcon(a.data_type)"/>{{ a.data_type }}
                </span>
              </td>
              <td class="table-td">
                <span v-if="a.is_default" class="chip bg-brand-100/40 text-brand-700">Default</span>
                <span v-else class="chip bg-accent-500/10 text-accent-500">Custom</span>
              </td>
              <td class="table-td text-right space-x-2">
                <button v-if="!a.is_default" @click="edit(a)" class="text-ink-500 hover:text-brand-500"><Icon name="edit"/></button>
                <button v-if="!a.is_default" @click="remove(a)" class="text-ink-500 hover:text-red-600"><Icon name="trash"/></button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <Modal v-model="open" :title="editing ? 'Edit attribute' : 'Create custom attribute'">
      <form id="newattr" @submit.prevent="save" class="space-y-3">
        <div><label class="label">Key *</label><input v-model="form.key" class="input font-mono" required pattern="[a-z0-9_]+" title="lowercase letters, numbers, underscores"/></div>
        <div><label class="label">Label *</label><input v-model="form.label" class="input" required/></div>
        <div>
          <label class="label">Data type</label>
          <div class="grid grid-cols-3 gap-2">
            <button v-for="t in types" :key="t.value" type="button" @click="form.data_type = t.value"
              class="p-3 rounded-lg border text-left transition"
              :class="form.data_type === t.value ? 'border-brand-500 bg-brand-100/30 text-brand-700' : 'border-ink-100 hover:border-ink-300'">
              <Icon :name="t.icon"/>
              <div class="text-xs font-semibold mt-1.5">{{ t.label }}</div>
              <div class="text-[10px] text-ink-500">{{ t.hint }}</div>
            </button>
          </div>
        </div>
      </form>
      <template #footer>
        <button @click="open = false" class="btn-secondary">Cancel</button>
        <button form="newattr" type="submit" class="btn-primary">{{ editing ? 'Update' : 'Create' }}</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const attrs = ref<any[]>([])
const open = ref(false)
const editing = ref<any>(null)
const form = reactive({ key: '', label: '', data_type: 'string' })

const types = [
  { value: 'string', label: 'Text', icon: 'tag', hint: 'Short text' },
  { value: 'number', label: 'Number', icon: 'trending', hint: 'Integer or decimal' },
  { value: 'boolean', label: 'Boolean', icon: 'check', hint: 'True / false' },
  { value: 'date', label: 'Date', icon: 'calendar', hint: 'Date only' },
  { value: 'datetime', label: 'Date & time', icon: 'clock', hint: 'Date with time' },
  { value: 'email', label: 'Email', icon: 'mail', hint: 'Email address' },
  { value: 'url', label: 'URL', icon: 'box', hint: 'Web link' },
  { value: 'phone', label: 'Phone', icon: 'smartphone', hint: 'Phone number' },
  { value: 'json', label: 'Object', icon: 'layers', hint: 'Structured JSON' },
  { value: 'array', label: 'List', icon: 'list', hint: 'Array of values' },
  { value: 'enum', label: 'Enum', icon: 'filter', hint: 'One of many' },
  { value: 'currency', label: 'Currency', icon: 'send', hint: 'Monetary value' },
]

const typeIcon = (t: string) => types.find(x => x.value === t)?.icon || 'tag'
const typeStyle = (t: string) => {
  if (['number','currency'].includes(t)) return 'bg-accent-500/10 text-accent-500'
  if (['boolean'].includes(t)) return 'bg-yellow-100 text-yellow-700'
  if (['date','datetime'].includes(t)) return 'bg-brand-100/40 text-brand-700'
  return 'bg-ink-100 text-ink-700'
}

const stats = computed(() => [
  { label: 'Total', value: attrs.value.length },
  { label: 'Default', value: attrs.value.filter(a => a.is_default).length },
  { label: 'Custom', value: attrs.value.filter(a => !a.is_default).length },
  { label: 'Data types', value: new Set(attrs.value.map(a => a.data_type)).size },
])

async function load() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('customer_attributes_schema').select('*').eq('workspace_id', workspaceId.value).order('is_default', { ascending: false }).order('label')
  attrs.value = data || []
}
function edit(a: any) {
  editing.value = a
  if (a) Object.assign(form, { key: a.key, label: a.label, data_type: a.data_type })
  else Object.assign(form, { key: '', label: '', data_type: 'string' })
  open.value = true
}
async function save() {
  if (editing.value) await supabase.from('customer_attributes_schema').update(form).eq('id', editing.value.id)
  else await supabase.from('customer_attributes_schema').insert({ ...form, workspace_id: workspaceId.value, is_default: false })
  open.value = false
  editing.value = null
  Object.assign(form, { key: '', label: '', data_type: 'string' })
  await load()
}
async function remove(a: any) {
  const ok = await useConfirm().ask({ title: 'Delete this attribute?', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await supabase.from('customer_attributes_schema').delete().eq('id', a.id)
  useToast().success('Attribute deleted')
  await load()
}
watch(workspaceId, load, { immediate: true })
</script>
