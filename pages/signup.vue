<template>
  <div class="min-h-screen flex">
    <div class="flex-1 flex items-center justify-center p-8">
      <div class="w-full max-w-md">
        <NuxtLink to="/" class="flex items-center gap-2 mb-8">
          <img src="/pulse-app-icon.svg" alt="Pulse" class="w-9 h-9 rounded-lg"/>
          <span class="font-bold text-lg text-brand-900">Pulse</span>
        </NuxtLink>
        <h1 class="text-3xl font-bold text-ink-900">Create your workspace</h1>
        <p class="text-ink-500 mt-1">{{ planTagline }}</p>

        <form @submit.prevent="submit" class="mt-8 space-y-4">
          <div>
            <label class="label">Work email</label>
            <input v-model="email" type="email" required class="input" placeholder="you@company.com"/>
          </div>
          <div>
            <label class="label">Password</label>
            <input v-model="password" type="password" required minlength="6" class="input" placeholder="at least 6 characters"/>
          </div>

          <div>
            <div class="label mb-2">Choose a starting plan</div>
            <div class="grid grid-cols-2 gap-2">
              <button
                v-for="p in pickablePlans" :key="p.id" type="button"
                @click="selectedPlanId = p.id"
                class="text-left p-3 rounded-lg border-2 transition"
                :class="selectedPlanId === p.id ? 'border-brand-500 bg-brand-50/40' : 'border-ink-200 hover:border-ink-300'">
                <div class="flex items-center justify-between">
                  <div class="font-semibold text-ink-900 text-sm">{{ p.name }}</div>
                  <span v-if="p.highlight" class="chip bg-brand-100/60 text-brand-700 !text-[9px]">Popular</span>
                </div>
                <div class="text-xs text-ink-500 mt-0.5">
                  <template v-if="p.contact_sales">Custom pricing</template>
                  <template v-else-if="p.price_monthly === 0">Free forever</template>
                  <template v-else>${{ p.price_monthly }}/mo</template>
                </div>
                <div v-if="p.default_trial_days" class="text-[10px] text-brand-600 font-medium mt-0.5">
                  {{ p.default_trial_days }}-day trial
                </div>
              </button>
            </div>
          </div>

          <div v-if="error" class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-lg px-3 py-2">{{ error }}</div>
          <button type="submit" :disabled="loading" class="btn-primary w-full">{{ loading ? 'Creating…' : submitLabel }}</button>
        </form>

        <div class="mt-6 text-sm text-ink-500 text-center">
          Already have an account? <NuxtLink to="/login" class="text-brand-500 font-semibold">Sign in</NuxtLink>
        </div>
      </div>
    </div>
    <div class="hidden lg:flex flex-1 bg-brand-900 text-white p-16 flex-col justify-between relative overflow-hidden">
      <img src="https://images.pexels.com/photos/3183150/pexels-photo-3183150.jpeg?auto=compress&cs=tinysrgb&w=1600" class="absolute inset-0 w-full h-full object-cover opacity-20" alt=""/>
      <div class="absolute inset-0 bg-gradient-to-br from-brand-900/92 via-brand-900/80 to-brand-700/70"></div>
      <div class="relative z-10">
        <div class="text-xs font-semibold uppercase tracking-wider text-brand-100/70">What's included in {{ selectedPlan?.name || 'Pulse' }}</div>
        <ul class="mt-6 space-y-3 text-brand-100">
          <li v-for="item in planHighlights" :key="item" class="flex items-start gap-2">
            <Icon name="check" class="text-accent-500 mt-0.5"/>{{ item }}
          </li>
        </ul>
      </div>
      <div class="relative z-10">
        <div class="flex -space-x-3">
          <img src="https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?auto=compress&cs=tinysrgb&w=96" class="w-10 h-10 rounded-full border-2 border-brand-900 object-cover" alt=""/>
          <img src="https://images.pexels.com/photos/774909/pexels-photo-774909.jpeg?auto=compress&cs=tinysrgb&w=96" class="w-10 h-10 rounded-full border-2 border-brand-900 object-cover" alt=""/>
          <img src="https://images.pexels.com/photos/697509/pexels-photo-697509.jpeg?auto=compress&cs=tinysrgb&w=96" class="w-10 h-10 rounded-full border-2 border-brand-900 object-cover" alt=""/>
          <div class="w-10 h-10 rounded-full border-2 border-brand-900 bg-white/15 backdrop-blur flex items-center justify-center text-[10px] font-bold">+2k</div>
        </div>
        <div class="text-sm text-brand-100/80 mt-3">Joined by 2,000+ product teams this month.</div>
      </div>
      <div class="absolute -right-20 -bottom-20 w-[500px] h-[500px] rounded-full bg-brand-500/30 blur-3xl"></div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: false })
import { useAuthStore } from '~/stores/auth'
const { $supabase } = useNuxtApp()
const auth = useAuthStore()

const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')
const plans = ref<any[]>([])
const selectedPlanId = ref<string>('')

onMounted(async () => {
  const { data } = await $supabase.from('plans').select('*').eq('is_public', true).order('sort_order')
  plans.value = data || []
  const free = plans.value.find((p: any) => p.code === 'free') || plans.value[0]
  if (free) selectedPlanId.value = free.id
})

const pickablePlans = computed(() => plans.value.filter((p: any) => !p.contact_sales))
const selectedPlan = computed(() => plans.value.find((p: any) => p.id === selectedPlanId.value))

const planTagline = computed(() => {
  const p = selectedPlan.value
  if (!p) return 'Start free. Upgrade anytime.'
  if (p.default_trial_days > 0) return `Start a ${p.default_trial_days}-day ${p.name} trial. No credit card required.`
  if (p.price_monthly === 0) return 'Free forever. No credit card required.'
  return p.tagline || p.description || ''
})

const submitLabel = computed(() => {
  const p = selectedPlan.value
  if (!p) return 'Create account'
  if (p.default_trial_days > 0) return `Start ${p.default_trial_days}-day trial`
  return 'Create account'
})

const planHighlights = computed(() => {
  const p = selectedPlan.value
  if (!p) return ['Unlimited customers', 'Campaigns and journeys', 'SDKs for every platform']
  const base = [
    `${(p.email_monthly_quota || 0).toLocaleString()} emails per month`,
    `${p.seats} team seats included`,
    `${p.max_active_journeys} active journeys`,
  ]
  if (p.feature_flags?.ab_testing) base.push('A/B testing & experimentation')
  if (p.feature_flags?.predictive) base.push('Predictive AI & anomaly detection')
  if (p.feature_flags?.commerce_integrations) base.push('Shopify & WooCommerce integrations')
  if (p.feature_flags?.custom_domain) base.push('Custom sending domain')
  if (p.feature_flags?.priority_support) base.push('Priority support')
  if (p.feature_flags?.sso) base.push('SSO & SCIM provisioning')
  return base.slice(0, 6)
})

async function submit() {
  loading.value = true; error.value = ''
  const { data, error: err } = await $supabase.auth.signUp({ email: email.value, password: password.value })
  if (err) { loading.value = false; error.value = err.message; return }
  if (data.user) {
    auth.user = data.user
    try {
      await auth.loadWorkspaces({ preferredPlanId: selectedPlanId.value || undefined })
    } catch (e: any) {
      loading.value = false
      error.value = e?.message || 'Could not provision your workspace. Please retry.'
      return
    }
  }
  loading.value = false
  await navigateTo('/dashboard')
}
</script>
