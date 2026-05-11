<template>
  <div v-if="isTest" class="flex items-start gap-3 rounded-lg border border-amber-200 bg-amber-50/70 px-4 py-3">
    <div class="w-7 h-7 rounded-md bg-amber-100 text-amber-700 flex items-center justify-center shrink-0">
      <Icon name="flask" class="w-4 h-4"/>
    </div>
    <div class="flex-1 min-w-0 text-[13px] text-amber-900">
      <div class="font-semibold">Test mode — demo data only</div>
      <div class="text-amber-800/90 mt-0.5">{{ message || defaultMessage }}</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const props = defineProps<{ what?: string; message?: string }>()
const isTest = computed(() => auth.workspace?.environment === 'test')
const defaultMessage = computed(() =>
  props.what
    ? `${props.what} in test mode stay sandboxed — no real customers are reached, no webhooks fire, and production quotas are not consumed.`
    : 'Everything on this page is sandboxed. Nothing you change here affects production data or reaches real customers.'
)
</script>
