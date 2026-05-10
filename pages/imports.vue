<template>
  <div>
    <PageHeader title="Imports" subtitle="Upload a CSV and map columns to customer attributes.">
      <template #actions>
        <label class="btn-primary cursor-pointer">
          <Icon name="upload"/>Upload CSV
          <input type="file" accept=".csv,text/csv" class="hidden" @change="onFile"/>
        </label>
      </template>
    </PageHeader>

    <div class="p-8 space-y-6">
      <div v-if="parsed" class="card p-6 space-y-4">
        <div>
          <div class="font-semibold text-ink-900">Map columns</div>
          <div class="text-xs text-ink-500">Select which customer attribute each CSV column maps to. Unmapped columns are saved as custom attributes.</div>
        </div>
        <div class="grid md:grid-cols-2 gap-3">
          <div v-for="col in parsed.columns" :key="col" class="flex items-center gap-3 p-3 border border-ink-100 rounded-lg">
            <div class="flex-1">
              <div class="text-xs text-ink-500">CSV column</div>
              <div class="font-semibold text-ink-900 text-sm">{{ col }}</div>
              <div class="text-[11px] text-ink-500 font-mono truncate">e.g. {{ parsed.sample[col] }}</div>
            </div>
            <Icon name="arrowRight" class="text-ink-300"/>
            <select v-model="mapping[col]" class="input w-40">
              <option value="">— skip —</option>
              <option value="__custom__">Custom attribute</option>
              <option v-for="a in attrs" :key="a.id" :value="a.key">{{ a.label }}</option>
            </select>
          </div>
        </div>
        <div class="flex items-center justify-between pt-3 border-t border-ink-100">
          <div class="text-sm text-ink-500">{{ parsed.rows.length }} rows ready to import</div>
          <div class="flex gap-2">
            <button @click="parsed = null" class="btn-secondary">Cancel</button>
            <button @click="runImport" :disabled="importing" class="btn-primary">{{ importing ? 'Importing…' : 'Import customers' }}</button>
          </div>
        </div>
      </div>

      <div class="card overflow-hidden">
        <div class="px-4 py-3 border-b border-ink-100 font-semibold text-ink-900">Past imports</div>
        <table class="w-full">
          <thead><tr><th class="table-th">File</th><th class="table-th">Rows</th><th class="table-th">Imported</th><th class="table-th">Failed</th><th class="table-th">Date</th></tr></thead>
          <tbody>
            <tr v-for="i in imports" :key="i.id">
              <td class="table-td font-medium">{{ i.filename }}</td>
              <td class="table-td">{{ i.total_rows }}</td>
              <td class="table-td text-accent-500 font-semibold">{{ i.imported_rows }}</td>
              <td class="table-td text-red-600">{{ i.failed_rows }}</td>
              <td class="table-td text-ink-500">{{ formatDateTime(i.created_at) }}</td>
            </tr>
          </tbody>
        </table>
        <EmptyState v-if="!imports.length" icon="upload" title="No imports yet" subtitle="Upload a CSV to begin."/>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import Papa from 'papaparse'
const { supabase, workspaceId } = useWorkspace()
const attrs = ref<any[]>([])
const imports = ref<any[]>([])
const parsed = ref<any>(null)
const mapping = reactive<Record<string, string>>({})
const importing = ref(false)
const currentFile = ref('')

async function load() {
  if (!workspaceId.value) return
  const { data: a } = await supabase.from('customer_attributes_schema').select('*').eq('workspace_id', workspaceId.value).order('label')
  attrs.value = a || []
  const { data: im } = await supabase.from('imports').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false })
  imports.value = im || []
}
watch(workspaceId, load, { immediate: true })

function onFile(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (!file) return
  currentFile.value = file.name
  Papa.parse(file, {
    header: true, skipEmptyLines: true,
    complete: (result: any) => {
      const columns = result.meta.fields as string[]
      const rows = result.data as any[]
      parsed.value = { columns, rows, sample: rows[0] || {} }
      for (const col of columns) {
        const guess = attrs.value.find(a => a.key === col.toLowerCase() || a.label.toLowerCase() === col.toLowerCase())
        mapping[col] = guess ? guess.key : ''
      }
    }
  })
}

async function runImport() {
  if (!parsed.value) return
  importing.value = true
  const defaults = new Set(attrs.value.filter(a => a.is_default).map(a => a.key))
  const wid = workspaceId.value
  let ok = 0, fail = 0
  const batch: any[] = []
  for (const row of parsed.value.rows) {
    const rec: any = { workspace_id: wid, attributes: {} }
    for (const col of parsed.value.columns) {
      const target = mapping[col]
      const val = row[col]
      if (!target) continue
      if (target === '__custom__') {
        rec.attributes[col.toLowerCase().replace(/\s+/g, '_')] = val
      } else if (defaults.has(target)) {
        rec[target] = val
      } else {
        rec.attributes[target] = val
      }
    }
    if (!rec.external_id) rec.external_id = rec.email || `imp_${Math.random().toString(36).slice(2, 10)}`
    batch.push(rec)
  }
  const { error, data } = await supabase.from('customers').upsert(batch, { onConflict: 'workspace_id,external_id' }).select('id')
  if (error) fail = batch.length
  else ok = data?.length || 0
  await supabase.from('imports').insert({
    workspace_id: wid, filename: currentFile.value,
    total_rows: batch.length, imported_rows: ok, failed_rows: fail,
    mapping, status: error ? 'failed' : 'completed'
  })
  importing.value = false
  parsed.value = null
  await load()
}
</script>
