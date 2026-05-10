<template>
  <div>
    <PageHeader title="Surveys & NPS" subtitle="In-app micro-surveys for NPS, CSAT and feedback.">
      <template #actions>
        <button @click="openNew()" class="btn-primary"><Icon name="plus"/>New survey</button>
      </template>
    </PageHeader>

    <div class="p-8 space-y-6">
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div class="card p-5">
          <div class="text-xs font-semibold text-ink-500 uppercase tracking-wider">Active surveys</div>
          <div class="mt-3 text-3xl font-bold text-ink-900">{{ activeCount }}</div>
        </div>
        <div class="card p-5">
          <div class="text-xs font-semibold text-ink-500 uppercase tracking-wider">Responses (30d)</div>
          <div class="mt-3 text-3xl font-bold text-ink-900">{{ totalResponses }}</div>
        </div>
        <div class="card p-5">
          <div class="text-xs font-semibold text-ink-500 uppercase tracking-wider">NPS score</div>
          <div class="mt-3 text-3xl font-bold" :class="npsColor">{{ npsScore === null ? '—' : npsScore }}</div>
          <div class="text-xs text-ink-500 mt-1">Promoters − Detractors</div>
        </div>
        <div class="card p-5">
          <div class="text-xs font-semibold text-ink-500 uppercase tracking-wider">CSAT avg</div>
          <div class="mt-3 text-3xl font-bold text-ink-900">{{ csatAvg === null ? '—' : csatAvg }}<span class="text-base text-ink-500">/5</span></div>
        </div>
      </div>

      <div class="card">
        <div class="px-5 py-3 border-b border-ink-100 font-semibold text-ink-900">Surveys</div>
        <template v-if="loading">
          <div class="p-4 space-y-2">
            <Skeleton v-for="i in 3" :key="i" height="72px" rounded="rounded-lg"/>
          </div>
        </template>
        <template v-else>
          <EmptyState v-if="!surveys.length" icon="activity" title="No surveys yet" subtitle="Create an NPS, CSAT or open-feedback survey to collect responses."/>
          <div v-else class="divide-y divide-ink-100">
            <div v-for="s in surveys" :key="s.id" class="p-4 hover:bg-ink-50 cursor-pointer" @click="select(s)">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 rounded-lg flex items-center justify-center" :class="typeBg(s.survey_type)">
                    <Icon :name="typeIcon(s.survey_type)"/>
                  </div>
                  <div>
                    <div class="font-semibold text-ink-900">{{ s.name }}</div>
                    <div class="text-xs text-ink-500 uppercase tracking-wider">{{ s.survey_type }} · {{ s.display_mode }}</div>
                  </div>
                </div>
                <div class="flex items-center gap-4">
                  <div class="text-right">
                    <div class="text-sm font-semibold text-ink-900">{{ s.responses_count }}</div>
                    <div class="text-[10px] text-ink-500 uppercase">responses</div>
                  </div>
                  <span class="chip" :class="s.status === 'active' ? 'bg-accent-500/10 text-accent-500' : 'bg-ink-100 text-ink-700'">{{ s.status }}</span>
                </div>
              </div>
            </div>
          </div>
        </template>
      </div>

      <div v-if="selected" class="card p-6">
        <div class="flex items-center justify-between mb-4">
          <div>
            <div class="font-semibold text-ink-900">Responses · {{ selected.name }}</div>
            <div class="text-xs text-ink-500">{{ selectedResponses.length }} responses</div>
          </div>
          <button @click="selected = null" class="btn-ghost text-xs">Close</button>
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
            <tr v-for="r in selectedResponses" :key="r.id" class="hover:bg-ink-50">
              <td class="table-td text-xs">{{ r.customer?.email || r.customer_id || 'anonymous' }}</td>
              <td class="table-td" v-if="selected.survey_type !== 'open'">
                <span class="chip" :class="scoreChip(selected.survey_type, r.score)">{{ r.score }}</span>
              </td>
              <td class="table-td text-xs text-ink-500">{{ r.comment || '—' }}</td>
              <td class="table-td text-xs text-ink-500">{{ timeAgo(r.created_at) }}</td>
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

        <div class="card !shadow-none p-4 bg-ink-50 border border-ink-100">
          <div class="text-xs font-semibold text-ink-500 uppercase tracking-wider mb-3">Preview</div>
          <div class="bg-white rounded-xl border border-ink-100 p-4">
            <div class="text-sm font-semibold text-ink-900">{{ form.question || questionPlaceholder }}</div>
            <div v-if="form.survey_type === 'nps'" class="flex gap-1 mt-3 flex-wrap">
              <span v-for="n in 11" :key="n" class="w-8 h-8 rounded-md border border-ink-100 flex items-center justify-center text-xs font-medium hover:border-brand-500 cursor-pointer">{{ n - 1 }}</span>
            </div>
            <div v-else-if="form.survey_type === 'csat'" class="flex gap-2 mt-3">
              <span v-for="n in 5" :key="n" class="w-9 h-9 rounded-full border border-ink-100 flex items-center justify-center hover:border-brand-500 cursor-pointer">{{ ['😞','😐','🙂','😀','🤩'][n-1] }}</span>
            </div>
            <div v-else-if="form.survey_type === 'ces'" class="flex gap-1 mt-3 flex-wrap">
              <span v-for="n in 7" :key="n" class="w-8 h-8 rounded-md border border-ink-100 flex items-center justify-center text-xs">{{ n }}</span>
            </div>
            <textarea v-else class="input mt-3" rows="3" placeholder="Type your feedback…" disabled></textarea>
            <input v-if="form.follow_up" class="input mt-3" :placeholder="form.follow_up" disabled/>
          </div>
        </div>
      </form>
      <template #footer>
        <button v-if="editing" @click="remove" class="btn-ghost text-red-600 mr-auto"><Icon name="trash"/>Delete</button>
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

const form = reactive({
  name: '', survey_type: 'nps', question: '', follow_up: 'Tell us why?', display_mode: 'inapp',
  trigger_event: '', status: 'draft', description: '',
})

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
    ces: 'bg-yellow-100 text-yellow-700',
    open: 'bg-ink-100 text-ink-700',
  } as any)[t] || 'bg-ink-100 text-ink-700'
}
function scoreChip(type: string, score: number) {
  if (type === 'nps') return score >= 9 ? 'bg-accent-500/10 text-accent-500' : score >= 7 ? 'bg-yellow-100 text-yellow-700' : 'bg-red-100 text-red-600'
  if (type === 'csat') return score >= 4 ? 'bg-accent-500/10 text-accent-500' : score === 3 ? 'bg-yellow-100 text-yellow-700' : 'bg-red-100 text-red-600'
  return 'bg-ink-100 text-ink-700'
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
  if (s === null) return 'text-ink-900'
  if (s >= 50) return 'text-accent-500'
  if (s >= 0) return 'text-yellow-600'
  return 'text-red-600'
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
  if (selected.value?.id === s.id) { openNew(s); return }
  selected.value = s
  const { data } = await supabase.from('survey_responses').select('*, customer:customers(email)').eq('survey_id', s.id).order('created_at', { ascending: false }).limit(100)
  selectedResponses.value = data || []
}

function openNew(s?: any) {
  editing.value = s || null
  Object.assign(form, s ? {
    name: s.name, survey_type: s.survey_type, question: s.question, follow_up: s.follow_up || '',
    display_mode: s.display_mode, trigger_event: s.trigger_event || '', status: s.status, description: s.description || '',
  } : {
    name: '', survey_type: 'nps', question: '', follow_up: 'Tell us why?',
    display_mode: 'inapp', trigger_event: '', status: 'draft', description: '',
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
  const ok = await confirmD.ask({ title: 'Delete this survey?', message: 'Responses will also be removed.', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await supabase.from('surveys').delete().eq('id', editing.value.id)
  audit.log('delete', 'survey', editing.value.id, editing.value.name)
  toast.success('Survey deleted')
  open.value = false
  await load()
}

watch(workspaceId, load, { immediate: true })
</script>
