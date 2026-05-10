<template>
  <div>
    <PageHeader title="Apps & SDKs" subtitle="Connect your mobile and web apps with SDK keys.">
      <template #actions>
        <button @click="openNew = true" class="btn-primary"><Icon name="plus"/>Connect app</button>
      </template>
    </PageHeader>

    <div class="p-8 space-y-6">
      <div class="card p-5">
        <div class="flex items-center justify-between">
          <div>
            <div class="font-semibold text-ink-900">Workspace API key</div>
            <div class="text-xs text-ink-500">Use with the <code class="bg-ink-50 px-1 rounded">/track</code> and <code class="bg-ink-50 px-1 rounded">/identify</code> endpoints from any client.</div>
          </div>
          <button @click="rotateKey" class="btn-ghost text-sm">Rotate</button>
        </div>
        <div class="mt-3 flex items-center gap-2 bg-ink-50 rounded-lg px-3 py-2">
          <code class="flex-1 text-xs font-mono text-ink-700 truncate">{{ apiKey?.key || 'Generating…' }}</code>
          <button @click="copy(apiKey?.key)" class="text-ink-500 hover:text-brand-500"><Icon name="copy"/></button>
        </div>
        <div class="mt-3 text-xs text-ink-500">Ingestion endpoint: <code class="bg-ink-50 px-1 rounded font-mono">{{ ingestUrl }}</code></div>
      </div>

      <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div v-for="a in apps" :key="a.id" class="card p-5">
          <div class="flex items-start justify-between">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-lg flex items-center justify-center" :class="platformStyle(a.platform)"><Icon :name="platformIcon(a.platform)"/></div>
              <div>
                <div class="font-semibold text-ink-900">{{ a.name }}</div>
                <div class="text-xs text-ink-500 capitalize">{{ a.platform }}</div>
              </div>
            </div>
            <div class="flex items-center gap-2">
              <span v-if="pushStatusFor(a)" class="chip bg-accent-500/10 text-accent-500 text-[10px]">push</span>
              <button @click="remove(a)" class="text-ink-300 hover:text-red-600"><Icon name="trash"/></button>
            </div>
          </div>
          <div class="mt-4">
            <div class="text-xs text-ink-500 font-semibold mb-1">SDK KEY</div>
            <div class="flex items-center gap-2 bg-ink-50 rounded-lg px-3 py-2">
              <code class="flex-1 text-xs font-mono text-ink-700 truncate">{{ a.sdk_key }}</code>
              <button @click="copy(a.sdk_key)" class="text-ink-500 hover:text-brand-500"><Icon name="copy"/></button>
            </div>
          </div>
          <div v-if="a.bundle_id" class="mt-3 text-xs text-ink-500">Bundle: <span class="font-mono">{{ a.bundle_id }}</span></div>
          <button @click="openPush(a)" class="btn-secondary w-full mt-4 text-xs"><Icon name="send"/>{{ pushStatusFor(a) ? 'Update push credentials' : 'Configure push' }}</button>
        </div>
      </div>

      <div class="card p-6">
        <div class="flex gap-2 mb-4 border-b border-ink-100 -mx-6 px-6 -mt-2">
          <button v-for="t in tabs" :key="t" @click="tab = t" class="px-3 py-2 text-sm font-medium border-b-2 -mb-px transition"
            :class="tab === t ? 'border-brand-500 text-brand-500' : 'border-transparent text-ink-500 hover:text-ink-900'">{{ t }}</button>
        </div>
        <pre v-if="tab === 'Web'" class="bg-ink-900 text-ink-100 rounded-lg p-4 text-xs overflow-x-auto"><code>// Identify a user
await fetch('{{ ingestUrl }}/identify', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'X-Api-Key': '{{ apiKey?.key || "YOUR_API_KEY" }}' },
  body: JSON.stringify({
    external_id: 'user_123',
    traits: { email: 'you@example.com', first_name: 'Ada', platform: 'web' }
  })
});

// Track an event
await fetch('{{ ingestUrl }}/track', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'X-Api-Key': '{{ apiKey?.key || "YOUR_API_KEY" }}' },
  body: JSON.stringify({
    external_id: 'user_123',
    name: 'product_viewed',
    properties: { product_id: 'sku-42', price: 49.99 }
  })
});</code></pre>
        <pre v-if="tab === 'iOS'" class="bg-ink-900 text-ink-100 rounded-lg p-4 text-xs overflow-x-auto"><code>// Swift
let url = URL(string: "{{ ingestUrl }}/track")!
var req = URLRequest(url: url)
req.httpMethod = "POST"
req.addValue("application/json", forHTTPHeaderField: "Content-Type")
req.addValue("{{ apiKey?.key || "YOUR_API_KEY" }}", forHTTPHeaderField: "X-Api-Key")
let body: [String: Any] = [
  "external_id": "user_123",
  "name": "app_opened",
  "properties": ["source": "push"]
]
req.httpBody = try JSONSerialization.data(withJSONObject: body)
URLSession.shared.dataTask(with: req).resume()</code></pre>
        <pre v-if="tab === 'Android'" class="bg-ink-900 text-ink-100 rounded-lg p-4 text-xs overflow-x-auto"><code>// Kotlin
val client = OkHttpClient()
val body = """{
  "external_id": "user_123",
  "name": "app_opened",
  "properties": { "source": "push" }
}""".toRequestBody("application/json".toMediaType())
val req = Request.Builder()
  .url("{{ ingestUrl }}/track")
  .addHeader("X-Api-Key", "{{ apiKey?.key || "YOUR_API_KEY" }}")
  .post(body).build()
client.newCall(req).execute()</code></pre>
        <pre v-if="tab === 'cURL'" class="bg-ink-900 text-ink-100 rounded-lg p-4 text-xs overflow-x-auto"><code>curl -X POST "{{ ingestUrl }}/track" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: {{ apiKey?.key || "YOUR_API_KEY" }}" \
  -d '{ "external_id": "user_123", "name": "signup", "properties": {} }'</code></pre>
        <button @click="sendTest" :disabled="sendingTest || !apiKey" class="btn-primary mt-4"><Icon name="activity"/>{{ sendingTest ? 'Sending…' : 'Send test event' }}</button>
        <span v-if="testResult" class="ml-3 text-sm" :class="testResult.ok ? 'text-accent-500' : 'text-red-600'">{{ testResult.ok ? 'Event received' : testResult.error }}</span>
      </div>
    </div>

    <Modal v-model="pushOpen" :title="`Push credentials · ${pushForm.app_name}`" subtitle="Configure FCM or APNs keys used to send push notifications." size="lg">
      <form id="pushf" @submit.prevent="savePush" class="space-y-3">
        <div class="flex gap-2">
          <button type="button" @click="pushForm.push_platform = 'fcm'" class="btn-secondary flex-1" :class="pushForm.push_platform === 'fcm' ? '!border-brand-500 !text-brand-500' : ''">
            <Icon name="smartphone"/>Firebase (Android)
          </button>
          <button type="button" @click="pushForm.push_platform = 'apns'" class="btn-secondary flex-1" :class="pushForm.push_platform === 'apns' ? '!border-brand-500 !text-brand-500' : ''">
            <Icon name="smartphone"/>APNs (iOS)
          </button>
        </div>
        <div v-if="pushForm.push_platform === 'fcm'" class="space-y-3">
          <div>
            <label class="label">FCM server key *</label>
            <textarea v-model="pushForm.fcm_server_key" class="input font-mono text-xs" rows="4" placeholder="AAAA..." required></textarea>
            <div class="text-xs text-ink-500 mt-1">Find it in Firebase Console → Project Settings → Cloud Messaging → Server key.</div>
          </div>
        </div>
        <div v-if="pushForm.push_platform === 'apns'" class="space-y-3">
          <div class="grid grid-cols-2 gap-3">
            <div><label class="label">Team ID *</label><input v-model="pushForm.apns_team_id" class="input font-mono" required placeholder="ABCDEF1234"/></div>
            <div><label class="label">Key ID *</label><input v-model="pushForm.apns_key_id" class="input font-mono" required placeholder="XYZ1234567"/></div>
          </div>
          <div><label class="label">Bundle ID *</label><input v-model="pushForm.apns_bundle_id" class="input font-mono" required placeholder="com.yourcompany.app"/></div>
          <div>
            <label class="label">.p8 auth key *</label>
            <textarea v-model="pushForm.apns_p8" class="input font-mono text-xs" rows="6" required placeholder="-----BEGIN PRIVATE KEY-----&#10;...&#10;-----END PRIVATE KEY-----"></textarea>
            <div class="flex items-center gap-2 mt-2">
              <label class="btn-secondary text-xs cursor-pointer">
                <Icon name="upload"/>Upload .p8 file
                <input type="file" accept=".p8,.pem,.txt" class="hidden" @change="readP8"/>
              </label>
              <span class="text-xs text-ink-500">Pasted or uploaded — stored encrypted at rest.</span>
            </div>
          </div>
        </div>
      </form>
      <template #footer>
        <button @click="pushOpen = false" class="btn-secondary">Cancel</button>
        <button form="pushf" type="submit" class="btn-primary">Save credentials</button>
      </template>
    </Modal>

    <Modal v-model="openNew" title="Connect a new app">
      <form id="apf" @submit.prevent="create" class="space-y-3">
        <div><label class="label">App name *</label><input v-model="form.name" class="input" required/></div>
        <div><label class="label">Platform</label>
          <select v-model="form.platform" class="input">
            <option value="web">Web</option><option value="ios">iOS</option><option value="android">Android</option>
          </select>
        </div>
        <div><label class="label">Bundle / Package ID</label><input v-model="form.bundle_id" class="input" placeholder="com.yourcompany.app"/></div>
      </form>
      <template #footer>
        <button @click="openNew = false" class="btn-secondary">Cancel</button>
        <button form="apf" type="submit" class="btn-primary">Create</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const config = useRuntimeConfig()
const apps = ref<any[]>([])
const openNew = ref(false)
const form = reactive({ name: '', platform: 'web', bundle_id: '' })
const apiKey = ref<any>(null)
const tabs = ['Web', 'iOS', 'Android', 'cURL']
const tab = ref('Web')
const sendingTest = ref(false)
const testResult = ref<any>(null)

const ingestUrl = computed(() => `${config.public.supabaseUrl}/functions/v1/track`)

const platformIcon = (p: string) => p === 'web' ? 'monitor' : 'smartphone'
const platformStyle = (p: string) => p === 'ios' ? 'bg-ink-900 text-white' : p === 'android' ? 'bg-accent-500/10 text-accent-500' : 'bg-brand-100/40 text-brand-500'

async function load() {
  if (!workspaceId.value) return
  const [ap, k] = await Promise.all([
    supabase.from('apps').select('*').eq('workspace_id', workspaceId.value).order('created_at'),
    supabase.from('api_keys').select('*').eq('workspace_id', workspaceId.value).order('created_at').limit(1).maybeSingle(),
  ])
  apps.value = ap.data || []
  if (k.data) apiKey.value = k.data
  else {
    const { data } = await supabase.from('api_keys').insert({ workspace_id: workspaceId.value, name: 'Default' }).select().maybeSingle()
    apiKey.value = data
  }
}
async function rotateKey() {
  const ok = await useConfirm().ask({ title: 'Rotate API key?', message: 'Existing integrations will break until the new key is deployed.', tone: 'danger', confirmText: 'Rotate key' })
  if (!ok) return
  if (apiKey.value?.id) await supabase.from('api_keys').delete().eq('id', apiKey.value.id)
  const { data } = await supabase.from('api_keys').insert({ workspace_id: workspaceId.value, name: 'Default' }).select().maybeSingle()
  apiKey.value = data
  useToast().success('API key rotated')
}
async function create() {
  await supabase.from('apps').insert({ ...form, workspace_id: workspaceId.value })
  openNew.value = false; Object.assign(form, { name: '', platform: 'web', bundle_id: '' })
  await load()
}
async function remove(a: any) {
  const ok = await useConfirm().ask({ title: 'Disconnect this app?', message: 'The SDK will stop sending events from this app.', tone: 'danger', confirmText: 'Disconnect' })
  if (!ok) return
  await supabase.from('apps').delete().eq('id', a.id)
  useToast().success('App disconnected')
  await load()
}
async function copy(t?: string) { if (t) await navigator.clipboard.writeText(t) }

const pushOpen = ref(false)
const pushForm = reactive({ id: '', app_name: '', push_platform: 'fcm', fcm_server_key: '', apns_team_id: '', apns_key_id: '', apns_bundle_id: '', apns_p8: '' })
function pushStatusFor(a: any) { return !!(a.fcm_server_key || a.apns_p8) }
function openPush(a: any) {
  Object.assign(pushForm, {
    id: a.id, app_name: a.name,
    push_platform: a.push_platform || (a.platform === 'ios' ? 'apns' : 'fcm'),
    fcm_server_key: a.fcm_server_key || '',
    apns_team_id: a.apns_team_id || '',
    apns_key_id: a.apns_key_id || '',
    apns_bundle_id: a.apns_bundle_id || a.bundle_id || '',
    apns_p8: a.apns_p8 || '',
  })
  pushOpen.value = true
}
async function readP8(ev: Event) {
  const f = (ev.target as HTMLInputElement).files?.[0]
  if (!f) return
  pushForm.apns_p8 = await f.text()
}
async function savePush() {
  const payload: any = { push_platform: pushForm.push_platform }
  if (pushForm.push_platform === 'fcm') {
    payload.fcm_server_key = pushForm.fcm_server_key
    payload.apns_p8 = ''
  } else {
    payload.apns_team_id = pushForm.apns_team_id
    payload.apns_key_id = pushForm.apns_key_id
    payload.apns_bundle_id = pushForm.apns_bundle_id
    payload.apns_p8 = pushForm.apns_p8
    payload.fcm_server_key = ''
  }
  const { error } = await supabase.from('apps').update(payload).eq('id', pushForm.id)
  if (error) { useToast().error('Could not save', error.message); return }
  useAudit().log('update', 'app', pushForm.id, pushForm.app_name, { push_platform: pushForm.push_platform })
  useToast().success('Push credentials saved')
  pushOpen.value = false
  await load()
}
async function sendTest() {
  sendingTest.value = true; testResult.value = null
  try {
    const r = await fetch(`${ingestUrl.value}/track`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Api-Key': apiKey.value.key },
      body: JSON.stringify({ external_id: `test_${Date.now()}`, name: 'test_event', properties: { source: 'dashboard' } })
    })
    testResult.value = await r.json()
  } catch (e: any) { testResult.value = { error: e.message } }
  sendingTest.value = false
  setTimeout(() => testResult.value = null, 4000)
}
watch(workspaceId, load, { immediate: true })
</script>
