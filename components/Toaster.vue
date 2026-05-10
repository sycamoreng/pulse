<template>
  <Teleport to="body">
    <div class="fixed top-4 right-4 z-[100] flex flex-col gap-2 max-w-sm w-full pointer-events-none">
      <TransitionGroup name="toast" tag="div" class="flex flex-col gap-2">
        <div v-for="t in toasts" :key="t.id"
          class="pointer-events-auto bg-white rounded-xl shadow-xl border border-ink-100 overflow-hidden flex items-start gap-3 p-4"
          :class="borderClass(t.kind)">
          <div class="w-8 h-8 rounded-lg flex items-center justify-center shrink-0" :class="iconBg(t.kind)">
            <Icon :name="iconName(t.kind)" class="w-4 h-4"/>
          </div>
          <div class="flex-1 min-w-0">
            <div class="text-sm font-semibold text-ink-900 leading-tight">{{ t.title }}</div>
            <div v-if="t.description" class="text-xs text-ink-500 mt-1 leading-relaxed">{{ t.description }}</div>
          </div>
          <button @click="dismiss(t.id)" class="text-ink-300 hover:text-ink-900 shrink-0 p-0.5"><Icon name="x" class="w-4 h-4"/></button>
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
const { toasts, dismiss } = useToast()
const iconName = (k: string) => ({ success: 'check', error: 'x', info: 'activity', warning: 'activity' } as any)[k]
const iconBg = (k: string) => ({
  success: 'bg-accent-500/15 text-accent-500',
  error: 'bg-red-100 text-red-600',
  info: 'bg-brand-100/40 text-brand-500',
  warning: 'bg-yellow-100 text-yellow-700',
} as any)[k]
const borderClass = (k: string) => ({
  success: 'border-l-4 border-l-accent-500',
  error: 'border-l-4 border-l-red-500',
  info: 'border-l-4 border-l-brand-500',
  warning: 'border-l-4 border-l-yellow-500',
} as any)[k]
</script>

<style scoped>
.toast-enter-active, .toast-leave-active { transition: all 0.32s cubic-bezier(.22,1,.36,1); }
.toast-enter-from { opacity: 0; transform: translateX(24px) scale(.98); }
.toast-leave-to { opacity: 0; transform: translateX(24px) scale(.98); }
.toast-move { transition: transform 0.3s ease; }
</style>
