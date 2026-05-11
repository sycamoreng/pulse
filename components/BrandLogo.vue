<template>
  <div
    v-if="!logoUrl || failed"
    :class="['shrink-0 rounded-lg flex items-center justify-center text-white font-bold select-none', sizeClasses]"
    :style="{ background: background }"
  >{{ initial }}</div>
  <img
    v-else
    :src="logoUrl"
    :alt="name || 'Brand logo'"
    :class="['shrink-0 rounded-lg object-cover bg-white', sizeClasses]"
    @error="failed = true"
  />
</template>

<script setup lang="ts">
const props = withDefaults(defineProps<{
  workspace?: any
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl'
  name?: string
  logoUrl?: string | null
  color?: string | null
}>(), { size: 'md' })

const failed = ref(false)
watch(() => [props.workspace?.logo_url, props.logoUrl], () => { failed.value = false })

const resolvedName = computed(() => props.name || props.workspace?.name || 'P')
const initial = computed(() => (resolvedName.value || 'P')[0].toUpperCase())
const logoUrl = computed(() => props.logoUrl ?? props.workspace?.logo_url ?? '')
const background = computed(() => props.color || props.workspace?.brand_primary || '#3087B9')

const sizeClasses = computed(() => ({
  xs: 'w-6 h-6 text-[10px]',
  sm: 'w-8 h-8 text-xs',
  md: 'w-9 h-9 text-sm',
  lg: 'w-12 h-12 text-base',
  xl: 'w-16 h-16 text-xl',
}[props.size]))
</script>
