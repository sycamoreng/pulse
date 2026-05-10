<template>
  <div class="flex flex-col items-center justify-center py-16 px-6 text-center">
    <div class="relative mb-5">
      <div class="absolute inset-0 rounded-full blur-xl opacity-60" :class="accentBlur"></div>
      <div class="relative w-20 h-20 rounded-2xl flex items-center justify-center overflow-hidden" :class="tileClasses">
        <div class="absolute inset-0 opacity-[0.07] bg-[radial-gradient(circle_at_30%_20%,currentColor_0_2px,transparent_2px)] bg-[length:12px_12px]"></div>
        <Icon :name="icon" class="relative w-8 h-8"/>
      </div>
    </div>
    <div class="font-semibold text-ink-900 text-base">{{ title }}</div>
    <div class="text-sm text-ink-500 mt-1.5 max-w-sm leading-relaxed">{{ subtitle }}</div>
    <div class="mt-5"><slot/></div>
  </div>
</template>
<script setup lang="ts">
const props = defineProps<{ icon: string; title: string; subtitle?: string; tone?: 'brand' | 'accent' | 'warning' | 'neutral' }>()
const tone = computed(() => props.tone || 'brand')
const tileClasses = computed(() => ({
  brand: 'bg-gradient-to-br from-brand-100/60 to-brand-100/20 text-brand-500 ring-1 ring-brand-100',
  accent: 'bg-gradient-to-br from-accent-500/15 to-accent-500/5 text-accent-500 ring-1 ring-accent-500/20',
  warning: 'bg-gradient-to-br from-amber-500/20 to-amber-500/5 text-amber-600 ring-1 ring-amber-500/20',
  neutral: 'bg-gradient-to-br from-ink-100 to-ink-50 text-ink-500 ring-1 ring-ink-100',
}[tone.value]))
const accentBlur = computed(() => ({
  brand: 'bg-brand-500/30',
  accent: 'bg-accent-500/30',
  warning: 'bg-amber-500/30',
  neutral: 'bg-ink-200/50',
}[tone.value]))
</script>
