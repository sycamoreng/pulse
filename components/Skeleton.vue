<template>
  <div class="shimmer" :class="rounded" :style="{ width, height }"></div>
</template>

<script setup lang="ts">
const props = defineProps<{ width?: string; height?: string; rounded?: string }>()
const width = props.width || '100%'
const height = props.height || '1rem'
const rounded = props.rounded || 'rounded-md'
</script>

<style scoped>
.shimmer {
  background: linear-gradient(90deg, #E6ECF0 0%, #F1F5F7 40%, #E6ECF0 80%);
  background-size: 200% 100%;
  animation: shimmer 1.4s infinite ease-in-out;
  display: block;
}
:global(.dark) .shimmer {
  background: linear-gradient(90deg, rgba(255,255,255,0.04) 0%, rgba(255,255,255,0.10) 40%, rgba(255,255,255,0.04) 80%);
  background-size: 200% 100%;
}
@keyframes shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
</style>
