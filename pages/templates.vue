<template>
  <div>
    <PageHeader title="Templates" subtitle="Reusable message templates for campaigns and journeys.">
      <template #actions>
        <button @click="edit(null)" class="btn-primary"><Icon name="plus"/>New template</button>
      </template>
    </PageHeader>

    <div class="p-8 space-y-4">
      <div class="flex gap-2 flex-wrap">
        <button @click="filter = ''" class="chip" :class="filter === '' ? 'bg-brand-500 text-white' : 'bg-white border border-ink-100 text-ink-700'">All ({{ templates.length }})</button>
        <button v-for="ch in channels" :key="ch" @click="filter = ch" class="chip capitalize" :class="filter === ch ? 'bg-brand-500 text-white' : 'bg-white border border-ink-100 text-ink-700'">{{ ch }}</button>
      </div>

      <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div v-for="t in filtered" :key="t.id" class="card hover:shadow-md cursor-pointer overflow-hidden group transition-all hover:-translate-y-0.5" @click="edit(t)">
          <div class="relative h-28 flex items-center justify-center text-white overflow-hidden" :class="channelGradient(t.channel)">
            <img :src="channelThumb(t.channel, t.category)" class="absolute inset-0 w-full h-full object-cover opacity-30 group-hover:opacity-40 group-hover:scale-105 transition-all duration-500" alt=""/>
            <div class="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent"></div>
            <div class="relative w-12 h-12 rounded-xl bg-white/15 backdrop-blur border border-white/20 flex items-center justify-center">
              <Icon :name="channelIcon(t.channel)" class="w-6 h-6"/>
            </div>
          </div>
          <div class="p-4">
            <div class="flex items-center justify-between">
              <div class="font-semibold text-ink-900 text-sm truncate">{{ t.name }}</div>
              <span class="chip bg-brand-100/40 text-brand-700 capitalize">{{ t.channel }}</span>
            </div>
            <div class="text-xs text-ink-500 mt-1">{{ t.category }}</div>
            <div class="text-xs text-ink-500 mt-2 line-clamp-2">{{ t.subject || t.content }}</div>
          </div>
        </div>
        <button @click="edit(null)" class="card p-5 border-dashed flex flex-col items-center justify-center text-ink-500 hover:text-brand-500 hover:border-brand-500 min-h-[200px]">
          <Icon name="plus"/><div class="mt-2 text-sm font-medium">Create template</div>
        </button>
      </div>
    </div>

    <Modal v-model="open" :title="editing?.id ? 'Edit template' : 'New template'" size="xl">
      <form id="tmpl" @submit.prevent="save" class="grid grid-cols-2 gap-5">
        <div class="space-y-3">
          <div class="grid grid-cols-2 gap-3">
            <div><label class="label">Name *</label><input v-model="form.name" class="input" required/></div>
            <div><label class="label">Channel</label>
              <select v-model="form.channel" class="input">
                <option>email</option><option>push</option><option>sms</option><option>whatsapp</option><option>inapp</option><option>onsite</option>
              </select>
            </div>
            <div><label class="label">Category</label>
              <select v-model="form.category" class="input">
                <option>general</option><option>onboarding</option><option>conversion</option><option>retention</option><option>transactional</option><option>promotional</option>
              </select>
            </div>
            <div v-if="form.channel === 'email'"><label class="label">Preview text</label><input v-model="form.preview_text" class="input"/></div>
          </div>
          <div v-if="form.channel === 'email'"><label class="label">Subject</label><input v-model="form.subject" class="input" placeholder="Hello {{first_name}}"/></div>
          <div>
            <label class="label">Content</label>
            <textarea v-model="form.content" rows="10" class="input font-mono text-sm" placeholder="Hi {{first_name}}, ..."></textarea>
            <div class="text-[11px] text-ink-500 mt-1">Liquid vars: <code class="bg-ink-50 px-1 rounded">&#123;&#123;first_name&#125;&#125;</code> <code class="bg-ink-50 px-1 rounded">&#123;&#123;attributes.wallet_balance_ngn&#125;&#125;</code> <code class="bg-ink-50 px-1 rounded">&#123;% if attributes.is_premium %&#125;...&#123;% endif %&#125;</code></div>
          </div>
          <div v-if="form.channel === 'email'" class="border-t border-ink-100 pt-3">
            <label class="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" v-model="ampEnabled"/>
              <span class="label !mb-0">Enable AMP for Email</span>
              <span class="chip bg-accent-500/10 text-accent-500 text-[10px]">Premium</span>
            </label>
            <div v-if="ampEnabled" class="mt-2">
              <textarea v-model="form.amp_html" rows="8" class="input font-mono text-sm" placeholder="<!doctype html>&#10;<html amp4email>&#10;  <head>...</head>&#10;  <body>...</body>&#10;</html>"></textarea>
              <div class="text-[11px] text-ink-500 mt-1">AMP-capable inboxes (Gmail, Yahoo) render the interactive version. Others fall back to HTML.</div>
            </div>
          </div>
        </div>

        <div class="space-y-3">
          <div class="flex items-center justify-between">
            <label class="label !mb-0">Live preview</label>
            <select v-model="previewCustomerId" class="input !py-1 !text-xs max-w-[220px]">
              <option value="">Sample customer</option>
              <option v-for="c in previewCustomers" :key="c.id" :value="c.id">{{ c.first_name }} {{ c.last_name }} · {{ c.email }}</option>
            </select>
          </div>
          <div class="rounded-xl border border-ink-100 overflow-hidden bg-white">
            <div v-if="form.channel === 'email'" class="bg-ink-50 p-4 border-b border-ink-100 text-xs">
              <div><span class="text-ink-500">From:</span> {{ auth.workspace?.name }}</div>
              <div class="mt-1"><span class="text-ink-500">Subject:</span> <strong>{{ previewSubject || '—' }}</strong></div>
              <div v-if="form.preview_text" class="mt-1 text-ink-500">{{ renderedPreviewText }}</div>
            </div>
            <div v-else-if="form.channel === 'push' || form.channel === 'inapp'" class="bg-ink-900 text-white p-4 text-sm flex items-start gap-3">
              <div class="w-9 h-9 rounded-lg flex items-center justify-center text-white font-bold" :style="{ background: auth.workspace?.brand_primary || '#3087B9' }">{{ (auth.workspace?.name || 'S')[0].toUpperCase() }}</div>
              <div class="flex-1">
                <div class="font-semibold text-sm">{{ auth.workspace?.name || 'App' }}</div>
                <div class="text-sm opacity-90 mt-0.5 whitespace-pre-wrap">{{ previewContent }}</div>
              </div>
            </div>
            <div v-else-if="form.channel === 'sms' || form.channel === 'whatsapp'" class="p-4">
              <div class="bg-accent-500/10 text-ink-900 text-sm rounded-2xl rounded-bl-sm p-3 max-w-[90%] whitespace-pre-wrap">{{ previewContent }}</div>
              <div class="text-[10px] text-ink-500 mt-1">{{ previewContent.length }} chars · ~{{ Math.ceil(previewContent.length / 160) }} SMS part(s)</div>
            </div>
            <div class="p-5">
              <div v-if="form.channel !== 'sms' && form.channel !== 'whatsapp'" class="text-sm text-ink-900 whitespace-pre-wrap leading-relaxed">{{ previewContent || 'Write your content on the left to see it here.' }}</div>
            </div>
          </div>
          <div class="card !shadow-none p-3 bg-ink-50 border border-ink-100">
            <div class="text-[10px] font-semibold text-ink-500 uppercase tracking-wider mb-2">Context</div>
            <pre class="text-[10px] text-ink-700 font-mono overflow-x-auto">{{ JSON.stringify(previewContext, null, 2) }}</pre>
          </div>
        </div>
      </form>
      <template #footer>
        <button v-if="editing?.id" @click="remove" class="btn-ghost text-red-600 mr-auto"><Icon name="trash"/>Delete</button>
        <button @click="open = false" class="btn-secondary">Cancel</button>
        <button form="tmpl" type="submit" class="btn-primary">Save</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId, auth } = useWorkspace()
const templates = ref<any[]>([])
const previewCustomers = ref<any[]>([])
const previewCustomerId = ref('')
const open = ref(false)
const editing = ref<any>(null)
const filter = ref('')
const channels = ['email','push','sms','whatsapp','inapp','onsite']
const form = reactive<any>({ name: '', channel: 'email', category: 'general', subject: '', content: '', preview_text: '', amp_html: '' })
const ampEnabled = ref(false)

const filtered = computed(() => filter.value ? templates.value.filter(t => t.channel === filter.value) : templates.value)
const channelIcon = (c: string) => ({ email: 'mail', push: 'bell', sms: 'smartphone', whatsapp: 'smartphone', inapp: 'smartphone', onsite: 'monitor' }[c] || 'mail')
const channelGradient = (c: string) => ({
  email: 'bg-gradient-to-br from-brand-700 to-brand-500',
  push: 'bg-gradient-to-br from-accent-600 to-accent-500',
  sms: 'bg-gradient-to-br from-emerald-700 to-emerald-500',
  whatsapp: 'bg-gradient-to-br from-green-700 to-green-500',
  inapp: 'bg-gradient-to-br from-rose-700 to-rose-500',
  onsite: 'bg-gradient-to-br from-amber-700 to-amber-500',
}[c] || 'bg-gradient-to-br from-brand-700 to-brand-500')
const categoryImages: Record<string, string> = {
  onboarding: 'https://images.pexels.com/photos/3184292/pexels-photo-3184292.jpeg?auto=compress&cs=tinysrgb&w=600',
  conversion: 'https://images.pexels.com/photos/3943716/pexels-photo-3943716.jpeg?auto=compress&cs=tinysrgb&w=600',
  retention: 'https://images.pexels.com/photos/3184405/pexels-photo-3184405.jpeg?auto=compress&cs=tinysrgb&w=600',
  transactional: 'https://images.pexels.com/photos/4386321/pexels-photo-4386321.jpeg?auto=compress&cs=tinysrgb&w=600',
  promotional: 'https://images.pexels.com/photos/5632402/pexels-photo-5632402.jpeg?auto=compress&cs=tinysrgb&w=600',
  general: 'https://images.pexels.com/photos/3184418/pexels-photo-3184418.jpeg?auto=compress&cs=tinysrgb&w=600',
}
const channelThumb = (_c: string, cat: string) => categoryImages[cat] || categoryImages.general

const previewContext = computed(() => {
  const cust = previewCustomers.value.find((c: any) => c.id === previewCustomerId.value)
  return sampleContext(cust)
})
const previewSubject = computed(() => renderLiquid(form.subject, previewContext.value))
const previewContent = computed(() => renderLiquid(form.content, previewContext.value))
const renderedPreviewText = computed(() => renderLiquid(form.preview_text, previewContext.value))

async function load() {
  if (!workspaceId.value) return
  const [t, c] = await Promise.all([
    supabase.from('templates').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('customers').select('id, first_name, last_name, email, phone, city, country, attributes').eq('workspace_id', workspaceId.value).limit(12),
  ])
  templates.value = t.data || []
  previewCustomers.value = c.data || []
}
function edit(t: any) {
  editing.value = t
  if (t) Object.assign(form, { name: t.name, channel: t.channel, category: t.category, subject: t.subject, content: t.content, preview_text: t.preview_text, amp_html: t.amp_html || '' })
  else Object.assign(form, { name: '', channel: 'email', category: 'general', subject: '', content: '', preview_text: '', amp_html: '' })
  ampEnabled.value = !!(t?.amp_html)
  open.value = true
}
async function save() {
  const payload = { ...form, amp_html: ampEnabled.value ? form.amp_html : '', workspace_id: workspaceId.value }
  const res = editing.value?.id
    ? await supabase.from('templates').update(payload).eq('id', editing.value.id).select().maybeSingle()
    : await supabase.from('templates').insert(payload).select().maybeSingle()
  if (res.error) { useToast().error('Could not save', res.error.message); return }
  useAudit().log(editing.value?.id ? 'update' : 'create', 'template', res.data?.id || null, form.name, { channel: form.channel })
  useToast().success('Template saved')
  open.value = false; await load()
}
async function remove() {
  const ok = await useConfirm().ask({ title: 'Delete this template?', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await supabase.from('templates').delete().eq('id', editing.value.id)
  useAudit().log('delete', 'template', editing.value.id, editing.value.name)
  useToast().success('Template deleted')
  open.value = false; await load()
}
watch(workspaceId, load, { immediate: true })
</script>
