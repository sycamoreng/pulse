<template>
  <span
    v-if="show"
    role="button"
    tabindex="0"
    :title="`Requires ${label} plan — click to upgrade`"
    class="inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide align-middle transition-colors cursor-pointer select-none"
    :class="pillClass"
    @click.stop.prevent="goUpgrade"
    @keydown.enter.stop.prevent="goUpgrade"
    @keydown.space.stop.prevent="goUpgrade"
  >
    {{ label }}
  </span>
</template>

<script setup lang="ts">
import { PLAN_LABELS, type PlanCode } from '~/composables/usePlanGating'

const props = defineProps<{ flag?: string; plan?: PlanCode }>()

const { hasFeature, requiredPlan } = usePlanGating()

const resolvedPlan = computed<PlanCode>(() => props.plan || (props.flag ? requiredPlan(props.flag) : 'pro'))
const show = computed(() => (props.flag ? !hasFeature(props.flag) : true))
const label = computed(() => PLAN_LABELS[resolvedPlan.value])

function goUpgrade() {
  const qs = new URLSearchParams({ upgrade: resolvedPlan.value })
  if (props.flag) qs.set('blocked', props.flag)
  return navigateTo(`/billing?${qs.toString()}`)
}

const pillClass = computed(() => {
  switch (resolvedPlan.value) {
    case 'pro': return 'bg-brand-50 text-brand-700 hover:bg-brand-100 dark:bg-brand-900/30 dark:text-brand-300'
    case 'advanced': return 'bg-amber-50 text-amber-700 hover:bg-amber-100 dark:bg-amber-900/30 dark:text-amber-300'
    case 'enterprise': return 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100 dark:bg-emerald-900/30 dark:text-emerald-300'
    default: return 'bg-ink-100 text-ink-700 hover:bg-ink-200 dark:bg-ink-800 dark:text-ink-200'
  }
})
</script>
