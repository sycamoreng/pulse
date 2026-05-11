<template>
  <div v-if="total > pageSize" class="flex flex-wrap items-center justify-between gap-3 px-4 py-3 border-t border-ink-100 dark:border-[color:var(--border-subtle)]">
    <div class="text-xs text-ink-500 dark:text-[color:var(--text-tertiary)]">
      <span class="font-medium text-ink-900 dark:text-[color:var(--text-primary)]">{{ rangeStart }}</span>
      to
      <span class="font-medium text-ink-900 dark:text-[color:var(--text-primary)]">{{ rangeEnd }}</span>
      of
      <span class="font-medium text-ink-900 dark:text-[color:var(--text-primary)]">{{ total.toLocaleString() }}</span>
    </div>
    <div class="flex items-center gap-2">
      <label class="text-xs text-ink-500 dark:text-[color:var(--text-tertiary)] hidden sm:block">Per page</label>
      <select :value="pageSize" @change="$emit('update:pageSize', Number(($event.target as HTMLSelectElement).value))" class="input !py-1.5 !text-xs w-auto">
        <option v-for="s in sizeOptions" :key="s" :value="s">{{ s }}</option>
      </select>
      <div class="flex items-center gap-1">
        <button type="button" @click="go(1)" :disabled="page === 1" class="btn-ghost !py-1.5 !px-2 !text-xs" aria-label="First page">
          <Icon name="chevronLeft" class="w-3 h-3"/><Icon name="chevronLeft" class="w-3 h-3 -ml-2"/>
        </button>
        <button type="button" @click="go(page - 1)" :disabled="page === 1" class="btn-ghost !py-1.5 !px-2 !text-xs" aria-label="Previous page">
          <Icon name="chevronLeft" class="w-3 h-3"/>
        </button>
        <span class="text-xs text-ink-700 dark:text-[color:var(--text-secondary)] px-2 whitespace-nowrap">Page {{ page }} of {{ totalPages }}</span>
        <button type="button" @click="go(page + 1)" :disabled="page >= totalPages" class="btn-ghost !py-1.5 !px-2 !text-xs" aria-label="Next page">
          <Icon name="chevronRight" class="w-3 h-3"/>
        </button>
        <button type="button" @click="go(totalPages)" :disabled="page >= totalPages" class="btn-ghost !py-1.5 !px-2 !text-xs" aria-label="Last page">
          <Icon name="chevronRight" class="w-3 h-3"/><Icon name="chevronRight" class="w-3 h-3 -ml-2"/>
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = withDefaults(defineProps<{
  page: number
  pageSize: number
  total: number
  sizeOptions?: number[]
}>(), {
  sizeOptions: () => [25, 50, 100, 200],
})
const emit = defineEmits<{
  (e: 'update:page', value: number): void
  (e: 'update:pageSize', value: number): void
}>()

const totalPages = computed(() => Math.max(1, Math.ceil(props.total / props.pageSize)))
const rangeStart = computed(() => props.total === 0 ? 0 : (props.page - 1) * props.pageSize + 1)
const rangeEnd = computed(() => Math.min(props.total, props.page * props.pageSize))

function go(n: number) {
  const next = Math.max(1, Math.min(totalPages.value, n))
  if (next !== props.page) emit('update:page', next)
}
</script>
