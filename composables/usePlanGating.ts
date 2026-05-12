export const PLAN_ORDER = ['free', 'pro', 'advanced', 'enterprise'] as const
export type PlanCode = typeof PLAN_ORDER[number]

export const PLAN_LABELS: Record<PlanCode, string> = {
  free: 'Free',
  pro: 'Pro',
  advanced: 'Advanced',
  enterprise: 'Enterprise',
}

// Minimum plan required for a feature flag.
export const FEATURE_MIN_PLAN: Record<string, PlanCode> = {
  rfm: 'pro',
  cohorts: 'pro',
  funnels: 'pro',
  ai_studio: 'pro',
  ab_testing: 'pro',
  custom_roles: 'pro',
  custom_domain: 'pro',
  inbox_placement: 'pro',
  scheduled_reports: 'pro',
  advanced_analytics: 'pro',
  commerce_integrations: 'pro',
  webhooks: 'pro',
  sms: 'pro',
  predictive: 'advanced',
  audit_export: 'advanced',
  dedicated_ip: 'advanced',
  advanced_rbac: 'advanced',
  priority_support: 'advanced',
  sso: 'enterprise',
  scim: 'enterprise',
  white_label: 'enterprise',
  sla: 'enterprise',
}

// Route -> feature flag that must be true to access.
export const ROUTE_FEATURE: Record<string, string> = {
  '/rfm': 'rfm',
  '/cohorts': 'cohorts',
  '/funnels': 'funnels',
  '/intelligence': 'predictive',
  '/integrations': 'commerce_integrations',
  '/products': 'commerce_integrations',
  '/imports': 'commerce_integrations',
  '/trust': 'audit_export',
}

export function usePlanGating() {
  const { features, plan } = useEntitlements()

  function requiredPlan(flag: string): PlanCode {
    return FEATURE_MIN_PLAN[flag] || 'pro'
  }

  function isOnOrAbove(target: PlanCode): boolean {
    const current = (plan.value?.code as PlanCode) || 'free'
    return PLAN_ORDER.indexOf(current) >= PLAN_ORDER.indexOf(target)
  }

  function hasFeature(flag: string): boolean {
    return features.value?.[flag] === true
  }

  function requiredPlanForRoute(path: string): { flag: string; plan: PlanCode } | null {
    const flag = ROUTE_FEATURE[path]
    if (!flag) return null
    if (hasFeature(flag)) return null
    return { flag, plan: requiredPlan(flag) }
  }

  return { hasFeature, requiredPlan, isOnOrAbove, requiredPlanForRoute }
}
