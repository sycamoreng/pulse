<template>
  <div>
    <PageHeader title="Apps & SDKs" subtitle="Connect your mobile and web apps with SDK keys.">
      <template #actions>
        <button @click="openNew = true" class="btn-primary"><Icon name="plus"/>Connect app</button>
      </template>
    </PageHeader>

    <div class="p-8 space-y-6">
      <div class="card p-5 space-y-5">
        <div class="flex items-start justify-between gap-4">
          <div class="min-w-0">
            <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">Workspace API keys</div>
            <div class="text-xs text-ink-500">Publishable keys (<code class="bg-ink-50 dark:bg-[color:var(--surface-muted)] px-1 rounded">ppk_</code>) are safe in browser &amp; mobile SDKs. Secret keys (<code class="bg-ink-50 dark:bg-[color:var(--surface-muted)] px-1 rounded">pk_</code>) are server-only.</div>
          </div>
        </div>

        <div class="grid md:grid-cols-2 gap-4">
          <div v-for="k in sortedKeys" :key="k.id"
            class="rounded-xl border p-4"
            :class="k.key_type === 'publishable'
              ? 'border-brand-200 bg-brand-50/40 dark:border-[color:var(--border-subtle)] dark:bg-[color:var(--surface-muted)]'
              : 'border-ink-100 dark:border-[color:var(--border-subtle)] bg-white dark:bg-[color:var(--surface-card)]'">
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0">
                <div class="flex items-center gap-2">
                  <span class="chip text-[10px]" :class="k.key_type === 'publishable' ? 'bg-brand-500 text-white' : 'bg-ink-900 text-white'">
                    {{ k.key_type === 'publishable' ? 'Publishable' : 'Secret' }}
                  </span>
                  <span class="font-medium text-ink-900 dark:text-[color:var(--text-primary)] text-sm truncate">{{ k.name || 'Default' }}</span>
                </div>
                <div class="text-[11px] text-ink-500 mt-1">
                  <template v-if="k.last_used_at">Last used {{ timeAgo(k.last_used_at) }}</template>
                  <template v-else>Never used yet</template>
                  · Created {{ new Date(k.created_at).toLocaleDateString() }}
                </div>
              </div>
              <div class="flex items-center gap-1">
                <button @click="rotateKey(k)" class="btn-ghost !text-xs !px-2" title="Rotate"><Icon name="activity"/></button>
                <button v-if="canDelete(k)" @click="deleteKey(k)" class="text-ink-300 hover:text-red-600 p-1" title="Delete"><Icon name="trash"/></button>
              </div>
            </div>

            <div class="mt-3 flex items-center gap-2 bg-white dark:bg-[color:var(--surface-card)] rounded-lg px-3 py-2 border border-ink-100 dark:border-[color:var(--border-subtle)]">
              <code class="flex-1 text-xs font-mono text-ink-700 dark:text-[color:var(--text-secondary)] truncate">{{ k.key }}</code>
              <button @click="copy(k.key)" class="text-ink-500 hover:text-brand-500" title="Copy"><Icon name="copy"/></button>
            </div>

            <div v-if="k.key_type === 'publishable'" class="mt-3">
              <div class="flex items-center justify-between">
                <label class="text-[11px] uppercase tracking-wider text-ink-500 font-semibold">Allowed origins</label>
                <button @click="editOrigins(k)" class="text-[11px] text-brand-500 hover:underline">Edit</button>
              </div>
              <div class="mt-2 flex flex-wrap gap-1.5">
                <template v-if="(k.allowed_origins || []).length">
                  <span v-for="o in k.allowed_origins" :key="o"
                    class="chip bg-white dark:bg-[color:var(--surface-card)] border border-ink-100 dark:border-[color:var(--border-subtle)] text-ink-700 dark:text-[color:var(--text-secondary)] text-[11px] font-mono">
                    {{ o }}
                  </span>
                </template>
                <span v-else class="text-[11px] text-amber-700 bg-amber-50 border border-amber-200 rounded px-2 py-0.5">
                  No allowlist — any origin can use this key
                </span>
              </div>
            </div>
          </div>
        </div>

        <div class="text-xs text-ink-500 flex items-center gap-3 flex-wrap pt-1">
          <span>Ingestion endpoint:</span>
          <code class="bg-ink-50 dark:bg-[color:var(--surface-muted)] px-2 py-1 rounded font-mono">{{ ingestUrl }}</code>
          <button @click="copy(ingestUrl)" class="text-ink-500 hover:text-brand-500"><Icon name="copy"/></button>
        </div>
      </div>

      <div class="card p-5">
        <div class="flex items-center justify-between mb-4">
          <div>
            <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)] flex items-center gap-2">
              Connection status
              <span v-if="status.live" class="flex items-center gap-1.5 text-[11px] text-emerald-600">
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>Live
              </span>
              <span v-else class="chip bg-ink-100 text-ink-500 text-[10px]">Idle</span>
            </div>
            <div class="text-xs text-ink-500">Live signal from any SDK hitting this workspace.</div>
          </div>
          <button @click="loadStatus" class="btn-ghost !text-xs" :disabled="statusLoading">
            <Icon name="activity"/>{{ statusLoading ? 'Refreshing…' : 'Refresh' }}
          </button>
        </div>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div class="rounded-xl border border-ink-100 dark:border-[color:var(--border-subtle)] p-4 bg-white dark:bg-[color:var(--surface-card)]">
            <div class="text-[11px] uppercase tracking-wider text-ink-500">Last event</div>
            <div class="text-lg font-bold text-ink-900 dark:text-[color:var(--text-primary)] mt-1">{{ status.lastEventLabel }}</div>
            <div class="text-[11px] text-ink-500 mt-1 truncate">{{ status.lastEvent?.name || '—' }}</div>
          </div>
          <div class="rounded-xl border border-ink-100 dark:border-[color:var(--border-subtle)] p-4 bg-white dark:bg-[color:var(--surface-card)]">
            <div class="text-[11px] uppercase tracking-wider text-ink-500">Events / 24h</div>
            <div class="text-2xl font-bold text-ink-900 dark:text-[color:var(--text-primary)] mt-1 tabular-nums">{{ status.events24h.toLocaleString() }}</div>
            <div class="text-[11px] text-ink-500 mt-1">across {{ status.uniqueCustomers.toLocaleString() }} customers</div>
          </div>
          <div class="rounded-xl border border-ink-100 dark:border-[color:var(--border-subtle)] p-4 bg-white dark:bg-[color:var(--surface-card)]">
            <div class="text-[11px] uppercase tracking-wider text-ink-500">SDK keys in use</div>
            <div class="text-2xl font-bold text-ink-900 dark:text-[color:var(--text-primary)] mt-1 tabular-nums">{{ status.activeKeys }}<span class="text-sm font-medium text-ink-500"> / {{ keys.length }}</span></div>
            <div class="text-[11px] text-ink-500 mt-1">active in the last 24h</div>
          </div>
          <div class="rounded-xl border border-ink-100 dark:border-[color:var(--border-subtle)] p-4 bg-white dark:bg-[color:var(--surface-card)]">
            <div class="text-[11px] uppercase tracking-wider text-ink-500">Apps connected</div>
            <div class="text-2xl font-bold text-ink-900 dark:text-[color:var(--text-primary)] mt-1 tabular-nums">{{ apps.length }}</div>
            <div class="text-[11px] text-ink-500 mt-1">{{ appsByPlatform }}</div>
          </div>
        </div>
        <div v-if="!status.hasEvents" class="mt-4 text-xs text-ink-500 bg-ink-50 dark:bg-[color:var(--surface-muted)] rounded-lg p-3">
          No events yet. Install an SDK and call <code class="font-mono">pulse.track()</code> — the connection indicator turns live within seconds.
        </div>
      </div>

      <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div v-for="a in apps" :key="a.id" class="card p-5">
          <div class="flex items-start justify-between">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-lg flex items-center justify-center" :class="platformStyle(a.platform)"><Icon :name="platformIcon(a.platform)"/></div>
              <div>
                <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">{{ a.name }}</div>
                <div class="text-xs text-ink-500 capitalize">{{ a.platform }}</div>
              </div>
            </div>
            <div class="flex items-center gap-2">
              <span v-if="pushStatusFor(a)" class="chip bg-accent-500/10 text-accent-500 text-[10px]">{{ pushLabel(a) }}</span>
              <button @click="remove(a)" class="text-ink-300 hover:text-red-600"><Icon name="trash"/></button>
            </div>
          </div>
          <div class="mt-4 text-xs text-ink-500">
            <div>Use your workspace publishable key (<code class="font-mono">ppk_…</code>) to send events from this app.</div>
            )
            <div v-if="a.bundle_id" class="mt-2">Bundle / package: <span class="font-mono text-ink-700 dark:text-[color:var(--text-secondary)]">{{ a.bundle_id }}</span></div>
          </div>
          <button @click="openPush(a)" class="btn-secondary w-full mt-4 text-xs"><Icon name="send"/>{{ pushStatusFor(a) ? 'Update push credentials' : `Configure ${pushChannelFor(a)}` }}</button>
        </div>
      </div>

      <div class="card p-6">
        <div class="flex gap-2 mb-4 border-b border-ink-100 dark:border-[color:var(--border-subtle)] -mx-6 px-6 -mt-2">
          <button v-for="t in tabs" :key="t" @click="tab = t" class="px-3 py-2 text-sm font-medium border-b-2 -mb-px transition"
            :class="tab === t ? 'border-brand-500 text-brand-500' : 'border-transparent text-ink-500 hover:text-ink-900 dark:hover:text-[color:var(--text-primary)]'">{{ t }}</button>
        </div>
        <div v-if="activeSample.install" class="flex items-center gap-2 mb-3 flex-wrap">
          <div class="inline-flex rounded-lg border border-ink-100 dark:border-[color:var(--border-subtle)] overflow-hidden text-xs">
            <button v-for="m in pkgMgrs" :key="m" @click="pkgMgr = m" type="button"
              class="px-2.5 py-1 font-mono transition"
              :class="pkgMgr === m ? 'bg-brand-500 text-white' : 'bg-transparent text-ink-600 dark:text-[color:var(--text-secondary)] hover:bg-ink-50 dark:hover:bg-[color:var(--surface-muted)]'">{{ m }}</button>
          </div>
          <div class="flex-1 flex items-center gap-2 bg-ink-50 dark:bg-[color:var(--surface-muted)] rounded-lg px-3 py-1.5 min-w-0">
            <code class="flex-1 text-xs font-mono text-ink-700 dark:text-[color:var(--text-secondary)] truncate">{{ activeInstallCmd }}</code>
            <button @click="copy(activeInstallCmd)" type="button" class="text-ink-500 hover:text-brand-500 shrink-0" title="Copy install command"><Icon name="copy"/></button>
          </div>
        </div>
        <div class="relative">
          <button @click="copy(activeFullText)" type="button"
            class="absolute top-2 right-2 z-10 inline-flex items-center gap-1 text-xs px-2 py-1 rounded bg-ink-800 hover:bg-ink-700 text-ink-100 border border-white/10"
            title="Copy sample">
            <Icon name="copy"/>Copy
          </button>
          <pre class="bg-ink-900 text-ink-100 rounded-lg p-4 pr-20 text-xs overflow-x-auto"><code>{{ activeSample.code }}</code></pre>
        </div>
        <div class="mt-4 flex items-center gap-3 flex-wrap">
          <button @click="sendTest" :disabled="sendingTest || !publishableKey" class="btn-primary">
            <Icon name="activity"/>{{ sendingTest ? 'Sending…' : 'Send test event' }}
          </button>
          <span v-if="testResult" class="text-sm" :class="testResult.ok ? 'text-emerald-600' : 'text-red-600'">
            {{ testResult.ok ? 'Event received — refresh Customers to see it' : testResult.error }}
          </span>
        </div>
      </div>
    </div>

    <Modal v-model="originsOpen" :title="`Allowed origins · ${originsEditing?.name || 'Key'}`" subtitle="Publishable keys are origin-locked so they can't be reused from other sites.">
      <form id="originsForm" @submit.prevent="saveOrigins" class="space-y-3">
        <div class="flex gap-2">
          <input v-model="originDraft" @keydown.enter.prevent="addOrigin" class="input flex-1 font-mono text-xs" placeholder="yourapp.com, *.vercel.app, localhost:3000"/>
          <button type="button" @click="addOrigin" class="btn-secondary"><Icon name="plus"/>Add</button>
        </div>
        <div class="flex flex-wrap gap-1.5 min-h-[32px]">
          <span v-for="(o, i) in originsDraft" :key="o + i"
            class="chip bg-ink-50 dark:bg-[color:var(--surface-muted)] border border-ink-100 dark:border-[color:var(--border-subtle)] text-ink-700 dark:text-[color:var(--text-secondary)] text-xs font-mono flex items-center gap-1.5">
            {{ o }}
            <button type="button" @click="originsDraft.splice(i, 1)" class="text-ink-400 hover:text-red-600">×</button>
          </span>
          <span v-if="!originsDraft.length" class="text-[11px] text-amber-700 bg-amber-50 border border-amber-200 rounded px-2 py-0.5 self-start">
            No allowlist — any origin can use this key
          </span>
        </div>
        <div class="text-[11px] text-ink-500 space-y-1 pt-1">
          <div>· Use the bare host (<code class="font-mono">yourapp.com</code>), no scheme, no path.</div>
          )
          <div>· Wildcards: <code class="font-mono">*.vercel.app</code> matches every subdomain.</div>
          <div>· Leave empty to allow any origin (fine for local dev, lock down before prod).</div>
        </div>
      </form>
      <template #footer>
        <button @click="originsOpen = false" type="button" class="btn-secondary">Cancel</button>
        <button form="originsForm" type="submit" class="btn-primary" :disabled="savingOrigins">{{ savingOrigins ? 'Saving…' : 'Save allowlist' }}</button>
      </template>
    </Modal>

    <Modal v-model="pushOpen" :title="`Push credentials · ${pushForm.app_name}`" :subtitle="pushModalSubtitle" size="lg">
      <form id="pushf" @submit.prevent="savePush" class="space-y-3">
        <div v-if="pushForm.push_platform === 'web_push'" class="space-y-3">
          <div class="callout callout-info text-xs">
            <div>Web Push uses the <strong>VAPID</strong> protocol (RFC 8292). Works natively in Chrome, Edge, Firefox, Opera, and Safari 16+ — no Firebase required.</div>
            <div class="mt-1">Dispatch currently sends a <strong>zero-byte tickle</strong> (no encrypted aes128gcm payload), so your service worker must fetch the title &amp; body itself when the <code>push</code> event fires.</div>
          </div>
          <div>
            <div class="flex items-center justify-between mb-1">
              <label class="label !mb-0">VAPID public key *</label>
              <button type="button" @click="generateVapid" class="text-xs text-brand-500 hover:underline" :disabled="generatingVapid">{{ generatingVapid ? 'Generating…' : 'Generate new pair' }}</button>
            </div>
            <textarea v-model="pushForm.vapid_public_key" class="input font-mono text-xs" rows="2" required placeholder="BL... (base64url, 65 bytes uncompressed)"></textarea>
            <div class="text-xs text-ink-500 mt-1">Ship this key to the browser when calling <code>pushManager.subscribe</code>.</div>
          </div>
          <div>
            <label class="label">VAPID private key *</label>
            <textarea v-model="pushForm.vapid_private_key" class="input font-mono text-xs" rows="2" required placeholder="private key (base64url)"></textarea>
            <div class="text-xs text-ink-500 mt-1">Kept server-side only and used to sign each push.</div>
          </div>
          <div>
            <label class="label">Subject *</label>
            <input v-model="pushForm.vapid_subject" class="input font-mono text-xs" required placeholder="mailto:deliverability@yourcompany.com"/>
            <div class="text-xs text-ink-500 mt-1">Contact URL or mailto that browser push services can reach out to.</div>
          </div>
        </div>
        <div v-else-if="pushForm.push_platform === 'fcm'" class="space-y-3">
          <div class="callout callout-info text-xs">
            <div>FCM is used for <strong>Android</strong> native apps. Paste the full <strong>HTTP v1 service-account JSON</strong> — Google deprecated the legacy <code>AAAA…</code> server key in June 2024 and it no longer delivers pushes.</div>
          </div>
          <div>
            <label class="label">Service-account JSON *</label>
            <textarea v-model="pushForm.fcm_server_key" class="input font-mono text-xs" rows="6" placeholder='{ "type": "service_account", "project_id": "...", "private_key": "-----BEGIN PRIVATE KEY-----\n..." }' required></textarea>
            <div class="text-xs text-ink-500 mt-1">Firebase Console → Project Settings → Service accounts → Generate new private key. Paste the whole JSON file here.</div>
          </div>
        </div>
        <div v-else-if="pushForm.push_platform === 'apns'" class="space-y-3">
          <div class="callout callout-info text-xs">
            <div>APNs is used for <strong>iOS</strong> native apps. Requires a .p8 auth key with the APNs capability. Pick <strong>sandbox</strong> for tokens from Xcode / TestFlight debug builds, <strong>production</strong> for App Store builds — a mismatch returns <code>BadDeviceToken</code>.</div>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div><label class="label">Team ID *</label><input v-model="pushForm.apns_team_id" class="input font-mono" required placeholder="ABCDEF1234"/></div>
            <div><label class="label">Key ID *</label><input v-model="pushForm.apns_key_id" class="input font-mono" required placeholder="XYZ1234567"/></div>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div><label class="label">Bundle ID *</label><input v-model="pushForm.apns_bundle_id" class="input font-mono" required placeholder="com.yourcompany.app"/></div>
            <div>
              <label class="label">Environment *</label>
              <select v-model="pushForm.apns_environment" class="input">
                <option value="production">Production (App Store)</option>
                <option value="sandbox">Sandbox (Xcode / TestFlight)</option>
              </select>
            </div>
          </div>
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
const keys = ref<any[]>([])
const openNew = ref(false)
const form = reactive({ name: '', platform: 'web', bundle_id: '' })
const tabs = ['Browser', 'React', 'Nuxt', 'React Native', 'Node.js', 'iOS', 'Android', 'REST', 'cURL']
const tab = ref('Browser')

const pkgMgr = ref<'npm' | 'yarn' | 'pnpm' | 'bun'>('npm')
const pkgMgrs = ['npm', 'yarn', 'pnpm', 'bun'] as const
const installVerb = computed(() => ({ npm: 'npm install', yarn: 'yarn add', pnpm: 'pnpm add', bun: 'bun add' }[pkgMgr.value]))

const sampleKey = computed(() => publishableKey.value?.key || 'ppk_YOUR_KEY')
const sampleSecret = computed(() => secretKey.value?.key || 'pk_YOUR_SECRET_KEY')

const samples = computed<Record<string, { install?: string; code: string }>>(() => ({
  Browser: {
    install: '@pulse/browser',
    code: `import { Pulse } from '@pulse/browser'

const pulse = new Pulse({
  apiKey: '${sampleKey.value}',
  apiUrl: '${ingestUrl.value}',
})

await pulse.identify('user_123', {
  email: 'ada@example.com',
  first_name: 'Ada',
})
pulse.track('signed_up', { plan: 'pro' })`,
  },
  React: {
    install: '@pulse/react',
    code: `import { PulseProvider, usePulse } from '@pulse/react'

export function App() {
  return (
    <PulseProvider
      apiKey="${sampleKey.value}"
      apiUrl="${ingestUrl.value}"
    >
      <Checkout />
    </PulseProvider>
  )
}

function Checkout() {
  const pulse = usePulse()
  return (
    <button onClick={() => pulse.track('checkout_started', { cart_value: 99 })}>
      Check out
    </button>
  )
}`,
  },
  Nuxt: {
    install: '@pulse/nuxt',
    code: `// nuxt.config.ts
export default defineNuxtConfig({
  modules: ['@pulse/nuxt'],
  pulse: {
    apiKey: '${sampleKey.value}',
    apiUrl: '${ingestUrl.value}',
    autoPage: true,
  },
})

// any component
const pulse = usePulse()
pulse.identify(user.id, { email: user.email })`,
  },
  'React Native': {
    install: '@pulse/react-native @react-native-async-storage/async-storage',
    code: `import { PulseProvider, usePulse } from '@pulse/react-native'

export default function Root() {
  return (
    <PulseProvider
      apiKey="${sampleKey.value}"
      apiUrl="${ingestUrl.value}"
      bundleId="com.yourcompany.app"
    >
      <Home />
    </PulseProvider>
  )
}

function Home() {
  const pulse = usePulse()
  React.useEffect(() => {
    pulse.identify('user_123', { email: 'ada@example.com' })
    pulse.track('app_opened', { source: 'cold_start' })
  }, [])
  return null
}`,
  },
  'Node.js': {
    install: '@pulse/node',
    code: `// Use a SECRET key (pk_...) on the server — never publishable.
import { Pulse } from '@pulse/node'

const pulse = new Pulse({
  apiKey: process.env.PULSE_SECRET_KEY!,  // ${sampleSecret.value}
  apiUrl: '${ingestUrl.value}',
})

await pulse.identify('user_123', {
  email: 'ada@example.com',
  plan: 'pro',
})
pulse.track('order_completed', {
  order_id: 'ord_42',
  total: 129.00,
  currency: 'USD',
}, { external_id: 'user_123' })

// On shutdown, flush any queued events
await pulse.flush()`,
  },
  iOS: {
    code: `// Swift
let url = URL(string: "${ingestUrl.value}/track")!
var req = URLRequest(url: url)
req.httpMethod = "POST"
req.addValue("application/json", forHTTPHeaderField: "Content-Type")
req.addValue("${sampleKey.value}", forHTTPHeaderField: "X-Api-Key")
let body: [String: Any] = [
  "external_id": "user_123",
  "name": "app_opened",
  "properties": ["source": "push"]
]
req.httpBody = try JSONSerialization.data(withJSONObject: body)
URLSession.shared.dataTask(with: req).resume()`,
  },
  Android: {
    code: `// Kotlin
val client = OkHttpClient()
val body = """{
  "external_id": "user_123",
  "name": "app_opened",
  "properties": { "source": "push" }
}""".toRequestBody("application/json".toMediaType())
val req = Request.Builder()
  .url("${ingestUrl.value}/track")
  .addHeader("X-Api-Key", "${sampleKey.value}")
  .post(body).build()
client.newCall(req).execute()`,
  },
  REST: {
    code: `// Identify a user
await fetch('${ingestUrl.value}/identify', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'X-Api-Key': '${sampleKey.value}' },
  body: JSON.stringify({
    external_id: 'user_123',
    traits: { email: 'you@example.com', first_name: 'Ada', platform: 'web' }
  })
});

// Track an event
await fetch('${ingestUrl.value}/track', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'X-Api-Key': '${sampleKey.value}' },
  body: JSON.stringify({
    external_id: 'user_123',
    name: 'product_viewed',
    properties: { product_id: 'sku-42', price: 49.99 }
  })
});`,
  },
  cURL: {
    code: `curl -X POST "${ingestUrl.value}/track" \\
  -H "Content-Type: application/json" \\
  -H "X-Api-Key: ${sampleKey.value}" \\
  -d '{ "external_id": "user_123", "name": "signup", "properties": {} }'`,
  },
}))

const activeSample = computed(() => samples.value[tab.value])
const activeInstallCmd = computed(() => activeSample.value?.install ? `${installVerb.value} ${activeSample.value.install}` : '')
const activeFullText = computed(() => {
  const s = activeSample.value
  if (!s) return ''
  return s.install ? `${installVerb.value} ${s.install}\n\n${s.code}` : s.code
})
const sendingTest = ref(false)
const testResult = ref<any>(null)

const ingestUrl = computed(() => `${config.public.supabaseUrl}/functions/v1/track`)

const sortedKeys = computed(() => [...keys.value].sort((a, b) => {
  if ((a.key_type === 'publishable') !== (b.key_type === 'publishable')) return a.key_type === 'publishable' ? -1 : 1
  return new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
}))
const publishableKey = computed(() => keys.value.find((k) => k.key_type === 'publishable') || null)
const secretKey = computed(() => keys.value.find((k) => k.key_type === 'secret') || null)

const appsByPlatform = computed(() => {
  const counts: Record<string, number> = {}
  for (const a of apps.value) counts[a.platform] = (counts[a.platform] || 0) + 1
  const parts = Object.entries(counts).map(([p, n]) => `${n} ${p}`)
  return parts.length ? parts.join(' · ') : 'Add one to get started'
})

const platformIcon = (p: string) => p === 'web' ? 'monitor' : 'smartphone'
const platformStyle = (p: string) =>
  p === 'ios' ? 'bg-ink-900 text-white'
  : p === 'android' ? 'bg-accent-500/10 text-accent-500'
  : 'bg-brand-100/40 text-brand-500'

function timeAgo(ts: string | null | undefined) {
  if (!ts) return 'never'
  const diff = (Date.now() - new Date(ts).getTime()) / 1000
  if (diff < 60) return `${Math.max(1, Math.floor(diff))}s ago`
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return `${Math.floor(diff / 86400)}d ago`
}

async function loadKeys() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('api_keys').select('*').eq('workspace_id', workspaceId.value).order('created_at')
  keys.value = data || []
  if (!publishableKey.value) {
    await supabase.from('api_keys').insert({
      workspace_id: workspaceId.value, name: 'Default publishable', key_type: 'publishable', allowed_origins: [],
    })
    const { data: again } = await supabase.from('api_keys').select('*').eq('workspace_id', workspaceId.value).order('created_at')
    keys.value = again || []
  }
  if (!secretKey.value) {
    await supabase.from('api_keys').insert({
      workspace_id: workspaceId.value, name: 'Default secret', key_type: 'secret',
    })
    const { data: again } = await supabase.from('api_keys').select('*').eq('workspace_id', workspaceId.value).order('created_at')
    keys.value = again || []
  }
}

async function load() {
  if (!workspaceId.value) return
  const { data: ap } = await supabase.from('apps').select('*').eq('workspace_id', workspaceId.value).order('created_at')
  apps.value = ap || []
  await loadKeys()
  await loadStatus()
}

const status = reactive({
  lastEvent: null as any, events24h: 0, uniqueCustomers: 0, activeKeys: 0,
  hasEvents: false, live: false, lastEventLabel: 'Never',
})
const statusLoading = ref(false)
async function loadStatus() {
  if (!workspaceId.value) return
  statusLoading.value = true
  try {
    const since = new Date(Date.now() - 86400000).toISOString()
    const [{ data: last }, { count: ec }, { data: recent }] = await Promise.all([
      supabase.from('events').select('name, occurred_at, customer_id')
        .eq('workspace_id', workspaceId.value)
        .order('occurred_at', { ascending: false }).limit(1).maybeSingle(),
      supabase.from('events').select('id', { count: 'exact', head: true })
        .eq('workspace_id', workspaceId.value).gte('occurred_at', since),
      supabase.from('events').select('customer_id')
        .eq('workspace_id', workspaceId.value).gte('occurred_at', since).limit(2000),
    ])
    status.lastEvent = last || null
    status.hasEvents = !!last
    status.events24h = ec || 0
    const uniq = new Set((recent || []).map((r: any) => r.customer_id).filter(Boolean))
    status.uniqueCustomers = uniq.size
    if (last?.occurred_at) {
      const diffSec = (Date.now() - new Date(last.occurred_at).getTime()) / 1000
      status.live = diffSec < 300
      status.lastEventLabel = timeAgo(last.occurred_at)
    } else {
      status.live = false
      status.lastEventLabel = 'Never'
    }
    status.activeKeys = keys.value.filter((k) => k.last_used_at && Date.now() - new Date(k.last_used_at).getTime() < 86400000).length
  } finally {
    statusLoading.value = false
  }
}
let statusTimer: any = null
onMounted(() => { statusTimer = setInterval(() => { if (!document.hidden) void loadStatus() }, 15000) })
onBeforeUnmount(() => { if (statusTimer) clearInterval(statusTimer) })

async function rotateKey(k: any) {
  const ok = await useConfirm().ask({
    title: `Rotate ${k.name || 'key'}?`,
    message: 'The old key stops working immediately. Update every SDK and server using it.',
    tone: 'danger', confirmText: 'Rotate',
  })
  if (!ok) return
  const payload: any = {
    workspace_id: workspaceId.value, name: k.name, key_type: k.key_type,
    allowed_origins: k.allowed_origins || [], allowed_bundle_ids: k.allowed_bundle_ids || [],
  }
  const { error: insErr } = await supabase.from('api_keys').insert(payload)
  if (insErr) { useToast().error('Could not rotate', insErr.message); return }
  await supabase.from('api_keys').delete().eq('id', k.id)
  useAudit().log('rotate', 'api_key', k.id, k.name, { key_type: k.key_type })
  useToast().success('Key rotated')
  await loadKeys()
}

function canDelete(k: any) {
  const sameType = keys.value.filter((x) => x.key_type === k.key_type)
  return sameType.length > 1
}
async function deleteKey(k: any) {
  const ok = await useConfirm().ask({
    title: `Delete ${k.name || 'key'}?`, message: 'SDKs using this key will stop working.',
    tone: 'danger', confirmText: 'Delete',
  })
  if (!ok) return
  const { error } = await supabase.from('api_keys').delete().eq('id', k.id)
  if (error) { useToast().error('Could not delete', error.message); return }
  useToast().success('Key deleted')
  await loadKeys()
}

const originsOpen = ref(false)
const originsEditing = ref<any>(null)
const originsDraft = ref<string[]>([])
const originDraft = ref('')
const savingOrigins = ref(false)
function editOrigins(k: any) {
  originsEditing.value = k
  originsDraft.value = [...(k.allowed_origins || [])]
  originDraft.value = ''
  originsOpen.value = true
}
function normaliseOrigin(raw: string) {
  let s = raw.trim().toLowerCase()
  if (!s) return ''
  s = s.replace(/^https?:\/\//, '').replace(/\/.*$/, '').replace(/:443$|:80$/, '')
  return s
}
function addOrigin() {
  const parts = originDraft.value.split(',').map(normaliseOrigin).filter(Boolean)
  for (const p of parts) if (!originsDraft.value.includes(p)) originsDraft.value.push(p)
  originDraft.value = ''
}
async function saveOrigins() {
  if (originDraft.value.trim()) addOrigin()
  savingOrigins.value = true
  const { error } = await supabase.from('api_keys')
    .update({ allowed_origins: originsDraft.value })
    .eq('id', originsEditing.value.id)
  savingOrigins.value = false
  if (error) { useToast().error('Could not save', error.message); return }
  useAudit().log('update', 'api_key', originsEditing.value.id, originsEditing.value.name, {
    allowed_origins: originsDraft.value,
  })
  useToast().success('Allowlist updated')
  originsOpen.value = false
  await loadKeys()
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
async function copy(t?: string) { if (t) { await navigator.clipboard.writeText(t); useToast().success('Copied') } }

const pushOpen = ref(false)
const generatingVapid = ref(false)
const pushForm = reactive({
  id: '', app_name: '', platform: 'web', push_platform: 'web_push',
  fcm_server_key: '', apns_team_id: '', apns_key_id: '', apns_bundle_id: '', apns_p8: '', apns_environment: 'production',
  vapid_public_key: '', vapid_private_key: '', vapid_subject: '',
})
function pushChannelFor(a: any): string {
  if (a.platform === 'web') return 'Web Push'
  if (a.platform === 'ios') return 'APNs'
  if (a.platform === 'android') return 'FCM'
  return 'push'
}
function pushLabel(a: any): string {
  if (a.vapid_public_key) return 'web push'
  if (a.apns_p8) return 'apns'
  if (a.fcm_server_key) return 'fcm'
  return 'push'
}
function pushStatusFor(a: any) { return !!(a.fcm_server_key || a.apns_p8 || a.vapid_public_key) }
const pushModalSubtitle = computed(() => {
  if (pushForm.push_platform === 'web_push') return 'Configure VAPID keys for browser Web Push.'
  if (pushForm.push_platform === 'fcm') return 'Configure Firebase Cloud Messaging for Android.'
  if (pushForm.push_platform === 'apns') return 'Configure Apple Push Notification service for iOS.'
  return ''
})
function defaultPushPlatform(platform: string): 'web_push' | 'fcm' | 'apns' {
  if (platform === 'ios') return 'apns'
  if (platform === 'android') return 'fcm'
  return 'web_push'
}
function openPush(a: any) {
  Object.assign(pushForm, {
    id: a.id, app_name: a.name, platform: a.platform,
    push_platform: a.push_platform || defaultPushPlatform(a.platform),
    fcm_server_key: a.fcm_server_key || '',
    apns_team_id: a.apns_team_id || '',
    apns_key_id: a.apns_key_id || '',
    apns_bundle_id: a.apns_bundle_id || a.bundle_id || '',
    apns_p8: a.apns_p8 || '',
    apns_environment: a.apns_environment || 'production',
    vapid_public_key: a.vapid_public_key || '',
    vapid_private_key: a.vapid_private_key || '',
    vapid_subject: a.vapid_subject || '',
  })
  pushOpen.value = true
}
async function readP8(ev: Event) {
  const f = (ev.target as HTMLInputElement).files?.[0]
  if (!f) return
  pushForm.apns_p8 = await f.text()
}
function b64url(buf: ArrayBuffer) {
  const bytes = new Uint8Array(buf)
  let s = ''
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i])
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}
async function generateVapid() {
  generatingVapid.value = true
  try {
    const kp = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign','verify'])
    const pub = await crypto.subtle.exportKey('raw', kp.publicKey)
    const priv = await crypto.subtle.exportKey('jwk', kp.privateKey)
    pushForm.vapid_public_key = b64url(pub)
    pushForm.vapid_private_key = priv.d || ''
    if (!pushForm.vapid_subject) pushForm.vapid_subject = 'mailto:deliverability@example.com'
    useToast().success('VAPID keys generated')
  } catch (e: any) {
    useToast().error('Could not generate keys', e.message)
  } finally {
    generatingVapid.value = false
  }
}
async function savePush() {
  const payload: any = {
    push_platform: pushForm.push_platform,
    fcm_server_key: '', apns_p8: '', apns_team_id: '', apns_key_id: '', apns_bundle_id: '', apns_environment: 'production',
    vapid_public_key: '', vapid_private_key: '', vapid_subject: '',
  }
  if (pushForm.push_platform === 'web_push') {
    payload.vapid_public_key = pushForm.vapid_public_key
    payload.vapid_private_key = pushForm.vapid_private_key
    payload.vapid_subject = pushForm.vapid_subject
  } else if (pushForm.push_platform === 'fcm') {
    payload.fcm_server_key = pushForm.fcm_server_key
  } else if (pushForm.push_platform === 'apns') {
    payload.apns_team_id = pushForm.apns_team_id
    payload.apns_key_id = pushForm.apns_key_id
    payload.apns_bundle_id = pushForm.apns_bundle_id
    payload.apns_p8 = pushForm.apns_p8
    payload.apns_environment = pushForm.apns_environment
  }
  const { error } = await supabase.from('apps').update(payload).eq('id', pushForm.id)
  if (error) { useToast().error('Could not save', error.message); return }
  useAudit().log('update', 'app', pushForm.id, pushForm.app_name, { push_platform: pushForm.push_platform })
  useToast().success('Push credentials saved')
  pushOpen.value = false
  await load()
}
async function sendTest() {
  if (!publishableKey.value) return
  sendingTest.value = true; testResult.value = null
  try {
    const r = await fetch(`${ingestUrl.value}/track`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Api-Key': publishableKey.value.key },
      body: JSON.stringify({ external_id: `test_${Date.now()}`, name: 'test_event', properties: { source: 'dashboard' } })
    })
    testResult.value = await r.json()
    if (testResult.value?.ok) setTimeout(() => loadStatus(), 600)
  } catch (e: any) { testResult.value = { error: e.message } }
  sendingTest.value = false
  setTimeout(() => testResult.value = null, 6000)
}
watch(workspaceId, load, { immediate: true })
</script>
