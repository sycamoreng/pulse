import { useAuthStore } from '~/stores/auth'

const PLAN_ORDER: Record<string, number> = { free: 0, pro: 1, advanced: 2, enterprise: 3 }

export function useBilling() {
  const auth = useAuthStore()
  const { $supabase } = useNuxtApp()
  const toast = useToast()
  const notify = useNotify()
  const audit = useAudit()

  const plans = ref<any[]>([])
  const paymentMethods = ref<any[]>([])
  const invoices = ref<any[]>([])
  const loaded = ref(false)
  const busy = ref(false)

  const workspaceId = computed(() => auth.workspace?.id || null)

  const currentPlan = computed(() =>
    plans.value.find((p) => p.id === auth.workspace?.plan_id) || plans.value.find((p) => p.code === 'free') || null
  )
  const publicPlans = computed(() =>
    plans.value.filter((p) => p.is_public).sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
  )
  const defaultPaymentMethod = computed(
    () => paymentMethods.value.find((m) => m.is_default) || paymentMethods.value[0] || null
  )
  const emailCap = computed(() => auth.workspace?.email_quota_override ?? currentPlan.value?.email_monthly_quota ?? 0)
  const smsCap = computed(() => auth.workspace?.sms_quota_override ?? currentPlan.value?.sms_monthly_quota ?? 0)
  const pushCap = computed(() => currentPlan.value?.push_monthly_quota ?? 0)

  const trialDaysLeft = computed(() => {
    const ends = auth.workspace?.trial_ends_at
    if (!ends) return 0
    return Math.max(0, Math.ceil((new Date(ends).getTime() - Date.now()) / 86400000))
  })
  const trialBannerVisible = computed(
    () => auth.workspace?.subscription_status === 'trialing' && !!auth.workspace?.trial_ends_at
  )
  const subscriptionStatusLabel = computed(() => {
    const s = auth.workspace?.subscription_status
    if (!s || s === 'active') return ''
    if (s === 'trialing') return 'Trial'
    return s.charAt(0).toUpperCase() + s.slice(1).replace('_', ' ')
  })
  const statusChipClass = computed(() => {
    const s = auth.workspace?.subscription_status
    if (s === 'trialing') return 'bg-brand-100/60 text-brand-700'
    if (s === 'past_due') return 'bg-yellow-100 text-yellow-700'
    if (s === 'cancelled' || s === 'expired') return 'bg-red-100 text-red-700'
    return 'bg-ink-100 text-ink-700'
  })

  function planRank(p: any) { return p ? (PLAN_ORDER[p.code] ?? p.sort_order ?? 0) : -1 }
  function pct(n: number, cap: number) { return cap > 0 ? Math.min(100, Math.round((n / cap) * 100)) : 0 }
  function invoiceStatusClass(s: string) {
    if (s === 'paid') return 'bg-green-100 text-green-700'
    if (s === 'open' || s === 'pending') return 'bg-yellow-100 text-yellow-700'
    if (s === 'void' || s === 'uncollectible') return 'bg-red-100 text-red-700'
    return 'bg-ink-100 text-ink-700'
  }

  async function load() {
    if (!workspaceId.value) return
    const [pls, pm, inv] = await Promise.all([
      $supabase.from('plans').select('*').order('sort_order', { ascending: true }),
      $supabase.from('payment_methods').select('*').eq('workspace_id', workspaceId.value).order('is_default', { ascending: false }),
      $supabase.from('invoices').select('*').eq('workspace_id', workspaceId.value).order('issued_at', { ascending: false }).limit(12),
    ])
    plans.value = pls.data || []
    paymentMethods.value = pm.data || []
    invoices.value = inv.data || []
    loaded.value = true
  }

  async function changePlan(planId: string, planName: string, mode: 'upgrade' | 'downgrade') {
    if (!workspaceId.value || busy.value) return { ok: false }
    busy.value = true
    const { data, error } = await $supabase.rpc('change_workspace_plan', {
      p_workspace_id: workspaceId.value, p_plan_id: planId,
    })
    busy.value = false
    if (error) { toast.error('Could not change plan', error.message); return { ok: false } }
    audit.log('update', 'workspace_plan', workspaceId.value, planName, { mode })
    if (data) {
      auth.workspace = data
      auth.workspaces = auth.workspaces.map((w: any) => (w.id === data.id ? data : w))
    }
    await Promise.all([load(), useEntitlements().load(true)])
    return { ok: true }
  }

  async function cancelSubscription() {
    if (!workspaceId.value) return { ok: false }
    const { data, error } = await $supabase.rpc('cancel_workspace_subscription', { p_workspace_id: workspaceId.value })
    if (error) { toast.error('Could not cancel', error.message); return { ok: false } }
    if (data) {
      auth.workspace = data
      auth.workspaces = auth.workspaces.map((w: any) => (w.id === data.id ? data : w))
    }
    await load()
    return { ok: true }
  }

  async function savePaymentMethod(payment: any) {
    if (!workspaceId.value) return { ok: false }
    const row = {
      workspace_id: workspaceId.value,
      holder_name: payment.holder_name,
      brand: payment.brand,
      last4: payment.last4,
      exp_month: payment.exp_month,
      exp_year: payment.exp_year,
      is_default: true,
    }
    if (payment.id) {
      const { error } = await $supabase.from('payment_methods').update(row).eq('id', payment.id)
      if (error) { toast.error('Could not save card', error.message); return { ok: false } }
    } else {
      const { error } = await $supabase.from('payment_methods').insert(row)
      if (error) { toast.error('Could not save card', error.message); return { ok: false } }
    }
    await load()
    return { ok: true }
  }

  async function removePaymentMethod(id: string) {
    const ok = await useConfirm().ask({ title: 'Remove this card?', tone: 'danger', confirmText: 'Remove' })
    if (!ok) return
    const { error } = await $supabase.from('payment_methods').delete().eq('id', id)
    if (error) { toast.error('Could not remove card', error.message); return }
    toast.success('Card removed')
    await load()
  }

  async function submitSalesRequest(sales: { planId: string; note: string; companySize: string }) {
    const target = plans.value.find((p) => p.id === sales.planId)
    audit.log('create', 'plan_request', workspaceId.value!, target?.name || '', {
      note: sales.note, company_size: sales.companySize,
    })
    await notify.notify({
      workspace_id: workspaceId.value!,
      to_email: auth.user?.email || '',
      to_user_id: auth.user?.id || null,
      kind: 'plan_request',
      title: `Plan request: ${target?.name}`,
      body: `Our sales team will reach out about ${target?.name}. Notes: ${sales.note || '—'}`,
      link: `${typeof window !== 'undefined' ? window.location.origin : ''}/billing`,
      send_email: false,
    })
    toast.success('Request sent', 'Our sales team will reach out shortly.')
  }

  watch(workspaceId, () => { if (workspaceId.value) void load() }, { immediate: true })

  return {
    plans, publicPlans, currentPlan, paymentMethods, invoices, defaultPaymentMethod,
    emailCap, smsCap, pushCap, loaded, busy,
    trialDaysLeft, trialBannerVisible, subscriptionStatusLabel, statusChipClass,
    planRank, pct, invoiceStatusClass,
    load, changePlan, cancelSubscription, savePaymentMethod, removePaymentMethod, submitSalesRequest,
  }
}
