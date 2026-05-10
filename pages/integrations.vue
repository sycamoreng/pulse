<template>
  <div>
    <PageHeader title="Integrations" subtitle="Connect your store, stream events to external systems, and schedule exports."/>

    <div class="p-8 max-w-5xl space-y-4">
      <div class="flex gap-2 border-b border-ink-100 overflow-x-auto">
        <button v-for="t in tabs" :key="t.id" @click="tab = t.id"
          class="px-4 py-3 text-sm font-medium whitespace-nowrap border-b-2 -mb-px transition"
          :class="tab === t.id ? 'border-brand-500 text-brand-500' : 'border-transparent text-ink-500 hover:text-ink-900'">
          <Icon :name="t.icon" class="inline-block w-4 h-4 mr-1"/>{{ t.label }}
        </button>
      </div>

      <!-- Commerce -->
      <div v-if="tab === 'commerce'" class="space-y-4">
        <div class="card p-6">
          <div class="font-semibold text-ink-900">Shopify & WooCommerce</div>
          <div class="text-xs text-ink-500 mt-1 mb-4">Connect by adding these webhook URLs in your store admin. Orders are normalized into Pulse, attribute revenue to campaigns, and emit <span class="font-mono">order_created</span> / <span class="font-mono">order_completed</span> events.</div>
          <div class="space-y-3">
            <div>
              <div class="label">Shopify webhook URL</div>
              <div class="flex items-center gap-2">
                <input :value="commerceUrl('shopify')" readonly class="input font-mono text-xs"/>
                <button @click="copy(commerceUrl('shopify'))" class="btn-secondary !py-1.5 !text-xs"><Icon name="copy" class="w-3 h-3"/></button>
              </div>
              <div class="text-[11px] text-ink-500 mt-1">Topic: <span class="font-mono">orders/create</span>, <span class="font-mono">orders/paid</span>. Format: JSON.</div>
            </div>
            <div>
              <div class="label">WooCommerce webhook URL</div>
              <div class="flex items-center gap-2">
                <input :value="commerceUrl('woocommerce')" readonly class="input font-mono text-xs"/>
                <button @click="copy(commerceUrl('woocommerce'))" class="btn-secondary !py-1.5 !text-xs"><Icon name="copy" class="w-3 h-3"/></button>
              </div>
              <div class="text-[11px] text-ink-500 mt-1">Topic: <span class="font-mono">order.created</span>, <span class="font-mono">order.updated</span>.</div>
            </div>
          </div>
        </div>

        <div class="card p-6">
          <div class="font-semibold text-ink-900">Recent orders</div>
          <div v-if="!orders.length" class="text-sm text-ink-500 py-4">No orders yet. They'll appear here once your first webhook fires.</div>
          <table v-else class="w-full text-sm mt-3">
            <thead class="text-left text-xs text-ink-500 uppercase tracking-wider border-b border-ink-100">
              <tr><th class="px-2 py-2">When</th><th class="px-2 py-2">Source</th><th class="px-2 py-2">Email</th><th class="px-2 py-2">Status</th><th class="px-2 py-2 text-right">Total</th></tr>
            </thead>
            <tbody>
              <tr v-for="o in orders" :key="o.id" class="border-b border-ink-100 last:border-0">
                <td class="px-2 py-2 text-xs text-ink-500">{{ new Date(o.occurred_at).toLocaleString() }}</td>
                <td class="px-2 py-2 capitalize">{{ o.source }}</td>
                <td class="px-2 py-2 text-xs">{{ o.email || '—' }}</td>
                <td class="px-2 py-2"><span class="chip bg-ink-100 text-ink-700 text-[10px]">{{ o.status }}</span></td>
                <td class="px-2 py-2 text-right font-mono">{{ o.currency }} {{ Number(o.total_amount).toFixed(2) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Outbound Webhooks -->
      <div v-if="tab === 'webhooks'" class="space-y-4">
        <div class="card p-6">
          <div class="flex items-center justify-between">
            <div>
              <div class="font-semibold text-ink-900">Outbound webhooks</div>
              <div class="text-xs text-ink-500 mt-1">Pulse posts a signed JSON payload to your URL when events occur. Use the secret + <span class="font-mono">X-Pulse-Signature</span> (HMAC-SHA256) header to verify.</div>
            </div>
            <button @click="newHook" class="btn-primary"><Icon name="plus"/>New webhook</button>
          </div>
        </div>
        <div v-if="!hooks.length" class="card p-8 text-center text-sm text-ink-500">No destinations configured.</div>
        <div v-for="h in hooks" :key="h.id" class="card p-5">
          <div class="flex items-start justify-between">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <div class="font-semibold text-ink-900">{{ h.name || 'Webhook' }}</div>
                <span class="chip text-[10px]" :class="h.is_active ? 'bg-accent-500/10 text-accent-500' : 'bg-ink-100 text-ink-700'">{{ h.is_active ? 'active' : 'paused' }}</span>
                <span v-if="h.failure_count > 0" class="chip bg-red-100 text-red-700 text-[10px]">{{ h.failure_count }} failures</span>
              </div>
              <div class="text-xs text-ink-500 font-mono truncate mt-1">{{ h.url }}</div>
              <div class="text-[11px] text-ink-500 mt-1">Events: {{ (h.event_filters || []).join(', ') || 'all' }}</div>
            </div>
            <div class="flex items-center gap-2">
              <button @click="testHook(h)" class="btn-ghost !py-1 !text-xs">Test</button>
              <button @click="editHook(h)" class="btn-secondary !py-1 !text-xs">Edit</button>
            </div>
          </div>
        </div>
      </div>

      <!-- API Keys -->
      <div v-if="tab === 'keys'" class="space-y-4">
        <div class="card p-6">
          <div class="flex items-center justify-between">
            <div>
              <div class="font-semibold text-ink-900">API keys</div>
              <div class="text-xs text-ink-500 mt-1">Used by the Track API and server-side identify/event calls. Scopes limit what a key can do.</div>
            </div>
            <button @click="newKey" class="btn-primary"><Icon name="plus"/>New key</button>
          </div>
        </div>
        <div v-if="newKeyValue" class="card p-5 border-l-4 border-accent-500 bg-accent-500/5">
          <div class="font-semibold text-ink-900 text-sm">Copy this key now. We won't show it again.</div>
          <div class="flex items-center gap-2 mt-2">
            <input :value="newKeyValue" readonly class="input font-mono text-xs"/>
            <button @click="copy(newKeyValue)" class="btn-secondary !py-1.5 !text-xs"><Icon name="copy" class="w-3 h-3"/></button>
          </div>
        </div>
        <div v-if="!keys.length" class="card p-8 text-center text-sm text-ink-500">No API keys yet.</div>
        <div v-for="k in keys" :key="k.id" class="card p-5 flex items-center justify-between">
          <div>
            <div class="font-semibold text-ink-900">{{ k.name || 'Untitled key' }}</div>
            <div class="text-xs text-ink-500 font-mono">{{ k.key_prefix || (k.key || '').slice(0, 8) }}…</div>
            <div class="text-[11px] text-ink-500 mt-1">Scopes: {{ (k.scopes || []).join(', ') || 'track:write' }}
              <span v-if="k.last_used_at"> · Last used {{ new Date(k.last_used_at).toLocaleDateString() }}</span>
              <span v-if="k.revoked_at" class="text-red-600"> · revoked</span>
            </div>
          </div>
          <button v-if="!k.revoked_at" @click="revokeKey(k)" class="btn-ghost text-red-600 !py-1 !text-xs">Revoke</button>
        </div>
      </div>

      <!-- Scheduled exports -->
      <div v-if="tab === 'exports'" class="space-y-4">
        <div class="card p-6">
          <div class="flex items-center justify-between">
            <div>
              <div class="font-semibold text-ink-900">Scheduled exports</div>
              <div class="text-xs text-ink-500 mt-1">Run customer / event / order exports on a schedule and ship to S3, GCS, or an HTTPS endpoint (reverse ETL).</div>
            </div>
            <button @click="newExport" class="btn-primary"><Icon name="plus"/>New schedule</button>
          </div>
        </div>
        <div v-if="!schedules.length" class="card p-8 text-center text-sm text-ink-500">No scheduled exports.</div>
        <div v-for="s in schedules" :key="s.id" class="card p-5 flex items-center justify-between">
          <div>
            <div class="font-semibold text-ink-900">{{ s.name || `${s.scope} export` }}</div>
            <div class="text-xs text-ink-500">{{ s.scope }} · {{ s.format.toUpperCase() }} · to {{ s.destination }}</div>
            <div class="text-[11px] text-ink-500 mt-1 font-mono">{{ s.cron }} — {{ s.last_status || 'not yet run' }}</div>
          </div>
          <div class="flex items-center gap-2">
            <span class="chip text-[10px]" :class="s.is_active ? 'bg-accent-500/10 text-accent-500' : 'bg-ink-100 text-ink-700'">{{ s.is_active ? 'active' : 'paused' }}</span>
            <button @click="editSchedule(s)" class="btn-secondary !py-1 !text-xs">Edit</button>
          </div>
        </div>
      </div>
    </div>

    <Modal v-model="hookOpen" :title="hookForm.id ? 'Edit webhook' : 'New webhook destination'" size="lg">
      <form id="hkf" @submit.prevent="saveHook" class="space-y-3">
        <div><label class="label">Name</label><input v-model="hookForm.name" class="input" placeholder="My CRM"/></div>
        <div><label class="label">Target URL *</label><input v-model="hookForm.url" class="input font-mono" type="url" required placeholder="https://hooks.example.com/pulse"/></div>
        <div><label class="label">Event filters</label>
          <input v-model="hookFilters" class="input font-mono" placeholder="order_created, order_completed, campaign_sent (blank = all)"/>
          <div class="text-[11px] text-ink-500 mt-1">Comma-separated event names, or * for all.</div>
        </div>
        <div><label class="label">Signing secret</label>
          <div class="flex items-center gap-2">
            <input v-model="hookForm.secret" class="input font-mono" placeholder="generated"/>
            <button type="button" @click="hookForm.secret = genSecret()" class="btn-secondary !py-2 !text-xs">Generate</button>
          </div>
          <div class="text-[11px] text-ink-500 mt-1">We sign the body with HMAC-SHA256 using this secret and send it as <span class="font-mono">X-Pulse-Signature</span>.</div>
        </div>
        <label class="flex items-center gap-2 text-sm"><input type="checkbox" v-model="hookForm.is_active"/> Active</label>
      </form>
      <template #footer>
        <button v-if="hookForm.id" @click="deleteHook" class="btn-ghost text-red-600 mr-auto">Delete</button>
        <button @click="hookOpen = false" class="btn-secondary">Cancel</button>
        <button form="hkf" type="submit" class="btn-primary">Save</button>
      </template>
    </Modal>

    <Modal v-model="keyOpen" title="New API key">
      <form id="kf" @submit.prevent="saveKey" class="space-y-3">
        <div><label class="label">Name *</label><input v-model="keyForm.name" class="input" required placeholder="Server-side tracking"/></div>
        <div>
          <label class="label">Key type</label>
          <div class="grid grid-cols-2 gap-2 mt-1">
            <label class="flex items-start gap-2 p-3 border border-ink-100 rounded-lg cursor-pointer" :class="keyForm.key_type === 'secret' ? 'border-brand-500 bg-brand-100/20' : ''">
              <input type="radio" value="secret" v-model="keyForm.key_type" class="mt-0.5"/>
              <div>
                <div class="text-xs font-semibold text-ink-900">Secret (pk_)</div>
                <div class="text-[11px] text-ink-500">Server-only. Full scopes.</div>
              </div>
            </label>
            <label class="flex items-start gap-2 p-3 border border-ink-100 rounded-lg cursor-pointer" :class="keyForm.key_type === 'publishable' ? 'border-brand-500 bg-brand-100/20' : ''">
              <input type="radio" value="publishable" v-model="keyForm.key_type" class="mt-0.5"/>
              <div>
                <div class="text-xs font-semibold text-ink-900">Publishable (ppk_)</div>
                <div class="text-[11px] text-ink-500">Safe for browser / mobile. track:write only.</div>
              </div>
            </label>
          </div>
        </div>
        <div v-if="keyForm.key_type === 'secret'"><label class="label">Scopes</label>
          <div class="flex flex-wrap gap-2 mt-1">
            <label v-for="s in allScopes" :key="s" class="flex items-center gap-1 text-xs">
              <input type="checkbox" :value="s" v-model="keyForm.scopes"/>{{ s }}
            </label>
          </div>
        </div>
        <div v-if="keyForm.key_type === 'publishable'">
          <label class="label">Allowed origins</label>
          <input v-model="keyForm.allowed_origins" class="input" placeholder="yourapp.com, *.yourapp.com"/>
          <div class="text-[11px] text-ink-500 mt-1">Comma-separated. Use <code>*.domain.com</code> for subdomain wildcards. Leave blank to allow any origin (not recommended).</div>
        </div>
        <div v-if="keyForm.key_type === 'publishable'">
          <label class="label">Allowed bundle IDs (mobile)</label>
          <input v-model="keyForm.allowed_bundle_ids" class="input" placeholder="com.yourco.app"/>
          <div class="text-[11px] text-ink-500 mt-1">Comma-separated. Used for React Native / iOS / Android apps.</div>
        </div>
      </form>
      <template #footer>
        <button @click="keyOpen = false" class="btn-secondary">Cancel</button>
        <button form="kf" type="submit" class="btn-primary">Create key</button>
      </template>
    </Modal>

    <Modal v-model="schedOpen" :title="schedForm.id ? 'Edit schedule' : 'New scheduled export'" size="lg">
      <form id="sf" @submit.prevent="saveSchedule" class="grid grid-cols-2 gap-3">
        <div class="col-span-2"><label class="label">Name *</label><input v-model="schedForm.name" class="input" required/></div>
        <div><label class="label">Scope</label>
          <select v-model="schedForm.scope" class="input">
            <option value="customers">Customers</option><option value="events">Events</option>
            <option value="orders">Orders</option><option value="campaign_messages">Campaign messages</option>
          </select>
        </div>
        <div><label class="label">Format</label>
          <select v-model="schedForm.format" class="input"><option>csv</option><option>json</option><option>parquet</option></select>
        </div>
        <div><label class="label">Destination</label>
          <select v-model="schedForm.destination" class="input">
            <option value="download">Download (staged)</option>
            <option value="s3">Amazon S3</option>
            <option value="gcs">Google Cloud Storage</option>
            <option value="https">HTTPS POST</option>
          </select>
        </div>
        <div><label class="label">Cron</label><input v-model="schedForm.cron" class="input font-mono" placeholder="0 5 * * *"/></div>
        <div v-if="schedForm.destination !== 'download'" class="col-span-2">
          <label class="label">Destination config (JSON)</label>
          <textarea v-model="schedConfigText" rows="4" class="input font-mono text-xs" placeholder='{"bucket":"my-bucket","prefix":"pulse/"}'></textarea>
        </div>
        <label class="flex items-center gap-2 text-sm col-span-2"><input type="checkbox" v-model="schedForm.is_active"/> Active</label>
      </form>
      <template #footer>
        <button v-if="schedForm.id" @click="deleteSchedule" class="btn-ghost text-red-600 mr-auto">Delete</button>
        <button @click="schedOpen = false" class="btn-secondary">Cancel</button>
        <button form="sf" type="submit" class="btn-primary">Save</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const { $supabase } = useNuxtApp()
const auth = useAuthStore()
const commerceEnabled = computed(() => !!auth.workspace?.commerce_enabled)
const tabs = computed(() => {
  const base: any[] = []
  if (commerceEnabled.value) base.push({ id: 'commerce', label: 'Shopify / Woo', icon: 'box' })
  base.push(
    { id: 'webhooks', label: 'Outbound webhooks', icon: 'send' },
    { id: 'keys', label: 'API keys', icon: 'shield' },
    { id: 'exports', label: 'Scheduled exports', icon: 'upload' },
  )
  return base
})
const tab = ref(commerceEnabled.value ? 'commerce' : 'webhooks')
watch(commerceEnabled, (on) => { if (!on && tab.value === 'commerce') tab.value = 'webhooks' })

const orders = ref<any[]>([])
const hooks = ref<any[]>([])
const keys = ref<any[]>([])
const schedules = ref<any[]>([])

const hookOpen = ref(false)
const hookForm = reactive<any>({ id: '', name: '', url: '', event_filters: [], secret: '', is_active: true })
const hookFilters = computed({
  get: () => (hookForm.event_filters || []).join(', '),
  set: (v: string) => { hookForm.event_filters = v.split(',').map((s: string) => s.trim()).filter(Boolean) },
})

const keyOpen = ref(false)
const keyForm = reactive<any>({ name: '', scopes: ['track:write'], key_type: 'secret', allowed_origins: '', allowed_bundle_ids: '' })
const newKeyValue = ref('')
const allScopes = ['track:write', 'track:read', 'customers:read', 'customers:write', 'events:read', 'campaigns:read']

const schedOpen = ref(false)
const schedForm = reactive<any>({ id: '', name: '', scope: 'customers', format: 'csv', destination: 'download', destination_config: {}, cron: '0 5 * * *', is_active: true })
const schedConfigText = computed({
  get: () => JSON.stringify(schedForm.destination_config || {}, null, 2),
  set: (v: string) => { try { schedForm.destination_config = JSON.parse(v || '{}') } catch {} },
})

function commerceUrl(source: string) {
  return `${useRuntimeConfig().public.supabaseUrl}/functions/v1/commerce-webhook?workspace_id=${workspaceId.value || ''}&source=${source}`
}
function copy(v: string) { navigator.clipboard.writeText(v); useToast().success('Copied') }
function genSecret() {
  const bytes = new Uint8Array(24)
  crypto.getRandomValues(bytes)
  return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('')
}
function genKey(prefix: string = 'pk_') {
  const bytes = new Uint8Array(32)
  crypto.getRandomValues(bytes)
  return prefix + Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('')
}
async function sha256(v: string) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(v))
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('')
}

async function load() {
  if (!workspaceId.value) return
  const [o, h, k, s] = await Promise.all([
    supabase.from('commerce_orders').select('*').eq('workspace_id', workspaceId.value).order('occurred_at', { ascending: false }).limit(20),
    supabase.from('webhook_destinations').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('api_keys').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('data_exports_scheduled').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
  ])
  orders.value = o.data || []
  hooks.value = h.data || []
  keys.value = k.data || []
  schedules.value = s.data || []
}

function newHook() {
  Object.assign(hookForm, { id: '', name: '', url: '', event_filters: [], secret: genSecret(), is_active: true })
  hookOpen.value = true
}
function editHook(h: any) {
  Object.assign(hookForm, { id: h.id, name: h.name, url: h.url, event_filters: h.event_filters || [], secret: h.secret, is_active: h.is_active })
  hookOpen.value = true
}
async function saveHook() {
  const payload = {
    workspace_id: workspaceId.value, name: hookForm.name, url: hookForm.url,
    event_filters: hookForm.event_filters, secret: hookForm.secret, is_active: hookForm.is_active,
    created_by: auth.user?.id || null,
  }
  const { error } = hookForm.id
    ? await supabase.from('webhook_destinations').update(payload).eq('id', hookForm.id)
    : await supabase.from('webhook_destinations').insert(payload)
  if (error) { useToast().error('Save failed', error.message); return }
  hookOpen.value = false; await load(); useToast().success('Webhook saved')
}
async function deleteHook() {
  const ok = await useConfirm().ask({ title: 'Delete webhook?', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await supabase.from('webhook_destinations').delete().eq('id', hookForm.id)
  hookOpen.value = false; await load()
}
async function testHook(h: any) {
  const { data: { session } } = await $supabase.auth.getSession()
  const url = `${useRuntimeConfig().public.supabaseUrl}/functions/v1/webhook-dispatch`
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${session?.access_token}` },
    body: JSON.stringify({ workspace_id: workspaceId.value, event_type: 'test', destination_id: h.id, payload: { message: 'hello from Pulse' } }),
  })
  const json = await res.json().catch(() => ({}))
  if (json?.delivered) useToast().success('Test delivered')
  else useToast().error('Test failed', 'Check delivery log for details')
  await load()
}

function newKey() { Object.assign(keyForm, { name: '', scopes: ['track:write'], key_type: 'secret', allowed_origins: '', allowed_bundle_ids: '' }); newKeyValue.value = ''; keyOpen.value = true }
async function saveKey() {
  const isPub = keyForm.key_type === 'publishable'
  const envTag = auth.workspace?.environment === 'test' ? 'test' : 'live'
  const basePrefix = isPub ? 'ppk_' : 'pk_'
  const plain = genKey(`${basePrefix}${envTag}_` as any)
  const hash = await sha256(plain)
  const prefix = plain.slice(0, 14)
  const scopes = isPub ? ['track:write'] : keyForm.scopes
  const allowedOrigins = isPub ? keyForm.allowed_origins.split(',').map((s: string) => s.trim()).filter(Boolean) : []
  const allowedBundleIds = isPub ? keyForm.allowed_bundle_ids.split(',').map((s: string) => s.trim()).filter(Boolean) : []
  const { error } = await supabase.from('api_keys').insert({
    workspace_id: workspaceId.value,
    name: keyForm.name,
    key: plain,
    key_prefix: prefix,
    key_hash: hash,
    scopes,
    key_type: keyForm.key_type,
    environment: auth.workspace?.environment === 'test' ? 'test' : 'production',
    allowed_origins: allowedOrigins,
    allowed_bundle_ids: allowedBundleIds,
    created_by: auth.user?.id || null,
  })
  if (error) { useToast().error('Save failed', error.message); return }
  keyOpen.value = false
  newKeyValue.value = plain
  await load()
}
async function revokeKey(k: any) {
  const ok = await useConfirm().ask({ title: 'Revoke this key?', body: 'Any servers using this key will immediately stop working.', tone: 'danger', confirmText: 'Revoke' })
  if (!ok) return
  await supabase.from('api_keys').update({ revoked_at: new Date().toISOString() }).eq('id', k.id)
  await load()
}

function newExport() { Object.assign(schedForm, { id: '', name: '', scope: 'customers', format: 'csv', destination: 'download', destination_config: {}, cron: '0 5 * * *', is_active: true }); schedOpen.value = true }
function editSchedule(s: any) {
  Object.assign(schedForm, { id: s.id, name: s.name, scope: s.scope, format: s.format, destination: s.destination, destination_config: s.destination_config || {}, cron: s.cron, is_active: s.is_active })
  schedOpen.value = true
}
async function saveSchedule() {
  const payload = {
    workspace_id: workspaceId.value, name: schedForm.name, scope: schedForm.scope, format: schedForm.format,
    destination: schedForm.destination, destination_config: schedForm.destination_config || {},
    cron: schedForm.cron, is_active: schedForm.is_active, created_by: auth.user?.id || null,
  }
  const { error } = schedForm.id
    ? await supabase.from('data_exports_scheduled').update(payload).eq('id', schedForm.id)
    : await supabase.from('data_exports_scheduled').insert(payload)
  if (error) { useToast().error('Save failed', error.message); return }
  schedOpen.value = false; await load(); useToast().success('Schedule saved')
}
async function deleteSchedule() {
  const ok = await useConfirm().ask({ title: 'Delete schedule?', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await supabase.from('data_exports_scheduled').delete().eq('id', schedForm.id)
  schedOpen.value = false; await load()
}

watch(workspaceId, load, { immediate: true })
</script>
