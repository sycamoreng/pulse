<template>
  <div>
    <PageHeader title="Integrations" subtitle="Connect your store, stream events to external systems, and schedule exports."/>

    <div class="p-8 max-w-5xl space-y-4">
      <TestModeStrip what="Integrations" message="Webhooks, commerce connectors, and exports do not fire from a test workspace — configure them here, then switch to production to go live."/>
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
          <Pagination v-if="orders.length" v-model:page="ordersPage" v-model:pageSize="ordersPageSize" :total="ordersTotal"/>
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

      <!-- Ad audiences -->
      <div v-if="tab === 'audiences'" class="space-y-4">
        <div class="card p-6">
          <div class="flex items-center justify-between gap-4">
            <div class="max-w-xl">
              <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">Ad audience destinations</div>
              <div class="text-xs text-ink-500 dark:text-[color:var(--text-tertiary)] mt-1">Sync lists and segments to Facebook Custom Audiences or Google Customer Match. Emails and phone numbers are SHA-256 hashed before upload. Your API credentials are encrypted at rest and never exposed to the browser after saving.</div>
            </div>
            <button @click="newDest" class="btn-primary shrink-0"><Icon name="plus"/>New destination</button>
          </div>
        </div>

        <div v-if="!destinations.length" class="card p-8 text-center text-sm text-ink-500 dark:text-[color:var(--text-tertiary)]">No audience destinations connected.</div>
        <div v-for="d in destinations" :key="d.id" class="card p-4">
          <div class="flex items-center justify-between gap-3 flex-wrap">
            <div class="min-w-0">
              <div class="flex items-center gap-2 flex-wrap">
                <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)] text-sm">{{ d.name || (d.provider === 'facebook' ? 'Facebook Custom Audience' : 'Google Customer Match') }}</div>
                <span class="chip text-[10px] capitalize" :class="d.provider === 'facebook' ? 'bg-brand-100/40 text-brand-700 dark:text-brand-400' : 'bg-accent-500/10 text-accent-500'">{{ d.provider }}</span>
                <span class="chip text-[10px]" :class="d.is_active ? 'bg-accent-500/10 text-accent-500' : 'bg-ink-100 dark:bg-[color:var(--surface-muted)] text-ink-700 dark:text-[color:var(--text-secondary)]'">{{ d.is_active ? 'active' : 'paused' }}</span>
                <span class="chip text-[10px]" :class="d.has_credentials ? 'bg-accent-500/10 text-accent-500' : 'bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-400'"><Icon name="shield" class="w-3 h-3 mr-0.5 inline"/>{{ d.has_credentials ? 'credentials stored' : 'credentials required' }}</span>
                <span v-if="d.last_status === 'failed'" class="chip bg-red-100 dark:bg-red-500/15 text-red-600 dark:text-red-400 text-[10px]">last sync failed</span>
              </div>
              <div class="text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)] font-mono truncate mt-1">{{ d.external_audience_id }}<span v-if="d.account_id"> · {{ d.account_id }}</span></div>
              <div class="text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)] mt-0.5">
                <span v-if="d.last_synced_at">Last synced {{ new Date(d.last_synced_at).toLocaleString() }}</span>
                <span v-else>Not synced yet</span>
                <span v-if="d.last_error" class="text-red-600 dark:text-red-400"> · {{ d.last_error.slice(0, 120) }}</span>
              </div>
            </div>
            <div class="flex items-center gap-2 flex-wrap shrink-0">
              <button @click="openCredentials(d.id, d.provider)" class="btn-ghost !py-1 !text-xs"><Icon name="shield" class="w-3 h-3"/>{{ d.has_credentials ? 'Update credentials' : 'Connect' }}</button>
              <button @click="syncDest(d)" :disabled="!d.has_credentials" class="btn-ghost !py-1 !text-xs disabled:opacity-40"><Icon name="send" class="w-3 h-3"/>Sync now</button>
              <button @click="editDest(d)" class="btn-secondary !py-1 !text-xs">Edit</button>
            </div>
          </div>
        </div>

        <div v-if="syncs.length" class="card">
          <div class="px-5 py-3 border-b border-ink-100 dark:border-[color:var(--border-subtle)] font-semibold text-ink-900 dark:text-[color:var(--text-primary)] text-sm">Recent sync jobs</div>
          <table class="w-full text-sm">
            <thead><tr>
              <th class="table-th">When</th><th class="table-th">Destination</th><th class="table-th">Source</th>
              <th class="table-th">Status</th><th class="table-th">Matched</th><th class="table-th">Unmatched</th>
            </tr></thead>
            <tbody>
              <tr v-for="s in syncs" :key="s.id">
                <td class="table-td text-xs">{{ new Date(s.created_at).toLocaleString() }}</td>
                <td class="table-td text-xs">{{ destMap[s.destination_id]?.name || '—' }}</td>
                <td class="table-td text-xs capitalize">{{ s.source_type }}</td>
                <td class="table-td"><span class="chip text-[10px]" :class="syncStatusClass(s.status)">{{ s.status }}</span></td>
                <td class="table-td text-xs">{{ s.matched_count }}</td>
                <td class="table-td text-xs">{{ s.unmatched_count }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Integration Hub -->
      <div v-if="tab === 'hub'" class="space-y-4">
        <div class="card p-6">
          <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">Integration hub</div>
          <div class="text-xs text-ink-500 dark:text-[color:var(--text-tertiary)] mt-1">Connect your ops and analytics stack. Pulse encrypts every credential server-side and never surfaces them back to this UI.</div>
        </div>
        <div class="grid md:grid-cols-2 xl:grid-cols-3 gap-4">
          <div v-for="p in hubProviders" :key="p.id" class="card p-5 flex flex-col">
            <div class="flex items-start gap-3">
              <div class="w-11 h-11 rounded-xl flex items-center justify-center shrink-0" :style="{ background: p.accent + '18' }">
                <svg viewBox="0 0 24 24" class="w-6 h-6" :style="{ fill: p.accent }" aria-hidden="true"><path :d="p.logoPath"/></svg>
              </div>
              <div class="min-w-0 flex-1">
                <div class="flex items-center gap-2 flex-wrap">
                  <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)] text-sm">{{ p.label }}</div>
                  <span v-if="hubConnectionFor(p.id)?.has_credentials" class="chip text-[10px] bg-accent-500/10 text-accent-500">connected</span>
                </div>
                <div class="text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)] uppercase tracking-wider mt-0.5">{{ p.category }}</div>
              </div>
            </div>
            <div class="text-sm font-medium text-ink-800 dark:text-[color:var(--text-secondary)] mt-3">{{ p.summary }}</div>
            <div class="text-[12px] leading-relaxed text-ink-600 dark:text-[color:var(--text-tertiary)] mt-1.5">{{ p.description }}</div>
            <ul class="mt-3 space-y-1">
              <li v-for="c in p.capabilities" :key="c" class="text-[11px] text-ink-700 dark:text-[color:var(--text-secondary)] flex items-start gap-1.5">
                <Icon name="check" class="w-3 h-3 text-accent-500 mt-0.5 shrink-0"/>
                <span>{{ c }}</span>
              </li>
            </ul>
            <div class="mt-4 pt-3 border-t border-ink-100 dark:border-[color:var(--border)] flex items-center gap-2">
              <button @click="openHubConnect(p)" class="btn-secondary !py-1.5 !text-xs">{{ hubConnectionFor(p.id) ? 'Manage' : 'Connect' }}</button>
              <button v-if="hubConnectionFor(p.id)?.has_credentials" @click="testHub(p)" :disabled="hubTesting === p.id" class="btn-ghost !py-1.5 !text-xs">{{ hubTesting === p.id ? 'Testing...' : 'Send test' }}</button>
            </div>
            <div v-if="hubConnectionFor(p.id)?.last_error" class="text-[11px] text-red-500 mt-2 truncate">{{ hubConnectionFor(p.id).last_error }}</div>
          </div>
        </div>
      </div>

      <!-- SMS / WhatsApp / RCS -->
      <div v-if="tab === 'sms'" class="space-y-4">
        <div class="card p-6 flex items-start justify-between gap-4">
          <div class="max-w-2xl">
            <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">SMS, WhatsApp &amp; RCS providers</div>
            <div class="text-xs text-ink-500 dark:text-[color:var(--text-tertiary)] mt-1">Connect Twilio to deliver campaigns and journey messages over SMS, WhatsApp Business, or RCS. Credentials are encrypted at rest and never leave the platform. Campaigns in test-mode workspaces skip real dispatch.</div>
          </div>
          <button @click="newSmsProvider" class="btn-primary shrink-0"><Icon name="plus"/>New sender</button>
        </div>

        <div v-if="!smsProviders.length" class="card p-8 text-center text-sm text-ink-500 dark:text-[color:var(--text-tertiary)]">No senders configured. Platform Twilio credentials (if set) will be used as a fallback.</div>

        <div v-for="p in smsProviders" :key="p.id" class="card p-4 flex items-center justify-between gap-3 flex-wrap">
          <div class="min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)] text-sm capitalize">{{ p.provider.replace('_', ' ') }}</div>
              <span class="chip text-[10px] uppercase" :class="p.channel === 'whatsapp' ? 'bg-accent-500/10 text-accent-500' : p.channel === 'rcs' ? 'bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-400' : 'bg-brand-100/40 text-brand-700 dark:text-brand-400'">{{ p.channel }}</span>
              <span class="chip text-[10px]" :class="p.is_active ? 'bg-accent-500/10 text-accent-500' : 'bg-ink-100 dark:bg-[color:var(--surface-muted)] text-ink-700 dark:text-[color:var(--text-secondary)]'">{{ p.is_active ? 'active' : 'disabled' }}</span>
            </div>
            <div class="text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)] mt-1 font-mono">{{ p.messaging_service_sid || p.from_number || 'no sender' }}</div>
            <div class="text-[11px] mt-1">
              <span v-if="p.has_credentials" class="chip bg-accent-500/10 text-accent-500">credentials connected</span>
              <span v-else class="chip bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-400">no credentials</span>
            </div>
          </div>
          <div class="flex items-center gap-2 shrink-0">
            <button @click="openSmsCredentials(p)" class="btn-secondary !py-1 !text-xs">{{ p.has_credentials ? 'Update credentials' : 'Connect' }}</button>
            <button @click="testSms(p)" :disabled="smsTesting === p.id || !p.has_credentials" class="btn-ghost !py-1 !text-xs">{{ smsTesting === p.id ? 'Sending...' : 'Test send' }}</button>
            <button @click="editSmsProvider(p)" class="btn-ghost !py-1 !text-xs">Edit</button>
          </div>
        </div>
      </div>

    <Modal v-model="smsOpen" :title="smsForm.id ? 'Edit sender' : 'New sender'">
      <form id="smsf" @submit.prevent="saveSmsProvider" class="space-y-3">
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">Provider</label>
            <select v-model="smsForm.provider" class="input">
              <option value="twilio">Twilio</option>
              <option value="twilio_whatsapp">Twilio WhatsApp</option>
              <option value="twilio_rcs">Twilio RCS</option>
            </select>
          </div>
          <div><label class="label">Channel</label>
            <select v-model="smsForm.channel" class="input">
              <option value="sms">SMS</option>
              <option value="whatsapp">WhatsApp</option>
              <option value="rcs">RCS</option>
            </select>
          </div>
        </div>
        <div><label class="label">From number (E.164)</label><input v-model="smsForm.from_number" class="input font-mono" placeholder="+14155551234"/></div>
        <div><label class="label">Messaging Service SID <span class="text-ink-400">(optional, overrides From)</span></label><input v-model="smsForm.messaging_service_sid" class="input font-mono" placeholder="MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"/></div>
        <div class="text-[11px] text-ink-500">Save the sender first, then click <span class="font-medium">Connect</span> on the sender row to supply the Account SID and Auth Token securely. Credentials are encrypted on the server and never surfaced to the UI again.</div>
        <label class="flex items-center gap-2 text-sm"><input type="checkbox" v-model="smsForm.is_active"/> Active</label>
      </form>
      <template #footer>
        <button v-if="smsForm.id" @click="deleteSmsProvider" class="btn-ghost text-red-600 dark:text-red-400 mr-auto">Delete</button>
        <button @click="smsOpen = false" class="btn-secondary">Cancel</button>
        <button form="smsf" type="submit" class="btn-primary">Save</button>
      </template>
    </Modal>

    <Modal v-model="smsCredsOpen" :title="smsCredsForm.has ? 'Update Twilio credentials' : 'Connect Twilio'">
      <form id="smscf" @submit.prevent="saveSmsCredentials" class="space-y-3">
        <div class="text-xs text-ink-500">Credentials are encrypted on the server and never shown back to the UI. Leave the auth token blank to keep the existing one.</div>
        <div><label class="label">Account SID *</label><input v-model="smsCredsForm.account_sid" class="input font-mono" required placeholder="ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"/></div>
        <div><label class="label">Auth Token {{ smsCredsForm.has ? '(leave blank to keep current)' : '*' }}</label>
          <input v-model="smsCredsForm.auth_token" type="password" class="input font-mono" :required="!smsCredsForm.has" placeholder="••••••••••••"/></div>
      </form>
      <template #footer>
        <button @click="smsCredsOpen = false" class="btn-secondary">Cancel</button>
        <button form="smscf" type="submit" class="btn-primary" :disabled="smsCredsSaving">{{ smsCredsSaving ? 'Saving...' : 'Save credentials' }}</button>
      </template>
    </Modal>

    <Modal v-model="hubCredsOpen" :title="hubCredsForm.connection_id ? `Update ${hubCredsForm.label}` : `Connect ${hubCredsForm.label}`">
      <form id="hubcf" @submit.prevent="saveHubConnection" class="space-y-3">
        <div class="text-xs text-ink-500">Secret fields are encrypted server-side. Leave them blank when updating if you want to keep the current values.</div>
        <div><label class="label">Name</label><input v-model="hubCredsForm.name" class="input" :placeholder="hubCredsForm.label"/></div>
        <div v-for="f in hubCredsForm.configFields" :key="f">
          <label class="label">{{ hubFieldLabel(f) }}</label>
          <input v-model="hubCredsForm.config[f]" class="input font-mono" :placeholder="hubFieldPlaceholder(f)"/>
        </div>
        <div v-for="f in hubCredsForm.secretFields" :key="f">
          <label class="label">{{ hubFieldLabel(f) }} {{ hubCredsForm.connection_id ? '(leave blank to keep)' : '*' }}</label>
          <textarea v-if="f.includes('json')" v-model="hubCredsForm.secrets[f]" rows="4" class="input font-mono text-xs" :required="!hubCredsForm.connection_id" :placeholder="hubFieldPlaceholder(f)"></textarea>
          <input v-else v-model="hubCredsForm.secrets[f]" type="password" class="input font-mono" :required="!hubCredsForm.connection_id" :placeholder="hubFieldPlaceholder(f)"/>
        </div>
      </form>
      <template #footer>
        <button v-if="hubCredsForm.connection_id" @click="disconnectHub" class="btn-ghost text-red-600 mr-auto">Disconnect</button>
        <button @click="hubCredsOpen = false" class="btn-secondary">Cancel</button>
        <button form="hubcf" type="submit" class="btn-primary" :disabled="hubCredsSaving">{{ hubCredsSaving ? 'Saving...' : 'Save' }}</button>
      </template>
    </Modal>

    <Modal v-model="destOpen" :title="destForm.id ? 'Edit audience destination' : 'New audience destination'">
      <form id="df" @submit.prevent="saveDest" class="space-y-3">
        <div><label class="label">Name</label><input v-model="destForm.name" class="input" placeholder="Meta — VIP list"/></div>
        <div><label class="label">Provider *</label>
          <select v-model="destForm.provider" class="input" :disabled="!!destForm.id">
            <option value="facebook">Facebook Custom Audiences</option>
            <option value="google">Google Customer Match</option>
          </select>
        </div>
        <div><label class="label">{{ destForm.provider === 'facebook' ? 'Audience ID *' : 'User list resource *' }}</label>
          <input v-model="destForm.external_audience_id" class="input font-mono" required :placeholder="destForm.provider === 'facebook' ? '123456789012345' : 'customers/1234567890/userLists/99999'"/>
        </div>
        <div v-if="destForm.provider === 'google'">
          <label class="label">Google Ads customer ID *</label>
          <input v-model="destForm.account_id" class="input font-mono" placeholder="1234567890 (no dashes)" required/>
        </div>
        <label class="flex items-center gap-2 text-sm"><input type="checkbox" v-model="destForm.is_active"/> Active</label>
      </form>
      <template #footer>
        <button v-if="destForm.id" @click="deleteDest" class="btn-ghost text-red-600 dark:text-red-400 mr-auto">Delete</button>
        <button @click="destOpen = false" class="btn-secondary">Cancel</button>
        <button form="df" type="submit" class="btn-primary">Save &amp; continue</button>
      </template>
    </Modal>

    <Modal v-model="credsOpen" :title="credsForm.provider === 'facebook' ? 'Connect Facebook credentials' : 'Connect Google Ads credentials'">
      <form id="cfr" @submit.prevent="saveCredentials" class="space-y-3">
        <div class="flex items-start gap-2 p-3 rounded-lg bg-brand-100/20 dark:bg-brand-500/10 border border-brand-100 dark:border-brand-500/30">
          <Icon name="shield" class="w-4 h-4 text-brand-500 mt-0.5"/>
          <div class="text-[11px] text-ink-700 dark:text-[color:var(--text-secondary)] leading-relaxed">Credentials are encrypted with AES-256-GCM in a private vault. They are only decrypted server-side during a sync and are never sent back to the browser.</div>
        </div>
        <div v-if="credsForm.provider === 'facebook'">
          <label class="label">Marketing API access token *</label>
          <input v-model="credsForm.fb_token" type="password" class="input font-mono" placeholder="EAAG…" required autocomplete="off"/>
          <div class="text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)] mt-1">Generate a long-lived user token with <span class="font-mono">ads_management</span> scope from Meta Business Suite.</div>
        </div>
        <template v-else>
          <div>
            <label class="label">Developer token *</label>
            <input v-model="credsForm.gads_developer_token" type="password" class="input font-mono" required autocomplete="off"/>
            <div class="text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)] mt-1">From your Google Ads API Center.</div>
          </div>
          <div>
            <label class="label">OAuth access token *</label>
            <input v-model="credsForm.gads_access_token" type="password" class="input font-mono" required autocomplete="off"/>
            <div class="text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)] mt-1">Access token for a refresh-token-backed OAuth client with scope <span class="font-mono">adwords</span>.</div>
          </div>
        </template>
      </form>
      <template #footer>
        <button @click="credsOpen = false" class="btn-secondary">Skip for now</button>
        <button form="cfr" type="submit" :disabled="savingCreds" class="btn-primary inline-flex items-center gap-1"><Icon v-if="savingCreds" name="spinner" class="animate-spin"/>{{ savingCreds ? 'Encrypting…' : 'Store securely' }}</button>
      </template>
    </Modal>

    <Modal v-model="syncOpen" title="Sync audience">
      <form id="syf" @submit.prevent="runSync" class="space-y-3">
        <div class="text-sm text-ink-700 dark:text-[color:var(--text-secondary)]">Push audience data to <strong>{{ syncTarget?.name || syncTarget?.provider }}</strong>.</div>
        <div>
          <label class="label">Source</label>
          <select v-model="syncForm.source_type" class="input">
            <option value="all">All customers</option>
            <option value="list">List</option>
            <option value="segment">Segment</option>
          </select>
        </div>
        <div v-if="syncForm.source_type === 'list'">
          <label class="label">List</label>
          <select v-model="syncForm.source_id" class="input" required>
            <option value="">—</option>
            <option v-for="l in lists" :key="l.id" :value="l.id">{{ l.name }}</option>
          </select>
        </div>
        <div v-if="syncForm.source_type === 'segment'">
          <label class="label">Segment</label>
          <select v-model="syncForm.source_id" class="input" required>
            <option value="">—</option>
            <option v-for="s in segments" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
        </div>
        <div>
          <label class="label">Operation</label>
          <select v-model="syncForm.operation" class="input">
            <option value="add">Add members</option>
            <option value="remove">Remove members</option>
          </select>
        </div>
      </form>
      <template #footer>
        <button @click="syncOpen = false" class="btn-secondary">Cancel</button>
        <button form="syf" type="submit" class="btn-primary" :disabled="syncing">{{ syncing ? 'Running…' : 'Run sync' }}</button>
      </template>
    </Modal>

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
    { id: 'audiences', label: 'Ad audiences', icon: 'users' },
    { id: 'sms', label: 'SMS / WhatsApp', icon: 'send' },
    { id: 'hub', label: 'Integration hub', icon: 'layers' },
  )
  return base
})
const tab = ref(commerceEnabled.value ? 'commerce' : 'webhooks')
watch(commerceEnabled, (on) => { if (!on && tab.value === 'commerce') tab.value = 'webhooks' })

const orders = ref<any[]>([])
const ordersPage = ref(1)
const ordersPageSize = ref(25)
const ordersTotal = ref(0)
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

const destinations = ref<any[]>([])
const syncs = ref<any[]>([])
const lists = ref<any[]>([])
const segments = ref<any[]>([])
const destOpen = ref(false)
const destForm = reactive<any>({ id: '', name: '', provider: 'facebook', external_audience_id: '', account_id: '', is_active: true })
const credsOpen = ref(false)
const credsForm = reactive<any>({ destination_id: '', provider: 'facebook', fb_token: '', gads_developer_token: '', gads_access_token: '' })
const savingCreds = ref(false)
const syncOpen = ref(false)
const syncTarget = ref<any>(null)
const syncForm = reactive<any>({ source_type: 'all', source_id: '', operation: 'add' })
const syncing = ref(false)
const destMap = computed(() => Object.fromEntries(destinations.value.map((d: any) => [d.id, d])))
function syncStatusClass(s: string) {
  if (s === 'completed') return 'bg-accent-500/10 text-accent-500'
  if (s === 'failed') return 'bg-red-100 dark:bg-red-500/15 text-red-600 dark:text-red-400'
  if (s === 'running') return 'bg-yellow-100 dark:bg-yellow-500/15 text-yellow-700 dark:text-yellow-400'
  return 'bg-ink-100 dark:bg-[color:var(--surface-muted)] text-ink-700 dark:text-[color:var(--text-secondary)]'
}
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
  const ordersFrom = (ordersPage.value - 1) * ordersPageSize.value
  const ordersTo = ordersFrom + ordersPageSize.value - 1
  const [o, h, k, s, d, sy, ls, sg, sp] = await Promise.all([
    supabase.from('commerce_orders').select('*', { count: 'exact' }).eq('workspace_id', workspaceId.value).order('occurred_at', { ascending: false }).range(ordersFrom, ordersTo),
    supabase.from('webhook_destinations').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('api_keys').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('data_exports_scheduled').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('ad_audience_destinations').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('ad_audience_syncs').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }).limit(20),
    supabase.from('lists').select('id, name').eq('workspace_id', workspaceId.value).order('name'),
    supabase.from('segments').select('id, name').eq('workspace_id', workspaceId.value).order('name'),
    supabase.from('sms_providers').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
  ])
  orders.value = o.data || []
  ordersTotal.value = o.count || 0
  hooks.value = h.data || []
  keys.value = k.data || []
  schedules.value = s.data || []
  destinations.value = d.data || []
  syncs.value = sy.data || []
  lists.value = ls.data || []
  segments.value = sg.data || []
  smsProviders.value = sp.data || []
}

const smsProviders = ref<any[]>([])
const smsOpen = ref(false)
const smsTesting = ref('')
const smsForm = reactive<any>({ id: '', provider: 'twilio', channel: 'sms', from_number: '', messaging_service_sid: '', is_active: true })
function newSmsProvider() {
  Object.assign(smsForm, { id: '', provider: 'twilio', channel: 'sms', from_number: '', messaging_service_sid: '', is_active: true })
  smsOpen.value = true
}
function editSmsProvider(p: any) {
  Object.assign(smsForm, {
    id: p.id, provider: p.provider, channel: p.channel,
    from_number: p.from_number || '', messaging_service_sid: p.messaging_service_sid || '',
    is_active: p.is_active,
  })
  smsOpen.value = true
}
async function saveSmsProvider() {
  const payload = {
    workspace_id: workspaceId.value, provider: smsForm.provider, channel: smsForm.channel,
    from_number: smsForm.from_number || '', messaging_service_sid: smsForm.messaging_service_sid || '',
    is_active: !!smsForm.is_active,
  }
  const { error } = smsForm.id
    ? await supabase.from('sms_providers').update(payload).eq('id', smsForm.id)
    : await supabase.from('sms_providers').insert(payload)
  if (error) { useToast().error('Save failed', error.message); return }
  smsOpen.value = false; await load(); useToast().success('Sender saved')
}
async function deleteSmsProvider() {
  if (!smsForm.id) return
  const { error } = await supabase.from('sms_providers').delete().eq('id', smsForm.id)
  if (error) { useToast().error('Delete failed', error.message); return }
  smsOpen.value = false; await load()
}
async function testSms(p: any) {
  const phone = window.prompt('Send a test message to which phone number? (E.164, e.g. +14155551234)')
  if (!phone) return
  smsTesting.value = p.id
  try {
    const apiUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/sms-dispatch`
    const res = await fetch(apiUrl, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ workspace_id: workspaceId.value, to_phone: phone, body: 'Pulse test message', channel: p.channel, kind: 'test' }),
    })
    const json = await res.json().catch(() => ({}))
    if (json?.ok) useToast().success('Test sent', `Status: ${json.status}`)
    else useToast().error('Test failed', json?.error || json?.status || 'Unknown error')
  } catch (e: any) {
    useToast().error('Test failed', String(e?.message || e))
  } finally {
    smsTesting.value = ''
  }
}

function newDest() {
  Object.assign(destForm, { id: '', name: '', provider: 'facebook', external_audience_id: '', account_id: '', is_active: true })
  destOpen.value = true
}
function editDest(d: any) {
  Object.assign(destForm, {
    id: d.id, name: d.name, provider: d.provider, external_audience_id: d.external_audience_id || '',
    account_id: d.account_id || '', is_active: d.is_active,
  })
  destOpen.value = true
}
function openCredentials(destinationId: string, provider: string) {
  Object.assign(credsForm, { destination_id: destinationId, provider, fb_token: '', gads_developer_token: '', gads_access_token: '' })
  credsOpen.value = true
}
async function saveDest() {
  const payload = {
    workspace_id: workspaceId.value, name: destForm.name, provider: destForm.provider,
    external_audience_id: destForm.external_audience_id, account_id: destForm.account_id,
    is_active: destForm.is_active,
    created_by: auth.user?.id || null,
  }
  let savedId = destForm.id
  if (destForm.id) {
    const { error } = await supabase.from('ad_audience_destinations').update(payload).eq('id', destForm.id)
    if (error) { useToast().error('Save failed', error.message); return }
  } else {
    const { data, error } = await supabase.from('ad_audience_destinations').insert(payload).select().maybeSingle()
    if (error) { useToast().error('Save failed', error.message); return }
    savedId = data?.id
  }
  destOpen.value = false
  await load()
  useToast().success('Destination saved')
  const dest = destinations.value.find(x => x.id === savedId)
  if (savedId && (!dest?.has_credentials)) openCredentials(savedId, destForm.provider)
}
async function saveCredentials() {
  if (!credsForm.destination_id) return
  const credentials = credsForm.provider === 'facebook'
    ? { access_token: (credsForm.fb_token || '').trim() }
    : { developer_token: (credsForm.gads_developer_token || '').trim(), access_token: (credsForm.gads_access_token || '').trim() }
  if (credsForm.provider === 'facebook' && !credentials.access_token) { useToast().error('Access token is required'); return }
  if (credsForm.provider === 'google' && (!(credentials as any).developer_token || !(credentials as any).access_token)) {
    useToast().error('Both tokens are required'); return
  }
  savingCreds.value = true
  try {
    const { data: { session } } = await $supabase.auth.getSession()
    const res = await fetch(`${useRuntimeConfig().public.supabaseUrl}/functions/v1/audience-connect`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${session?.access_token}` },
      body: JSON.stringify({ destination_id: credsForm.destination_id, workspace_id: workspaceId.value, credentials }),
    })
    const json = await res.json().catch(() => ({}))
    if (json?.ok) {
      useToast().success('Credentials stored securely')
      credsForm.fb_token = ''; credsForm.gads_access_token = ''; credsForm.gads_developer_token = ''
      credsOpen.value = false
      await load()
    } else {
      useToast().error('Could not store credentials', json?.error || 'Unknown error')
    }
  } finally {
    savingCreds.value = false
  }
}
async function deleteDest() {
  const ok = await useConfirm().ask({ title: 'Delete destination?', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await supabase.from('ad_audience_destinations').delete().eq('id', destForm.id)
  destOpen.value = false; await load()
}
function syncDest(d: any) {
  syncTarget.value = d
  Object.assign(syncForm, { source_type: 'all', source_id: '', operation: 'add' })
  syncOpen.value = true
}
async function runSync() {
  if (!syncTarget.value) return
  if (syncForm.source_type !== 'all' && !syncForm.source_id) { useToast().error('Pick a source list or segment'); return }
  syncing.value = true
  try {
    const { data: { session } } = await $supabase.auth.getSession()
    const res = await fetch(`${useRuntimeConfig().public.supabaseUrl}/functions/v1/audience-sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${session?.access_token}` },
      body: JSON.stringify({
        workspace_id: workspaceId.value,
        destination_id: syncTarget.value.id,
        source_type: syncForm.source_type,
        source_id: syncForm.source_id || null,
        operation: syncForm.operation,
      }),
    })
    const json = await res.json().catch(() => ({}))
    if (json?.ok) useToast().success('Sync complete', `${json.matched} matched / ${json.unmatched} unmatched`)
    else useToast().error('Sync failed', json?.error || 'Unknown error')
  } finally {
    syncing.value = false
    syncOpen.value = false
    await load()
  }
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

// ----- SMS credentials (encrypted) -----
const smsCredsOpen = ref(false)
const smsCredsSaving = ref(false)
const smsCredsForm = reactive<{ provider_id: string; account_sid: string; auth_token: string; has: boolean }>({
  provider_id: '', account_sid: '', auth_token: '', has: false,
})
function openSmsCredentials(p: any) {
  smsCredsForm.provider_id = p.id
  smsCredsForm.account_sid = ''
  smsCredsForm.auth_token = ''
  smsCredsForm.has = !!p.has_credentials
  smsCredsOpen.value = true
}
async function saveSmsCredentials() {
  if (!smsCredsForm.provider_id || !smsCredsForm.account_sid) return
  smsCredsSaving.value = true
  try {
    const url = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/sms-connect`
    const { data: { session } } = await supabase.auth.getSession()
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${session?.access_token || ''}`,
        'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY,
      },
      body: JSON.stringify({
        provider_id: smsCredsForm.provider_id,
        workspace_id: workspaceId.value,
        credentials: { account_sid: smsCredsForm.account_sid, auth_token: smsCredsForm.auth_token },
      }),
    })
    const j = await res.json().catch(() => ({}))
    if (!res.ok || !j.ok) throw new Error(j.error || `HTTP ${res.status}`)
    smsCredsOpen.value = false
    useToast().success('Credentials saved')
    await load()
  } catch (e: any) {
    useToast().error('Save failed', e.message)
  } finally {
    smsCredsSaving.value = false
  }
}

// ----- Integration hub -----
const hubProviders = [
  {
    id: 'slack', label: 'Slack', category: 'Ops & alerts', accent: '#4A154B',
    logoPath: 'M5.042 15.165a2.528 2.528 0 0 1-2.52 2.523A2.528 2.528 0 0 1 0 15.165a2.527 2.527 0 0 1 2.522-2.52h2.52v2.52zM6.313 15.165a2.527 2.527 0 0 1 2.521-2.52 2.527 2.527 0 0 1 2.521 2.52v6.313A2.528 2.528 0 0 1 8.834 24a2.528 2.528 0 0 1-2.521-2.522v-6.313zM8.834 5.042a2.528 2.528 0 0 1-2.521-2.52A2.528 2.528 0 0 1 8.834 0a2.528 2.528 0 0 1 2.521 2.522v2.52H8.834zM8.834 6.313a2.528 2.528 0 0 1 2.521 2.521 2.528 2.528 0 0 1-2.521 2.521H2.522A2.528 2.528 0 0 1 0 8.834a2.528 2.528 0 0 1 2.522-2.521h6.312zM18.956 8.834a2.528 2.528 0 0 1 2.522-2.521A2.528 2.528 0 0 1 24 8.834a2.528 2.528 0 0 1-2.522 2.521h-2.522V8.834zM17.688 8.834a2.528 2.528 0 0 1-2.523 2.521 2.527 2.527 0 0 1-2.52-2.521V2.522A2.527 2.527 0 0 1 15.165 0a2.528 2.528 0 0 1 2.523 2.522v6.312zM15.165 18.956a2.528 2.528 0 0 1 2.523 2.522A2.528 2.528 0 0 1 15.165 24a2.527 2.527 0 0 1-2.52-2.522v-2.522h2.52zM15.165 17.688a2.527 2.527 0 0 1-2.52-2.523 2.526 2.526 0 0 1 2.52-2.52h6.313A2.527 2.527 0 0 1 24 15.165a2.528 2.528 0 0 1-2.522 2.523h-6.313z',
    summary: 'Real-time alerts to a Slack channel.',
    description: 'Route campaign summaries, anomaly detections, and high-intent customer signals to any Slack channel via an incoming webhook. Use it so your growth and support teams see movement the moment it happens — no dashboard refresh required.',
    capabilities: ['Campaign launch + send summaries', 'AI anomaly & churn-risk alerts', 'Journey failure notifications'],
  },
  {
    id: 'mixpanel', label: 'Mixpanel', category: 'Product analytics', accent: '#7856FF',
    logoPath: 'M1.2 10.8a1.2 1.2 0 1 1 0 2.4 1.2 1.2 0 0 1 0-2.4zm10.8 0a1.2 1.2 0 1 1 0 2.4 1.2 1.2 0 0 1 0-2.4zm10.8 0a1.2 1.2 0 1 1 0 2.4 1.2 1.2 0 0 1 0-2.4zM6.6 9.6a2.4 2.4 0 1 1 0 4.8 2.4 2.4 0 0 1 0-4.8zm10.8 0a2.4 2.4 0 1 1 0 4.8 2.4 2.4 0 0 1 0-4.8z',
    summary: 'Mirror Pulse events into Mixpanel.',
    description: 'Stream every tracked event from Pulse into Mixpanel using a service account, so product, marketing, and growth teams analyse behaviour in the tool they already use. Event properties, distinct IDs, and timestamps are preserved end-to-end.',
    capabilities: ['Server-side event import', 'Shared distinct_id for stitching', 'Strict schema mode'],
  },
  {
    id: 'adjust', label: 'Adjust', category: 'Mobile attribution', accent: '#2D4DDE',
    logoPath: 'M12 0L0 12l12 12 12-12L12 0zm0 4.8L19.2 12 12 19.2 4.8 12 12 4.8z',
    summary: 'Server-to-server mobile conversion events.',
    description: 'Forward Pulse conversion events to Adjust with per-event token mapping, so paid acquisition campaigns can optimise on real downstream actions — not just installs. Supports IDFA / GPS ADID passthrough and revenue.',
    capabilities: ['S2S event forwarding', 'Per-event token map', 'Revenue + currency attribution'],
  },
  {
    id: 'metabase', label: 'Metabase', category: 'BI & dashboards', accent: '#509EE3',
    logoPath: 'M5.558 15.056c-.88 0-1.594.715-1.594 1.595s.714 1.594 1.594 1.594 1.594-.714 1.594-1.594-.714-1.595-1.594-1.595zm0-5.845c-.88 0-1.594.714-1.594 1.594 0 .881.714 1.595 1.594 1.595s1.594-.714 1.594-1.595c0-.88-.714-1.594-1.594-1.594zM5.558 3.366C4.678 3.366 3.964 4.08 3.964 4.96s.714 1.594 1.594 1.594 1.594-.713 1.594-1.594c0-.88-.714-1.594-1.594-1.594zM12 15.056c-.88 0-1.595.715-1.595 1.595S11.12 18.245 12 18.245s1.594-.714 1.594-1.594S12.88 15.056 12 15.056zm0-5.845c-.88 0-1.595.714-1.595 1.594 0 .881.715 1.595 1.595 1.595s1.594-.714 1.594-1.595c0-.88-.713-1.594-1.594-1.594zM12 3.366C11.12 3.366 10.405 4.08 10.405 4.96S11.12 6.554 12 6.554s1.594-.713 1.594-1.594c0-.88-.713-1.594-1.594-1.594zM18.442 15.056c-.88 0-1.594.715-1.594 1.595s.713 1.594 1.594 1.594c.881 0 1.595-.714 1.595-1.594s-.714-1.595-1.595-1.595zm0-5.845c-.88 0-1.594.714-1.594 1.594 0 .881.713 1.595 1.594 1.595.881 0 1.595-.714 1.595-1.595 0-.88-.714-1.594-1.595-1.594zM18.442 3.366c-.88 0-1.594.714-1.594 1.594s.713 1.594 1.594 1.594c.881 0 1.595-.713 1.595-1.594 0-.88-.714-1.594-1.595-1.594z',
    summary: 'Embed saved questions into Pulse.',
    description: 'Pull the JSON result of any Metabase saved question into Pulse using an API key. Perfect for surfacing warehouse-derived KPIs right next to engagement metrics, without rebuilding the query in a second tool.',
    capabilities: ['Query saved cards by ID', 'Self-hosted or Metabase Cloud', 'API-key auth (no cookie proxy)'],
  },
  {
    id: 'sheets', label: 'Google Sheets', category: 'Exports & ops', accent: '#0F9D58',
    logoPath: 'M14.4 0H3.6A1.6 1.6 0 0 0 2 1.6v20.8A1.6 1.6 0 0 0 3.6 24h16.8a1.6 1.6 0 0 0 1.6-1.6V7.6L14.4 0zm-.8 1.6h.4L21 8h-6.6a.8.8 0 0 1-.8-.8V1.6zM6 11h12v2H6v-2zm0 3h12v2H6v-2zm0 3h12v2H6v-2z',
    summary: 'Append exports to a spreadsheet.',
    description: 'Send cohort snapshots, campaign results, and customer exports straight to a Google Sheet via a service account. Useful for finance reconciliations, weekly exec reviews, or any workflow that lives in a spreadsheet.',
    capabilities: ['Append rows to a worksheet', 'Service-account JWT auth', 'Schedule via Pulse reports'],
  },
  {
    id: 'gcs', label: 'Google Cloud Storage', category: 'Warehouse staging', accent: '#4285F4',
    logoPath: 'M12.19 2.38a9.344 9.344 0 0 0-9.234 6.893c.053-.02-.055.013 0 0-3.875 2.551-3.922 8.11-.247 10.941l.006-.007-.007.03a6.717 6.717 0 0 0 4.077 1.356h5.173l.03.002h5.192c2.828 0 5.442-1.266 6.916-3.438 1.475-2.173 1.653-4.96.491-7.302l-.043-.086-.004-.007v-.001c-.116-.225-.245-.445-.385-.658l-.002-.001v-.002a7.728 7.728 0 0 0-.53-.676l-.119-.131a7.476 7.476 0 0 0-.243-.253l-.128-.124a7.196 7.196 0 0 0-.612-.515l-.002-.002-.002-.002a7.5 7.5 0 0 0-2.964-1.317l-.028-.005a7.542 7.542 0 0 0-.704-.098 7.497 7.497 0 0 0-.463-.024h-.056a7.544 7.544 0 0 0-.497.016l-.013.001a9.356 9.356 0 0 0-5.586-4.57v-.002a9.362 9.362 0 0 0-.727-.16l-.014-.003a9.28 9.28 0 0 0-.584-.079l-.036-.004a9.145 9.145 0 0 0-.85-.042z',
    summary: 'Stage files for BigQuery loads.',
    description: 'Write JSON or CSV exports to a GCS bucket. Ideal for teams that land data in a Google warehouse: pair with a scheduled BigQuery load job or Dataform to move engagement data into your lakehouse.',
    capabilities: ['Service-account upload', 'Configurable prefix / path', 'Great for BigQuery pipelines'],
  },
  {
    id: 's3', label: 'Amazon S3', category: 'Warehouse staging', accent: '#E25444',
    logoPath: 'M20.913 13.147l-.12.076-7.369 2.595v6.511l7.489-2.28v-6.902zm.894-.187v7.708l-.27.275-8.24 2.508-.38.121v-8.334l.27-.122 8.24-2.9zM3.087 13.147l.12.076 7.369 2.595v6.511l-7.489-2.28v-6.902zm-.894-.187v7.708l.27.275 8.24 2.508.38.121v-8.334l-.27-.122-8.24-2.9zM11.999.249l-.38.121L2.193 3.51l-.27.09v2.898l.894-.283V4.225L12 1.23l9.183 2.995v1.99l.894.283V3.6l-.27-.09-9.427-3.14L12 .25zm0 9.66l-.38.121-9.426 3.14-.27.09v-2.898l.894-.283v1.99L12 13.994l9.183-2.995V9.009l.894.283v2.898l-.27.09-9.427 3.14-.38-.12z',
    summary: 'Stage files for Redshift / Snowflake / Athena.',
    description: 'Ship exports to any S3 bucket using native AWS SigV4 signing. Works with Snowflake external stages, Redshift COPY, Athena, and Databricks — so your warehouse team owns the load on their own terms.',
    capabilities: ['AWS SigV4 PutObject', 'Region + prefix control', 'IAM access key pair (rotatable)'],
  },
]
const hubConnections = ref<any[]>([])
const hubTesting = ref<string>('')
const hubCredsOpen = ref(false)
const hubCredsSaving = ref(false)
const hubCredsForm = reactive<{
  connection_id: string; provider: string; label: string; name: string;
  configFields: string[]; secretFields: string[];
  config: Record<string, string>; secrets: Record<string, string>;
}>({
  connection_id: '', provider: '', label: '', name: '',
  configFields: [], secretFields: [], config: {}, secrets: {},
})

const hubSchemas: Record<string, { config: string[]; secret: string[] }> = {
  slack:    { config: ['default_channel'],          secret: ['webhook_url'] },
  mixpanel: { config: ['project_id'],               secret: ['service_account_user', 'service_account_password'] },
  adjust:   { config: ['app_token'],                secret: ['event_token_map', 'environment'] },
  metabase: { config: ['base_url'],                 secret: ['api_key'] },
  sheets:   { config: ['spreadsheet_id', 'worksheet'], secret: ['service_account_json'] },
  gcs:      { config: ['bucket', 'prefix'],         secret: ['service_account_json'] },
  s3:       { config: ['bucket', 'region', 'prefix'], secret: ['access_key_id', 'secret_access_key'] },
}

function hubFieldLabel(f: string) {
  return f.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}
function hubFieldPlaceholder(f: string) {
  if (f === 'webhook_url') return 'https://hooks.slack.com/services/...'
  if (f === 'default_channel') return '#pulse-alerts'
  if (f === 'project_id') return 'Mixpanel project token'
  if (f === 'base_url') return 'https://metabase.mycompany.com'
  if (f === 'spreadsheet_id') return '1A2B3C...'
  if (f === 'worksheet') return 'Sheet1'
  if (f === 'bucket') return 'pulse-exports'
  if (f === 'region') return 'us-east-1'
  if (f === 'prefix') return 'pulse/'
  if (f === 'environment') return 'production or sandbox'
  if (f.includes('json')) return '{ "type": "service_account", ... }'
  return ''
}
function hubConnectionFor(provider: string) {
  return hubConnections.value.find(c => c.provider === provider) || null
}
function openHubConnect(p: { id: string; label: string }) {
  const schema = hubSchemas[p.id]
  const existing = hubConnectionFor(p.id)
  hubCredsForm.provider = p.id
  hubCredsForm.label = p.label
  hubCredsForm.connection_id = existing?.id || ''
  hubCredsForm.name = existing?.name || p.label
  hubCredsForm.configFields = schema.config
  hubCredsForm.secretFields = schema.secret
  hubCredsForm.config = {}
  hubCredsForm.secrets = {}
  for (const f of schema.config) hubCredsForm.config[f] = existing?.config?.[f] ?? ''
  for (const f of schema.secret) hubCredsForm.secrets[f] = ''
  hubCredsOpen.value = true
}
async function saveHubConnection() {
  hubCredsSaving.value = true
  try {
    const secrets: Record<string, any> = {}
    for (const [k, v] of Object.entries(hubCredsForm.secrets)) {
      if (v === '' || v == null) continue
      secrets[k] = v
    }
    const url = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/integration-connect`
    const { data: { session } } = await supabase.auth.getSession()
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${session?.access_token || ''}`,
        'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY,
      },
      body: JSON.stringify({
        workspace_id: workspaceId.value,
        provider: hubCredsForm.provider,
        name: hubCredsForm.name,
        connection_id: hubCredsForm.connection_id || undefined,
        config: hubCredsForm.config,
        secrets,
      }),
    })
    const j = await res.json().catch(() => ({}))
    if (!res.ok || !j.ok) throw new Error(j.error || `HTTP ${res.status}`)
    hubCredsOpen.value = false
    useToast().success('Integration saved')
    await loadHub()
  } catch (e: any) {
    useToast().error('Save failed', e.message)
  } finally {
    hubCredsSaving.value = false
  }
}
async function disconnectHub() {
  if (!hubCredsForm.connection_id) return
  const ok = await useConfirm().ask({ title: `Disconnect ${hubCredsForm.label}?`, tone: 'danger', confirmText: 'Disconnect' })
  if (!ok) return
  await supabase.from('integration_connections').delete().eq('id', hubCredsForm.connection_id)
  hubCredsOpen.value = false
  useToast().success('Disconnected')
  await loadHub()
}
async function testHub(p: { id: string; label: string }) {
  const conn = hubConnectionFor(p.id)
  if (!conn) return
  hubTesting.value = p.id
  try {
    const url = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/integration-dispatch`
    const payload: any = p.id === 'slack'
      ? { text: `Pulse test from ${workspaceId.value}` }
      : p.id === 'metabase'
      ? { card_id: 1 }
      : p.id === 'mixpanel'
      ? { events: [{ name: 'pulse_test', properties: {}, distinct_id: 'pulse-test' }] }
      : { filename: 'pulse-test.json', content: { ok: true, at: new Date().toISOString() } }
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
        'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY,
      },
      body: JSON.stringify({ workspace_id: workspaceId.value, provider: p.id, connection_id: conn.id, payload }),
    })
    const j = await res.json().catch(() => ({}))
    if (!res.ok || !j.ok) throw new Error(j.error || `HTTP ${res.status}`)
    useToast().success(`${p.label} test ok`)
    await loadHub()
  } catch (e: any) {
    useToast().error(`${p.label} test failed`, e.message)
  } finally {
    hubTesting.value = ''
  }
}
async function loadHub() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('integration_connections').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false })
  hubConnections.value = data || []
}

watch(ordersPageSize, () => { ordersPage.value = 1 })
watch([workspaceId, ordersPage, ordersPageSize], load, { immediate: true })
watch(workspaceId, loadHub, { immediate: true })
</script>
