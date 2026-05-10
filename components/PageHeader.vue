<template>
  <header class="px-8 py-6 border-b border-ink-100 bg-white">
    <div class="flex items-start justify-between gap-6 flex-wrap">
      <div>
        <div v-if="breadcrumb" class="text-xs text-ink-500 font-medium mb-1">{{ breadcrumb }}</div>
        <h1 class="text-2xl font-bold text-ink-900 tracking-tight">{{ title }}</h1>
        <p v-if="subtitle" class="text-sm text-ink-500 mt-1 max-w-2xl">{{ subtitle }}</p>
      </div>
      <div class="flex items-center gap-2">
        <slot name="actions"/>
      </div>
    </div>
  </header>
</template>
<script setup lang="ts">
defineProps<{ title: string; subtitle?: string; breadcrumb?: string }>()
</script>
