<template>
  <div>
    <PageHeader title="Settings" subtitle="Workspace preferences, branding, roles, email senders, and team."/>

    <div class="p-8 max-w-5xl space-y-4">
      <div class="flex gap-2 border-b border-ink-100 overflow-x-auto">
        <button v-for="t in tabs" :key="t.id" @click="tab = t.id"
          class="px-4 py-3 text-sm font-medium whitespace-nowrap border-b-2 -mb-px transition"
          :class="tab === t.id ? 'border-brand-500 text-brand-500' : 'border-transparent text-ink-500 hover:text-ink-900'">
          <Icon :name="t.icon" class="inline-block w-4 h-4 mr-1"/>{{ t.label }}
        </button>
      </div>

      <!-- Workspace -->
      <div v-if="tab === 'workspace'" class="space-y-4">
        <div class="card p-6">
          <div class="font-semibold text-ink-900 mb-4">Workspace profile</div>
          <form @submit.prevent="saveWorkspace" class="space-y-3">
            <div class="grid grid-cols-2 gap-3">
              <div><label class="label">Name *</label><input v-model="wsForm.name" class="input" required/></div>
              <div><label class="label">Slug *</label><input v-model="wsForm.slug" class="input font-mono" required/></div>
              <div><label class="label">Industry</label>
                <select v-model="wsForm.industry" class="input">
                  <option value="">—</option>
                  <option>Ecommerce</option><option>Fintech</option><option>SaaS</option>
                  <option>Media</option><option>Healthcare</option><option>Education</option>
                  <option>Travel</option><option>Gaming</option><option>Other</option>
                </select>
              </div>
              <div><label class="label">Timezone</label>
                <select v-model="wsForm.timezone" class="input">
                  <option>UTC</option><option>Africa/Lagos</option><option>Africa/Nairobi</option>
                  <option>Africa/Johannesburg</option><option>Europe/London</option><option>America/New_York</option><option>America/Los_Angeles</option>
                </select>
              </div>
              <div class="col-span-2"><label class="label">Website</label><input v-model="wsForm.website" class="input" placeholder="https://"/></div>
              <div><label class="label">Plan</label><input :value="auth.workspace?.plan" disabled class="input capitalize bg-ink-50"/></div>
            </div>
            <div class="flex items-center justify-between pt-2">
              <div class="text-xs text-ink-500">Changes apply to this workspace only.</div>
              <button type="submit" :disabled="saving || !isOwner" class="btn-primary" :title="!isOwner ? 'Only workspace owners can edit' : ''">{{ saving ? 'Saving…' : 'Save changes' }}</button>
            </div>
          </form>
        </div>

        <div class="card p-6">
          <div class="font-semibold text-ink-900 mb-4">Branding</div>
          <div class="grid md:grid-cols-2 gap-4">
            <div>
              <label class="label">Logo URL</label>
              <input v-model="wsForm.logo_url" class="input" placeholder="https://..."/>
              <div class="mt-3 w-24 h-24 rounded-xl bg-ink-50 border border-ink-100 flex items-center justify-center overflow-hidden">
                <img v-if="wsForm.logo_url" :src="wsForm.logo_url" class="w-full h-full object-contain" alt=""/>
                <Icon v-else name="box" class="w-8 h-8 text-ink-300"/>
              </div>
            </div>
            <div class="space-y-3">
              <div>
                <label class="label">Primary brand color</label>
                <div class="flex items-center gap-2">
                  <input type="color" v-model="wsForm.brand_primary" class="w-12 h-10 rounded border border-ink-100"/>
                  <input v-model="wsForm.brand_primary" class="input font-mono"/>
                </div>
              </div>
              <div>
                <label class="label">Accent color</label>
                <div class="flex items-center gap-2">
                  <input type="color" v-model="wsForm.brand_accent" class="w-12 h-10 rounded border border-ink-100"/>
                  <input v-model="wsForm.brand_accent" class="input font-mono"/>
                </div>
              </div>
              <div class="pt-2">
                <div class="text-xs font-semibold text-ink-500 uppercase tracking-wider mb-2">Preview</div>
                <div class="rounded-xl p-4 text-white" :style="{ background: wsForm.brand_primary }">
                  <div class="text-sm font-semibold">{{ wsForm.name || 'Workspace' }}</div>
                  <div class="text-xs opacity-90">Sample campaign header</div>
                  <button type="button" class="mt-3 px-3 py-1.5 rounded-lg text-xs font-semibold" :style="{ background: wsForm.brand_accent }">Call to action</button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div v-if="tab === 'workspace'" class="card p-6">
        <div class="font-semibold text-ink-900 mb-1">Feature modules</div>
        <div class="text-xs text-ink-500 mb-4">Turn on only what your workspace needs. Fintech, SaaS, and media teams can leave commerce disabled.</div>
        <label class="flex items-start gap-3 p-3 border border-ink-100 rounded-lg cursor-pointer hover:bg-ink-50">
          <input type="checkbox" :checked="!!auth.workspace?.commerce_enabled" @change="toggleCommerce(($event.target as HTMLInputElement).checked)" :disabled="!isOwner" class="mt-1"/>
          <div class="flex-1">
            <div class="text-sm font-semibold text-ink-900 flex items-center gap-2">
              <Icon name="box" class="w-4 h-4"/>Commerce
            </div>
            <div class="text-xs text-ink-500 mt-0.5">Product catalog, Shopify / WooCommerce order ingestion, abandoned-cart flows, and revenue attribution.</div>
          </div>
          <span v-if="auth.workspace?.commerce_enabled" class="chip bg-accent-500/10 text-accent-500 text-[10px]">ON</span>
          <span v-else class="chip bg-ink-100 text-ink-500 text-[10px]">OFF</span>
        </label>
      </div>

      <!-- Workspaces -->
      <div v-if="tab === 'workspaces'" class="card p-6">
        <div class="flex items-center justify-between mb-4">
          <div>
            <div class="font-semibold text-ink-900">Your workspaces</div>
            <div class="text-xs text-ink-500">Create or switch between workspaces you own or belong to.</div>
          </div>
          <button @click="createWs = true" class="btn-primary"><Icon name="plus"/>New workspace</button>
        </div>
        <div class="space-y-2">
          <div v-for="w in auth.workspaces" :key="w.id" class="flex items-center justify-between p-3 rounded-lg border border-ink-100 hover:bg-ink-50">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-lg flex items-center justify-center text-white font-bold" :style="{ background: w.brand_primary || '#3087B9' }">{{ w.name?.[0]?.toUpperCase() }}</div>
              <div>
                <div class="font-medium text-ink-900">{{ w.name }}</div>
                <div class="text-xs text-ink-500 font-mono">{{ w.slug }} · {{ w.owner_id === auth.user?.id ? 'Owner' : 'Member' }}</div>
              </div>
            </div>
            <div class="flex items-center gap-2">
              <span v-if="w.id === auth.workspace?.id" class="chip bg-accent-500/10 text-accent-500">Active</span>
              <button v-else @click="switchTo(w.id)" class="btn-secondary text-xs">Switch</button>
            </div>
          </div>
        </div>
      </div>

      <!-- Email & domains -->
      <div v-if="tab === 'email'" class="space-y-4">
        <div class="card p-6">
          <div class="flex items-center justify-between mb-4">
            <div>
              <div class="font-semibold text-ink-900">Sending domains</div>
              <div class="text-xs text-ink-500">Verify SPF, DKIM and DMARC to send from your own domain.</div>
            </div>
            <button @click="openDomain = true" class="btn-primary" :disabled="!isOwner"><Icon name="plus"/>Add domain</button>
          </div>
          <div v-if="loadingEmail" class="space-y-2">
            <Skeleton v-for="i in 2" :key="i" height="72px" rounded="rounded-xl"/>
          </div>
          <div v-else-if="!domains.length" class="text-sm text-ink-500 text-center py-10">No domains yet. Add one to start sending email from your brand.</div>
          <div v-else class="space-y-2">
            <div v-for="d in domains" :key="d.id" class="rounded-xl border border-ink-100 hover:border-brand-500 transition">
              <div class="flex items-center justify-between p-4">
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 rounded-lg bg-brand-100/40 text-brand-500 flex items-center justify-center"><Icon name="activity"/></div>
                  <div>
                    <div class="font-semibold text-ink-900">{{ d.domain }}</div>
                    <div class="flex items-center gap-2 mt-1">
                      <span class="chip text-[10px]" :class="statusChip(d.status)">{{ d.status }}</span>
                      <span class="text-[10px] text-ink-500">added {{ timeAgo(d.created_at) }}</span>
                    </div>
                  </div>
                </div>
                <div class="flex items-center gap-2">
                  <button @click="toggleDns(d.id)" class="btn-ghost text-xs">{{ expanded === d.id ? 'Hide DNS' : 'View DNS' }}</button>
                  <button @click="verifyDomain(d)" class="btn-secondary text-xs" :disabled="d.status === 'verified'">Verify</button>
                  <button @click="removeDomain(d)" class="text-ink-300 hover:text-red-600"><Icon name="trash"/></button>
                </div>
              </div>
              <div v-if="expanded === d.id" class="border-t border-ink-100 p-4 bg-ink-50/40 space-y-3">
                <DnsRow type="TXT" host="@" value="v=spf1 include:pulse.email ~all" :status="d.spf_status" label="SPF"/>
                <DnsRow :type="'CNAME'" :host="`${d.dkim_selector}._domainkey`" :value="`${d.dkim_selector}.dkim.pulse.email`" :status="d.dkim_status" label="DKIM"/>
                <DnsRow type="TXT" host="_dmarc" value="v=DMARC1; p=none; rua=mailto:dmarc@pulse.email" :status="d.dmarc_status" label="DMARC"/>
              </div>
            </div>
          </div>
        </div>

        <div class="card p-6">
          <div class="flex items-center justify-between mb-4">
            <div>
              <div class="font-semibold text-ink-900">From identities</div>
              <div class="text-xs text-ink-500">Set the default "From" name and address used by campaigns.</div>
            </div>
            <button @click="openSender = true" class="btn-primary" :disabled="!domains.length || !isOwner"><Icon name="plus"/>Add sender</button>
          </div>
          <div v-if="!senders.length" class="text-sm text-ink-500 text-center py-6">No senders yet. Add a domain first, then a From identity.</div>
          <table v-else class="w-full text-sm">
            <thead><tr><th class="table-th">From</th><th class="table-th">Reply-to</th><th class="table-th">Domain</th><th class="table-th"></th></tr></thead>
            <tbody>
              <tr v-for="s in senders" :key="s.id" class="hover:bg-ink-50">
                <td class="table-td">
                  <div class="font-medium">{{ s.from_name }} <span v-if="s.is_default" class="chip bg-accent-500/10 text-accent-500 ml-1 text-[10px]">default</span></div>
                  <div class="text-xs text-ink-500 font-mono">{{ s.from_email }}</div>
                </td>
                <td class="table-td text-xs text-ink-500 font-mono">{{ s.reply_to || '—' }}</td>
                <td class="table-td text-xs text-ink-500">{{ domainFor(s.domain_id) }}</td>
                <td class="table-td text-right">
                  <button v-if="!s.is_default" @click="makeDefault(s)" class="text-xs text-brand-500 font-semibold mr-3">Make default</button>
                  <button @click="removeSender(s)" class="text-ink-300 hover:text-red-600"><Icon name="trash"/></button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Roles -->
      <div v-if="tab === 'roles'" class="space-y-4">
        <div class="card p-6">
          <div class="flex items-center justify-between mb-4">
            <div>
              <div class="font-semibold text-ink-900">Roles & permissions</div>
              <div class="text-xs text-ink-500">System roles gate common workflows. Create custom roles for finer-grained access.</div>
            </div>
            <button @click="openRole()" class="btn-primary" :disabled="!isOwner"><Icon name="plus"/>New role</button>
          </div>
          <div v-if="loadingRoles" class="grid md:grid-cols-2 gap-3">
            <Skeleton v-for="i in 4" :key="i" height="110px" rounded="rounded-xl"/>
          </div>
          <div v-else class="grid md:grid-cols-2 gap-3">
            <div v-for="r in roles" :key="r.id" class="rounded-xl border border-ink-100 p-4 hover:border-brand-500 transition">
              <div class="flex items-start justify-between">
                <div>
                  <div class="font-semibold text-ink-900">{{ r.name }}</div>
                  <div class="text-xs text-ink-500 mt-1">{{ r.description }}</div>
                </div>
                <div class="flex items-center gap-2">
                  <span v-if="r.is_system" class="chip bg-ink-100 text-ink-700">system</span>
                  <span v-else class="chip bg-brand-100/40 text-brand-700">custom</span>
                </div>
              </div>
              <div class="flex flex-wrap gap-1 mt-3">
                <span v-for="p in permissionChips(r)" :key="p" class="chip bg-brand-100/40 text-brand-700 text-[10px]">{{ p }}</span>
              </div>
              <div v-if="!r.is_system" class="pt-3 mt-3 border-t border-ink-100 flex items-center gap-2">
                <button @click="openRole(r)" class="btn-ghost text-xs">Edit</button>
                <button @click="deleteRole(r)" class="btn-ghost text-xs text-red-600">Delete</button>
              </div>
            </div>
          </div>
        </div>

        <div class="card p-6">
          <div class="font-semibold text-ink-900 mb-1">Approval flow</div>
          <div class="text-xs text-ink-500 mb-4">Campaigns and journeys marked as requiring approval must be signed off before rollout.</div>
          <div v-if="approvals.length" class="space-y-2">
            <div v-for="a in approvals" :key="a.id" class="flex items-center justify-between p-3 rounded-lg border border-ink-100">
              <div>
                <div class="font-medium text-ink-900 text-sm">{{ a.entity_name }} <span class="chip ml-2 capitalize" :class="a.entity_type === 'campaign' ? 'bg-brand-100/40 text-brand-700' : 'bg-accent-500/10 text-accent-500'">{{ a.entity_type }}</span></div>
                <div class="text-xs text-ink-500">Requested {{ timeAgo(a.created_at) }}</div>
              </div>
              <div class="flex items-center gap-2">
                <span class="chip" :class="a.status === 'approved' ? 'bg-accent-500/10 text-accent-500' : a.status === 'rejected' ? 'bg-red-100 text-red-600' : 'bg-yellow-100 text-yellow-700'">{{ a.status }}</span>
                <button v-if="a.status === 'pending'" @click="review(a, 'approved')" class="btn-secondary text-xs">Approve</button>
                <button v-if="a.status === 'pending'" @click="review(a, 'rejected')" class="btn-ghost text-xs text-red-600">Reject</button>
              </div>
            </div>
          </div>
          <div v-else class="text-sm text-ink-500">No approval requests yet.</div>
        </div>
      </div>

      <!-- Team -->
      <div v-if="tab === 'team'" class="card p-6">
        <div class="flex items-center justify-between mb-4">
          <div>
            <div class="font-semibold text-ink-900">Team members</div>
            <div class="text-xs text-ink-500">Invite teammates and assign a role.</div>
          </div>
          <button @click="inviteOpen = true" class="btn-primary" :disabled="!isOwner"><Icon name="plus"/>Invite</button>
        </div>
        <table class="w-full text-sm">
          <thead><tr><th class="table-th">Member</th><th class="table-th">Role</th><th class="table-th"></th></tr></thead>
          <tbody>
            <tr>
              <td class="table-td">
                <div class="font-medium">{{ auth.user?.email }}</div>
                <div class="text-xs text-ink-500">You</div>
              </td>
              <td class="table-td"><span class="chip bg-brand-500 text-white">Owner</span></td>
              <td class="table-td"></td>
            </tr>
            <tr v-for="m in members" :key="m.id" class="hover:bg-ink-50">
              <td class="table-td">
                <div class="font-medium">{{ m.email || m.user_id }}</div>
              </td>
              <td class="table-td">
                <select :value="m.role_id" @change="updateMemberRole(m, ($event.target as HTMLSelectElement).value)" class="input !py-1 !text-xs max-w-[200px]" :disabled="!isOwner">
                  <option v-for="r in roles" :key="r.id" :value="r.id">{{ r.name }}</option>
                </select>
              </td>
              <td class="table-td text-right">
                <button v-if="isOwner" @click="removeMember(m)" class="text-ink-500 hover:text-red-600"><Icon name="trash"/></button>
              </td>
            </tr>
            <tr v-if="!members.length">
              <td colspan="3" class="table-td text-center text-ink-500 py-6">No teammates yet. Invite someone to get started.</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Messaging policies -->
      <div v-if="tab === 'policies'" class="space-y-4">
        <div v-if="auth.workspace?.sending_paused" class="card p-5 border-l-4 border-red-500 bg-red-50">
          <div class="flex items-start gap-3">
            <Icon name="shield" class="text-red-600 w-5 h-5 mt-0.5"/>
            <div class="flex-1">
              <div class="font-semibold text-red-900">Sending is paused for this workspace</div>
              <div class="text-xs text-red-700 mt-0.5">{{ auth.workspace.sending_paused_reason }}</div>
              <button @click="resumeSending" class="mt-3 btn-secondary !py-1 !text-xs">Resume sending</button>
            </div>
          </div>
        </div>

        <div class="card p-6">
          <div class="font-semibold text-ink-900">Deliverability safeguards</div>
          <div class="text-xs text-ink-500 mt-1 mb-4">Platform-wide limits that protect your sender reputation. Applied on every transactional and broadcast send.</div>
          <div class="grid md:grid-cols-2 gap-3">
            <div><label class="label">Max messages per contact, 24h</label><input v-model.number="sendingPolicy.max_messages_per_contact_24h" type="number" min="1" class="input"/></div>
            <div><label class="label">Max messages per contact, 7d</label><input v-model.number="sendingPolicy.max_messages_per_contact_7d" type="number" min="1" class="input"/></div>
            <div><label class="label">Quiet hours start ({{ wsForm.timezone }})</label><input v-model.number="sendingPolicy.quiet_hours_start" type="number" min="0" max="23" class="input"/></div>
            <div><label class="label">Quiet hours end ({{ wsForm.timezone }})</label><input v-model.number="sendingPolicy.quiet_hours_end" type="number" min="0" max="23" class="input"/></div>
            <div><label class="label">Complaint rate threshold</label><input v-model.number="sendingPolicyComplaintPct" type="number" step="0.01" min="0" class="input"/><div class="text-[11px] text-ink-500 mt-1">%. Auto-pause if crossed over 24h (min 100 sends).</div></div>
            <div><label class="label">Hard-bounce rate threshold</label><input v-model.number="sendingPolicyBouncePct" type="number" step="0.1" min="0" class="input"/><div class="text-[11px] text-ink-500 mt-1">%. Auto-pause if crossed over 24h (min 100 sends).</div></div>
          </div>
          <div class="flex items-center gap-4 mt-3">
            <label class="flex items-center gap-2 text-sm text-ink-700"><input type="checkbox" v-model="sendingPolicy.respect_quiet_hours"/> Enforce quiet hours</label>
            <label class="flex items-center gap-2 text-sm text-ink-700"><input type="checkbox" v-model="sendingPolicy.auto_suspend_on_breach"/> Auto-pause on threshold breach</label>
          </div>
          <div class="flex justify-end pt-3">
            <button @click="saveSendingPolicy" class="btn-primary">Save safeguards</button>
          </div>
        </div>

        <div class="card p-6">
          <div class="font-semibold text-ink-900">Per-channel messaging policies</div>
          <div class="text-xs text-ink-500 mt-1">Channel-specific caps and send-time optimization. Apply on top of the platform safeguards above.</div>
        </div>
        <div class="grid md:grid-cols-2 gap-4">
          <div v-for="p in policies" :key="p.channel" class="card p-5 space-y-3">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <div class="w-9 h-9 rounded-lg bg-brand-100/40 text-brand-500 flex items-center justify-center"><Icon :name="policyIcon(p.channel)"/></div>
                <div>
                  <div class="font-semibold text-ink-900 capitalize">{{ p.channel }}</div>
                  <div class="text-[11px] text-ink-500">Frequency capping & quiet hours</div>
                </div>
              </div>
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div><label class="label">Max per day</label><input v-model.number="p.max_per_day" type="number" min="0" class="input"/></div>
              <div><label class="label">Max per week</label><input v-model.number="p.max_per_week" type="number" min="0" class="input"/></div>
              <div><label class="label">Quiet start</label><input v-model="p.quiet_start" type="time" class="input"/></div>
              <div><label class="label">Quiet end</label><input v-model="p.quiet_end" type="time" class="input"/></div>
            </div>
            <div class="space-y-1.5 pt-1">
              <label class="flex items-center gap-2 text-sm text-ink-700">
                <input type="checkbox" v-model="p.send_time_optimization"/> Enable send-time optimization
              </label>
              <label class="flex items-center gap-2 text-sm text-ink-700">
                <input type="checkbox" v-model="p.respect_time_zone"/> Respect recipient time zone
              </label>
            </div>
            <button @click="savePolicy(p)" class="btn-secondary w-full">Save {{ p.channel }} policy</button>
          </div>
        </div>
      </div>

      <!-- Data exports & retention -->
      <div v-if="tab === 'data'" class="space-y-4">
        <div class="card p-6">
          <div class="flex items-center justify-between">
            <div>
              <div class="font-semibold text-ink-900">Data retention</div>
              <div class="text-xs text-ink-500 mt-1">Events and messages older than this will be archived. Minimum 30, maximum 1825 days.</div>
            </div>
          </div>
          <div class="mt-4 flex items-center gap-4">
            <input type="range" v-model.number="retentionDays" min="30" max="1825" step="30" class="flex-1 accent-brand-500"/>
            <div class="min-w-[100px] text-right">
              <div class="text-2xl font-bold text-ink-900">{{ retentionDays }}</div>
              <div class="text-[10px] text-ink-500 uppercase tracking-wider">days</div>
            </div>
            <button @click="saveRetention" class="btn-primary">Save</button>
          </div>
        </div>

        <div class="card p-6">
          <div class="flex items-center justify-between mb-4">
            <div>
              <div class="font-semibold text-ink-900">Data exports</div>
              <div class="text-xs text-ink-500 mt-1">Download your customer, event or campaign data as CSV or JSON.</div>
            </div>
            <button @click="openExport = true" class="btn-primary"><Icon name="upload"/>Request export</button>
          </div>
          <EmptyState v-if="!exports.length" icon="upload" title="No exports yet" subtitle="Your export jobs will appear here."/>
          <table v-else class="w-full">
            <thead><tr>
              <th class="table-th">Scope</th><th class="table-th">Format</th><th class="table-th">Rows</th>
              <th class="table-th">Requested</th><th class="table-th">Status</th>
            </tr></thead>
            <tbody>
              <tr v-for="e in exports" :key="e.id" class="hover:bg-ink-50">
                <td class="table-td capitalize">{{ e.scope }}</td>
                <td class="table-td text-xs uppercase">{{ e.format }}</td>
                <td class="table-td">{{ e.row_count || 0 }}</td>
                <td class="table-td text-xs text-ink-500">{{ e.requested_email }}</td>
                <td class="table-td"><span class="chip" :class="exportChip(e.status)">{{ e.status }}</span></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Plan & usage -->
      <div v-if="tab === 'plan'" class="space-y-4">
        <div class="card p-6">
          <div class="flex items-start justify-between">
            <div>
              <div class="text-xs uppercase tracking-wider text-ink-500">Current plan</div>
              <div class="text-2xl font-bold text-ink-900 mt-1">{{ currentPlan?.name || 'Free' }}</div>
              <div class="text-sm text-ink-500 mt-1">{{ currentPlan?.description }}</div>
            </div>
            <div class="text-right">
              <div class="text-3xl font-bold text-ink-900">${{ currentPlan?.price_monthly || 0 }}<span class="text-base text-ink-500">/mo</span></div>
              <a href="mailto:sales@pulse.app" class="btn-primary mt-2 inline-flex"><Icon name="send"/>Talk to sales</a>
            </div>
          </div>
          <div class="grid grid-cols-3 gap-3 mt-6">
            <div class="p-4 rounded-lg bg-ink-50">
              <div class="text-xs text-ink-500">Email this month</div>
              <div class="text-xl font-bold text-ink-900 mt-1">{{ (auth.workspace?.email_used_this_month || 0).toLocaleString() }} / {{ (emailCap).toLocaleString() }}</div>
              <div class="h-2 rounded-full bg-ink-100 mt-2 overflow-hidden"><div class="h-full bg-brand-500" :style="{ width: pct(auth.workspace?.email_used_this_month || 0, emailCap) + '%' }"></div></div>
            </div>
            <div class="p-4 rounded-lg bg-ink-50">
              <div class="text-xs text-ink-500">SMS this month</div>
              <div class="text-xl font-bold text-ink-900 mt-1">{{ (auth.workspace?.sms_used_this_month || 0).toLocaleString() }} / {{ (smsCap).toLocaleString() }}</div>
              <div class="h-2 rounded-full bg-ink-100 mt-2 overflow-hidden"><div class="h-full bg-accent-500" :style="{ width: pct(auth.workspace?.sms_used_this_month || 0, smsCap) + '%' }"></div></div>
            </div>
            <div class="p-4 rounded-lg bg-ink-50">
              <div class="text-xs text-ink-500">Seats</div>
              <div class="text-xl font-bold text-ink-900 mt-1">{{ members.length }} / {{ currentPlan?.seats || 1 }}</div>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
          <div v-for="p in publicPlans" :key="p.id" class="card p-5" :class="p.id === auth.workspace?.plan_id ? 'border-brand-500 ring-2 ring-brand-500/20' : ''">
            <div class="font-semibold text-ink-900">{{ p.name }}</div>
            <div class="text-2xl font-bold text-ink-900 mt-2">${{ p.price_monthly }}<span class="text-xs text-ink-500">/mo</span></div>
            <ul class="text-xs text-ink-500 mt-3 space-y-1.5">
              <li>{{ p.email_monthly_quota.toLocaleString() }} emails/mo</li>
              <li>{{ p.sms_monthly_quota.toLocaleString() }} SMS/mo</li>
              <li>{{ p.seats }} seats</li>
              <li v-if="p.feature_flags?.ab_testing">A/B testing</li>
              <li v-if="p.feature_flags?.priority_support">Priority support</li>
              <li v-if="p.feature_flags?.sso">SSO</li>
            </ul>
          </div>
        </div>
      </div>

      <!-- Audit log -->
      <div v-if="tab === 'audit'" class="card p-6">
        <div class="flex items-center justify-between mb-4">
          <div>
            <div class="font-semibold text-ink-900">Audit log</div>
            <div class="text-xs text-ink-500">Every create, update, delete and send across the workspace.</div>
          </div>
          <div class="flex items-center gap-2">
            <select v-model="auditFilter" class="input !py-1 !text-xs">
              <option value="">All entities</option>
              <option value="campaign">Campaigns</option>
              <option value="journey">Journeys</option>
              <option value="template">Templates</option>
              <option value="survey">Surveys</option>
              <option value="app">Apps</option>
              <option value="segment">Segments</option>
              <option value="workspace">Workspace</option>
            </select>
          </div>
        </div>
        <EmptyState v-if="!filteredAudit.length" icon="activity" title="No audit events yet" subtitle="Changes will show up here as your team works."/>
        <div v-else class="divide-y divide-ink-100">
          <div v-for="a in filteredAudit" :key="a.id" class="py-3 flex items-start gap-3">
            <div class="w-8 h-8 rounded-lg flex items-center justify-center shrink-0" :class="auditBg(a.action)">
              <Icon :name="auditIcon(a.action)" class="w-4 h-4"/>
            </div>
            <div class="flex-1 min-w-0">
              <div class="text-sm text-ink-900">
                <span class="font-semibold">{{ a.actor_email }}</span>
                <span class="text-ink-500"> {{ a.action }} </span>
                <span class="capitalize">{{ a.entity_type }}</span>
                <span v-if="a.entity_name" class="font-semibold"> · {{ a.entity_name }}</span>
              </div>
              <div class="text-[11px] text-ink-500 mt-0.5">{{ timeAgo(a.created_at) }}</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Account -->
      <div v-if="tab === 'account'" class="card p-6">
        <div class="font-semibold text-ink-900 mb-3">Account</div>
        <div class="text-sm text-ink-500">Signed in as <span class="font-semibold text-ink-900">{{ auth.user?.email }}</span></div>
        <div class="pt-4 mt-4 border-t border-ink-100 space-y-3">
          <button @click="auth.signOut()" class="btn-secondary">Sign out</button>
          <div>
            <div class="font-semibold text-ink-900 mt-6 mb-1">Danger zone</div>
            <div class="text-sm text-ink-500 mb-3">Delete all demo data in this workspace.</div>
            <button @click="purge" class="btn-ghost text-red-600"><Icon name="trash"/>Purge workspace data</button>
          </div>
        </div>
      </div>
    </div>

    <Modal v-model="createWs" title="Create workspace" subtitle="Start fresh with a new workspace.">
      <form id="cwf" @submit.prevent="doCreateWorkspace" class="space-y-3">
        <div><label class="label">Workspace name *</label><input v-model="newWsName" class="input" required/></div>
      </form>
      <template #footer>
        <button @click="createWs = false" class="btn-secondary">Cancel</button>
        <button form="cwf" type="submit" class="btn-primary">Create</button>
      </template>
    </Modal>

    <Modal v-model="inviteOpen" title="Invite teammate" subtitle="Add a user by email and assign their role.">
      <form id="inv" @submit.prevent="invite" class="space-y-3">
        <div><label class="label">Email *</label><input v-model="invEmail" type="email" class="input" required/></div>
        <div><label class="label">Role *</label>
          <select v-model="invRoleId" class="input" required>
            <option v-for="r in roles" :key="r.id" :value="r.id">{{ r.name }} — {{ r.description }}</option>
          </select>
        </div>
        <div class="text-xs text-ink-500">Once they sign up with this email, the workspace shows up in their switcher.</div>
      </form>
      <template #footer>
        <button @click="inviteOpen = false" class="btn-secondary">Cancel</button>
        <button form="inv" type="submit" class="btn-primary">Add member</button>
      </template>
    </Modal>

    <Modal v-model="openDomain" title="Add sending domain" subtitle="We'll generate DNS records to verify ownership.">
      <form id="df" @submit.prevent="addDomain" class="space-y-3">
        <div>
          <label class="label">Domain *</label>
          <input v-model="domainInput" class="input font-mono" placeholder="mail.yourbrand.com" required/>
          <div class="text-xs text-ink-500 mt-1">Use a subdomain such as <span class="font-mono">mail.sycamore.ng</span> — not your root domain.</div>
        </div>
      </form>
      <template #footer>
        <button @click="openDomain = false" class="btn-secondary">Cancel</button>
        <button form="df" type="submit" class="btn-primary">Add domain</button>
      </template>
    </Modal>

    <Modal v-model="openSender" title="Add From identity" subtitle="Set the From name and email for outbound campaigns.">
      <form id="sf" @submit.prevent="addSender" class="space-y-3">
        <div><label class="label">Domain *</label>
          <select v-model="senderForm.domain_id" class="input" required>
            <option value="">Select a domain…</option>
            <option v-for="d in domains" :key="d.id" :value="d.id">{{ d.domain }} — {{ d.status }}</option>
          </select>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">From name *</label><input v-model="senderForm.from_name" class="input" required placeholder="Sycamore"/></div>
          <div><label class="label">From email *</label><input v-model="senderForm.from_email" class="input font-mono" required placeholder="hello@mail.sycamore.ng"/></div>
        </div>
        <div><label class="label">Reply-to</label><input v-model="senderForm.reply_to" class="input font-mono" placeholder="support@sycamore.ng"/></div>
        <label class="flex items-center gap-2 text-sm"><input type="checkbox" v-model="senderForm.is_default"/> Make this the default sender</label>
      </form>
      <template #footer>
        <button @click="openSender = false" class="btn-secondary">Cancel</button>
        <button form="sf" type="submit" class="btn-primary">Save sender</button>
      </template>
    </Modal>

    <Modal v-model="openExport" title="Request data export" subtitle="We'll prepare your file and email a link when it's ready.">
      <form id="ef" @submit.prevent="requestExport" class="space-y-3">
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">Scope</label>
            <select v-model="exportForm.scope" class="input">
              <option value="customers">Customers</option>
              <option value="events">Events (30 days)</option>
              <option value="campaigns">Campaigns</option>
              <option value="messages">Campaign messages</option>
              <option value="all">Everything</option>
            </select>
          </div>
          <div><label class="label">Format</label>
            <select v-model="exportForm.format" class="input">
              <option value="csv">CSV</option><option value="json">JSON</option>
            </select>
          </div>
        </div>
        <div><label class="label">Note (optional)</label><input v-model="exportForm.note" class="input" placeholder="Compliance review — Q2"/></div>
      </form>
      <template #footer>
        <button @click="openExport = false" class="btn-secondary">Cancel</button>
        <button form="ef" type="submit" class="btn-primary">Request export</button>
      </template>
    </Modal>

    <Modal v-model="roleOpen" :title="editingRole ? 'Edit role' : 'Create role'" subtitle="Tailor permissions to your org's workflows." size="lg">
      <form id="rf" @submit.prevent="saveRole" class="space-y-3">
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">Role name *</label><input v-model="roleForm.name" class="input" required placeholder="e.g. Brand Reviewer"/></div>
          <div><label class="label">Short description</label><input v-model="roleForm.description" class="input" placeholder="What can they do?"/></div>
        </div>
        <div>
          <div class="label mb-2">Permissions</div>
          <div class="grid sm:grid-cols-2 gap-2">
            <label v-for="p in permissionCatalog" :key="p.key" class="flex items-start gap-2 p-3 rounded-lg border border-ink-100 hover:border-brand-500 cursor-pointer">
              <input type="checkbox" v-model="roleForm.flags[p.key]" class="mt-1"/>
              <div>
                <div class="text-sm font-medium text-ink-900">{{ p.label }}</div>
                <div class="text-xs text-ink-500">{{ p.hint }}</div>
              </div>
            </label>
          </div>
        </div>
      </form>
      <template #footer>
        <button @click="roleOpen = false" class="btn-secondary">Cancel</button>
        <button form="rf" type="submit" class="btn-primary">{{ editingRole ? 'Save role' : 'Create role' }}</button>
      </template>
    </Modal>

  </div>
</template>

<script setup lang="ts">
const { supabase, auth, workspaceId } = useWorkspace()
const toast = useToast()
const confirmDialog = useConfirm()

const tabs = [
  { id: 'workspace', label: 'Workspace', icon: 'settings' },
  { id: 'workspaces', label: 'Workspaces', icon: 'layers' },
  { id: 'email', label: 'Email & domains', icon: 'send' },
  { id: 'roles', label: 'Roles & approvals', icon: 'shield' },
  { id: 'team', label: 'Team', icon: 'users' },
  { id: 'policies', label: 'Messaging policies', icon: 'clock' },
  { id: 'plan', label: 'Plan & usage', icon: 'box' },
  { id: 'data', label: 'Data & retention', icon: 'upload' },
  { id: 'audit', label: 'Audit log', icon: 'activity' },
  { id: 'account', label: 'Account', icon: 'box' },
]
const tab = ref('workspace')
const saving = ref(false)
const wsForm = reactive({
  name: '', slug: '', industry: '', timezone: 'UTC', website: '',
  logo_url: '', brand_primary: '#3087B9', brand_accent: '#26C165',
})

const roles = ref<any[]>([])
const members = ref<any[]>([])
const approvals = ref<any[]>([])
const domains = ref<any[]>([])
const senders = ref<any[]>([])
const policies = ref<any[]>([])
const sendingPolicy = reactive<any>({
  max_messages_per_contact_24h: 2,
  max_messages_per_contact_7d: 5,
  quiet_hours_start: 21,
  quiet_hours_end: 8,
  respect_quiet_hours: true,
  complaint_rate_threshold: 0.001,
  bounce_rate_threshold: 0.05,
  auto_suspend_on_breach: true,
})
const sendingPolicyComplaintPct = computed({
  get: () => Number((sendingPolicy.complaint_rate_threshold * 100).toFixed(3)),
  set: (v: number) => { sendingPolicy.complaint_rate_threshold = Number(v) / 100 },
})
const sendingPolicyBouncePct = computed({
  get: () => Number((sendingPolicy.bounce_rate_threshold * 100).toFixed(2)),
  set: (v: number) => { sendingPolicy.bounce_rate_threshold = Number(v) / 100 },
})
const exports = ref<any[]>([])
const auditLogs = ref<any[]>([])
const auditFilter = ref('')
const plans = ref<any[]>([])
const publicPlans = computed(() => plans.value.filter((p: any) => p.is_public).sort((a: any, b: any) => a.sort_order - b.sort_order))
const currentPlan = computed(() => plans.value.find((p: any) => p.id === auth.workspace?.plan_id) || plans.value.find((p: any) => p.code === 'free'))
const emailCap = computed(() => auth.workspace?.email_quota_override ?? currentPlan.value?.email_monthly_quota ?? 0)
const smsCap = computed(() => auth.workspace?.sms_quota_override ?? currentPlan.value?.sms_monthly_quota ?? 0)
function pct(n: number, cap: number) { return cap > 0 ? Math.min(100, Math.round((n / cap) * 100)) : 0 }
const retentionDays = ref(365)
const openExport = ref(false)
const exportForm = reactive({ scope: 'customers', format: 'csv', note: '' })
const audit = useAudit()
const notify = useNotify()

const POLICY_CHANNELS = ['email', 'push', 'sms', 'whatsapp']
function defaultPolicy(channel: string) {
  return { channel, max_per_day: 3, max_per_week: 12, quiet_start: '22:00', quiet_end: '08:00', send_time_optimization: false, respect_time_zone: true }
}
function policyIcon(c: string) { return ({ email: 'mail', push: 'bell', sms: 'smartphone', whatsapp: 'smartphone' } as any)[c] || 'clock' }
function exportChip(s: string) {
  return s === 'ready' ? 'bg-accent-500/10 text-accent-500' : s === 'failed' ? 'bg-red-100 text-red-600' : 'bg-yellow-100 text-yellow-700'
}
function auditBg(action: string) {
  if (action === 'delete') return 'bg-red-100 text-red-600'
  if (action === 'create') return 'bg-accent-500/10 text-accent-500'
  if (action === 'send') return 'bg-brand-500/10 text-brand-500'
  return 'bg-ink-100 text-ink-700'
}
function auditIcon(action: string) {
  if (action === 'delete') return 'trash'
  if (action === 'create') return 'plus'
  if (action === 'send') return 'send'
  if (action === 'update') return 'edit'
  return 'activity'
}
const filteredAudit = computed(() => auditFilter.value ? auditLogs.value.filter((a: any) => a.entity_type === auditFilter.value) : auditLogs.value)

async function saveSendingPolicy() {
  const payload = {
    workspace_id: workspaceId.value,
    max_messages_per_contact_24h: sendingPolicy.max_messages_per_contact_24h,
    max_messages_per_contact_7d: sendingPolicy.max_messages_per_contact_7d,
    quiet_hours_start: sendingPolicy.quiet_hours_start,
    quiet_hours_end: sendingPolicy.quiet_hours_end,
    respect_quiet_hours: sendingPolicy.respect_quiet_hours,
    complaint_rate_threshold: sendingPolicy.complaint_rate_threshold,
    bounce_rate_threshold: sendingPolicy.bounce_rate_threshold,
    auto_suspend_on_breach: sendingPolicy.auto_suspend_on_breach,
    updated_at: new Date().toISOString(),
    updated_by: auth.user?.id || null,
  }
  const { error } = await supabase.from('sending_policies').upsert(payload, { onConflict: 'workspace_id' })
  if (error) { toast.error('Save failed', error.message); return }
  audit.log('update', 'sending_policy', workspaceId.value, 'Deliverability safeguards', payload)
  toast.success('Deliverability safeguards saved')
}

async function resumeSending() {
  const ok = await confirmDialog.ask({ title: 'Resume sending?', body: 'Make sure the cause of the pause has been resolved (e.g. high complaints, bad list). Resuming will clear the pause immediately.', confirmText: 'Resume' })
  if (!ok) return
  await supabase.from('workspaces').update({ sending_paused: false, sending_paused_reason: '' }).eq('id', workspaceId.value)
  const open = await supabase.from('sending_suspensions').select('id').eq('workspace_id', workspaceId.value).is('resolved_at', null).limit(1).maybeSingle()
  if (open.data?.id) {
    await supabase.from('sending_suspensions').update({ resolved_at: new Date().toISOString(), resolved_by: auth.user?.id || null }).eq('id', open.data.id)
  }
  audit.log('update', 'workspace', workspaceId.value, 'Resumed sending', {})
  toast.success('Sending resumed')
  const { data } = await supabase.from('workspaces').select('*').eq('id', workspaceId.value).maybeSingle()
  if (data) auth.workspace = data
}

async function savePolicy(p: any) {
  const payload: any = {
    workspace_id: workspaceId.value,
    channel: p.channel,
    max_per_day: p.max_per_day || 0,
    max_per_week: p.max_per_week || 0,
    quiet_start: p.quiet_start || '22:00',
    quiet_end: p.quiet_end || '08:00',
    send_time_optimization: !!p.send_time_optimization,
    respect_time_zone: !!p.respect_time_zone,
  }
  if (p.id) {
    await supabase.from('messaging_policies').update(payload).eq('id', p.id)
  } else {
    const { data } = await supabase.from('messaging_policies').insert(payload).select().maybeSingle()
    if (data) p.id = data.id
  }
  audit.log('update', 'policy', p.id || null, `${p.channel} policy`, { max_per_day: p.max_per_day, max_per_week: p.max_per_week })
  toast.success(`${p.channel} policy saved`)
}

async function saveRetention() {
  if (!workspaceId.value) return
  const days = Math.max(30, Math.min(1825, retentionDays.value))
  const { data, error } = await supabase.from('workspaces').update({ data_retention_days: days }).eq('id', workspaceId.value).select().maybeSingle()
  if (error) { toast.error('Could not save', error.message); return }
  if (data) auth.workspace = data
  audit.log('update', 'workspace', workspaceId.value, 'Data retention', { data_retention_days: days })
  toast.success('Retention updated', `${days} days`)
}

async function requestExport() {
  const payload: any = {
    workspace_id: workspaceId.value,
    requested_by: auth.user?.id || null,
    requested_email: auth.user?.email || '',
    scope: exportForm.scope,
    format: exportForm.format,
    note: exportForm.note || null,
    status: 'pending',
    row_count: 0,
  }
  const { data, error } = await supabase.from('data_exports').insert(payload).select().maybeSingle()
  if (error) { toast.error('Could not request export', error.message); return }
  audit.log('create', 'export', data?.id || null, `${exportForm.scope} export`, { format: exportForm.format })
  openExport.value = false
  Object.assign(exportForm, { scope: 'customers', format: 'csv', note: '' })
  toast.success('Export requested', 'We will email you when it is ready.')
  if (data) {
    setTimeout(async () => {
      const rows = Math.floor(Math.random() * 5000 + 200)
      await supabase.from('data_exports').update({ status: 'ready', row_count: rows, completed_at: new Date().toISOString() }).eq('id', data.id)
      await notify.notify({
        workspace_id: workspaceId.value!,
        to_email: auth.user?.email || '',
        to_user_id: auth.user?.id || null,
        kind: 'export_ready',
        title: 'Your export is ready',
        body: `Your ${data.scope} export (${rows.toLocaleString()} rows) is ready to download.`,
        link: `${window.location.origin}/settings`,
        send_email: true,
      })
      await loadAll()
    }, 2500)
  }
  await loadAll()
}
const loadingEmail = ref(true)
const loadingRoles = ref(true)

const createWs = ref(false)
const newWsName = ref('')
const inviteOpen = ref(false)
const invEmail = ref('')
const invRoleId = ref('')

const openDomain = ref(false)
const domainInput = ref('')
const expanded = ref<string | null>(null)
const openSender = ref(false)
const senderForm = reactive({ domain_id: '', from_name: '', from_email: '', reply_to: '', is_default: false })

const roleOpen = ref(false)
const editingRole = ref<any>(null)
const permissionCatalog = [
  { key: 'campaigns_create', label: 'Create campaigns', hint: 'Draft and save campaigns' },
  { key: 'campaigns_send', label: 'Send campaigns', hint: 'Launch approved campaigns' },
  { key: 'campaigns_approve', label: 'Approve campaigns', hint: 'Sign off on marketing sends' },
  { key: 'journeys_create', label: 'Create journeys', hint: 'Build automated journeys' },
  { key: 'journeys_activate', label: 'Activate journeys', hint: 'Turn journeys on/off' },
  { key: 'journeys_approve', label: 'Approve journeys', hint: 'Sign off on product journeys' },
  { key: 'templates_create', label: 'Manage templates', hint: 'Create and edit templates' },
  { key: 'customers_import', label: 'Import customers', hint: 'Upload CSVs' },
  { key: 'customers_edit', label: 'Edit customers', hint: 'Update customer records' },
  { key: 'apps_create', label: 'Manage apps & SDK keys', hint: 'Create/rotate API keys' },
  { key: 'analytics_view', label: 'View analytics', hint: 'Access funnels, RFM, cohorts' },
  { key: 'settings_manage', label: 'Manage settings', hint: 'Edit workspace settings' },
]
const roleForm = reactive<{ name: string; description: string; flags: Record<string, boolean> }>({
  name: '', description: '', flags: {},
})

const isOwner = computed(() => auth.workspace?.owner_id === auth.user?.id)

function hydrateForm() {
  const w = auth.workspace
  if (!w) return
  wsForm.name = w.name || ''
  wsForm.slug = w.slug || ''
  wsForm.industry = w.industry || ''
  wsForm.timezone = w.timezone || 'UTC'
  wsForm.website = w.website || ''
  wsForm.logo_url = w.logo_url || ''
  wsForm.brand_primary = w.brand_primary || '#3087B9'
  wsForm.brand_accent = w.brand_accent || '#26C165'
}
watchEffect(hydrateForm)

async function toggleCommerce(on: boolean) {
  if (!workspaceId.value) return
  const { data, error } = await supabase.from('workspaces').update({ commerce_enabled: on }).eq('id', workspaceId.value).select().maybeSingle()
  if (error || !data) { toast.error('Could not update', error?.message || 'Only owners can toggle modules.'); return }
  auth.workspace = data
  auth.workspaces = auth.workspaces.map((w: any) => w.id === data.id ? data : w)
  audit.log('update', 'workspace', workspaceId.value, 'Commerce module', { commerce_enabled: on })
  toast.success(`Commerce ${on ? 'enabled' : 'disabled'}`)
}

async function saveWorkspace() {
  if (!workspaceId.value) return
  saving.value = true
  const payload = {
    name: wsForm.name.trim(),
    slug: (wsForm.slug || '').trim().toLowerCase().replace(/[^a-z0-9-]/g, '-'),
    industry: wsForm.industry || '',
    timezone: wsForm.timezone || 'UTC',
    website: wsForm.website || '',
    logo_url: wsForm.logo_url || '',
    brand_primary: wsForm.brand_primary || '#3087B9',
    brand_accent: wsForm.brand_accent || '#26C165',
  }
  const { data, error } = await supabase.from('workspaces').update(payload).eq('id', workspaceId.value).select().maybeSingle()
  saving.value = false
  if (error) { toast.error('Could not save', error.message); return }
  if (!data) { toast.error('Not authorized', 'Only workspace owners can update settings.'); return }
  auth.workspace = data
  auth.workspaces = auth.workspaces.map((w: any) => w.id === data.id ? data : w)
  toast.success('Workspace saved')
}

async function loadAll() {
  if (!workspaceId.value) return
  loadingRoles.value = true
  loadingEmail.value = true
  const [r, m, a, d, s, pol, ex, al, pls] = await Promise.all([
    supabase.from('workspace_roles').select('*').eq('workspace_id', workspaceId.value).order('is_system', { ascending: false }).order('name'),
    supabase.from('workspace_members').select('*').eq('workspace_id', workspaceId.value),
    supabase.from('approvals').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }).limit(20),
    supabase.from('email_domains').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('email_senders').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }),
    supabase.from('messaging_policies').select('*').eq('workspace_id', workspaceId.value),
    supabase.from('data_exports').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }).limit(30),
    supabase.from('audit_logs').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }).limit(100),
    supabase.from('plans').select('*').order('sort_order'),
  ])
  roles.value = r.data || []
  members.value = m.data || []
  approvals.value = a.data || []
  domains.value = d.data || []
  senders.value = s.data || []
  const existing = pol.data || []
  policies.value = POLICY_CHANNELS.map(ch => existing.find((x: any) => x.channel === ch) || defaultPolicy(ch))
  exports.value = ex.data || []
  auditLogs.value = al.data || []
  plans.value = pls.data || []
  retentionDays.value = auth.workspace?.data_retention_days || 365
  const { data: sp } = await supabase.from('sending_policies').select('*').eq('workspace_id', workspaceId.value).maybeSingle()
  if (sp) Object.assign(sendingPolicy, sp)
  loadingRoles.value = false
  loadingEmail.value = false
  if (!invRoleId.value) {
    const viewer = roles.value.find((x: any) => x.name === 'Viewer')
    invRoleId.value = viewer?.id || roles.value[0]?.id || ''
  }
}

function permissionChips(r: any) {
  const chips: string[] = []
  const p = r.permissions || {}
  if (p.all) chips.push('full access')
  if (p.campaigns?.approve) chips.push('approve campaigns')
  if (p.campaigns?.send) chips.push('send campaigns')
  if (p.campaigns?.create) chips.push('create campaigns')
  if (p.journeys?.approve) chips.push('approve journeys')
  if (p.journeys?.activate) chips.push('activate journeys')
  if (p.journeys?.create) chips.push('create journeys')
  if (p.templates?.create) chips.push('templates')
  if (p.customers?.import) chips.push('import customers')
  if (p.customers?.edit) chips.push('edit customers')
  if (p.apps?.create) chips.push('apps & SDKs')
  if (p.analytics?.view) chips.push('view analytics')
  if (p.settings?.manage) chips.push('settings')
  return chips.slice(0, 6)
}

async function review(a: any, status: 'approved' | 'rejected') {
  await supabase.from('approvals').update({ status, reviewed_at: new Date().toISOString(), reviewed_by: auth.user.id }).eq('id', a.id)
  const table = a.entity_type === 'campaign' ? 'campaigns' : 'journeys'
  await supabase.from(table).update({ approval_status: status }).eq('id', a.entity_id)
  if (a.requested_email) {
    await notify.notify({
      workspace_id: workspaceId.value!,
      to_email: a.requested_email,
      kind: 'approval_' + status,
      title: `Your ${a.entity_type} was ${status}`,
      body: `${auth.user?.email} ${status} your ${a.entity_type} "${a.entity_name}".`,
      link: `${window.location.origin}/${a.entity_type === 'campaign' ? 'campaigns' : 'journeys'}`,
      send_email: true,
    })
  }
  audit.log(status, 'approval', a.id, a.entity_name, { entity_type: a.entity_type })
  toast.success(`Request ${status}`)
  await loadAll()
}

async function switchTo(id: string) { await auth.setActiveWorkspace(id) }

async function doCreateWorkspace() {
  if (!newWsName.value) return
  const ws = await auth.createWorkspace(newWsName.value)
  createWs.value = false
  newWsName.value = ''
  if (ws) { await auth.setActiveWorkspace(ws.id); toast.success('Workspace created') }
}

async function invite() {
  if (!workspaceId.value || !invEmail.value || !invRoleId.value) return
  const email = invEmail.value.trim().toLowerCase()
  if (email === (auth.user?.email || '').toLowerCase()) {
    toast.error("You're already the owner of this workspace."); return
  }
  const { error } = await supabase.from('workspace_members').insert({
    workspace_id: workspaceId.value, email, role_id: invRoleId.value, role: 'member',
  })
  if (error) { toast.error('Could not invite', error.message.includes('duplicate') ? 'That email is already invited.' : error.message); return }
  inviteOpen.value = false
  invEmail.value = ''
  await notify.notify({
    workspace_id: workspaceId.value!,
    to_email: email,
    kind: 'invite',
    title: `You've been added to ${auth.workspace?.name}`,
    body: `${auth.user?.email} invited you to collaborate on ${auth.workspace?.name}. Sign in to access the workspace.`,
    link: `${window.location.origin}/login`,
    send_email: true,
  })
  audit.log('invite', 'member', null, email, { role_id: invRoleId.value })
  toast.success('Invite sent', `${email} will be notified by email and in-app.`)
  await loadAll()
}

async function updateMemberRole(m: any, roleId: string) {
  const { error } = await supabase.from('workspace_members').update({ role_id: roleId }).eq('id', m.id)
  if (error) { toast.error('Could not update role', error.message); return }
  toast.success('Role updated')
  await loadAll()
}
async function removeMember(m: any) {
  const ok = await confirmDialog.ask({ title: 'Remove this member?', message: 'They will lose access to this workspace immediately.', tone: 'danger', confirmText: 'Remove' })
  if (!ok) return
  await supabase.from('workspace_members').delete().eq('id', m.id)
  toast.success('Member removed')
  await loadAll()
}

// Email & domains
async function addDomain() {
  const domain = domainInput.value.trim().toLowerCase()
  if (!domain) return
  const dkim_selector = 'pulse' + Math.floor(Math.random() * 9000 + 1000)
  const { error } = await supabase.from('email_domains').insert({
    workspace_id: workspaceId.value, domain, dkim_selector,
    dkim_public_key: 'v=DKIM1;k=rsa;p=' + Math.random().toString(36).slice(2),
    return_path: 'bounce.' + domain,
  })
  if (error) { toast.error('Could not add domain', error.message); return }
  openDomain.value = false
  domainInput.value = ''
  toast.success('Domain added', 'Publish the DNS records to verify ownership.')
  await loadAll()
}
function toggleDns(id: string) { expanded.value = expanded.value === id ? null : id }
async function verifyDomain(d: any) {
  toast.info('Checking DNS…', d.domain)
  const res: any = await notify.verifyDomain(d.id)
  if (res?.error) { toast.error('Verification failed', res.error); await loadAll(); return }
  if (res?.ok) {
    toast.success('Domain verified', d.domain)
  } else {
    const missing: string[] = []
    if (!res?.spf) missing.push('SPF')
    if (!res?.dkim) missing.push('DKIM')
    if (!res?.dmarc) missing.push('DMARC')
    toast.warning('DNS not ready', missing.length ? `Missing/invalid: ${missing.join(', ')}` : 'DNS not propagated yet')
  }
  await loadAll()
}
async function removeDomain(d: any) {
  const ok = await confirmDialog.ask({ title: `Remove ${d.domain}?`, message: 'Campaigns using senders on this domain will stop working.', tone: 'danger', confirmText: 'Remove domain' })
  if (!ok) return
  await supabase.from('email_domains').delete().eq('id', d.id)
  toast.success('Domain removed')
  await loadAll()
}
function statusChip(s: string) {
  return s === 'verified' ? 'bg-accent-500/10 text-accent-500' : s === 'failed' ? 'bg-red-100 text-red-600' : 'bg-yellow-100 text-yellow-700'
}
function domainFor(id: string) { return domains.value.find((d: any) => d.id === id)?.domain || '—' }

async function addSender() {
  if (!senderForm.domain_id || !senderForm.from_email) return
  if (senderForm.is_default) {
    await supabase.from('email_senders').update({ is_default: false }).eq('workspace_id', workspaceId.value)
  }
  const { error } = await supabase.from('email_senders').insert({
    workspace_id: workspaceId.value, ...senderForm, verified: false,
  })
  if (error) { toast.error('Could not save sender', error.message); return }
  openSender.value = false
  Object.assign(senderForm, { domain_id: '', from_name: '', from_email: '', reply_to: '', is_default: false })
  toast.success('Sender saved')
  await loadAll()
}
async function makeDefault(s: any) {
  await supabase.from('email_senders').update({ is_default: false }).eq('workspace_id', workspaceId.value)
  await supabase.from('email_senders').update({ is_default: true }).eq('id', s.id)
  toast.success('Default sender updated')
  await loadAll()
}
async function removeSender(s: any) {
  const ok = await confirmDialog.ask({ title: 'Remove this sender?', tone: 'danger', confirmText: 'Remove' })
  if (!ok) return
  await supabase.from('email_senders').delete().eq('id', s.id)
  toast.success('Sender removed')
  await loadAll()
}

// Custom roles
function flagsFromPermissions(p: any): Record<string, boolean> {
  return {
    campaigns_create: !!p?.campaigns?.create,
    campaigns_send: !!p?.campaigns?.send,
    campaigns_approve: !!p?.campaigns?.approve,
    journeys_create: !!p?.journeys?.create,
    journeys_activate: !!p?.journeys?.activate,
    journeys_approve: !!p?.journeys?.approve,
    templates_create: !!p?.templates?.create,
    customers_import: !!p?.customers?.import,
    customers_edit: !!p?.customers?.edit,
    apps_create: !!p?.apps?.create,
    analytics_view: !!p?.analytics?.view,
    settings_manage: !!p?.settings?.manage,
  }
}
function permissionsFromFlags(f: Record<string, boolean>) {
  return {
    campaigns: { create: f.campaigns_create, send: f.campaigns_send, approve: f.campaigns_approve },
    journeys: { create: f.journeys_create, activate: f.journeys_activate, approve: f.journeys_approve },
    templates: { create: f.templates_create },
    customers: { import: f.customers_import, edit: f.customers_edit },
    apps: { create: f.apps_create },
    analytics: { view: f.analytics_view },
    settings: { manage: f.settings_manage },
  }
}
function openRole(r?: any) {
  editingRole.value = r || null
  roleForm.name = r?.name || ''
  roleForm.description = r?.description || ''
  roleForm.flags = flagsFromPermissions(r?.permissions)
  roleOpen.value = true
}
async function saveRole() {
  if (!workspaceId.value || !roleForm.name.trim()) return
  const payload = {
    workspace_id: workspaceId.value,
    name: roleForm.name.trim(),
    description: roleForm.description.trim(),
    permissions: permissionsFromFlags(roleForm.flags),
    is_system: false,
  }
  const { error } = editingRole.value
    ? await supabase.from('workspace_roles').update(payload).eq('id', editingRole.value.id)
    : await supabase.from('workspace_roles').insert(payload)
  if (error) { toast.error('Could not save role', error.message); return }
  roleOpen.value = false
  toast.success(editingRole.value ? 'Role updated' : 'Role created')
  await loadAll()
}
async function deleteRole(r: any) {
  const ok = await confirmDialog.ask({ title: `Delete ${r.name}?`, message: 'Members assigned this role will need to be reassigned.', tone: 'danger', confirmText: 'Delete role' })
  if (!ok) return
  const { error } = await supabase.from('workspace_roles').delete().eq('id', r.id)
  if (error) { toast.error('Could not delete', error.message); return }
  toast.success('Role deleted')
  await loadAll()
}

async function purge() {
  const ok = await confirmDialog.ask({ title: 'Purge workspace data?', message: 'Deletes customers, events, campaigns, journeys, messages, banners, lists, segments and imports.', tone: 'danger', confirmText: 'Purge everything' })
  if (!ok) return
  const wid = workspaceId.value
  await Promise.all([
    supabase.from('events').delete().eq('workspace_id', wid),
    supabase.from('campaigns').delete().eq('workspace_id', wid),
    supabase.from('journeys').delete().eq('workspace_id', wid),
    supabase.from('onsite_messages').delete().eq('workspace_id', wid),
    supabase.from('inapp_banners').delete().eq('workspace_id', wid),
    supabase.from('segments').delete().eq('workspace_id', wid),
    supabase.from('lists').delete().eq('workspace_id', wid),
    supabase.from('imports').delete().eq('workspace_id', wid),
    supabase.from('event_definitions').delete().eq('workspace_id', wid),
    supabase.from('customers').delete().eq('workspace_id', wid),
    supabase.from('templates').delete().eq('workspace_id', wid),
    supabase.from('funnels').delete().eq('workspace_id', wid),
    supabase.from('cohorts').delete().eq('workspace_id', wid),
  ])
  toast.success('Workspace data cleared')
}

watch(workspaceId, loadAll, { immediate: true })
</script>
