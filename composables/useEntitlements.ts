type Limits = {
  email_monthly_quota: number
  sms_monthly_quota: number
  push_monthly_quota: number
  seats: number
  max_active_journeys: number
  max_active_campaigns: number
  max_segments: number
  max_events_per_month: number
  max_workspaces: number
  data_retention_days: number
  support_sla_hours: number
  included_domains: number
}

const defaultLimits: Limits = {
  email_monthly_quota: 0, sms_monthly_quota: 0, push_monthly_quota: 0,
  seats: 1, max_active_journeys: 1, max_active_campaigns: 3, max_segments: 5,
  max_events_per_month: 10000, max_workspaces: 1, data_retention_days: 30,
  support_sla_hours: 72, included_domains: 1,
}

const features = ref<Record<string, boolean>>({})
const limits = ref<Limits>({ ...defaultLimits })
const plan = ref<any | null>(null)
const loaded = ref(false)
let lastWorkspaceId: string | null = null

export function useEntitlements() {
  const auth = useAuthStore()
  const { $supabase } = useNuxtApp()

  async function load(force = false) {
    const wsId = auth.workspace?.id
    if (!wsId) { features.value = {}; limits.value = { ...defaultLimits }; plan.value = null; loaded.value = false; return }
    if (!force && loaded.value && wsId === lastWorkspaceId) return
    lastWorkspaceId = wsId

    const [flagsRes, limitsRes, planRes] = await Promise.all([
      $supabase.rpc('workspace_entitlements', { p_workspace_id: wsId }),
      $supabase.rpc('workspace_effective_limits', { p_workspace_id: wsId }),
      auth.workspace?.plan_id
        ? $supabase.from('plans').select('*').eq('id', auth.workspace.plan_id).maybeSingle()
        : Promise.resolve({ data: null } as any),
    ])
    features.value = (flagsRes.data as any) || {}
    limits.value = { ...defaultLimits, ...((limitsRes.data as any) || {}) }
    plan.value = planRes.data || null
    loaded.value = true
  }

  function can(flag: string): boolean {
    return features.value[flag] === true
  }

  const trial = computed(() => {
    const ws = auth.workspace
    if (!ws) return { active: false, days_left: 0, ends_at: null as string | null }
    const status = ws.subscription_status
    const ends = ws.trial_ends_at ? new Date(ws.trial_ends_at) : null
    const daysLeft = ends ? Math.max(0, Math.ceil((ends.getTime() - Date.now()) / 86400000)) : 0
    return { active: status === 'trialing' && daysLeft > 0, days_left: daysLeft, ends_at: ws.trial_ends_at || null }
  })

  const subscriptionStatus = computed(() => auth.workspace?.subscription_status || 'active')

  watch(() => auth.workspace?.id, () => { loaded.value = false; void load() })

  return { features, limits, plan, trial, subscriptionStatus, load, can, loaded }
}
