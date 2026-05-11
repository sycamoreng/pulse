<template>
  <div>
    <PageHeader title="Surveys & NPS" subtitle="In-app micro-surveys for NPS, CSAT and feedback.">
      <template #actions>
        <button @click="openNew()" class="btn-primary"><Icon name="plus"/>New survey</button>
      </template>
    </PageHeader>

    <div class="p-8 space-y-6">
      <TestModeStrip what="Surveys" message="Responses captured in test mode are demo data and do not feed your production feedback dashboards."/>
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div class="card p-5">
          <div class="text-xs font-semibold text-ink-500 dark:text-[color:var(--text-tertiary)] uppercase tracking-wider">Active surveys</div>
          <div class="mt-3 text-3xl font-bold text-ink-900 dark:text-[color:var(--text-primary)]">{{ activeCount }}</div>
        </div>
        <div class="card p-5">
          <div class="text-xs font-semibold text-ink-500 dark:text-[color:var(--text-tertiary)] uppercase tracking-wider">Responses (30d)</div>
          <div class="mt-3 text-3xl font-bold text-ink-900 dark:text-[color:var(--text-primary)]">{{ totalResponses }}</div>
        </div>
        <div class="card p-5">
          <div class="text-xs font-semibold text-ink-500 dark:text-[color:var(--text-tertiary)] uppercase tracking-wider">NPS score</div>
          <div class="mt-3 text-3xl font-bold" :class="npsColor">{{ npsScore === null ? '—' : npsScore }}</div>
          <div class="text-xs text-ink-500 dark:text-[color:var(--text-tertiary)] mt-1">Promoters − Detractors</div>
        </div>
        <div class="card p-5">
          <div class="text-xs font-semibold text-ink-500 dark:text-[color:var(--text-tertiary)] uppercase tracking-wider">CSAT avg</div>
          <div class="mt-3 text-3xl font-bold text-ink-900 dark:text-[color:var(--text-primary)]">{{ csatAvg === null ? '—' : csatAvg }}<span class="text-base text-ink-500 dark:text-[color:var(--text-tertiary)]">/5</span></div>
        </div>
      </div>

      <div class="card">
        <div class="px-5 py-3 border-b border-ink-100 dark:border-[color:var(--border-subtle)] font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">Surveys</div>
        <template v-if="loading">
          <div class="p-4 space-y-2">
            <Skeleton v-for="i in 3" :key="i" height="72px" rounded="rounded-lg"/>
          </div>
        </template>
        <template v-else>
          <EmptyState v-if="!surveys.length" icon="activity" title="No surveys yet" subtitle="Create an NPS, CSAT or open-feedback survey to collect responses."/>
          <div v-else class="divide-y divide-ink-100 dark:divide-[color:var(--border-subtle)]">
            <div v-for="s in surveys" :key="s.id" class="p-4 hover:bg-ink-50 dark:hover:bg-[color:var(--surface-muted)] cursor-pointer" @click="select(s)">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 rounded-lg flex items-center justify-center" :class="typeBg(s.survey_type)">
                    <Icon :name="typeIcon(s.survey_type)"/>
                  </div>
                  <div>
                    <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">{{ s.name }}</div>
                    <div class="text-xs text-ink-500 dark:text-[color:var(--text-tertiary)] uppercase tracking-wider">{{ s.survey_type }} · {{ s.display_mode }}</div>
                  </div>
                </div>
                <div class="flex items-center gap-4">
                  <div class="text-right">
                    <div class="text-sm font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">{{ s.responses_count || 0 }}</div>
                    <div class="text-[10px] text-ink-500 dark:text-[color:var(--text-tertiary)] uppercase">responses</div>
                  </div>
                  <div class="text-right">
                    <div class="text-sm font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">{{ s.impressions || 0 }}</div>
                    <div class="text-[10px] text-ink-500 dark:text-[color:var(--text-tertiary)] uppercase">views</div>
                  </div>
                  <button
                    type="button"
                    class="btn-ghost text-xs"
                    :title="rowShareUrl(s)"
                    @click.stop="copyRowShare(s)"
                  ><Icon name="copy" class="w-3 h-3"/>Copy link</button>
                  <button
                    type="button"
                    class="btn-ghost text-xs"
                    @click.stop="openNew(s)"
                  ><Icon name="edit" class="w-3 h-3"/>Edit</button>
                  <button
                    type="button"
                    class="btn-ghost text-xs text-red-600 dark:text-red-400"
                    @click.stop="removeRow(s)"
                  ><Icon name="trash" class="w-3 h-3"/></button>
                  <button
                    type="button"
                    class="btn-ghost text-xs"
                    @click.stop="toggleStatus(s)"
                  >
                    <Icon :name="s.status === 'active' ? 'pause' : 'play'" class="w-3 h-3"/>
                    {{ s.status === 'active' ? 'Pause' : 'Activate' }}
                  </button>
                  <span class="chip" :class="s.status === 'active' ? 'bg-accent-500/10 text-accent-500' : 'bg-ink-100 dark:bg-[color:var(--surface-muted)] text-ink-700 dark:text-[color:var(--text-secondary)]'">{{ s.status }}</span>
                </div>
              </div>
            </div>
          </div>
        </template>
      </div>

      <div v-if="selected" class="card p-6">
        <div class="flex items-center justify-between mb-4 flex-wrap gap-3">
          <div>
            <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">Responses · {{ selected.name }}</div>
            <div class="text-xs text-ink-500 dark:text-[color:var(--text-tertiary)]">{{ selectedResponses.length }} responses · {{ selected.impressions || 0 }} views · response rate {{ responseRate }}%</div>
          </div>
          <div class="flex items-center gap-2 flex-wrap">
            <div class="flex items-center gap-1 bg-ink-50 dark:bg-[color:var(--surface-muted)] border border-ink-100 dark:border-[color:var(--border-subtle)] rounded-lg px-2 py-1 text-xs font-mono text-ink-700 dark:text-[color:var(--text-secondary)] max-w-[320px] truncate">
              <Icon name="route" class="w-3 h-3 shrink-0"/>
              <span class="truncate">{{ shareUrl }}</span>
            </div>
            <button class="btn-ghost text-xs" @click="copyShare"><Icon name="copy" class="w-3 h-3"/>{{ copied ? 'Copied' : 'Copy link' }}</button>
            <a :href="shareUrl" target="_blank" rel="noopener" class="btn-ghost text-xs"><Icon name="arrowRight" class="w-3 h-3"/>Open</a>
            <button class="btn-ghost text-xs" @click="exportCsv" :disabled="!selectedResponses.length"><Icon name="upload" class="w-3 h-3"/>Export CSV</button>
            <button @click="selected = null" class="btn-ghost text-xs">Close</button>
          </div>
        </div>

        <div v-if="selectedAnalytics" class="grid md:grid-cols-3 gap-4 mb-5">
          <div class="rounded-xl border border-ink-100 dark:border-[color:var(--border-subtle)] p-4">
            <div class="text-[11px] uppercase tracking-wider text-ink-500 dark:text-[color:var(--text-tertiary)] font-semibold">{{ selectedAnalytics.primaryLabel }}</div>
            <div class="mt-2 text-2xl font-bold" :class="selectedAnalytics.primaryColor">{{ selectedAnalytics.primaryValue }}</div>
            <div class="text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)] mt-0.5">{{ selectedAnalytics.primaryHint }}</div>
          </div>
          <div class="rounded-xl border border-ink-100 dark:border-[color:var(--border-subtle)] p-4 md:col-span-2">
            <div class="text-[11px] uppercase tracking-wider text-ink-500 dark:text-[color:var(--text-tertiary)] font-semibold mb-2">Distribution</div>
            <div v-if="!selectedAnalytics.distribution.length" class="text-xs text-ink-500 dark:text-[color:var(--text-tertiary)]">No scored responses yet.</div>
            <div v-else class="space-y-1.5">
              <div v-for="b in selectedAnalytics.distribution" :key="b.label" class="flex items-center gap-2 text-xs">
                <div class="w-10 font-medium text-ink-700 dark:text-[color:var(--text-secondary)]">{{ b.label }}</div>
                <div class="flex-1 h-2 rounded-full bg-ink-100 dark:bg-[color:var(--surface-muted)] overflow-hidden">
                  <div class="h-full" :style="{ width: (b.count / selectedAnalytics.maxCount * 100) + '%', background: b.color }"></div>
                </div>
                <div class="w-10 text-right font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">{{ b.count }}</div>
              </div>
            </div>
          </div>
        </div>
        <EmptyState v-if="!selectedResponses.length" icon="activity" title="No responses yet" subtitle="Responses appear here once customers submit the survey."/>
        <table v-else class="w-full text-sm">
          <thead>
            <tr>
              <th class="table-th">Customer</th>
              <th class="table-th" v-if="selected.survey_type !== 'open'">Score</th>
              <th class="table-th">Comment</th>
              <th class="table-th">When</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="r in selectedResponses" :key="r.id" class="hover:bg-ink-50 dark:hover:bg-[color:var(--surface-muted)]">
              <td class="table-td text-xs">{{ r.customer?.email || r.customer_id || 'anonymous' }}</td>
              <td class="table-td" v-if="selected.survey_type !== 'open'">
                <span class="chip" :class="scoreChip(selected.survey_type, r.score)">{{ r.score }}</span>
              </td>
              <td class="table-td text-xs text-ink-500 dark:text-[color:var(--text-tertiary)]">{{ r.comment || '—' }}</td>
              <td class="table-td text-xs text-ink-500 dark:text-[color:var(--text-tertiary)]">{{ timeAgo(r.created_at) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <Modal v-model="open" :title="editing ? 'Edit survey' : 'New survey'" subtitle="Collect targeted feedback from your users." size="lg">
      <form id="sv" @submit.prevent="save" class="space-y-3">
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">Name *</label><input v-model="form.name" class="input" required/></div>
          <div><label class="label">Type *</label>
            <select v-model="form.survey_type" class="input">
              <option value="nps">NPS (0–10)</option>
              <option value="csat">CSAT (1–5)</option>
              <option value="ces">CES (1–7)</option>
              <option value="open">Open feedback</option>
            </select>
          </div>
        </div>
        <div><label class="label">Question *</label><input v-model="form.question" class="input" required :placeholder="questionPlaceholder"/></div>
        <div><label class="label">Follow-up (optional)</label><input v-model="form.follow_up" class="input" placeholder="Tell us why?"/></div>
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">Display</label>
            <select v-model="form.display_mode" class="input">
              <option value="inapp">In-app modal</option>
              <option value="onsite">Web on-site</option>
              <option value="email">Email</option>
              <option value="link">Standalone link</option>
            </select>
          </div>
          <div><label class="label">Trigger event</label><input v-model="form.trigger_event" class="input font-mono" placeholder="e.g. purchase_completed"/></div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">Status</label>
            <select v-model="form.status" class="input">
              <option value="draft">Draft</option>
              <option value="active">Active</option>
              <option value="paused">Paused</option>
            </select>
          </div>
          <div><label class="label">Description</label><input v-model="form.description" class="input"/></div>
        </div>
        <div><label class="label">Thank-you message</label><input v-model="form.thank_you" class="input" placeholder="Thanks for your feedback!"/></div>

        <div class="rounded-xl border border-ink-100 dark:border-[color:var(--border-subtle)] p-4 bg-ink-50/60 dark:bg-[color:var(--surface-muted)]/60">
          <div class="flex items-center justify-between mb-3">
            <div>
              <div class="text-sm font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">Form builder</div>
              <div class="text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)]">Add fields in the order they should appear. The first numeric field drives NPS/CSAT/CES analytics.</div>
            </div>
            <div class="flex gap-1 flex-wrap justify-end">
              <button type="button" class="btn-ghost text-[11px]" @click="addField('scale')"><Icon name="plus" class="w-3 h-3"/>Scale</button>
              <button type="button" class="btn-ghost text-[11px]" @click="addField('rating')"><Icon name="plus" class="w-3 h-3"/>Emoji rating</button>
              <button type="button" class="btn-ghost text-[11px]" @click="addField('short_text')"><Icon name="plus" class="w-3 h-3"/>Short text</button>
              <button type="button" class="btn-ghost text-[11px]" @click="addField('long_text')"><Icon name="plus" class="w-3 h-3"/>Long text</button>
              <button type="button" class="btn-ghost text-[11px]" @click="addField('single_choice')"><Icon name="plus" class="w-3 h-3"/>Single choice</button>
              <button type="button" class="btn-ghost text-[11px]" @click="addField('multi_choice')"><Icon name="plus" class="w-3 h-3"/>Multi choice</button>
              <button type="button" class="btn-ghost text-[11px]" @click="addField('email')"><Icon name="plus" class="w-3 h-3"/>Email</button>
              <button type="button" class="btn-ghost text-[11px]" @click="addField('number')"><Icon name="plus" class="w-3 h-3"/>Number</button>
            </div>
          </div>

          <div v-if="!form.form_schema.length" class="text-xs text-ink-500 dark:text-[color:var(--text-tertiary)] bg-white dark:bg-[color:var(--surface-card)] rounded-lg border border-dashed border-ink-200 dark:border-[color:var(--border-subtle)] p-4 text-center">
            No custom fields — this survey will use the default {{ form.survey_type.toUpperCase() }} layout built from the "Question" above.
          </div>

          <div v-else class="space-y-2">
            <div v-for="(f, idx) in form.form_schema" :key="f.id" class="bg-white dark:bg-[color:var(--surface-card)] rounded-lg border border-ink-100 dark:border-[color:var(--border-subtle)] p-3">
              <div class="flex items-center gap-2 mb-2">
                <span class="chip text-[10px] bg-ink-100 dark:bg-[color:var(--surface-muted)] text-ink-700 dark:text-[color:var(--text-secondary)] capitalize">{{ f.type.replace('_', ' ') }}</span>
                <input v-model="f.label" class="input !py-1 !text-xs flex-1" placeholder="Question label"/>
                <label class="text-[11px] text-ink-600 dark:text-[color:var(--text-secondary)] flex items-center gap-1"><input type="checkbox" v-model="f.required" class="accent-brand-500"/>Required</label>
                <button type="button" class="btn-ghost text-[11px]" :disabled="idx === 0" @click="moveField(idx, -1)"><Icon name="arrow-left" class="w-3 h-3 -rotate-90"/></button>
                <button type="button" class="btn-ghost text-[11px]" :disabled="idx === form.form_schema.length - 1" @click="moveField(idx, 1)"><Icon name="arrow-left" class="w-3 h-3 rotate-90"/></button>
                <button type="button" class="btn-ghost text-[11px] text-red-600 dark:text-red-400" @click="removeField(idx)"><Icon name="trash" class="w-3 h-3"/></button>
              </div>
              <div class="grid grid-cols-2 gap-2">
                <input v-if="['short_text','long_text','email','number'].includes(f.type)" v-model="f.placeholder" class="input !py-1 !text-xs" placeholder="Placeholder"/>
                <input v-model="f.help" class="input !py-1 !text-xs" placeholder="Help text (optional)"/>
                <template v-if="f.type === 'scale' || f.type === 'number'">
                  <input v-model.number="f.min" type="number" class="input !py-1 !text-xs" placeholder="Min"/>
                  <input v-model.number="f.max" type="number" class="input !py-1 !text-xs" placeholder="Max"/>
                </template>
                <template v-if="f.type === 'scale'">
                  <input v-model="f.min_label" class="input !py-1 !text-xs" placeholder="Low label"/>
                  <input v-model="f.max_label" class="input !py-1 !text-xs" placeholder="High label"/>
                </template>
                <template v-if="f.type === 'rating'">
                  <input v-model.number="f.max" type="number" min="2" max="10" class="input !py-1 !text-xs" placeholder="Stars/emojis"/>
                </template>
                <div v-if="['single_choice','multi_choice'].includes(f.type)" class="col-span-2">
                  <label class="text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)]">Options (one per line)</label>
                  <textarea :value="(f.options || []).join('\n')" @input="e => f.options = (e.target as HTMLTextAreaElement).value.split('\n').map(s => s.trim()).filter(Boolean)" rows="3" class="input !py-1 !text-xs"></textarea>
                </div>
              </div>
            </div>
          </div>
        </div>
      </form>
      <template #footer>
        <button v-if="editing" @click="remove" class="btn-ghost text-red-600 dark:text-red-400 mr-auto"><Icon name="trash"/>Delete</button>
        <button @click="open = false" class="btn-secondary">Cancel</button>
        <button form="sv" type="submit" class="btn-primary">{{ editing ? 'Save' : 'Create survey' }}</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const toast = useToast()
const confirmD = useConfirm()
const audit = useAudit()

const surveys = ref<any[]>([])
const responses = ref<any[]>([])
const loading = ref(true)
const open = ref(false)
const editing = ref<any>(null)
const selected = ref<any>(null)
const selectedResponses = ref<any[]>([])

const form = reactive<any>({
  name: '', survey_type: 'nps', question: '', follow_up: 'Tell us why?', display_mode: 'inapp',
  trigger_event: '', status: 'draft', description: '', thank_you: 'Thanks for your feedback!',
  form_schema: [] as any[],
})

const copied = ref(false)

function fieldDefaults(type: string): any {
  const id = 'f_' + Math.random().toString(36).slice(2, 9)
  const base: any = { id, type, label: '', required: false, help: '' }
  if (type === 'scale') Object.assign(base, { label: 'On a scale, how would you rate…', min: 0, max: 10, min_label: 'Low', max_label: 'High' })
  if (type === 'rating') Object.assign(base, { label: 'How satisfied are you?', max: 5 })
  if (type === 'short_text') Object.assign(base, { label: 'Your answer', placeholder: '' })
  if (type === 'long_text') Object.assign(base, { label: 'Tell us more', placeholder: '' })
  if (type === 'single_choice' || type === 'multi_choice') Object.assign(base, { label: 'Pick one', options: ['Option 1', 'Option 2'] })
  if (type === 'email') Object.assign(base, { label: 'Email address' })
  if (type === 'number') Object.assign(base, { label: 'Enter a number' })
  return base
}
function addField(type: string) { form.form_schema.push(fieldDefaults(type)) }
function removeField(idx: number) { form.form_schema.splice(idx, 1) }
function moveField(idx: number, dir: number) {
  const target = idx + dir
  if (target < 0 || target >= form.form_schema.length) return
  const [f] = form.form_schema.splice(idx, 1)
  form.form_schema.splice(target, 0, f)
}

function rowShareUrl(s: any) {
  if (!s?.id) return ''
  if (typeof window === 'undefined') return `/s/${s.id}`
  return `${window.location.origin}/s/${s.id}`
}
async function copyRowShare(s: any) {
  const url = rowShareUrl(s)
  try {
    await navigator.clipboard.writeText(url)
    toast.success('Link copied', url)
  } catch {
    toast.success('Share link', url)
  }
}

const shareUrl = computed(() => {
  if (!selected.value) return ''
  if (typeof window === 'undefined') return `/s/${selected.value.id}`
  return `${window.location.origin}/s/${selected.value.id}`
})
async function copyShare() {
  if (!shareUrl.value) return
  try {
    await navigator.clipboard.writeText(shareUrl.value)
    copied.value = true
    setTimeout(() => (copied.value = false), 1500)
  } catch {
    toast.success('Share link', shareUrl.value)
  }
}
const responseRate = computed(() => {
  const imp = Number(selected.value?.impressions || 0)
  const resp = selectedResponses.value.length
  if (!imp) return 0
  return Math.round((resp / imp) * 100)
})

const selectedAnalytics = computed(() => {
  if (!selected.value) return null
  const type = selected.value.survey_type
  const scored = selectedResponses.value.filter((r: any) => r.score !== null && r.score !== undefined)
  if (type === 'nps') {
    const promoters = scored.filter((r: any) => r.score >= 9).length
    const passives = scored.filter((r: any) => r.score >= 7 && r.score <= 8).length
    const detractors = scored.filter((r: any) => r.score <= 6).length
    const score = scored.length ? Math.round(((promoters - detractors) / scored.length) * 100) : null
    const label = score === null ? '—' : score >= 50 ? 'Great' : score >= 0 ? 'Fair' : 'Needs work'
    const color = score === null ? 'text-ink-900 dark:text-[color:var(--text-primary)]' : score >= 50 ? 'text-accent-500' : score >= 0 ? 'text-yellow-600 dark:text-yellow-400' : 'text-red-600 dark:text-red-400'
    const buckets = Array.from({ length: 11 }, (_, i) => i)
    const distribution = buckets.map(n => ({
      label: String(n),
      count: scored.filter((r: any) => r.score === n).length,
      color: n >= 9 ? '#26C165' : n >= 7 ? '#F59E0B' : '#EF4444',
    }))
    return {
      primaryLabel: 'NPS score',
      primaryValue: score ?? '—',
      primaryHint: `${label} · ${promoters} promoters / ${passives} passives / ${detractors} detractors`,
      primaryColor: color,
      distribution,
      maxCount: Math.max(1, ...distribution.map(b => b.count)),
    }
  }
  if (type === 'csat') {
    const avg = scored.length ? (scored.reduce((a: number, b: any) => a + b.score, 0) / scored.length).toFixed(2) : null
    const distribution = [1, 2, 3, 4, 5].map(n => ({
      label: ['1 · 😞','2 · 😐','3 · 🙂','4 · 😀','5 · 🤩'][n - 1],
      count: scored.filter((r: any) => r.score === n).length,
      color: n >= 4 ? '#26C165' : n === 3 ? '#F59E0B' : '#EF4444',
    }))
    return {
      primaryLabel: 'CSAT average',
      primaryValue: avg === null ? '—' : `${avg}/5`,
      primaryHint: `${scored.length} scored responses`,
      primaryColor: 'text-ink-900 dark:text-[color:var(--text-primary)]',
      distribution,
      maxCount: Math.max(1, ...distribution.map(b => b.count)),
    }
  }
  if (type === 'ces') {
    const avg = scored.length ? (scored.reduce((a: number, b: any) => a + b.score, 0) / scored.length).toFixed(2) : null
    const distribution = [1, 2, 3, 4, 5, 6, 7].map(n => ({
      label: String(n),
      count: scored.filter((r: any) => r.score === n).length,
      color: n >= 6 ? '#26C165' : n >= 4 ? '#F59E0B' : '#EF4444',
    }))
    return {
      primaryLabel: 'CES average',
      primaryValue: avg === null ? '—' : `${avg}/7`,
      primaryHint: `${scored.length} scored responses`,
      primaryColor: 'text-ink-900 dark:text-[color:var(--text-primary)]',
      distribution,
      maxCount: Math.max(1, ...distribution.map(b => b.count)),
    }
  }
  return null
})

function exportCsv() {
  if (!selected.value || !selectedResponses.value.length) return
  const rows = [['id', 'customer_id', 'email', 'score', 'answer', 'comment', 'answers', 'created_at']]
  for (const r of selectedResponses.value) {
    rows.push([
      r.id,
      r.customer_id || '',
      r.customer?.email || '',
      r.score ?? '',
      (r.answer || '').replace(/"/g, '""'),
      (r.comment || '').replace(/"/g, '""'),
      JSON.stringify(r.answers || {}).replace(/"/g, '""'),
      r.created_at,
    ])
  }
  const csv = rows.map(row => row.map(v => `"${String(v ?? '')}"`).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `${selected.value.name.replace(/[^a-z0-9]+/gi, '_')}_responses.csv`
  a.click()
  URL.revokeObjectURL(url)
}

const questionPlaceholder = computed(() => ({
  nps: 'How likely are you to recommend Sycamore to a friend?',
  csat: 'How satisfied are you with your recent experience?',
  ces: 'How easy was it to complete your task?',
  open: 'What could we do better?',
} as any)[form.survey_type])

function typeIcon(t: string) { return ({ nps: 'trending', csat: 'activity', ces: 'filter', open: 'copy' } as any)[t] || 'activity' }
function typeBg(t: string) {
  return ({
    nps: 'bg-brand-100/40 text-brand-500',
    csat: 'bg-accent-500/10 text-accent-500',
    ces: 'bg-yellow-100 dark:bg-yellow-500/15 text-yellow-700 dark:text-yellow-400',
    open: 'bg-ink-100 dark:bg-[color:var(--surface-muted)] text-ink-700 dark:text-[color:var(--text-secondary)]',
  } as any)[t] || 'bg-ink-100 dark:bg-[color:var(--surface-muted)] text-ink-700 dark:text-[color:var(--text-secondary)]'
}
function scoreChip(type: string, score: number) {
  if (type === 'nps') return score >= 9 ? 'bg-accent-500/10 text-accent-500' : score >= 7 ? 'bg-yellow-100 dark:bg-yellow-500/15 text-yellow-700 dark:text-yellow-400' : 'bg-red-100 dark:bg-red-500/15 text-red-600 dark:text-red-400'
  if (type === 'csat') return score >= 4 ? 'bg-accent-500/10 text-accent-500' : score === 3 ? 'bg-yellow-100 dark:bg-yellow-500/15 text-yellow-700 dark:text-yellow-400' : 'bg-red-100 dark:bg-red-500/15 text-red-600 dark:text-red-400'
  return 'bg-ink-100 dark:bg-[color:var(--surface-muted)] text-ink-700 dark:text-[color:var(--text-secondary)]'
}

const activeCount = computed(() => surveys.value.filter((s: any) => s.status === 'active').length)
const totalResponses = computed(() => responses.value.length)
const npsScore = computed(() => {
  const npsResp = responses.value.filter((r: any) => surveys.value.find((s: any) => s.id === r.survey_id)?.survey_type === 'nps' && r.score !== null)
  if (!npsResp.length) return null
  const promoters = npsResp.filter((r: any) => r.score >= 9).length
  const detractors = npsResp.filter((r: any) => r.score <= 6).length
  return Math.round(((promoters - detractors) / npsResp.length) * 100)
})
const npsColor = computed(() => {
  const s = npsScore.value
  if (s === null) return 'text-ink-900 dark:text-[color:var(--text-primary)]'
  if (s >= 50) return 'text-accent-500'
  if (s >= 0) return 'text-yellow-600 dark:text-yellow-400'
  return 'text-red-600 dark:text-red-400'
})
const csatAvg = computed(() => {
  const r = responses.value.filter((r: any) => surveys.value.find((s: any) => s.id === r.survey_id)?.survey_type === 'csat' && r.score !== null)
  if (!r.length) return null
  return (r.reduce((a: number, b: any) => a + (b.score || 0), 0) / r.length).toFixed(2)
})

async function load() {
  if (!workspaceId.value) return
  loading.value = true
  const [s, r] = await Promise.all([
    supabase.from('surveys').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('survey_responses').select('*').eq('workspace_id', workspaceId.value).gte('created_at', new Date(Date.now() - 30*24*3600*1000).toISOString()),
  ])
  surveys.value = s.data || []
  responses.value = r.data || []
  loading.value = false
}

async function select(s: any) {
  selected.value = s
  const { data } = await supabase.from('survey_responses').select('*, customer:customers(email)').eq('survey_id', s.id).order('created_at', { ascending: false }).limit(100)
  selectedResponses.value = data || []
}

function openNew(s?: any) {
  editing.value = s || null
  Object.assign(form, s ? {
    name: s.name, survey_type: s.survey_type, question: s.question, follow_up: s.follow_up || '',
    display_mode: s.display_mode, trigger_event: s.trigger_event || '', status: s.status, description: s.description || '',
    thank_you: s.thank_you || 'Thanks for your feedback!',
    form_schema: Array.isArray(s.form_schema) ? JSON.parse(JSON.stringify(s.form_schema)) : [],
  } : {
    name: '', survey_type: 'nps', question: '', follow_up: 'Tell us why?',
    display_mode: 'inapp', trigger_event: '', status: 'draft', description: '',
    thank_you: 'Thanks for your feedback!',
    form_schema: [],
  })
  open.value = true
}

async function save() {
  const payload = { ...form, workspace_id: workspaceId.value }
  const { error, data } = editing.value
    ? await supabase.from('surveys').update(payload).eq('id', editing.value.id).select().maybeSingle()
    : await supabase.from('surveys').insert(payload).select().maybeSingle()
  if (error) { toast.error('Could not save', error.message); return }
  audit.log(editing.value ? 'update' : 'create', 'survey', data?.id || null, form.name, { survey_type: form.survey_type, status: form.status })
  toast.success(editing.value ? 'Survey updated' : 'Survey created')
  open.value = false
  await load()
}

async function remove() {
  if (!editing.value?.id) return
  await removeSurvey(editing.value)
  open.value = false
}

async function removeRow(s: any) {
  await removeSurvey(s)
}

async function removeSurvey(s: any) {
  const ok = await confirmD.ask({ title: `Delete "${s.name}"?`, message: 'All responses to this survey will also be removed. This cannot be undone.', tone: 'danger', confirmText: 'Delete survey' })
  if (!ok) return
  await supabase.from('survey_responses').delete().eq('survey_id', s.id)
  const { error } = await supabase.from('surveys').delete().eq('id', s.id)
  if (error) { toast.error('Could not delete', error.message); return }
  audit.log('delete', 'survey', s.id, s.name)
  if (selected.value?.id === s.id) selected.value = null
  toast.success('Survey deleted')
  await load()
}

async function toggleStatus(s: any) {
  const next = s.status === 'active' ? 'paused' : 'active'
  const { error } = await supabase.from('surveys').update({ status: next }).eq('id', s.id)
  if (error) { toast.error('Could not update', error.message); return }
  audit.log('update', 'survey', s.id, s.name, { status: next })
  toast.success(next === 'active' ? 'Survey activated' : 'Survey paused')
  await load()
  if (selected.value?.id === s.id) selected.value = { ...selected.value, status: next }
}

watch(workspaceId, load, { immediate: true })
</script>
