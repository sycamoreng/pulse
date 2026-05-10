<template>
  <Teleport to="body">
    <Transition name="modal">
      <div v-if="modelValue" class="fixed inset-0 z-50 flex items-center justify-center p-4" @click.self="$emit('update:modelValue', false)">
        <div class="absolute inset-0 bg-ink-900/50 backdrop-blur-sm modal-backdrop"></div>
        <div class="relative bg-white rounded-2xl shadow-2xl w-full modal-card" :class="sizeClass">
          <div class="flex items-center justify-between px-6 py-4 border-b border-ink-100">
            <div>
              <div class="font-bold text-ink-900">{{ title }}</div>
              <div v-if="subtitle" class="text-xs text-ink-500 mt-0.5">{{ subtitle }}</div>
            </div>
            <button @click="$emit('update:modelValue', false)" class="text-ink-500 hover:text-ink-900 p-1.5 rounded-lg hover:bg-ink-50 transition"><Icon name="x"/></button>
          </div>
          <div class="px-6 py-5 max-h-[70vh] overflow-y-auto"><slot/></div>
          <div v-if="$slots.footer" class="px-6 py-4 bg-ink-50 border-t border-ink-100 rounded-b-2xl flex justify-end gap-2">
            <slot name="footer"/>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
const props = defineProps<{ modelValue: boolean; title: string; subtitle?: string; size?: 'sm'|'md'|'lg'|'xl' }>()
defineEmits<{ (e: 'update:modelValue', v: boolean): void }>()
const sizeClass = computed(() => ({ sm: 'max-w-sm', md: 'max-w-lg', lg: 'max-w-2xl', xl: 'max-w-4xl' }[props.size || 'md']))
</script>

<style scoped>
.modal-enter-active, .modal-leave-active { transition: opacity .22s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.modal-enter-active .modal-backdrop, .modal-leave-active .modal-backdrop { transition: opacity .22s ease; }
.modal-enter-from .modal-backdrop, .modal-leave-to .modal-backdrop { opacity: 0; }
.modal-enter-active .modal-card, .modal-leave-active .modal-card { transition: transform .3s cubic-bezier(.22,1,.36,1), opacity .22s ease; }
.modal-enter-from .modal-card { transform: translateY(18px) scale(.97); opacity: 0; }
.modal-leave-to .modal-card { transform: translateY(10px) scale(.98); opacity: 0; }
</style>
