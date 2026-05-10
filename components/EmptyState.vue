<template>
  <div class="flex flex-col items-center justify-center py-16 px-6 text-center">
    <div class="w-14 h-14 rounded-full bg-brand-100/40 text-brand-500 flex items-center justify-center mb-4">
      <Icon :name="icon"/>
    </div>
    <div class="font-semibold text-ink-900">{{ title }}</div>
    <div class="text-sm text-ink-500 mt-1 max-w-sm">{{ subtitle }}</div>
    <div class="mt-4"><slot/></div>
  </div>
</template>
<script setup lang="ts">
defineProps<{ icon: string; title: string; subtitle?: string }>()
</script>
