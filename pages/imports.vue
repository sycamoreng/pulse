<template>
  <div>
    <PageHeader title="Imports" subtitle="Upload a CSV of customers. Pulse will auto-map columns to attributes and show you progress and any failures.">
      <template #actions>
        <label class="btn-primary cursor-pointer">
          <Icon name="upload"/>
          <span>{{ parsed ? 'Choose a different file' : 'Upload CSV' }}</span>
          <input type="file" accept=".csv,text/csv" class="hidden" @change="onFile"/>
        </label>
      </template>
    </PageHeader>

    <div class="p-8 space-y-6">
      <TestModeStrip what="Imports" message="Imported rows only populate this test workspace. Use this to preview mappings without touching production customer data."/>
      <div v-if="parseError" class="card p-4 border-red-200 bg-red-50 dark:bg-red-950/30 dark:border-red-900/50 text-red-700 dark:text-red-300 text-sm flex items-start gap-3">
        <Icon name="alert"/>
        <div>
          <div class="font-semibold">We couldn't read that file</div>
          <div>{{ parseError }}</div>
        </div>
      </div>

      <div v-if="parsed" class="card p-6 space-y-5">
        <div class="flex items-start justify-between gap-6 flex-wrap">
          <div>
            <div class="font-semibold text-ink-900">{{ currentFile }}</div>
            <div class="text-xs text-ink-500 mt-0.5">{{ parsed.rows.length }} rows detected, {{ parsed.columns.length }} columns</div>
          </div>
          <div class="text-xs text-ink-500 flex items-center gap-4">
            <span class="inline-flex items-center gap-1.5"><span class="w-2 h-2 rounded-full bg-accent-500"></span>{{ mappedCount }} mapped</span>
            <span class="inline-flex items-center gap-1.5"><span class="w-2 h-2 rounded-full bg-ink-300"></span>{{ parsed.columns.length - mappedCount }} skipped</span>
          </div>
        </div>

        <div>
          <div class="font-semibold text-ink-900 text-sm mb-1">Map your columns</div>
          <div class="text-xs text-ink-500 mb-3">We guessed a mapping from column names. Anything set to <em>Custom attribute</em> will be stored under <code class="text-[11px]">attributes</code>.</div>
          <div class="grid md:grid-cols-2 gap-3">
            <div v-for="col in parsed.columns" :key="col" class="flex items-center gap-3 p-3 border border-ink-100 dark:border-ink-700 rounded-lg bg-white dark:bg-ink-900">
              <div class="flex-1 min-w-0">
                <div class="text-[11px] text-ink-500 uppercase tracking-wide">CSV column</div>
                <div class="font-semibold text-ink-900 text-sm truncate">{{ col }}</div>
                <div class="text-[11px] text-ink-500 font-mono truncate">e.g. {{ formatSample(parsed.sample[col]) }}</div>
              </div>
              <Icon name="arrowRight" class="text-ink-300 shrink-0"/>
              <select v-model="mapping[col]" class="input w-44 shrink-0">
                <option value="">— skip —</option>
                <option value="__custom__">Custom attribute</option>
                <option v-for="a in attrs" :key="a.id" :value="a.key">{{ a.label }}</option>
              </select>
            </div>
          </div>
        </div>

        <div v-if="previewRows.length" class="border border-ink-100 dark:border-ink-700 rounded-lg overflow-hidden">
          <div class="px-3 py-2 text-xs font-semibold text-ink-500 bg-ink-50 dark:bg-ink-900/40 border-b border-ink-100 dark:border-ink-700">Preview (first {{ previewRows.length }} rows)</div>
          <div class="overflow-x-auto">
            <table class="w-full text-xs">
              <thead><tr>
                <th v-for="col in parsed.columns" :key="col" class="px-3 py-2 text-left font-semibold text-ink-900 whitespace-nowrap">{{ col }}</th>
              </tr></thead>
              <tbody>
                <tr v-for="(r, idx) in previewRows" :key="idx" class="border-t border-ink-100 dark:border-ink-700">
                  <td v-for="col in parsed.columns" :key="col" class="px-3 py-2 text-ink-700 whitespace-nowrap max-w-[220px] truncate">{{ formatSample(r[col]) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div v-if="importing" class="space-y-2">
          <div class="flex items-center justify-between text-xs text-ink-500">
            <span>Importing batch {{ progress.batchesDone }}/{{ progress.batchesTotal }}</span>
            <span>{{ progress.processed }}/{{ progress.total }} rows · {{ progress.succeeded }} ok · <span class="text-red-600">{{ progress.failed }} failed</span></span>
          </div>
          <div class="h-2 rounded-full bg-ink-100 dark:bg-ink-800 overflow-hidden">
            <div class="h-full bg-brand-500 transition-all duration-200" :style="{ width: progressPct + '%' }"></div>
          </div>
        </div>

        <div class="flex items-center justify-between pt-3 border-t border-ink-100 dark:border-ink-700">
          <div class="text-xs text-ink-500">
            <span v-if="!importing && mappedCount === 0" class="text-amber-600 dark:text-amber-400">Map at least one column to import.</span>
            <span v-else-if="!importing">Ready to import {{ parsed.rows.length }} rows.</span>
          </div>
          <div class="flex gap-2">
            <button @click="reset" :disabled="importing" class="btn-secondary">Cancel</button>
            <button @click="runImport" :disabled="importing || mappedCount === 0" class="btn-primary">
              <Icon v-if="importing" name="spinner" class="animate-spin"/>
              <span>{{ importing ? 'Importing…' : 'Import customers' }}</span>
            </button>
          </div>
        </div>
      </div>

      <div v-if="lastResult" class="card p-5" :class="lastResult.failed > 0 ? 'border-amber-200 dark:border-amber-900/50' : 'border-accent-200 dark:border-accent-900/50'">
        <div class="flex items-start gap-4">
          <div class="w-10 h-10 rounded-full flex items-center justify-center" :class="lastResult.failed > 0 ? 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300' : 'bg-accent-100 text-accent-700 dark:bg-accent-900/40 dark:text-accent-300'">
            <Icon :name="lastResult.failed > 0 ? 'alert' : 'check'"/>
          </div>
          <div class="flex-1">
            <div class="font-semibold text-ink-900">
              Imported {{ lastResult.succeeded }} of {{ lastResult.total }} customers
            </div>
            <div class="text-sm text-ink-500">
              <span v-if="lastResult.failed > 0">{{ lastResult.failed }} rows could not be imported.</span>
              <span v-else>All rows succeeded.</span>
            </div>
            <div v-if="lastResult.errors.length" class="mt-3 border border-red-200 dark:border-red-900/40 rounded-lg bg-red-50 dark:bg-red-950/20 p-3 max-h-56 overflow-auto">
              <div class="text-xs font-semibold text-red-700 dark:text-red-300 mb-1.5">First {{ lastResult.errors.length }} errors</div>
              <ul class="text-xs text-red-700 dark:text-red-300 space-y-1">
                <li v-for="(e, i) in lastResult.errors" :key="i">
                  <span class="font-mono">Row {{ e.row }}:</span> {{ e.message }}
                </li>
              </ul>
            </div>
          </div>
          <button class="text-xs text-ink-500 hover:text-ink-900" @click="lastResult = null">Dismiss</button>
        </div>
      </div>

      <div class="card overflow-hidden">
        <div class="px-4 py-3 border-b border-ink-100 dark:border-ink-700 font-semibold text-ink-900 flex items-center justify-between">
          <span>Past imports</span>
          <button @click="load" class="text-xs text-ink-500 hover:text-ink-900 inline-flex items-center gap-1">
            <Icon name="refresh"/><span>Refresh</span>
          </button>
        </div>
        <table v-if="imports.length" class="w-full">
          <thead><tr>
            <th class="table-th">File</th>
            <th class="table-th">Status</th>
            <th class="table-th">Rows</th>
            <th class="table-th">Imported</th>
            <th class="table-th">Failed</th>
            <th class="table-th">Date</th>
          </tr></thead>
          <tbody>
            <tr v-for="i in imports" :key="i.id">
              <td class="table-td font-medium">{{ i.filename }}</td>
              <td class="table-td">
                <span class="inline-flex items-center gap-1.5 text-xs font-medium px-2 py-0.5 rounded-full" :class="statusClass(i.status)">
                  <span class="w-1.5 h-1.5 rounded-full" :class="statusDot(i.status)"></span>
                  {{ i.status }}
                </span>
              </td>
              <td class="table-td">{{ i.total_rows }}</td>
              <td class="table-td text-accent-600 dark:text-accent-400 font-semibold">{{ i.imported_rows }}</td>
              <td class="table-td" :class="i.failed_rows > 0 ? 'text-red-600 dark:text-red-400 font-semibold' : 'text-ink-500'">{{ i.failed_rows }}</td>
              <td class="table-td text-ink-500">{{ formatDateTime(i.created_at) }}</td>
            </tr>
          </tbody>
        </table>
        <EmptyState v-else icon="upload" title="No imports yet" subtitle="Upload a CSV to add customers. We'll auto-detect columns and show you exactly what happened."/>
        <Pagination v-if="imports.length" v-model:page="importsPage" v-model:pageSize="importsPageSize" :total="importsTotal"/>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import Papa from 'papaparse'
const { supabase, workspaceId } = useWorkspace()
const toast = useToast()
const config = useRuntimeConfig()

const BATCH_SIZE = 200
const BULK_THRESHOLD = 1000
const BULK_CHUNK = 5000

type ParsedCsv = { columns: string[]; rows: Record<string, any>[]; sample: Record<string, any> }
type ImportError = { row: number; message: string }

const attrs = ref<any[]>([])
const imports = ref<any[]>([])
const importsPage = ref(1)
const importsPageSize = ref(25)
const importsTotal = ref(0)
const parsed = ref<ParsedCsv | null>(null)
const parseError = ref('')
const mapping = reactive<Record<string, string>>({})
const importing = ref(false)
const currentFile = ref('')
const progress = reactive({ total: 0, processed: 0, succeeded: 0, failed: 0, batchesTotal: 0, batchesDone: 0 })
const lastResult = ref<{ total: number; succeeded: number; failed: number; errors: ImportError[] } | null>(null)

const mappedCount = computed(() => parsed.value ? parsed.value.columns.filter(c => mapping[c]).length : 0)
const previewRows = computed(() => (parsed.value?.rows || []).slice(0, 5))
const progressPct = computed(() => progress.total === 0 ? 0 : Math.min(100, Math.round((progress.processed / progress.total) * 100)))

async function load() {
  if (!workspaceId.value) return
  const { data: a } = await supabase.from('customer_attributes_schema').select('*').eq('workspace_id', workspaceId.value).order('label')
  attrs.value = a || []
  const fromIdx = (importsPage.value - 1) * importsPageSize.value
  const toIdx = fromIdx + importsPageSize.value - 1
  const { data: im, count: imCount } = await supabase.from('imports').select('*', { count: 'exact' }).eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }).range(fromIdx, toIdx)
  imports.value = im || []
  importsTotal.value = imCount || 0
}
watch(importsPageSize, () => { importsPage.value = 1 })
watch([workspaceId, importsPage, importsPageSize], load, { immediate: true })

function reset() {
  parsed.value = null
  parseError.value = ''
  currentFile.value = ''
  Object.keys(mapping).forEach(k => delete mapping[k])
}

function guessMapping(col: string): string {
  const n = col.toLowerCase().trim().replace(/\s+/g, '_')
  const aliases: Record<string, string> = {
    'email_address': 'email',
    'e_mail': 'email',
    'mail': 'email',
    'phone_number': 'phone',
    'mobile': 'phone',
    'mobile_number': 'phone',
    'firstname': 'first_name',
    'first': 'first_name',
    'given_name': 'first_name',
    'lastname': 'last_name',
    'last': 'last_name',
    'family_name': 'last_name',
    'surname': 'last_name',
    'id': 'external_id',
    'user_id': 'external_id',
    'customer_id': 'external_id',
  }
  const target = aliases[n] || n
  const hit = attrs.value.find(a => a.key === target || a.label.toLowerCase() === col.toLowerCase())
  return hit ? hit.key : ''
}

function formatSample(v: unknown) {
  if (v === null || v === undefined || v === '') return '—'
  const s = String(v)
  return s.length > 60 ? s.slice(0, 60) + '…' : s
}

function onFile(e: Event) {
  const input = e.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return
  lastResult.value = null
  parseError.value = ''
  currentFile.value = file.name
  Papa.parse(file, {
    header: true,
    skipEmptyLines: true,
    complete: (result: any) => {
      const errs = (result.errors || []).filter((e: any) => e.code !== 'TooManyFields' && e.code !== 'TooFewFields')
      if (errs.length && (!result.data || !result.data.length)) {
        parseError.value = errs[0].message || 'Could not parse CSV'
        return
      }
      const columns = (result.meta.fields || []).filter(Boolean) as string[]
      const rows = (result.data as any[]).filter(r => r && Object.values(r).some(v => v !== null && v !== '' && v !== undefined))
      if (!columns.length || !rows.length) {
        parseError.value = 'The file is empty or has no header row.'
        return
      }
      parsed.value = { columns, rows, sample: rows[0] || {} }
      for (const col of columns) mapping[col] = guessMapping(col)
    },
    error: (err: any) => { parseError.value = err?.message || 'Could not read file' },
  })
}

const DEFAULT_CUSTOMER_COLUMNS = new Set([
  'external_id', 'email', 'phone', 'first_name', 'last_name',
  'country', 'city', 'device', 'platform', 'timezone', 'locale',
])

function buildRecord(row: Record<string, any>): any {
  if (!parsed.value) return null
  const rec: any = { workspace_id: workspaceId.value, attributes: {} }
  const defaults = new Set(attrs.value.filter(a => a.is_default).map(a => a.key))
  for (const col of parsed.value.columns) {
    const target = mapping[col]
    const val = row[col]
    if (!target) continue
    if (val === undefined || val === null || val === '') continue
    if (target === '__custom__') {
      rec.attributes[col.toLowerCase().trim().replace(/\s+/g, '_')] = val
    } else if (defaults.has(target) || DEFAULT_CUSTOMER_COLUMNS.has(target)) {
      rec[target] = val
    } else {
      rec.attributes[target] = val
    }
  }
  if (!rec.external_id) rec.external_id = rec.email || rec.phone || null
  return rec
}

async function runImport() {
  if (!parsed.value || !workspaceId.value) return
  importing.value = true
  lastResult.value = null
  const allRows = parsed.value.rows
  progress.total = allRows.length
  progress.processed = 0
  progress.succeeded = 0
  progress.failed = 0
  progress.batchesTotal = 0
  progress.batchesDone = 0
  const errors: ImportError[] = []

  const { data: importRow } = await supabase.from('imports').insert({
    workspace_id: workspaceId.value,
    filename: currentFile.value,
    total_rows: allRows.length,
    imported_rows: 0,
    failed_rows: 0,
    mapping,
    status: 'running',
  }).select('id').maybeSingle()
  const importId = importRow?.id

  const useBulk = allRows.length >= BULK_THRESHOLD
  const chunkSize = useBulk ? BULK_CHUNK : BATCH_SIZE
  progress.batchesTotal = Math.ceil(allRows.length / chunkSize)

  if (useBulk) {
    const { data: { session } } = await supabase.auth.getSession()
    const token = session?.access_token
    const url = `${config.public.supabaseUrl}/functions/v1/bulk-ingest`
    for (let i = 0; i < allRows.length; i += chunkSize) {
      const chunk = allRows.slice(i, i + chunkSize)
      const records: any[] = []
      const recordRowIndex: number[] = []
      chunk.forEach((row, idx) => {
        const rec = buildRecord(row)
        const rowNumber = i + idx + 2
        if (!rec || !rec.external_id) {
          errors.length < 20 && errors.push({ row: rowNumber, message: 'No email, phone, or external id to identify the customer.' })
          progress.failed++
        } else {
          const { workspace_id: _w, ...rest } = rec
          records.push(rest)
          recordRowIndex.push(rowNumber)
        }
      })
      if (records.length) {
        try {
          const res = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
            body: JSON.stringify({ workspace_id: workspaceId.value, customers: records }),
          })
          const json = await res.json()
          if (!res.ok || !json.ok) {
            progress.failed += records.length
            if (errors.length < 20) errors.push({ row: recordRowIndex[0], message: json.error || `HTTP ${res.status}` })
          } else {
            progress.succeeded += json.customers_upserted || records.length
            progress.failed += json.customers_failed || 0
            for (const e of (json.errors || [])) {
              if (errors.length < 20) errors.push({ row: recordRowIndex[0], message: e.message })
            }
          }
        } catch (e: any) {
          progress.failed += records.length
          if (errors.length < 20) errors.push({ row: recordRowIndex[0], message: e?.message || String(e) })
        }
      }
      progress.processed = Math.min(progress.total, i + chunk.length)
      progress.batchesDone++
      await nextTick()
    }
  } else {
    for (let i = 0; i < allRows.length; i += chunkSize) {
      const chunk = allRows.slice(i, i + chunkSize)
      const records: any[] = []
      const recordRowIndex: number[] = []
      chunk.forEach((row, idx) => {
        const rec = buildRecord(row)
        const rowNumber = i + idx + 2
        if (!rec || !rec.external_id) {
          errors.length < 20 && errors.push({ row: rowNumber, message: 'No email, phone, or external id to identify the customer.' })
          progress.failed++
        } else {
          records.push(rec)
          recordRowIndex.push(rowNumber)
        }
      })
      if (records.length) {
        const { data, error } = await supabase
          .from('customers')
          .upsert(records, { onConflict: 'workspace_id,external_id' })
          .select('id')
        if (error) {
          progress.failed += records.length
          if (errors.length < 20) errors.push({ row: recordRowIndex[0], message: error.message })
        } else {
          progress.succeeded += data?.length || records.length
        }
      }
      progress.processed = Math.min(progress.total, i + chunk.length)
      progress.batchesDone++
      await nextTick()
    }
  }

  if (importId) {
    await supabase.from('imports').update({
      imported_rows: progress.succeeded,
      failed_rows: progress.failed,
      status: progress.failed === 0 ? 'completed' : progress.succeeded === 0 ? 'failed' : 'partial',
    }).eq('id', importId)
  }

  lastResult.value = {
    total: progress.total,
    succeeded: progress.succeeded,
    failed: progress.failed,
    errors,
  }

  if (progress.failed === 0) toast.success('Import complete', `${progress.succeeded} customers added or updated.`)
  else if (progress.succeeded === 0) toast.error('Import failed', 'No rows were imported. See details below.')
  else toast.warning('Import finished with errors', `${progress.succeeded} imported, ${progress.failed} failed.`)

  importing.value = false
  reset()
  await load()
}

function statusClass(s: string) {
  switch (s) {
    case 'completed': return 'bg-accent-100 text-accent-700 dark:bg-accent-900/40 dark:text-accent-300'
    case 'partial': return 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300'
    case 'failed': return 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300'
    case 'running': return 'bg-brand-100 text-brand-700 dark:bg-brand-900/40 dark:text-brand-300'
    default: return 'bg-ink-100 text-ink-700 dark:bg-ink-800 dark:text-ink-300'
  }
}
function statusDot(s: string) {
  switch (s) {
    case 'completed': return 'bg-accent-500'
    case 'partial': return 'bg-amber-500'
    case 'failed': return 'bg-red-500'
    case 'running': return 'bg-brand-500 animate-pulse'
    default: return 'bg-ink-400'
  }
}
</script>
