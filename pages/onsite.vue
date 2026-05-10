<template>
  <div>
    <PageHeader title="On-Site Messages" subtitle="Popups, bars, and slide-ins for your website.">
      <template #actions>
        <button @click="edit(null)" class="btn-primary"><Icon name="plus"/>New message</button>
      </template>
    </PageHeader>

    <div class="p-8 grid md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="m in messages" :key="m.id" class="card overflow-hidden hover:shadow-md cursor-pointer" @click="edit(m)">
        <div class="bg-gradient-to-br from-brand-700 to-brand-500 h-32 p-4 flex items-center justify-center relative">
          <div class="bg-white rounded-lg shadow-xl p-3 max-w-[80%]">
            <div class="text-xs font-bold text-ink-900 truncate">{{ m.title || 'Untitled' }}</div>
            <div class="text-[10px] text-ink-500 line-clamp-2 mt-0.5">{{ m.body }}</div>
            <div v-if="m.cta_text" class="mt-1.5 inline-block px-2 py-0.5 bg-brand-500 text-white rounded text-[10px]">{{ m.cta_text }}</div>
          </div>
        </div>
        <div class="p-4">
          <div class="flex items-center justify-between">
            <div class="font-semibold text-ink-900 text-sm truncate">{{ m.name }}</div>
            <span class="chip" :class="m.status === 'active' ? 'bg-accent-500/10 text-accent-500' : 'bg-ink-100 text-ink-700'">{{ m.status }}</span>
          </div>
          <div class="text-xs text-ink-500 mt-1 capitalize">{{ m.message_type }} · {{ m.position }}</div>
          <div class="mt-2 flex items-center gap-3 text-[11px] text-ink-500">
            <span><Icon name="monitor" class="inline"/> {{ m.impressions }} views</span>
            <span>{{ m.clicks }} clicks</span>
          </div>
        </div>
      </div>
      <button @click="edit(null)" class="card p-5 border-dashed flex flex-col items-center justify-center text-ink-500 hover:text-brand-500 hover:border-brand-500 min-h-[240px]">
        <Icon name="plus"/><div class="mt-2 text-sm font-medium">Create message</div>
      </button>
    </div>

    <Modal v-model="open" :title="editing?.id ? 'Edit on-site message' : 'New on-site message'" size="xl">
      <div class="grid grid-cols-2 gap-5">
        <form id="omf" @submit.prevent="save" class="space-y-3">
          <div class="grid grid-cols-2 gap-3">
            <div><label class="label">Name *</label><input v-model="form.name" class="input" required/></div>
            <div><label class="label">Type</label>
              <select v-model="form.message_type" class="input">
                <option value="popup">Popup</option><option value="bar">Top bar</option><option value="slide">Slide-in</option>
              </select>
            </div>
            <div><label class="label">Position</label>
              <select v-model="form.position" class="input">
                <option value="center">Center</option><option value="top">Top</option><option value="bottom">Bottom</option><option value="right">Right</option>
              </select>
            </div>
            <div><label class="label">Status</label>
              <select v-model="form.status" class="input"><option value="draft">Draft</option><option value="active">Active</option><option value="paused">Paused</option></select>
            </div>
            <div class="col-span-2"><label class="label">Title</label><input v-model="form.title" class="input"/></div>
            <div class="col-span-2"><label class="label">Body</label><textarea v-model="form.body" rows="3" class="input"></textarea></div>
            <div><label class="label">CTA text</label><input v-model="form.cta_text" class="input"/></div>
            <div><label class="label">CTA URL</label><input v-model="form.cta_url" class="input" type="url"/></div>
            <div class="col-span-2"><label class="label">Show on URL (contains)</label><input v-model="form.target_url" class="input" placeholder="/pricing"/></div>
          </div>
        </form>

        <div class="space-y-3">
          <label class="label !mb-0">Live preview</label>
          <div class="rounded-xl border border-ink-100 bg-ink-100 overflow-hidden relative" style="height: 420px">
            <div class="bg-white border-b border-ink-100 flex items-center gap-1.5 px-3 py-2">
              <span class="w-2.5 h-2.5 rounded-full bg-red-400"></span>
              <span class="w-2.5 h-2.5 rounded-full bg-yellow-400"></span>
              <span class="w-2.5 h-2.5 rounded-full bg-accent-500"></span>
              <div class="ml-3 flex-1 bg-ink-50 rounded-md px-2 py-0.5 text-[10px] text-ink-500 font-mono truncate">{{ auth.workspace?.website || 'https://example.com' }}{{ form.target_url }}</div>
            </div>
            <div class="relative bg-white h-[calc(100%-36px)] overflow-hidden">
              <div class="p-4 space-y-3 opacity-60">
                <div class="h-4 w-2/3 bg-ink-100 rounded"></div>
                <div class="h-2 bg-ink-100 rounded w-full"></div>
                <div class="h-2 bg-ink-100 rounded w-5/6"></div>
                <div class="h-24 bg-ink-50 rounded mt-4"></div>
                <div class="h-2 bg-ink-100 rounded w-4/6"></div>
                <div class="h-2 bg-ink-100 rounded w-3/6"></div>
              </div>

              <div v-if="form.message_type === 'bar'"
                class="absolute left-0 right-0 shadow-lg flex items-center justify-between px-4 py-2.5 text-white text-sm"
                :class="form.position === 'bottom' ? 'bottom-0' : 'top-0'"
                :style="{ background: auth.workspace?.brand_primary || '#3087B9' }">
                <div class="truncate">
                  <span class="font-semibold">{{ form.title || 'Announcement' }}</span>
                  <span v-if="form.body" class="opacity-90 ml-2">{{ form.body }}</span>
                </div>
                <button v-if="form.cta_text" type="button" class="ml-3 px-3 py-1 rounded-md bg-white text-xs font-bold whitespace-nowrap" :style="{ color: auth.workspace?.brand_primary || '#3087B9' }">{{ form.cta_text }}</button>
              </div>

              <div v-else-if="form.message_type === 'popup'" class="absolute inset-0 bg-ink-900/40 flex items-center justify-center"
                :class="form.position === 'top' ? 'items-start pt-10' : form.position === 'bottom' ? 'items-end pb-10' : 'items-center'">
                <div class="bg-white rounded-xl shadow-2xl p-5 max-w-[80%] text-center">
                  <div class="text-base font-bold text-ink-900">{{ form.title || 'Headline' }}</div>
                  <div class="text-sm text-ink-500 mt-2 leading-relaxed">{{ form.body || 'Explain the value in a sentence or two.' }}</div>
                  <button v-if="form.cta_text" type="button" class="mt-4 px-4 py-2 rounded-lg text-white text-xs font-bold" :style="{ background: auth.workspace?.brand_primary || '#3087B9' }">{{ form.cta_text }}</button>
                </div>
              </div>

              <div v-else class="absolute rounded-xl shadow-2xl bg-white w-56 p-4 border border-ink-100"
                :class="form.position === 'bottom' ? 'bottom-4 left-4' : form.position === 'top' ? 'top-4 right-4' : form.position === 'right' ? 'bottom-4 right-4' : 'bottom-4 right-4'">
                <div class="text-sm font-bold text-ink-900">{{ form.title || 'Heads up' }}</div>
                <div class="text-xs text-ink-500 mt-1 leading-relaxed">{{ form.body || 'A quick note that slides in from the side.' }}</div>
                <button v-if="form.cta_text" type="button" class="mt-3 w-full py-1.5 rounded-md text-white text-xs font-bold" :style="{ background: auth.workspace?.brand_primary || '#3087B9' }">{{ form.cta_text }}</button>
              </div>
            </div>
          </div>
          <div class="text-[11px] text-ink-500">Preview reflects your workspace brand color. CTA opens <span class="font-mono text-ink-700">{{ form.cta_url || '—' }}</span>.</div>
        </div>
      </div>
      <template #footer>
        <button @click="open = false" class="btn-secondary">Cancel</button>
        <button v-if="editing?.id" @click="remove" class="btn-ghost text-red-600 mr-auto"><Icon name="trash"/>Delete</button>
        <button form="omf" type="submit" class="btn-primary">Save</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId, auth } = useWorkspace()
const audit = useAudit()
const messages = ref<any[]>([])
const open = ref(false)
const editing = ref<any>(null)
const form = reactive({ name: '', message_type: 'popup', position: 'center', status: 'draft', title: '', body: '', cta_text: '', cta_url: '', target_url: '' })

async function load() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('onsite_messages').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false })
  messages.value = data || []
}
function edit(m: any) {
  editing.value = m
  if (m) Object.assign(form, m)
  else Object.assign(form, { name: '', message_type: 'popup', position: 'center', status: 'draft', title: '', body: '', cta_text: '', cta_url: '', target_url: '' })
  open.value = true
}
async function save() {
  const payload: any = { name: form.name, message_type: form.message_type, position: form.position, status: form.status, title: form.title, body: form.body, cta_text: form.cta_text, cta_url: form.cta_url, target_url: form.target_url, workspace_id: workspaceId.value }
  const { data } = editing.value?.id
    ? await supabase.from('onsite_messages').update(payload).eq('id', editing.value.id).select().maybeSingle()
    : await supabase.from('onsite_messages').insert(payload).select().maybeSingle()
  audit.log(editing.value?.id ? 'update' : 'create', 'onsite_message', data?.id || null, form.name, { type: form.message_type, status: form.status })
  useToast().success('Message saved')
  open.value = false; await load()
}
async function remove() {
  const ok = await useConfirm().ask({ title: 'Delete this message?', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await supabase.from('onsite_messages').delete().eq('id', editing.value.id)
  audit.log('delete', 'onsite_message', editing.value.id, editing.value.name)
  useToast().success('Message deleted')
  open.value = false; await load()
}
watch(workspaceId, load, { immediate: true })
</script>
