<template>
  <div class="fixed top-0 left-0 right-0 z-[100] pointer-events-none h-[2px] overflow-hidden">
    <Transition name="net-fade">
      <div v-if="visible" class="h-full w-full relative">
        <div class="absolute inset-0 bg-brand-500/15"></div>
        <div class="net-bar absolute inset-y-0 w-1/3 bg-gradient-to-r from-transparent via-brand-500 to-transparent shadow-[0_0_12px_rgba(48,135,185,0.6)]"></div>
      </div>
    </Transition>
  </div>
</template>

<script setup lang="ts">
const network = useNetwork()
const visible = ref(false)
let hideTimer: any = null
let showTimer: any = null

watch(() => network.active.value, (v) => {
  if (v) {
    if (hideTimer) { clearTimeout(hideTimer); hideTimer = null }
    if (!visible.value && !showTimer) {
      showTimer = setTimeout(() => { visible.value = true; showTimer = null }, 120)
    }
  } else {
    if (showTimer) { clearTimeout(showTimer); showTimer = null }
    if (visible.value && !hideTimer) {
      hideTimer = setTimeout(() => { visible.value = false; hideTimer = null }, 260)
    }
  }
})

onBeforeUnmount(() => {
  if (hideTimer) clearTimeout(hideTimer)
  if (showTimer) clearTimeout(showTimer)
})
</script>

<style scoped>
.net-bar { animation: net-slide 1.1s linear infinite; }
@keyframes net-slide {
  0%   { transform: translateX(-50%); }
  100% { transform: translateX(300%); }
}
.net-fade-enter-active, .net-fade-leave-active { transition: opacity 160ms ease; }
.net-fade-enter-from, .net-fade-leave-to { opacity: 0; }
</style>
