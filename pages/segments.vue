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
          <div class="flex items-center justify-between mb-2">
            <label class="label !mb-0">Rules · customers matching
              <select v-model="form.match" class="input !w-auto !inline-block !py-1 !px-2 text-xs font-semibold">
                <option value="all">ALL</option>
                <option value="any">ANY</option>
              </select>
              of:
            </label>
            <span class="text-xs text-ink-500" v-if="previewing">Previewing…</span>
          </div>
          <div class="space-y-2">
            <div v-for="(c, i) in form.conditions" :key="i" class="grid grid-cols-[minmax(0,1fr)_minmax(0,160px)_minmax(0,1.4fr)_auto] gap-2 items-center">
              <select v-model="c.field" @change="onFieldChange(c)" class="input min-w-0">
                <optgroup label="Profile">
                  <option v-for="f in coreFields" :key="f.key" :value="f.key">{{ f.label }}</option>
                </optgroup>
                <optgroup label="Attributes" v-if="attrFields.length">
                  <option v-for="f in attrFields" :key="f.key" :value="f.key">{{ f.label }}</option>
                </optgroup>
              </select>
              <select v-model="c.op" class="input min-w-0">
                <option v-for="op in operatorsFor(c.field)" :key="op.value" :value="op.value">{{ op.label }}</option>
              </select>
              <component
                :is="valueComponent(c)"
                v-bind="valueBindings(c)"
                v-model="c.value"
                class="input min-w-0"
              />
              <button type="button" @click="form.conditions.splice(i, 1)" class="w-9 h-9 rounded-lg text-ink-500 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 flex items-center justify-center transition" aria-label="Remove condition"><Icon name="x"/></button>
            </div>
            <button type="button" @click="addCondition" class="btn-ghost text-sm"><Icon name="plus"/>Add condition</button>
          </div>
        </div>
        <div class="bg-ink-50 rounded-lg p-3 flex items-center justify-between text-sm">
          <span class="text-ink-700">Matching customers</span>
          <div class="flex items-center gap-2">
            <span class="font-semibold text-ink-900">{{ estimated.toLocaleString() }}</span>
            <button type="button" @click="preview" class="btn-secondary text-xs">{{ previewing ? 'Refreshing…' : 'Refresh' }}</button>
          </div>
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
type FieldType = 'text' | 'number' | 'boolean' | 'date'
type FieldDef = { key: string; label: string; type: FieldType; column: string }

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
const form = reactive({ name: '', description: '', match: 'all' as 'all' | 'any', conditions: [] as any[] })

const coreFields: FieldDef[] = [
  { key: 'email', label: 'Email', type: 'text', column: 'email' },
  { key: 'phone', label: 'Phone', type: 'text', column: 'phone' },
  { key: 'first_name', label: 'First name', type: 'text', column: 'first_name' },
  { key: 'last_name', label: 'Last name', type: 'text', column: 'last_name' },
  { key: 'country', label: 'Country', type: 'text', column: 'country' },
  { key: 'city', label: 'City', type: 'text', column: 'city' },
  { key: 'platform', label: 'Platform', type: 'text', column: 'platform' },
  { key: 'device', label: 'Device', type: 'text', column: 'device' },
  { key: 'is_blacklisted', label: 'Blacklisted', type: 'boolean', column: 'is_blacklisted' },
  { key: 'last_seen_at', label: 'Last seen', type: 'date', column: 'last_seen_at' },
  { key: 'created_at', label: 'Created', type: 'date', column: 'created_at' },
]
const attrFields = ref<FieldDef[]>([])
const fieldMap = computed(() => {
  const map = new Map<string, FieldDef>()
  for (const f of [...coreFields, ...attrFields.value]) map.set(f.key, f)
  return map
})

const TEXT_OPS = [
  { value: 'eq', label: 'equals' },
  { value: 'neq', label: 'not equal' },
  { value: 'contains', label: 'contains' },
  { value: 'ncontains', label: 'does not contain' },
  { value: 'starts', label: 'starts with' },
  { value: 'ends', label: 'ends with' },
  { value: 'in', label: 'in list' },
  { value: 'nin', label: 'not in list' },
  { value: 'empty', label: 'is empty' },
  { value: 'nempty', label: 'is not empty' },
]
const NUMBER_OPS = [
  { value: 'eq', label: '=' },
  { value: 'neq', label: '≠' },
  { value: 'gt', label: '>' },
  { value: 'gte', label: '≥' },
  { value: 'lt', label: '<' },
  { value: 'lte', label: '≤' },
  { value: 'between', label: 'between' },
  { value: 'empty', label: 'is empty' },
  { value: 'nempty', label: 'is not empty' },
]
const BOOL_OPS = [
  { value: 'is_true', label: 'is true' },
  { value: 'is_false', label: 'is false' },
]
const DATE_OPS = [
  { value: 'on', label: 'on' },
  { value: 'before', label: 'before' },
  { value: 'after', label: 'after' },
  { value: 'between', label: 'between dates' },
  { value: 'in_year', label: 'in year' },
  { value: 'in_month', label: 'in month (YYYY-MM)' },
  { value: 'last_days', label: 'in last N days' },
  { value: 'next_days', label: 'in next N days' },
  { value: 'empty', label: 'is empty' },
  { value: 'nempty', label: 'is not empty' },
]

function operatorsFor(key: string) {
  const f = fieldMap.value.get(key)
  if (!f) return TEXT_OPS
  if (f.type === 'number') return NUMBER_OPS
  if (f.type === 'boolean') return BOOL_OPS
  if (f.type === 'date') return DATE_OPS
  return TEXT_OPS
}

function defaultOpFor(key: string) {
  const ops = operatorsFor(key)
  return ops[0]?.value || 'eq'
}

function valueComponent(c: any) {
  const f = fieldMap.value.get(c.field)
  if (!f) return 'input'
  if (['empty','nempty','is_true','is_false'].includes(c.op)) return DisabledInput
  if (c.op === 'between') return BetweenInput
  return 'input'
}
function valueBindings(c: any) {
  const f = fieldMap.value.get(c.field)
  if (!f) return { placeholder: 'value' }
  if (['empty','nempty','is_true','is_false'].includes(c.op)) return { placeholder: '(no value required)' }
  if (c.op === 'between') return { type: f.type === 'date' ? 'date' : 'number' }
  if (c.op === 'in_year') return { type: 'number', placeholder: 'YYYY', min: 1970, max: 2100 }
  if (c.op === 'in_month') return { type: 'month', placeholder: 'YYYY-MM' }
  if (c.op === 'last_days' || c.op === 'next_days') return { type: 'number', placeholder: 'days', min: 1 }
  if (['in','nin'].includes(c.op)) return { placeholder: 'comma,separated,values' }
  if (f.type === 'number') return { type: 'number' }
  if (f.type === 'date') return { type: c.op === 'on' ? 'date' : 'datetime-local' }
  return { placeholder: 'value' }
}

const DisabledInput = defineComponent({
  props: ['modelValue', 'placeholder'],
  setup(props) { return () => h('input', { class: 'input min-w-0 opacity-50', placeholder: props.placeholder, disabled: true }) }
})
const BetweenInput = defineComponent({
  props: ['modelValue', 'type'],
  emits: ['update:modelValue'],
  setup(props, { emit }) {
    const parts = computed(() => {
      const raw = typeof props.modelValue === 'string' ? props.modelValue.split('|') : ['', '']
      return { a: raw[0] ?? '', b: raw[1] ?? '' }
    })
    const update = (which: 'a' | 'b', v: string) => {
      const next = { ...parts.value, [which]: v }
      emit('update:modelValue', `${next.a}|${next.b}`)
    }
    return () => h('div', { class: 'flex gap-1 min-w-0' }, [
      h('input', { class: 'input min-w-0 flex-1', type: props.type, value: parts.value.a, onInput: (e: any) => update('a', e.target.value) }),
      h('span', { class: 'text-ink-400 text-xs self-center' }, 'to'),
      h('input', { class: 'input min-w-0 flex-1', type: props.type, value: parts.value.b, onInput: (e: any) => update('b', e.target.value) }),
    ])
  }
})

function addCondition() {
  const key = coreFields[0].key
  form.conditions.push({ field: key, op: defaultOpFor(key), value: '' })
}
function onFieldChange(c: any) {
  c.op = defaultOpFor(c.field)
  c.value = ''
}

function columnRef(f: FieldDef) {
  return f.column.startsWith('attributes.') ? `attributes->>${f.column.slice('attributes.'.length)}` : f.column
}
function castNumeric(f: FieldDef, val: string) {
  return val === '' ? val : val
}

async function discoverAttributes() {
  if (!workspaceId.value) return
  const { data } = await supabase
    .from('customers')
    .select('attributes')
    .eq('workspace_id', workspaceId.value)
    .not('attributes', 'is', null)
    .limit(500)
  const types = new Map<string, Set<string>>()
  for (const row of data || []) {
    const attrs = row.attributes || {}
    for (const [k, v] of Object.entries(attrs)) {
      if (!types.has(k)) types.set(k, new Set())
      const t = v === null ? 'null' : typeof v
      types.get(k)!.add(t)
    }
  }
  const out: FieldDef[] = []
  for (const [k, s] of types.entries()) {
    let type: FieldType = 'text'
    if (s.has('number') && !s.has('string')) type = 'number'
    else if (s.has('boolean') && s.size === 1) type = 'boolean'
    else if (/(_at|_date|birthday|dob|joined|signup)$/i.test(k)) type = 'date'
    out.push({ key: `attr.${k}`, label: k, type, column: `attributes.${k}` })
  }
  out.sort((a, b) => a.label.localeCompare(b.label))
  attrFields.value = out
}

function applyConds(q: any) {
  const match = form.match === 'any' ? 'or' : 'and'
  const clauses: string[] = []
  const direct: Array<(qq: any) => any> = []

  for (const c of form.conditions) {
    const f = fieldMap.value.get(c.field)
    if (!f) continue
    const col = columnRef(f)
    const v = c.value
    const needsValue = !['empty','nempty','is_true','is_false'].includes(c.op)
    if (needsValue && (v === '' || v === null || v === undefined)) continue

    if (match === 'and') {
      switch (c.op) {
        case 'eq': direct.push(qq => qq.eq(col, coerce(f, v))); break
        case 'neq': direct.push(qq => qq.neq(col, coerce(f, v))); break
        case 'gt': direct.push(qq => qq.gt(col, v)); break
        case 'gte': direct.push(qq => qq.gte(col, v)); break
        case 'lt': direct.push(qq => qq.lt(col, v)); break
        case 'lte': direct.push(qq => qq.lte(col, v)); break
        case 'contains': direct.push(qq => qq.ilike(col, `%${v}%`)); break
        case 'ncontains': direct.push(qq => qq.not(col, 'ilike', `%${v}%`)); break
        case 'starts': direct.push(qq => qq.ilike(col, `${v}%`)); break
        case 'ends': direct.push(qq => qq.ilike(col, `%${v}`)); break
        case 'in': direct.push(qq => qq.in(col, String(v).split(',').map(s => s.trim()).filter(Boolean))); break
        case 'nin': direct.push(qq => qq.not(col, 'in', `(${String(v).split(',').map(s => s.trim()).filter(Boolean).join(',')})`)); break
        case 'empty': direct.push(qq => qq.or(`${col}.is.null,${col}.eq.`)); break
        case 'nempty': direct.push(qq => qq.not(col, 'is', null).neq(col, '')); break
        case 'is_true': direct.push(qq => qq.eq(col, true)); break
        case 'is_false': direct.push(qq => qq.eq(col, false)); break
        case 'on': { const [s, e] = dayRange(v); direct.push(qq => qq.gte(col, s).lt(col, e)); break }
        case 'before': direct.push(qq => qq.lt(col, v)); break
        case 'after': direct.push(qq => qq.gt(col, v)); break
        case 'between': {
          const [a, b] = String(v).split('|')
          if (a) direct.push(qq => qq.gte(col, a))
          if (b) direct.push(qq => qq.lte(col, b))
          break
        }
        case 'in_year': {
          const y = parseInt(v, 10); if (!y) break
          direct.push(qq => qq.gte(col, `${y}-01-01`).lt(col, `${y + 1}-01-01`))
          break
        }
        case 'in_month': {
          const [yy, mm] = String(v).split('-').map(n => parseInt(n, 10))
          if (!yy || !mm) break
          const start = `${yy}-${String(mm).padStart(2,'0')}-01`
          const nextMonth = mm === 12 ? `${yy + 1}-01-01` : `${yy}-${String(mm + 1).padStart(2,'0')}-01`
          direct.push(qq => qq.gte(col, start).lt(col, nextMonth))
          break
        }
        case 'last_days': {
          const n = parseInt(v, 10); if (!n) break
          const d = new Date(Date.now() - n * 86400000).toISOString()
          direct.push(qq => qq.gte(col, d))
          break
        }
        case 'next_days': {
          const n = parseInt(v, 10); if (!n) break
          const d = new Date(Date.now() + n * 86400000).toISOString()
          direct.push(qq => qq.lte(col, d).gte(col, new Date().toISOString()))
          break
        }
      }
    } else {
      const esc = (s: any) => String(s).replace(/,/g, '\\,').replace(/\)/g, '\\)')
      switch (c.op) {
        case 'eq': clauses.push(`${col}.eq.${esc(v)}`); break
        case 'neq': clauses.push(`${col}.neq.${esc(v)}`); break
        case 'gt': clauses.push(`${col}.gt.${esc(v)}`); break
        case 'gte': clauses.push(`${col}.gte.${esc(v)}`); break
        case 'lt': clauses.push(`${col}.lt.${esc(v)}`); break
        case 'lte': clauses.push(`${col}.lte.${esc(v)}`); break
        case 'contains': clauses.push(`${col}.ilike.%${esc(v)}%`); break
        case 'starts': clauses.push(`${col}.ilike.${esc(v)}%`); break
        case 'ends': clauses.push(`${col}.ilike.%${esc(v)}`); break
        case 'is_true': clauses.push(`${col}.eq.true`); break
        case 'is_false': clauses.push(`${col}.eq.false`); break
        case 'empty': clauses.push(`${col}.is.null`); break
        case 'nempty': clauses.push(`${col}.not.is.null`); break
        case 'before': clauses.push(`${col}.lt.${esc(v)}`); break
        case 'after': clauses.push(`${col}.gt.${esc(v)}`); break
      }
    }
  }

  if (match === 'or' && clauses.length) q = q.or(clauses.join(','))
  for (const fn of direct) q = fn(q)
  return q
}

function coerce(f: FieldDef, v: any) {
  if (f.type === 'boolean') return v === 'true' ? true : v === 'false' ? false : v
  return v
}
function dayRange(d: string) {
  const start = `${d}T00:00:00.000Z`
  const dt = new Date(d); dt.setUTCDate(dt.getUTCDate() + 1)
  return [start, dt.toISOString()]
}

async function load() {
  if (!workspaceId.value) return
  const [s, l] = await Promise.all([
    supabase.from('segments').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('lists').select('id,name').eq('workspace_id', workspaceId.value),
  ])
  segments.value = s.data || []; lists.value = l.data || []
  await discoverAttributes()
}
function close() { open.value = false; editing.value = null; Object.assign(form, { name: '', description: '', match: 'all', conditions: [] }); estimated.value = 0; matches.value = []; addToListId.value = '' }
function edit(s: any) {
  editing.value = s
  if (s) { Object.assign(form, { name: s.name, description: s.description, match: s.rules?.match || 'all', conditions: s.rules?.conditions || [] }); estimated.value = s.estimated_count }
  else Object.assign(form, { name: '', description: '', match: 'all', conditions: [] })
  matches.value = []
  open.value = true
  if (s) preview()
}

async function preview() {
  previewing.value = true
  try {
    const countQ = applyConds(supabase.from('customers').select('id', { count: 'exact', head: true }).eq('workspace_id', workspaceId.value))
    const { count } = await countQ
    estimated.value = count || 0
    const dataQ = applyConds(supabase.from('customers').select('id,first_name,last_name,email').eq('workspace_id', workspaceId.value).limit(25))
    const { data } = await dataQ
    matches.value = data || []
  } finally {
    previewing.value = false
  }
}
let previewTimer: ReturnType<typeof setTimeout> | null = null
watch(() => JSON.stringify({ m: form.match, c: form.conditions }), () => {
  if (!open.value) return
  if (previewTimer) clearTimeout(previewTimer)
  previewTimer = setTimeout(() => { if (open.value) preview() }, 300)
})

async function save() {
  await preview()
  const payload = { name: form.name, description: form.description, rules: { match: form.match, conditions: form.conditions }, estimated_count: estimated.value, workspace_id: workspaceId.value }
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
