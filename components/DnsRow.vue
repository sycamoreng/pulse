<template>
  <div class="flex items-start gap-3 text-xs">
    <span class="chip shrink-0 mt-0.5" :class="statusChip(status)">{{ label }} · {{ status }}</span>
    <div class="flex-1 grid grid-cols-[auto_auto_1fr] gap-2 items-center font-mono">
      <span class="text-ink-500">{{ type }}</span>
      <span class="text-ink-900">{{ host }}</span>
      <div class="flex items-center gap-2 min-w-0">
        <span class="truncate text-ink-500">{{ value }}</span>
        <button @click="copy" class="text-brand-500 hover:text-brand-700 shrink-0 text-[10px] font-semibold uppercase tracking-wider">
          {{ copied ? 'Copied' : 'Copy' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{ type: string; host: string; value: string; status: string; label: string }>()
const copied = ref(false)
function copy() {
  navigator.clipboard?.writeText(props.value)
  copied.value = true
  setTimeout(() => copied.value = false, 1200)
}
function statusChip(s: string) {
  return s === 'verified' ? 'bg-accent-500/10 text-accent-500' : s === 'failed' ? 'bg-red-100 text-red-600' : 'bg-yellow-100 text-yellow-700'
}
</script>
