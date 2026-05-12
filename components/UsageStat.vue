<template>
  <div class="rounded-xl border border-ink-100 dark:border-[color:var(--border-subtle)] p-4 bg-white dark:bg-[color:var(--surface-card)]">
    <div class="flex items-center justify-between">
      <div class="text-[11px] uppercase tracking-wider text-ink-500">{{ label }}</div>
      <div class="text-[11px] font-medium tabular-nums" :class="pctClass">{{ cap > 0 ? pct + '%' : '—' }}</div>
    </div>
    <div class="text-2xl font-bold text-ink-900 dark:text-[color:var(--text-primary)] mt-1 tabular-nums">
      {{ used.toLocaleString() }}<span class="text-sm font-medium text-ink-500"> / {{ cap > 0 ? cap.toLocaleString() : '—' }}</span>
    </div>
    <div class="h-1.5 rounded-full bg-ink-100 dark:bg-[color:var(--surface-muted)] mt-3 overflow-hidden">
      <div class="h-full transition-all duration-500" :class="barClass" :style="{ width: pct + '%' }"></div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{ label: string; used: number; cap: number; colorClass?: string }>()

const pct = computed(() => (props.cap > 0 ? Math.min(100, Math.round((props.used / props.cap) * 100)) : 0))
const pctClass = computed(() => {
  if (pct.value >= 90) return 'text-red-600'
  if (pct.value >= 75) return 'text-amber-600'
  return 'text-ink-500'
})
const barClass = computed(() => {
  if (pct.value >= 90) return 'bg-red-500'
  if (pct.value >= 75) return 'bg-amber-500'
  return props.colorClass || 'bg-brand-500'
})
</script>
