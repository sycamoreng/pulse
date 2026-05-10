const pending = ref(0)
const active = computed(() => pending.value > 0)

export function useNetwork() {
  const begin = () => { pending.value++ }
  const end = () => { pending.value = Math.max(0, pending.value - 1) }
  return { pending, active, begin, end }
}
