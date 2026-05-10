<template>
  <div>
    <PageHeader title="Sending providers" subtitle="Connect Amazon SES, Postmark, or Resend per workspace. Tenants never see this.">
      <template #actions><button @click="edit(null)" class="btn-primary"><Icon name="plus"/>Add provider</button></template>
    </PageHeader>

    <div class="p-8 space-y-4">
      <div class="card p-4 flex items-center gap-3">
        <select v-model="filterWs" class="input !w-64"><option value="">All workspaces</option><option v-for="w in workspaces" :key="w.id" :value="w.id">{{ w.name }}</option></select>
        <div class="text-xs text-ink-500 ml-auto">Webhook URL: <span class="font-mono text-ink-700 break-all">{{ webhookUrl }}</span></div>
      </div>

      <div class="card">
        <table class="w-full text-sm">
          <thead class="text-left text-xs text-ink-500 uppercase tracking-wider border-b border-ink-100">
            <tr><th class="px-4 py-3">Workspace</th><th class="px-4 py-3">Provider</th><th class="px-4 py-3">Stream</th><th class="px-4 py-3">Region / pool</th><th class="px-4 py-3">Secret</th><th class="px-4 py-3">Status</th><th></th></tr>
          </thead>
          <tbody>
            <tr v-if="!filtered.length"><td colspan="7" class="text-center py-12 text-sm text-ink-500">No providers configured. Tenants will use the platform fallback.</td></tr>
            <tr v-for="p in filtered" :key="p.id" class="border-b border-ink-100 last:border-0 hover:bg-ink-50">
              <td class="px-4 py-3 font-medium text-ink-900">{{ wsName(p.workspace_id) }}</td>
              <td class="px-4 py-3 capitalize">{{ p.provider }}</td>
              <td class="px-4 py-3"><span class="chip" :class="p.stream === 'bulk' ? 'bg-brand-100/40 text-brand-700' : 'bg-accent-500/10 text-accent-500'">{{ p.stream }}</span></td>
              <td class="px-4 py-3 text-xs text-ink-500">{{ p.region || '—' }} · {{ p.ip_pool || 'shared' }}</td>
              <td class="px-4 py-3 text-xs text-ink-500 font-mono">{{ p.credentials_secret_name || '—' }}</td>
              <td class="px-4 py-3"><span class="chip" :class="p.is_active ? 'bg-accent-500/10 text-accent-500' : 'bg-ink-100 text-ink-700'">{{ p.is_active ? 'active' : 'disabled' }}</span></td>
              <td class="px-4 py-3 text-right"><button @click="edit(p)" class="btn-secondary !py-1 !text-xs">Edit</button></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <Modal v-model="open" :title="editing?.id ? 'Edit provider' : 'Add sending provider'" size="lg">
      <form id="prvf" @submit.prevent="save" class="grid grid-cols-2 gap-3">
        <div class="col-span-2"><label class="label">Workspace</label>
          <select v-model="form.workspace_id" class="input" required><option value="">Choose workspace</option><option v-for="w in workspaces" :key="w.id" :value="w.id">{{ w.name }}</option></select>
        </div>
        <div><label class="label">Provider</label>
          <select v-model="form.provider" class="input"><option value="ses">Amazon SES</option><option value="postmark">Postmark</option><option value="resend">Resend</option></select>
        </div>
        <div><label class="label">Stream</label>
          <select v-model="form.stream" class="input"><option value="bulk">Bulk</option><option value="transactional">Transactional</option></select>
        </div>
        <div v-if="form.provider === 'ses'"><label class="label">AWS region</label><input v-model="form.region" class="input" placeholder="us-east-1"/></div>
        <div><label class="label">IP pool</label><input v-model="form.ip_pool" class="input" placeholder="dedicated-bulk"/></div>
        <div class="col-span-2"><label class="label">Credentials secret name</label><input v-model="form.credentials_secret_name" class="input" :placeholder="form.provider === 'ses' ? 'SES_CLIENT_A' : form.provider === 'postmark' ? 'POSTMARK_CLIENT_A' : 'RESEND_CLIENT_A'"/>
          <div class="text-[11px] text-ink-500 mt-1">Set the actual secret in Supabase Edge Function env. SES looks up <span class="font-mono">{NAME}</span> and <span class="font-mono">{NAME}_SECRET</span>.</div>
        </div>
        <div v-if="form.provider === 'ses'" class="col-span-2"><label class="label">Configuration set</label><input v-model="form.config.configuration_set" class="input"/></div>
        <div v-if="form.provider === 'postmark'" class="col-span-2"><label class="label">Message stream</label><input v-model="form.config.message_stream" class="input"/></div>
        <label class="flex items-center gap-2 col-span-2 mt-2"><input type="checkbox" v-model="form.is_active"/> Active</label>
      </form>
      <template #footer>
        <button @click="open = false" class="btn-secondary">Cancel</button>
        <button v-if="editing?.id" @click="remove" class="btn-ghost text-red-600 mr-auto"><Icon name="trash"/>Remove</button>
        <button form="prvf" type="submit" class="btn-primary">Save</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })
const { $supabase } = useNuxtApp()
const providers = ref<any[]>([])
const workspaces = ref<any[]>([])
const filterWs = ref('')
const open = ref(false)
const editing = ref<any>(null)
const form = reactive<any>({ workspace_id: '', provider: 'ses', stream: 'bulk', region: 'us-east-1', ip_pool: '', credentials_secret_name: '', is_active: true, config: { configuration_set: '', message_stream: '' } })
const webhookUrl = computed(() => `${useRuntimeConfig().public.supabaseUrl}/functions/v1/email-webhook?source=ses`)

async function load() {
  const [pr, ws] = await Promise.all([
    $supabase.from('email_providers').select('*').order('created_at', { ascending: false }),
    $supabase.from('workspaces').select('id, name').order('name'),
  ])
  providers.value = pr.data || []
  workspaces.value = ws.data || []
}
function wsName(id: string) { return workspaces.value.find((w: any) => w.id === id)?.name || 'Unknown' }
const filtered = computed(() => filterWs.value ? providers.value.filter((p: any) => p.workspace_id === filterWs.value) : providers.value)

function edit(p: any) {
  editing.value = p
  if (p) Object.assign(form, { ...p, config: p.config || {} })
  else Object.assign(form, { workspace_id: '', provider: 'ses', stream: 'bulk', region: 'us-east-1', ip_pool: '', credentials_secret_name: '', is_active: true, config: { configuration_set: '', message_stream: '' } })
  open.value = true
}
async function save() {
  if (!form.workspace_id) { useToast().error('Pick a workspace'); return }
  const payload = { ...form }
  const { error } = editing.value?.id
    ? await $supabase.from('email_providers').update(payload).eq('id', editing.value.id)
    : await $supabase.from('email_providers').insert(payload)
  if (error) { useToast().error('Save failed', error.message); return }
  useToast().success('Provider saved')
  open.value = false; await load()
}
async function remove() {
  const ok = await useConfirm().ask({ title: 'Remove provider?', tone: 'danger', confirmText: 'Remove' })
  if (!ok) return
  await $supabase.from('email_providers').delete().eq('id', editing.value.id)
  open.value = false; await load()
}
onMounted(load)
</script>
