<template>
  <span v-if="isTest" class="inline-flex items-center gap-1.5 text-[10px] font-semibold uppercase tracking-wider px-2 py-0.5 rounded-full bg-amber-100 text-amber-900 border border-amber-200" :title="tooltip">
    <span class="w-1.5 h-1.5 rounded-full bg-amber-500"></span>
    <span>{{ label || 'Test mode' }}</span>
    <span v-if="detail" class="font-normal text-amber-800/80 normal-case tracking-normal">· {{ detail }}</span>
  </span>
</template>

<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const props = defineProps<{ label?: string; detail?: string; tooltip?: string }>()
const isTest = computed(() => auth.workspace?.environment === 'test')
</script>
