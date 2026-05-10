<template>
  <div>
    <PageHeader title="Campaigns" subtitle="One-off messages across email, push, SMS, and more.">
      <template #actions>
        <button v-if="role.can('campaigns', 'create')" @click="edit(null)" class="btn-primary"><Icon name="plus"/>New campaign</button>
        <div v-else class="chip bg-ink-100 text-ink-700 text-xs">View only</div>
      </template>
    </PageHeader>

    <div class="p-8 space-y-4">
      <div class="grid grid-cols-4 gap-4">
        <div v-for="s in stats" :key="s.label" class="card p-4">
          <div class="text-xs text-ink-500 font-semibold uppercase tracking-wider">{{ s.label }}</div>
          <div class="text-2xl font-bold text-ink-900 mt-1">{{ s.value }}</div>
          <div class="text-xs text-ink-500">{{ s.hint }}</div>
        </div>
      </div>

      <div class="card overflow-hidden">
        <table class="w-full">
          <thead><tr>
            <th class="table-th">Name</th><th class="table-th">Channel</th><th class="table-th">Status</th>
            <th class="table-th">Audience</th><th class="table-th">Sent</th><th class="table-th">Opens</th><th class="table-th">Clicks</th><th class="table-th">CTR</th><th class="table-th"></th>
          </tr></thead>
          <tbody>
            <tr v-for="c in campaigns" :key="c.id" class="hover:bg-ink-50 cursor-pointer" @click="edit(c)">
              <td class="table-td font-medium">{{ c.name }}</td>
              <td class="table-td"><span class="chip bg-brand-100/40 text-brand-700 capitalize">{{ c.channel }}</span></td>
              <td class="table-td"><span class="chip" :class="statusClass(c.status)">{{ c.status }}</span></td>
              <td class="table-td text-xs capitalize">{{ c.audience_type }}</td>
              <td class="table-td">{{ c.sent_count }}</td>
              <td class="table-td">{{ c.open_count }}</td>
              <td class="table-td">{{ c.click_count }}</td>
              <td class="table-td text-xs">{{ ctr(c) }}%</td>
              <td class="table-td text-right"><Icon name="chevronRight" class="text-ink-300"/></td>
            </tr>
          </tbody>
        </table>
        <EmptyState v-if="!campaigns.length" icon="send" title="No campaigns yet" subtitle="Create your first campaign to reach your users.">
          <button @click="edit(null)" class="btn-primary"><Icon name="plus"/>New campaign</button>
        </EmptyState>
      </div>
    </div>

    <Modal v-model="open" :title="editing?.id ? editing.name : 'New campaign'" :subtitle="editing?.id ? `Status: ${editing.status}` : ''" size="lg">
      <form id="cf" @submit.prevent="save" class="space-y-4">
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">Name *</label><input v-model="form.name" class="input" required/></div>
          <div><label class="label">Channel</label>
            <select v-model="form.channel" class="input">
              <option>email</option><option>push</option><option>sms</option><option>whatsapp</option>
            </select>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">Audience</label>
            <select v-model="form.audience_type" class="input">
              <option value="all">All customers</option>
              <option value="segment">Segment</option>
              <option value="list">List</option>
            </select>
          </div>
          <div v-if="form.audience_type === 'segment'">
            <label class="label">Segment</label>
            <select v-model="form.audience_id" class="input"><option value="">—</option><option v-for="s in segments" :key="s.id" :value="s.id">{{ s.name }}</option></select>
          </div>
          <div v-else-if="form.audience_type === 'list'">
            <label class="label">List</label>
            <select v-model="form.audience_id" class="input"><option value="">—</option><option v-for="l in lists" :key="l.id" :value="l.id">{{ l.name }}</option></select>
          </div>
          <div v-else class="text-sm text-ink-500 self-end pb-2">Audience preview: <span class="font-semibold text-ink-900">{{ audienceCount }} customers</span></div>
        </div>
        <div v-if="form.channel === 'email'"><label class="label">Subject</label><input v-model="form.subject" class="input"/></div>
        <div><label class="label">Message content</label><textarea v-model="form.content" rows="6" class="input font-mono text-sm" placeholder="Hi {{first_name}}, ..."></textarea></div>

        <div v-if="form.channel === 'email'" class="rounded-xl border border-ink-100 bg-ink-50/60 p-4">
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-2">
              <Icon name="shield" class="w-4 h-4 text-ink-500"/>
              <div class="font-semibold text-ink-900 text-sm">Deliverability score</div>
            </div>
            <div class="flex items-center gap-3">
              <div class="text-2xl font-bold" :class="scoreColor">{{ lintScore.score }}<span class="text-xs font-medium text-ink-500">/100</span></div>
              <span class="chip capitalize" :class="scoreChipClass">{{ lintScore.label }}</span>
            </div>
          </div>
          <div v-if="lintFindings.length" class="space-y-1">
            <div v-for="f in lintFindings" :key="f.code" class="flex items-start gap-2 text-xs">
              <span class="mt-0.5 w-1.5 h-1.5 rounded-full shrink-0" :class="f.severity === 'error' ? 'bg-red-500' : f.severity === 'warn' ? 'bg-amber-500' : 'bg-ink-300'"></span>
              <span :class="f.severity === 'error' ? 'text-red-700' : f.severity === 'warn' ? 'text-amber-700' : 'text-ink-700'">{{ f.message }}</span>
            </div>
          </div>
          <div v-else class="text-xs text-accent-500">No issues detected — looks good to send.</div>
          <div class="mt-3 pt-3 border-t border-ink-100 flex items-center gap-2">
            <input v-model="previewTo" type="email" placeholder="Send preview to (your email)" class="input !py-1.5 !text-xs flex-1"/>
            <button type="button" @click="sendPreview" :disabled="previewing || !previewTo" class="btn-secondary !py-1.5 !text-xs">{{ previewing ? 'Sending…' : 'Send preview to inbox' }}</button>
          </div>
        </div>
        <div class="grid grid-cols-3 gap-3">
          <div>
            <label class="label">Schedule</label>
            <input v-model="form.scheduled_at" type="datetime-local" class="input"/>
          </div>
          <div>
            <label class="label">Send-time mode</label>
            <select v-model="form.send_time_mode" class="input">
              <option value="immediate">Immediate / scheduled</option>
              <option value="optimized">Per-user optimized (STO)</option>
              <option value="timezone">Respect user timezone</option>
            </select>
            <div class="text-[11px] text-ink-500 mt-1">STO uses each user's past event times to pick the best delivery window.</div>
          </div>
          <div>
            <label class="label">Holdout %</label>
            <input v-model.number="form.holdout_percent" type="number" min="0" max="50" class="input"/>
            <div class="text-[11px] text-ink-500 mt-1">Portion of audience that receives nothing, used as a control group.</div>
          </div>
        </div>

        <div class="pt-4 border-t border-ink-100">
          <div class="flex items-center justify-between mb-3">
            <div>
              <div class="label !mb-0">A/B variants</div>
              <div class="text-[11px] text-ink-500">Split your audience across content variants and pick a winner by the metric below.</div>
            </div>
            <button type="button" @click="addVariant" class="btn-ghost text-xs"><Icon name="plus"/>Add variant</button>
          </div>
          <div v-if="!variants.length" class="text-xs text-ink-500 rounded-lg bg-ink-50 border border-dashed border-ink-100 p-3 text-center">No variants. All recipients get the content above.</div>
          <div v-else class="space-y-2">
            <div class="grid grid-cols-3 gap-3 items-end">
              <div>
                <label class="label">Strategy</label>
                <select v-model="form.variant_strategy" class="input">
                  <option value="random">Random split</option>
                  <option value="multivariate">Multivariate</option>
                  <option value="bandit">Multi-armed bandit</option>
                </select>
              </div>
              <div>
                <label class="label">Winner metric</label>
                <select v-model="form.winner_metric" class="input">
                  <option value="open_rate">Open rate</option>
                  <option value="click_rate">Click rate</option>
                  <option value="conversion_rate">Conversion rate</option>
                </select>
              </div>
              <div class="text-xs text-ink-500">Total weight: <span class="font-semibold text-ink-900">{{ variantTotalWeight }}</span></div>
            </div>
            <div v-for="(v, i) in variants" :key="i" class="rounded-xl border border-ink-100 p-3 space-y-2">
              <div class="flex items-center gap-2">
                <input v-model="v.label" class="input !py-1 !text-xs max-w-[120px] font-semibold" placeholder="A"/>
                <input v-model.number="v.weight" type="number" min="1" max="100" class="input !py-1 !text-xs max-w-[80px]"/>
                <span class="text-[10px] text-ink-500 uppercase tracking-wider">%</span>
                <div class="flex-1"></div>
                <span class="text-xs text-ink-500">sent {{ v.sent_count || 0 }} · open {{ v.open_count || 0 }} · click {{ v.click_count || 0 }}</span>
                <span v-if="v.is_winner" class="chip bg-accent-500/10 text-accent-500 text-[10px]">winner</span>
                <button type="button" @click="removeVariant(i)" class="text-ink-300 hover:text-red-600"><Icon name="trash"/></button>
              </div>
              <input v-if="form.channel === 'email'" v-model="v.subject" class="input !py-1 !text-xs" placeholder="Subject override"/>
              <input v-model="v.preview_text" class="input !py-1 !text-xs" placeholder="Preview text override"/>
              <textarea v-model="v.content" rows="3" class="input !py-1 !text-xs font-mono" placeholder="Content override. Leave blank to inherit the main content."></textarea>
            </div>
          </div>
        </div>

        <div v-if="editing?.id && recipients.length" class="pt-3 border-t border-ink-100">
          <div class="font-semibold text-ink-900 mb-2 text-sm">Recent recipients</div>
          <div class="max-h-40 overflow-y-auto text-xs space-y-1">
            <div v-for="r in recipients" :key="r.id" class="flex items-center justify-between py-1 border-b border-ink-100">
              <span>{{ r.customer?.email || r.customer_id }}</span>
              <span class="chip" :class="r.status === 'clicked' ? 'bg-accent-500/10 text-accent-500' : r.status === 'opened' ? 'bg-brand-100/40 text-brand-700' : 'bg-ink-100 text-ink-700'">{{ r.status }}</span>
            </div>
          </div>
        </div>
      </form>
      <template #footer>
        <button v-if="editing?.id && role.can('campaigns', 'delete')" @click="remove" class="btn-ghost text-red-600"><Icon name="trash"/></button>
        <button @click="open = false" class="btn-secondary">Close</button>
        <button v-if="(!editing?.id || editing.status === 'draft' || editing.status === 'scheduled') && role.can('campaigns', 'send')" @click="sendNow" :disabled="sending" class="btn-primary"><Icon name="send"/>{{ sending ? 'Sending…' : 'Save & send now' }}</button>
        <button v-else-if="editing?.id && !role.can('campaigns', 'send')" @click="askApproval" :disabled="requesting" class="btn-primary"><Icon name="shield"/>{{ requesting ? 'Requesting…' : 'Request approval' }}</button>
        <button form="cf" type="submit" class="btn-secondary">Save draft</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const { sendCampaign, resolveAudience } = useEngagement()
const role = useRole()
const audit = useAudit()
const { $supabase } = useNuxtApp()
const { lintEmail, scoreFromFindings } = useSpamLinter()
const previewTo = ref('')
const previewing = ref(false)
const requesting = ref(false)
const approvalFlash = ref('')
async function askApproval() {
  if (!editing.value?.id) return
  requesting.value = true
  try {
    await role.requestApproval('campaign', editing.value.id, editing.value.name, 'Send approval requested')
    await supabase.from('campaigns').update({ requires_approval: true, approval_status: 'pending' }).eq('id', editing.value.id)
    approvalFlash.value = 'Approval requested'
    open.value = false
    await load()
  } finally { requesting.value = false }
}
const campaigns = ref<any[]>([])
const segments = ref<any[]>([])
const lists = ref<any[]>([])
const open = ref(false)
const editing = ref<any>(null)
const sending = ref(false)
const recipients = ref<any[]>([])
const audienceCount = ref(0)
const form = reactive({
  name: '', channel: 'email', audience_type: 'all', audience_id: '',
  subject: '', content: '', scheduled_at: '',
  holdout_percent: 0, send_time_mode: 'immediate',
  variant_strategy: 'random', winner_metric: 'open_rate',
})
const variants = ref<any[]>([])
const variantTotalWeight = computed(() => variants.value.reduce((a, v) => a + (Number(v.weight) || 0), 0))
function addVariant() {
  const labels = ['A', 'B', 'C', 'D', 'E']
  const label = labels[variants.value.length] || String.fromCharCode(65 + variants.value.length)
  variants.value.push({ label, weight: 50, subject: '', preview_text: '', content: '', sent_count: 0, open_count: 0, click_count: 0, is_winner: false })
}
function removeVariant(i: number) { variants.value.splice(i, 1) }

const statusClass = (s: string) => ({ draft: 'bg-ink-100 text-ink-700', scheduled: 'bg-brand-100/40 text-brand-700', sent: 'bg-accent-500/10 text-accent-500', sending: 'bg-yellow-100 text-yellow-700' }[s] || 'bg-ink-100 text-ink-700')

const lintFindings = computed(() => form.channel === 'email' ? lintEmail({ subject: form.subject, html: form.content, channel: form.channel }) : [])
const lintScore = computed(() => scoreFromFindings(lintFindings.value))
const scoreColor = computed(() => ({ accent: 'text-accent-500', brand: 'text-brand-500', amber: 'text-amber-600', red: 'text-red-600' }[lintScore.value.tone] || 'text-ink-900'))
const scoreChipClass = computed(() => ({ accent: 'bg-accent-500/10 text-accent-500', brand: 'bg-brand-100/40 text-brand-700', amber: 'bg-amber-100 text-amber-700', red: 'bg-red-100 text-red-700' }[lintScore.value.tone] || 'bg-ink-100 text-ink-700'))

async function sendPreview() {
  if (!previewTo.value || !workspaceId.value) return
  previewing.value = true
  try {
    const { data: { session } } = await $supabase.auth.getSession()
    const url = `${useRuntimeConfig().public.supabaseUrl}/functions/v1/notify`
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${session?.access_token || useRuntimeConfig().public.supabaseAnonKey}`,
      },
      body: JSON.stringify({
        workspace_id: workspaceId.value,
        to_email: previewTo.value,
        kind: 'otp',
        title: `[PREVIEW] ${form.subject || form.name || 'Campaign'}`,
        body: form.content || '(empty body)',
        send_email: true,
        stream_override: 'transactional',
      }),
    })
    const json = await res.json().catch(() => ({}))
    if (json?.email?.sent) useToast().success('Preview sent', `Check ${previewTo.value}`)
    else useToast().error('Preview failed', json?.email?.error || json?.email?.status || 'Unknown error')
  } catch (e: any) {
    useToast().error('Preview failed', e?.message || '')
  } finally {
    previewing.value = false
  }
}
const ctr = (c: any) => c.sent_count ? ((c.click_count / c.sent_count) * 100).toFixed(1) : '0.0'

const stats = computed(() => {
  const total = campaigns.value.length
  const sent = campaigns.value.reduce((a, c) => a + (c.sent_count || 0), 0)
  const opens = campaigns.value.reduce((a, c) => a + (c.open_count || 0), 0)
  const clicks = campaigns.value.reduce((a, c) => a + (c.click_count || 0), 0)
  return [
    { label: 'Campaigns', value: total, hint: 'total' },
    { label: 'Messages sent', value: sent.toLocaleString(), hint: 'lifetime' },
    { label: 'Open rate', value: sent ? `${((opens/sent)*100).toFixed(1)}%` : '—', hint: `${opens} opens` },
    { label: 'Click rate', value: sent ? `${((clicks/sent)*100).toFixed(1)}%` : '—', hint: `${clicks} clicks` },
  ]
})

async function load() {
  if (!workspaceId.value) return
  const [c, s, l] = await Promise.all([
    supabase.from('campaigns').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('segments').select('id,name').eq('workspace_id', workspaceId.value),
    supabase.from('lists').select('id,name').eq('workspace_id', workspaceId.value),
  ])
  campaigns.value = c.data || []; segments.value = s.data || []; lists.value = l.data || []
}
async function edit(c: any) {
  editing.value = c
  recipients.value = []
  variants.value = []
  if (c) {
    Object.assign(form, {
      name: c.name, channel: c.channel, audience_type: c.audience_type, audience_id: c.audience_id || '',
      subject: c.subject, content: c.content, scheduled_at: c.scheduled_at ? c.scheduled_at.slice(0, 16) : '',
      holdout_percent: c.holdout_percent || 0, send_time_mode: c.send_time_mode || 'immediate',
      variant_strategy: c.variant_strategy || 'random', winner_metric: c.winner_metric || 'open_rate',
    })
    const [msgs, vars] = await Promise.all([
      supabase.from('campaign_messages').select('*, customer:customers(email)').eq('campaign_id', c.id).order('sent_at', { ascending: false }).limit(30),
      supabase.from('campaign_variants').select('*').eq('campaign_id', c.id).order('label'),
    ])
    recipients.value = msgs.data || []
    variants.value = vars.data || []
  } else {
    Object.assign(form, {
      name: '', channel: 'email', audience_type: 'all', audience_id: '',
      subject: '', content: '', scheduled_at: '',
      holdout_percent: 0, send_time_mode: 'immediate',
      variant_strategy: 'random', winner_metric: 'open_rate',
    })
  }
  open.value = true
  refreshAudience()
}
async function refreshAudience() {
  if (!workspaceId.value) return
  const ids = await resolveAudience(workspaceId.value, form.audience_type, form.audience_id || null)
  audienceCount.value = ids.length
}
watch(() => [form.audience_type, form.audience_id], refreshAudience)

async function buildPayload(): Promise<any> {
  return {
    name: form.name, channel: form.channel, audience_type: form.audience_type,
    audience_id: form.audience_id || null, subject: form.subject, content: form.content,
    scheduled_at: form.scheduled_at || null,
    holdout_percent: form.holdout_percent || 0,
    send_time_mode: form.send_time_mode,
    variant_strategy: form.variant_strategy,
    winner_metric: form.winner_metric,
    workspace_id: workspaceId.value,
    status: form.scheduled_at ? 'scheduled' : (editing.value?.status || 'draft'),
  }
}
async function persistVariants(campaignId: string) {
  await supabase.from('campaign_variants').delete().eq('campaign_id', campaignId)
  if (!variants.value.length) return
  const rows = variants.value.map((v: any) => ({
    campaign_id: campaignId,
    workspace_id: workspaceId.value,
    label: v.label || 'A',
    weight: Number(v.weight) || 0,
    subject: v.subject || null,
    preview_text: v.preview_text || null,
    content: v.content || null,
    sent_count: v.sent_count || 0,
    open_count: v.open_count || 0,
    click_count: v.click_count || 0,
    is_winner: !!v.is_winner,
  }))
  await supabase.from('campaign_variants').insert(rows)
}
async function save() {
  const payload = await buildPayload()
  let id = editing.value?.id
  if (id) {
    await supabase.from('campaigns').update(payload).eq('id', id)
  } else {
    const { data } = await supabase.from('campaigns').insert(payload).select().maybeSingle()
    id = data?.id
  }
  if (id) await persistVariants(id)
  audit.log(editing.value?.id ? 'update' : 'create', 'campaign', id || null, form.name, { channel: form.channel, variants: variants.value.length, holdout: form.holdout_percent })
  useToast().success('Campaign saved')
  open.value = false
  await load()
}
async function sendNow() {
  sending.value = true
  const payload = await buildPayload()
  let camp = editing.value
  if (camp?.id) {
    await supabase.from('campaigns').update(payload).eq('id', camp.id)
  } else {
    const { data } = await supabase.from('campaigns').insert(payload).select().maybeSingle()
    camp = data
  }
  if (camp?.id) await persistVariants(camp.id)
  if (camp) {
    await sendCampaign(camp)
    audit.log('send', 'campaign', camp.id, camp.name, { channel: camp.channel })
  }
  sending.value = false
  open.value = false
  await load()
}
async function remove() {
  const ok = await useConfirm().ask({ title: 'Delete this campaign?', message: 'All message records linked to it will also be removed.', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await supabase.from('campaign_messages').delete().eq('campaign_id', editing.value.id)
  await supabase.from('campaign_variants').delete().eq('campaign_id', editing.value.id)
  await supabase.from('campaigns').delete().eq('id', editing.value.id)
  audit.log('delete', 'campaign', editing.value.id, editing.value.name)
  useToast().success('Campaign deleted')
  open.value = false; await load()
}

watch(workspaceId, load, { immediate: true })
</script>
