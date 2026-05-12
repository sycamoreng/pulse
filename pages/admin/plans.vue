<template>
  <div>
    <PageHeader title="Plans" subtitle="Pricing tiers, feature entitlements and trial settings.">
      <template #actions><button @click="edit(null)" class="btn-primary"><Icon name="plus"/>New plan</button></template>
    </PageHeader>
    <div class="p-8 grid md:grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="p in plans" :key="p.id"
        class="card p-5 cursor-pointer hover:shadow-md transition"
        :class="p.highlight ? 'ring-2 ring-brand-500' : ''"
        @click="edit(p)">
        <div class="flex items-center justify-between">
          <div class="font-semibold text-ink-900">{{ p.name }}</div>
          <div class="flex items-center gap-1">
            <span v-if="p.highlight" class="chip bg-brand-100/60 text-brand-700">Featured</span>
            <span v-if="!p.is_public" class="chip bg-ink-100 text-ink-700">Hidden</span>
          </div>
        </div>
        <div class="text-xs text-ink-500 mt-1">{{ p.tagline || p.description?.slice(0, 60) }}</div>
        <div class="text-3xl font-bold text-ink-900 mt-3">
          <span v-if="p.contact_sales">Custom</span>
          <template v-else>${{ p.price_monthly }}<span class="text-xs text-ink-500">/mo</span></template>
        </div>
        <ul class="text-xs text-ink-600 mt-4 space-y-1.5">
          <li>{{ p.email_monthly_quota.toLocaleString() }} emails/mo</li>
          <li>{{ p.sms_monthly_quota.toLocaleString() }} SMS/mo</li>
          <li>{{ p.push_monthly_quota.toLocaleString() }} push/mo</li>
          <li>{{ p.seats }} seats / {{ p.max_workspaces }} workspaces</li>
          <li>{{ p.max_active_journeys }} journeys / {{ p.max_active_campaigns }} campaigns</li>
          <li>{{ p.data_retention_days }}d retention / {{ p.support_sla_hours }}h SLA</li>
          <li class="text-brand-600 font-medium" v-if="p.default_trial_days">{{ p.default_trial_days }}-day free trial</li>
        </ul>
        <div class="mt-4 flex flex-wrap gap-1">
          <span v-for="f in enabledFeatures(p)" :key="f" class="chip bg-ink-50 text-ink-700 text-[10px]">{{ humanize(f) }}</span>
          <span v-if="enabledFeatures(p).length > 6" class="chip bg-ink-50 text-ink-500 text-[10px]">+{{ enabledFeatures(p).length - 6 }} more</span>
        </div>
      </div>
    </div>

    <Modal v-model="open" :title="editing?.id ? 'Edit plan' : 'New plan'" size="lg">
      <form id="plf" @submit.prevent="save" class="space-y-4">
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">Code</label><input v-model="form.code" class="input" required/></div>
          <div><label class="label">Name</label><input v-model="form.name" class="input" required/></div>
          <div class="col-span-2"><label class="label">Tagline</label><input v-model="form.tagline" class="input" placeholder="Short one-liner shown on pricing cards"/></div>
          <div class="col-span-2"><label class="label">Description</label><textarea v-model="form.description" rows="2" class="input"></textarea></div>
        </div>

        <div class="border-t border-ink-100 pt-3">
          <div class="text-xs font-semibold text-ink-700 uppercase tracking-wider mb-2">Pricing and trial</div>
          <div class="grid grid-cols-4 gap-3">
            <div><label class="label">Price/mo</label><input v-model.number="form.price_monthly" type="number" class="input"/></div>
            <div><label class="label">Price/yr</label><input v-model.number="form.price_yearly" type="number" class="input"/></div>
            <div><label class="label">Trial days</label><input v-model.number="form.default_trial_days" type="number" min="0" class="input"/></div>
            <div><label class="label">CTA label</label><input v-model="form.cta_label" class="input"/></div>
          </div>
          <div class="flex flex-wrap items-center gap-4 mt-3 text-sm">
            <label class="flex items-center gap-2"><input type="checkbox" v-model="form.is_public"/> Publicly listed</label>
            <label class="flex items-center gap-2"><input type="checkbox" v-model="form.highlight"/> Featured</label>
            <label class="flex items-center gap-2"><input type="checkbox" v-model="form.contact_sales"/> Contact sales (custom pricing)</label>
          </div>
        </div>

        <div class="border-t border-ink-100 pt-3">
          <div class="text-xs font-semibold text-ink-700 uppercase tracking-wider mb-2">Usage limits</div>
          <div class="grid grid-cols-3 gap-3">
            <div><label class="label">Seats</label><input v-model.number="form.seats" type="number" class="input"/></div>
            <div><label class="label">Workspaces</label><input v-model.number="form.max_workspaces" type="number" class="input"/></div>
            <div><label class="label">Domains</label><input v-model.number="form.included_domains" type="number" class="input"/></div>
            <div><label class="label">Email/mo</label><input v-model.number="form.email_monthly_quota" type="number" class="input"/></div>
            <div><label class="label">SMS/mo</label><input v-model.number="form.sms_monthly_quota" type="number" class="input"/></div>
            <div><label class="label">Push/mo</label><input v-model.number="form.push_monthly_quota" type="number" class="input"/></div>
            <div><label class="label">Active journeys</label><input v-model.number="form.max_active_journeys" type="number" class="input"/></div>
            <div><label class="label">Active campaigns</label><input v-model.number="form.max_active_campaigns" type="number" class="input"/></div>
            <div><label class="label">Segments</label><input v-model.number="form.max_segments" type="number" class="input"/></div>
            <div><label class="label">Events/mo</label><input v-model.number="form.max_events_per_month" type="number" class="input"/></div>
            <div><label class="label">Retention days</label><input v-model.number="form.data_retention_days" type="number" class="input"/></div>
            <div><label class="label">Support SLA hrs</label><input v-model.number="form.support_sla_hours" type="number" class="input"/></div>
          </div>
        </div>

        <div class="border-t border-ink-100 pt-3">
          <div class="text-xs font-semibold text-ink-700 uppercase tracking-wider mb-2">Feature entitlements</div>
          <div class="grid grid-cols-2 md:grid-cols-3 gap-2 text-sm">
            <label v-for="f in FEATURE_KEYS" :key="f" class="flex items-center gap-2 py-1 px-2 rounded hover:bg-ink-50 cursor-pointer">
              <input type="checkbox" :checked="!!form.feature_flags?.[f]" @change="(e: any) => setFlag(f, e.target.checked)"/>
              <span class="text-ink-800">{{ humanize(f) }}</span>
            </label>
          </div>
        </div>

        <div class="border-t border-ink-100 pt-3">
          <label class="label">Sort order</label>
          <input v-model.number="form.sort_order" type="number" class="input !w-32"/>
        </div>
      </form>
      <template #footer>
        <button @click="open = false" type="button" class="btn-secondary">Cancel</button>
        <button v-if="editing?.id" @click="remove" type="button" class="btn-ghost text-red-600 mr-auto"><Icon name="trash"/>Delete</button>
        <button form="plf" type="submit" class="btn-primary">Save plan</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })
const { $supabase } = useNuxtApp()

const FEATURE_KEYS = [
  'journeys','segments','campaigns','templates','customer_profiles','basic_analytics',
  'advanced_analytics','funnels','cohorts','rfm','predictive','ai_studio',
  'ab_testing','sms','web_push','custom_domain','commerce_integrations','api_access','webhooks',
  'inbox_placement','scheduled_reports','custom_roles','advanced_rbac','dedicated_ip',
  'sso','scim','audit_export','sla','priority_support','email_support','white_label',
]

function humanize(f: string) {
  return f.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
    .replace(/Rfm/, 'RFM').replace(/Ai /, 'AI ').replace(/Sms/, 'SMS').replace(/Sso/, 'SSO')
    .replace(/Scim/, 'SCIM').replace(/Api/, 'API').replace(/Sla/, 'SLA').replace(/Ab /, 'A/B ')
    .replace(/Rbac/, 'RBAC')
}

const plans = ref<any[]>([])
const open = ref(false)
const editing = ref<any>(null)
const emptyForm = () => ({
  code: '', name: '', description: '', tagline: '',
  price_monthly: 0, price_yearly: 0, default_trial_days: 0, cta_label: 'Choose plan',
  seats: 1, max_workspaces: 1, included_domains: 1,
  email_monthly_quota: 0, sms_monthly_quota: 0, push_monthly_quota: 0,
  max_active_journeys: 1, max_active_campaigns: 3, max_segments: 5,
  max_events_per_month: 10000, data_retention_days: 30, support_sla_hours: 72,
  feature_flags: {} as Record<string, boolean>,
  is_public: true, highlight: false, contact_sales: false, sort_order: 1,
})
const form = reactive<any>(emptyForm())

function enabledFeatures(p: any) { return FEATURE_KEYS.filter((k) => p?.feature_flags?.[k]) }
function setFlag(key: string, on: boolean) {
  form.feature_flags = { ...(form.feature_flags || {}), [key]: on }
}

async function load() {
  const { data } = await $supabase.from('plans').select('*').order('sort_order')
  plans.value = data || []
}
function edit(p: any) {
  editing.value = p
  Object.assign(form, emptyForm())
  if (p) Object.assign(form, { ...p, feature_flags: { ...(p.feature_flags || {}) } })
  open.value = true
}
async function save() {
  const payload = { ...form }
  if (editing.value?.id) await $supabase.from('plans').update(payload).eq('id', editing.value.id)
  else await $supabase.from('plans').insert(payload)
  useToast().success('Plan saved')
  open.value = false; await load()
}
async function remove() {
  const ok = await useConfirm().ask({ title: 'Delete plan?', message: 'Workspaces on this plan will need to be moved first.', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  const { error } = await $supabase.from('plans').delete().eq('id', editing.value.id)
  if (error) { useToast().error('Could not delete', error.message); return }
  useToast().success('Plan deleted')
  open.value = false; await load()
}
onMounted(load)
</script>
