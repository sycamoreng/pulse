<template>
  <Teleport to="body">
    <Transition name="confirm">
      <div v-if="state.open" class="fixed inset-0 z-[90] flex items-center justify-center p-4" @click.self="cancel">
        <div class="absolute inset-0 bg-ink-900/50 backdrop-blur-sm"></div>
        <div class="relative bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden confirm-card">
          <div class="p-6 flex items-start gap-4">
            <div class="w-11 h-11 rounded-xl flex items-center justify-center shrink-0"
              :class="state.tone === 'danger' ? 'bg-red-100 text-red-600' : 'bg-brand-100/40 text-brand-500'">
              <Icon :name="state.tone === 'danger' ? 'trash' : 'activity'" class="w-5 h-5"/>
            </div>
            <div class="flex-1">
              <div class="text-lg font-bold text-ink-900">{{ state.title }}</div>
              <div v-if="state.message" class="text-sm text-ink-500 mt-1 leading-relaxed">{{ state.message }}</div>
            </div>
          </div>
          <div class="px-6 py-4 bg-ink-50 border-t border-ink-100 flex justify-end gap-2">
            <button @click="cancel" class="btn-secondary">{{ state.cancelText || 'Cancel' }}</button>
            <button @click="confirm" :class="state.tone === 'danger' ? 'btn-danger' : 'btn-primary'">
              {{ state.confirmText || 'Confirm' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
const { state, resolve } = useConfirm()
const confirm = () => resolve(true)
const cancel = () => resolve(false)
</script>

<style scoped>
.confirm-enter-active, .confirm-leave-active { transition: opacity .22s ease; }
.confirm-enter-from, .confirm-leave-to { opacity: 0; }
.confirm-enter-active .confirm-card, .confirm-leave-active .confirm-card { transition: transform .28s cubic-bezier(.22,1,.36,1), opacity .2s ease; }
.confirm-enter-from .confirm-card { transform: translateY(14px) scale(.96); opacity: 0; }
.confirm-leave-to .confirm-card { transform: translateY(8px) scale(.97); opacity: 0; }
</style>
