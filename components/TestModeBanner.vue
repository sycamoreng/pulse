<template>
  <div v-if="isTest" class="relative overflow-hidden rounded-xl border border-amber-200 bg-gradient-to-r from-amber-50 via-amber-50 to-white">
    <div class="flex items-start gap-4 p-4 md:p-5">
      <div class="w-10 h-10 rounded-lg bg-amber-100 text-amber-700 flex items-center justify-center shrink-0">
        <Icon name="flask" class="w-5 h-5"/>
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2 flex-wrap">
          <div class="font-semibold text-amber-900">{{ displayName }} is in test mode</div>
          <span class="inline-flex items-center gap-1 text-[10px] font-semibold uppercase tracking-wider px-2 py-0.5 rounded-full bg-amber-500 text-white">
            <span class="w-1.5 h-1.5 rounded-full bg-white animate-pulse"></span>Sandbox
          </span>
        </div>
        <p class="text-sm text-amber-800/90 mt-1">
          {{ description || defaultDescription }}
        </p>
        <div class="mt-3 flex flex-wrap gap-2 text-[11px]">
          <span class="inline-flex items-center gap-1.5 bg-white/70 border border-amber-200 text-amber-900 px-2 py-1 rounded-full">
            <Icon name="x" class="w-3 h-3"/>No real messages sent
          </span>
          <span class="inline-flex items-center gap-1.5 bg-white/70 border border-amber-200 text-amber-900 px-2 py-1 rounded-full">
            <Icon name="x" class="w-3 h-3"/>No webhooks fired
          </span>
          <span class="inline-flex items-center gap-1.5 bg-white/70 border border-amber-200 text-amber-900 px-2 py-1 rounded-full">
            <Icon name="x" class="w-3 h-3"/>Quotas unaffected
          </span>
          <span class="inline-flex items-center gap-1.5 bg-white/70 border border-amber-200 text-amber-900 px-2 py-1 rounded-full">
            <Icon name="check" class="w-3 h-3"/>Data is demo only
          </span>
        </div>
      </div>
      <button type="button" @click="goProduction" class="btn-secondary text-xs whitespace-nowrap">
        <Icon name="arrowRight" class="w-3 h-3"/>Switch to production
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const props = defineProps<{ description?: string }>()
const isTest = computed(() => auth.workspace?.environment === 'test')
const displayName = computed(() => {
  const ws: any = auth.displayWorkspace
  return ws?.name || 'Your workspace'
})
const defaultDescription = computed(
  () => `Everything you see here is sandboxed demo data for ${displayName.value}. Explore freely — nothing you do in test mode reaches real customers, real inboxes, or production analytics.`
)
async function goProduction() {
  await (auth as any).switchEnvironment('production')
}
</script>
