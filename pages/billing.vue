<template>
  <div class="max-w-6xl mx-auto space-y-6">
    <PageHeader title="Billing & plans" subtitle="Manage your plan, usage, payment method and invoices."/>

    <div v-if="blockedFlag" class="card p-4 border-amber-300 bg-amber-50 dark:bg-amber-500/10 flex items-start gap-3">
      <div class="w-10 h-10 rounded-lg bg-white dark:bg-[color:var(--surface-card)] flex items-center justify-center shrink-0">
        <Icon name="shield" class="w-5 h-5 text-amber-600"/>
      </div>
      <div class="flex-1">
        <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">
          {{ blockedFlagLabel }} is on a higher plan
        </div>
        <div class="text-xs text-ink-600 dark:text-[color:var(--text-tertiary)]">
          Upgrade to the {{ blockedFlagRequiredPlan }} plan to unlock this feature.
        </div>
      </div>
    </div>

    <div v-if="billing.trialBannerVisible.value" class="card p-4 flex items-center justify-between"
      :class="billing.trialDaysLeft.value <= 3 ? 'border-yellow-300 bg-yellow-50' : 'border-brand-200 bg-brand-50/40'">
      <div class="flex items-start gap-3">
        <div class="w-10 h-10 rounded-lg bg-white flex items-center justify-center">
          <Icon name="activity" class="w-5 h-5 text-brand-600"/>
        </div>
        <div>
          <div class="font-semibold text-ink-900">
            {{ billing.trialDaysLeft.value > 0
              ? `${billing.trialDaysLeft.value} days left in your ${billing.currentPlan.value?.name} trial`
              : `Your ${billing.currentPlan.value?.name} trial has ended` }}
          </div>
          <div class="text-xs text-ink-600">
            Ends {{ new Date(auth.workspace?.trial_ends_at).toLocaleDateString() }}. Upgrade anytime to keep your features.
          </div>
        </div>
      </div>
      <button @click="scrollToPlans" class="btn-primary">Upgrade now</button>
    </div>

    <section class="card p-6">
      <div class="flex flex-wrap items-start justify-between gap-6">
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <div class="text-[11px] uppercase tracking-wider text-ink-500">Current plan</div>
            <span v-if="billing.subscriptionStatusLabel.value" class="chip text-[10px]" :class="billing.statusChipClass.value">
              {{ billing.subscriptionStatusLabel.value }}
            </span>
          </div>
          <div class="flex items-baseline gap-3 mt-1">
            <div class="text-3xl font-bold text-ink-900 dark:text-[color:var(--text-primary)]">
              {{ billing.currentPlan.value?.name || 'Free' }}
            </div>
            <div class="text-sm text-ink-500">
              <template v-if="billing.currentPlan.value?.contact_sales">Custom pricing</template>
              <template v-else>${{ billing.currentPlan.value?.price_monthly || 0 }}/mo</template>
            </div>
          </div>
          <div class="text-sm text-ink-500 mt-2 max-w-xl">{{ billing.currentPlan.value?.description }}</div>
        </div>
        <div class="flex items-center gap-2">
          <button @click="scrollToPlans" class="btn-primary"><Icon name="send"/>Compare plans</button>
          <button v-if="billing.currentPlan.value?.code !== 'enterprise' && billing.currentPlan.value?.code !== 'free'"
            @click="onCancel" class="btn-ghost text-red-600 !text-xs">Cancel subscription</button>
        </div>
      </div>
    </section>

    <section class="card p-6">
      <div class="flex items-center justify-between mb-4">
        <div>
          <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">Usage this month</div>
          <div class="text-xs text-ink-500">Quotas reset at the start of each billing cycle.</div>
        </div>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
        <UsageStat label="Email" :used="auth.workspace?.email_used_this_month || 0" :cap="billing.emailCap.value" colorClass="bg-brand-500"/>
        <UsageStat label="SMS" :used="auth.workspace?.sms_used_this_month || 0" :cap="billing.smsCap.value" colorClass="bg-accent-500"/>
        <UsageStat label="Push" :used="auth.workspace?.push_used_this_month || 0" :cap="billing.pushCap.value" colorClass="bg-emerald-500"/>
        <div class="rounded-xl border border-ink-100 dark:border-[color:var(--border-subtle)] p-4 bg-white dark:bg-[color:var(--surface-card)]">
          <div class="text-[11px] uppercase tracking-wider text-ink-500">Seats</div>
          <div class="text-2xl font-bold text-ink-900 dark:text-[color:var(--text-primary)] mt-1 tabular-nums">
            {{ seatsUsed }}<span class="text-sm font-medium text-ink-500"> / {{ billing.currentPlan.value?.seats || 1 }}</span>
          </div>
          <div class="text-[11px] text-ink-500 mt-2">{{ billing.currentPlan.value?.data_retention_days || 30 }} days retention</div>
        </div>
      </div>
    </section>

    <section class="card p-6">
      <div class="flex items-center justify-between mb-4">
        <div>
          <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">Payment method</div>
          <div class="text-xs text-ink-500">Used for monthly subscription charges.</div>
        </div>
        <button @click="openPayment" class="btn-secondary" :disabled="billing.currentPlan.value?.code === 'free'">
          <Icon name="plus"/>{{ billing.defaultPaymentMethod.value ? 'Update card' : 'Add card' }}
        </button>
      </div>
      <div v-if="billing.currentPlan.value?.code === 'free'" class="text-sm text-ink-500">
        You're on the Free plan. No billing details required.
      </div>
      <template v-else>
        <div v-if="billing.defaultPaymentMethod.value" class="flex items-center justify-between p-4 rounded-lg bg-ink-50 dark:bg-[color:var(--surface-muted)]">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-lg bg-white dark:bg-[color:var(--surface-card)] flex items-center justify-center">
              <Icon name="activity" class="w-5 h-5 text-ink-700"/>
            </div>
            <div>
              <div class="font-medium text-ink-900 dark:text-[color:var(--text-primary)] text-sm">
                {{ billing.defaultPaymentMethod.value.brand }} ending {{ billing.defaultPaymentMethod.value.last4 }}
              </div>
              <div class="text-xs text-ink-500">
                Expires {{ String(billing.defaultPaymentMethod.value.exp_month).padStart(2, '0') }}/{{ billing.defaultPaymentMethod.value.exp_year }}
                · {{ billing.defaultPaymentMethod.value.holder_name }}
              </div>
            </div>
          </div>
          <button @click="billing.removePaymentMethod(billing.defaultPaymentMethod.value.id)" class="btn-ghost text-red-600 !text-xs">Remove</button>
        </div>
        <div v-else class="text-sm text-ink-500">No payment method on file yet.</div>
      </template>
    </section>

    <section class="card p-0 overflow-hidden">
      <div class="flex items-center justify-between p-6 pb-4">
        <div>
          <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">Invoices</div>
          <div class="text-xs text-ink-500">The last 12 issued invoices.</div>
        </div>
      </div>
      <div v-if="!billing.invoices.value.length" class="px-6 pb-6 text-sm text-ink-500">No invoices issued yet.</div>
      <table v-else class="w-full text-sm">
        <thead class="text-left text-[11px] text-ink-500 uppercase tracking-wider border-t border-b border-ink-100 dark:border-[color:var(--border-subtle)] bg-ink-50/60 dark:bg-[color:var(--surface-muted)]">
          <tr><th class="px-6 py-2">Invoice</th><th class="px-6 py-2">Period</th><th class="px-6 py-2">Amount</th><th class="px-6 py-2">Status</th><th></th></tr>
        </thead>
        <tbody>
          <tr v-for="inv in billing.invoices.value" :key="inv.id" class="border-b border-ink-100 dark:border-[color:var(--border-subtle)] last:border-0">
            <td class="px-6 py-3 font-medium text-ink-900 dark:text-[color:var(--text-primary)]">{{ inv.number || inv.id.slice(0, 8) }}</td>
            <td class="px-6 py-3 text-ink-600 dark:text-[color:var(--text-tertiary)] text-xs">
              {{ inv.period_start ? new Date(inv.period_start).toLocaleDateString() : '—' }}
              – {{ inv.period_end ? new Date(inv.period_end).toLocaleDateString() : '—' }}
            </td>
            <td class="px-6 py-3 text-ink-900 dark:text-[color:var(--text-primary)] tabular-nums">
              ${{ ((inv.amount_cents || 0) / 100).toFixed(2) }} {{ inv.currency }}
            </td>
            <td class="px-6 py-3"><span class="chip text-[10px]" :class="billing.invoiceStatusClass(inv.status)">{{ inv.status }}</span></td>
            <td class="px-6 py-3 text-right"><a v-if="inv.hosted_url" :href="inv.hosted_url" target="_blank" class="btn-ghost !text-xs">View</a></td>
          </tr>
        </tbody>
      </table>
    </section>

    <section ref="plansRef" class="space-y-3">
      <div class="flex items-end justify-between flex-wrap gap-3">
        <div>
          <div class="text-lg font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">Plans</div>
          <div class="text-xs text-ink-500">Upgrade or downgrade any time. Changes take effect immediately.</div>
        </div>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
        <div v-for="p in billing.publicPlans.value" :key="p.id"
          class="card p-5 relative flex flex-col"
          :class="[
            p.id === auth.workspace?.plan_id ? 'border-brand-500 ring-2 ring-brand-500/20' : '',
            p.highlight && p.id !== auth.workspace?.plan_id ? 'border-brand-300' : ''
          ]">
          <div v-if="p.highlight" class="absolute -top-2.5 left-4 chip bg-brand-500 text-white !text-[10px]">Most popular</div>
          <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">{{ p.name }}</div>
          <div class="text-xs text-ink-500 mt-0.5 min-h-[32px]">{{ p.tagline }}</div>
          <div class="text-3xl font-bold text-ink-900 dark:text-[color:var(--text-primary)] mt-3">
            <template v-if="p.contact_sales">Custom</template>
            <template v-else>${{ p.price_monthly }}<span class="text-xs font-medium text-ink-500">/mo</span></template>
          </div>
          <div v-if="p.default_trial_days && !p.contact_sales" class="text-[11px] text-brand-600 font-medium mt-0.5">{{ p.default_trial_days }}-day free trial</div>
          <ul class="text-xs text-ink-600 dark:text-[color:var(--text-tertiary)] mt-4 space-y-1.5 flex-1">
            <li class="flex items-start gap-2"><Icon name="check" class="w-3.5 h-3.5 text-accent-500 shrink-0 mt-0.5"/>{{ p.email_monthly_quota.toLocaleString() }} emails/mo</li>
            <li class="flex items-start gap-2"><Icon name="check" class="w-3.5 h-3.5 text-accent-500 shrink-0 mt-0.5"/>{{ p.sms_monthly_quota.toLocaleString() }} SMS/mo</li>
            <li class="flex items-start gap-2"><Icon name="check" class="w-3.5 h-3.5 text-accent-500 shrink-0 mt-0.5"/>{{ p.seats }} seats</li>
            <li class="flex items-start gap-2"><Icon name="check" class="w-3.5 h-3.5 text-accent-500 shrink-0 mt-0.5"/>{{ p.max_active_journeys }} journeys · {{ p.max_active_campaigns }} campaigns</li>
            <li v-if="p.feature_flags?.ab_testing" class="flex items-start gap-2"><Icon name="check" class="w-3.5 h-3.5 text-accent-500 shrink-0 mt-0.5"/>A/B testing</li>
            <li v-if="p.feature_flags?.predictive" class="flex items-start gap-2"><Icon name="check" class="w-3.5 h-3.5 text-accent-500 shrink-0 mt-0.5"/>Predictive analytics</li>
            <li v-if="p.feature_flags?.priority_support" class="flex items-start gap-2"><Icon name="check" class="w-3.5 h-3.5 text-accent-500 shrink-0 mt-0.5"/>Priority support</li>
            <li v-if="p.feature_flags?.sso" class="flex items-start gap-2"><Icon name="check" class="w-3.5 h-3.5 text-accent-500 shrink-0 mt-0.5"/>SSO &amp; SCIM</li>
            <li v-if="p.feature_flags?.sla" class="flex items-start gap-2"><Icon name="check" class="w-3.5 h-3.5 text-accent-500 shrink-0 mt-0.5"/>SLA uptime</li>
          </ul>
          <button
            @click="onChoose(p)"
            :disabled="p.id === auth.workspace?.plan_id || billing.busy.value"
            class="w-full mt-5"
            :class="p.id === auth.workspace?.plan_id ? 'btn-secondary' : (p.highlight ? 'btn-primary' : 'btn-secondary')">
            <template v-if="p.id === auth.workspace?.plan_id">Current plan</template>
            <template v-else-if="p.code === 'enterprise' || billing.currentPlan.value?.code === 'enterprise'">Talk to sales</template>
            <template v-else-if="billing.planRank(p) > billing.planRank(billing.currentPlan.value)">Upgrade to {{ p.name }}</template>
            <template v-else-if="billing.planRank(p) < billing.planRank(billing.currentPlan.value)">Downgrade to {{ p.name }}</template>
            <template v-else>{{ p.cta_label || 'Choose plan' }}</template>
          </button>
        </div>
      </div>
    </section>

    <section class="card p-6">
      <button @click="featuresOpen = !featuresOpen" class="w-full flex items-center justify-between text-left">
        <div>
          <div class="font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">Feature comparison</div>
          <div class="text-xs text-ink-500">See exactly what's included in every tier.</div>
        </div>
        <Icon name="chevronDown" class="w-5 h-5 text-ink-500 transition-transform" :class="featuresOpen ? 'rotate-180' : ''"/>
      </button>
      <div v-if="featuresOpen" class="mt-5 overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wider text-ink-500">
              <th class="py-2 font-medium">Feature</th>
              <th v-for="p in billing.publicPlans.value" :key="p.id" class="py-2 font-medium text-center">{{ p.name }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="f in FEATURE_DISPLAY" :key="f.key" class="border-t border-ink-100 dark:border-[color:var(--border-subtle)]">
              <td class="py-2.5 text-ink-800 dark:text-[color:var(--text-secondary)]">{{ f.label }}</td>
              <td v-for="p in billing.publicPlans.value" :key="p.id" class="py-2.5 text-center">
                <Icon v-if="p.feature_flags?.[f.key]" name="check" class="w-4 h-4 text-accent-500 inline"/>
                <span v-else class="text-ink-300">—</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <Modal v-model="planChangeOpen" :title="planChange.mode === 'downgrade' ? `Downgrade to ${planChange.planName}?` : `Upgrade to ${planChange.planName}?`"
      :subtitle="planChange.mode === 'downgrade' ? 'Lower limits take effect immediately.' : 'Higher limits and features unlock immediately.'">
      <div class="space-y-3">
        <div class="p-4 rounded-lg bg-ink-50 dark:bg-[color:var(--surface-muted)] flex items-center justify-between">
          <div>
            <div class="text-xs text-ink-500 uppercase tracking-wider">New price</div>
            <div class="text-2xl font-bold text-ink-900 dark:text-[color:var(--text-primary)]">${{ planChange.price }}<span class="text-sm text-ink-500">/mo</span></div>
          </div>
          <div class="text-right">
            <div class="text-xs text-ink-500 uppercase tracking-wider">Current</div>
            <div class="text-lg font-semibold text-ink-700 dark:text-[color:var(--text-secondary)]">{{ billing.currentPlan.value?.name }}</div>
          </div>
        </div>
        <div v-if="planChange.mode === 'downgrade'" class="text-sm text-yellow-800 bg-yellow-50 border border-yellow-100 rounded-lg p-3">
          Going to a lower plan reduces your quotas and may disable features you're actively using. We won't delete any data.
        </div>
        <div v-if="!billing.defaultPaymentMethod.value && planChange.price > 0" class="text-sm text-ink-700 bg-brand-50/60 border border-brand-100 rounded-lg p-3">
          You'll be prompted to add a payment method after confirming.
        </div>
      </div>
      <template #footer>
        <button @click="planChangeOpen = false" type="button" class="btn-secondary" :disabled="billing.busy.value">Cancel</button>
        <button @click="confirmPlanChange" type="button" class="btn-primary" :disabled="billing.busy.value">
          {{ billing.busy.value ? 'Working…' : (planChange.mode === 'downgrade' ? 'Downgrade' : 'Confirm upgrade') }}
        </button>
      </template>
    </Modal>

    <Modal v-model="salesOpen" title="Talk to sales" subtitle="Enterprise moves are arranged by our team to tailor pricing and SLAs.">
      <form id="salesForm" @submit.prevent="onSubmitSales" class="space-y-3">
        <div>
          <label class="label">Plan</label>
          <div class="input bg-ink-50">{{ sales.planName }}</div>
        </div>
        <div>
          <label class="label">Company size</label>
          <input v-model="sales.companySize" class="input" placeholder="e.g. 50 employees, 1M contacts"/>
        </div>
        <div>
          <label class="label">What do you need?</label>
          <textarea v-model="sales.note" rows="3" class="input" placeholder="Tell us about your volume, SLAs, compliance needs, or timeline"></textarea>
        </div>
      </form>
      <template #footer>
        <button @click="salesOpen = false" type="button" class="btn-secondary">Cancel</button>
        <button form="salesForm" type="submit" class="btn-primary">Send to sales</button>
      </template>
    </Modal>

    <Modal v-model="paymentOpen" :title="billing.defaultPaymentMethod.value ? 'Update payment method' : 'Add payment method'">
      <form id="payForm" @submit.prevent="onSavePayment" class="space-y-3">
        <div>
          <label class="label">Cardholder name</label>
          <input v-model="payment.holder_name" class="input" required placeholder="Jane Appleseed"/>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="label">Card brand</label>
            <select v-model="payment.brand" class="input">
              <option value="Visa">Visa</option>
              <option value="Mastercard">Mastercard</option>
              <option value="Amex">American Express</option>
              <option value="Discover">Discover</option>
            </select>
          </div>
          <div>
            <label class="label">Last 4</label>
            <input v-model="payment.last4" class="input" required maxlength="4" pattern="\d{4}" placeholder="4242"/>
          </div>
          <div>
            <label class="label">Exp month</label>
            <input v-model.number="payment.exp_month" type="number" min="1" max="12" class="input" required/>
          </div>
          <div>
            <label class="label">Exp year</label>
            <input v-model.number="payment.exp_year" type="number" :min="new Date().getFullYear()" class="input" required/>
          </div>
        </div>
        <div class="text-[11px] text-ink-500">We never store full card numbers. In production this form hands off to the payment processor.</div>
      </form>
      <template #footer>
        <button @click="paymentOpen = false" type="button" class="btn-secondary">Cancel</button>
        <button form="payForm" type="submit" class="btn-primary">Save card</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'

const auth = useAuthStore()
const billing = useBilling()
const toast = useToast()
const confirm = useConfirm()
const route = useRoute()
const { $supabase } = useNuxtApp()

const featuresOpen = ref(false)
const plansRef = ref<HTMLElement | null>(null)

const seatsUsed = ref(1)
async function loadSeats() {
  if (!auth.workspace?.id) return
  const { count } = await $supabase.from('workspace_members').select('id', { count: 'exact', head: true })
    .eq('workspace_id', auth.workspace.id)
  seatsUsed.value = count || 1
}
watch(() => auth.workspace?.id, () => { void loadSeats() }, { immediate: true })

const blockedFlag = computed<string>(() => (route.query.blocked as string) || '')
const blockedFlagLabel = computed(() =>
  blockedFlag.value ? blockedFlag.value.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()) : ''
)
const blockedFlagRequiredPlan = computed(() => {
  const { requiredPlan } = usePlanGating()
  const code = blockedFlag.value ? requiredPlan(blockedFlag.value) : 'pro'
  return code.charAt(0).toUpperCase() + code.slice(1)
})

const planChangeOpen = ref(false)
const planChange = reactive({ planId: '', planName: '', price: 0, mode: 'upgrade' as 'upgrade' | 'downgrade' })
const salesOpen = ref(false)
const sales = reactive({ planId: '', planName: '', companySize: '', note: '' })
const paymentOpen = ref(false)
const payment = reactive<any>({
  id: null, holder_name: '', brand: 'Visa', last4: '',
  exp_month: 1, exp_year: new Date().getFullYear() + 1,
})

function scrollToPlans() {
  plansRef.value?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

function onChoose(p: any) {
  if (!p || !billing.currentPlan.value || p.id === auth.workspace?.plan_id) return
  if (p.code === 'enterprise' || billing.currentPlan.value.code === 'enterprise' || p.contact_sales) {
    sales.planId = p.id
    sales.planName = p.name
    sales.companySize = ''
    sales.note = p.code === 'enterprise' ? 'Interested in moving to Enterprise.' : 'I need to change plans from Enterprise.'
    salesOpen.value = true
    return
  }
  planChange.planId = p.id
  planChange.planName = p.name
  planChange.price = p.price_monthly
  planChange.mode = billing.planRank(p) < billing.planRank(billing.currentPlan.value) ? 'downgrade' : 'upgrade'
  planChangeOpen.value = true
}

async function confirmPlanChange() {
  const { ok } = await billing.changePlan(planChange.planId, planChange.planName, planChange.mode)
  if (!ok) return
  planChangeOpen.value = false
  toast.success(
    `${planChange.mode === 'upgrade' ? 'Upgraded' : 'Downgraded'} to ${planChange.planName}`,
    'Your new limits are now in effect.'
  )
  if (!billing.defaultPaymentMethod.value && planChange.price > 0) openPayment()
}

async function onSubmitSales() {
  await billing.submitSalesRequest(sales)
  salesOpen.value = false
}

async function onCancel() {
  const ok = await confirm.ask({
    title: 'Cancel subscription?',
    message: 'Your workspace will move to the Free plan at the end of the current cycle. Quotas will drop immediately.',
    tone: 'danger', confirmText: 'Move to Free',
  })
  if (!ok) return
  const res = await billing.cancelSubscription()
  if (res.ok) toast.success('Subscription cancelled', 'You are now on the Free plan.')
}

function openPayment() {
  const existing = billing.defaultPaymentMethod.value
  if (existing) {
    Object.assign(payment, {
      id: existing.id,
      holder_name: existing.holder_name || '',
      brand: existing.brand || 'Visa',
      last4: existing.last4 || '',
      exp_month: existing.exp_month || 1,
      exp_year: existing.exp_year || new Date().getFullYear() + 1,
    })
  } else {
    Object.assign(payment, {
      id: null, holder_name: '', brand: 'Visa', last4: '',
      exp_month: 1, exp_year: new Date().getFullYear() + 1,
    })
  }
  paymentOpen.value = true
}

async function onSavePayment() {
  const { ok } = await billing.savePaymentMethod(payment)
  if (ok) { paymentOpen.value = false; toast.success('Payment method saved') }
}

const FEATURE_DISPLAY: { key: string; label: string }[] = [
  { key: 'journeys', label: 'Journeys' },
  { key: 'segments', label: 'Segments' },
  { key: 'campaigns', label: 'Campaigns' },
  { key: 'templates', label: 'Templates' },
  { key: 'ab_testing', label: 'A/B testing' },
  { key: 'sms', label: 'SMS channel' },
  { key: 'web_push', label: 'Web push' },
  { key: 'funnels', label: 'Funnels' },
  { key: 'cohorts', label: 'Cohorts' },
  { key: 'rfm', label: 'RFM analysis' },
  { key: 'predictive', label: 'Predictive AI' },
  { key: 'ai_studio', label: 'AI studio' },
  { key: 'custom_domain', label: 'Custom domain' },
  { key: 'dedicated_ip', label: 'Dedicated IP' },
  { key: 'commerce_integrations', label: 'Commerce integrations' },
  { key: 'webhooks', label: 'Webhooks' },
  { key: 'scheduled_reports', label: 'Scheduled reports' },
  { key: 'inbox_placement', label: 'Inbox placement tests' },
  { key: 'custom_roles', label: 'Custom roles' },
  { key: 'advanced_rbac', label: 'Advanced RBAC' },
  { key: 'sso', label: 'SSO' },
  { key: 'scim', label: 'SCIM provisioning' },
  { key: 'audit_export', label: 'Audit log export' },
  { key: 'priority_support', label: 'Priority support' },
  { key: 'sla', label: 'SLA' },
  { key: 'white_label', label: 'White-label' },
]

onMounted(() => {
  if (route.query.tab === 'plan' || route.query.upgrade || blockedFlag.value) {
    nextTick(() => scrollToPlans())
  }
})
</script>
