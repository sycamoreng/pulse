<template>
  <div class="min-h-screen bg-gradient-to-br from-ink-50 via-white to-brand-100/30 dark:from-[color:var(--surface-app)] dark:via-[color:var(--surface-app)] dark:to-[color:var(--surface-muted)]">
    <div class="max-w-4xl mx-auto px-6 py-10">
      <div v-if="loading" class="card p-16 text-center">
        <div class="w-10 h-10 rounded-full border-2 border-ink-200 border-t-brand-500 animate-spin mx-auto"></div>
        <div class="mt-4 text-sm text-ink-500">Loading shared dashboard…</div>
      </div>

      <div v-else-if="notFound" class="card p-16 text-center">
        <div class="w-14 h-14 rounded-full bg-red-100 text-red-600 flex items-center justify-center mx-auto">
          <Icon name="alert" class="w-6 h-6"/>
        </div>
        <div class="mt-4 text-lg font-semibold text-ink-900">This dashboard isn't available</div>
        <div class="mt-1 text-sm text-ink-500">The link may have expired or been revoked.</div>
      </div>

      <div v-else>
        <div class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-brand-700 via-brand-500 to-brand-900 text-white p-8 mb-6">
          <div class="absolute -right-16 -top-16 w-[280px] h-[280px] rounded-full bg-accent-500/30 blur-3xl"></div>
          <div class="relative">
            <div class="text-xs font-semibold uppercase tracking-[0.2em] text-white/70">{{ snap.label }}</div>
            <h1 class="mt-2 text-3xl font-bold tracking-tight">{{ snap.workspace?.name }}</h1>
            <p class="mt-1 text-sm text-white/80">Read-only snapshot · Generated {{ formatTime(snap.generated_at) }}</p>
          </div>
        </div>

        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <div v-for="s in statCards" :key="s.label" class="card p-5">
            <div class="flex items-center justify-between">
              <div class="text-xs font-semibold text-ink-500 uppercase tracking-wider">{{ s.label }}</div>
              <div class="w-8 h-8 rounded-lg flex items-center justify-center bg-brand-100/40 text-brand-500"><Icon :name="s.icon"/></div>
            </div>
            <div class="mt-3 text-3xl font-bold text-ink-900">{{ s.value.toLocaleString() }}</div>
          </div>
        </div>

        <div class="card p-6">
          <div class="font-semibold text-ink-900 mb-1">Events over time</div>
          <div class="text-xs text-ink-500 mb-4">Last 14 days</div>
          <div class="h-56 flex flex-col">
            <div class="flex-1 flex items-end gap-2">
              <div v-for="(v, i) in chartBuckets" :key="i" class="flex-1 h-full flex flex-col justify-end items-center group relative">
                <div class="absolute -top-8 opacity-0 group-hover:opacity-100 transition bg-ink-900 text-white text-[10px] px-2 py-1 rounded pointer-events-none whitespace-nowrap z-10">{{ v }} events</div>
                <div class="w-full rounded-t bg-gradient-to-t from-brand-500 to-brand-700" :style="{ height: `${Math.max(2, (v / maxBucket) * 100)}%` }"></div>
              </div>
            </div>
          </div>
        </div>

        <div class="mt-6 text-center text-xs text-ink-500">
          Powered by <span class="font-semibold text-ink-700">Pulse</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'blank' })

const route = useRoute()
const { $supabase } = useNuxtApp()

const loading = ref(true)
const notFound = ref(false)
const snap = ref<any>({})

const statCards = computed(() => {
  const s = snap.value?.stats || {}
  return [
    { label: 'Customers', value: s.customers || 0, icon: 'users' },
    { label: 'Events (30d)', value: s.events_30d || 0, icon: 'activity' },
    { label: 'Segments', value: s.segments || 0, icon: 'segment' },
    { label: 'Campaigns', value: s.campaigns || 0, icon: 'send' },
  ]
})

const chartBuckets = computed<number[]>(() => {
  const arr = Array(14).fill(0)
  const rows: any[] = Array.isArray(snap.value?.chart) ? snap.value.chart : []
  const today = new Date(); today.setHours(0, 0, 0, 0)
  for (const r of rows) {
    const d = new Date(r.d); d.setHours(0, 0, 0, 0)
    const diff = Math.floor((today.getTime() - d.getTime()) / (24 * 3600 * 1000))
    if (diff >= 0 && diff < 14) arr[13 - diff] = r.c
  }
  return arr
})
const maxBucket = computed(() => Math.max(1, ...chartBuckets.value))

function formatTime(iso: string) {
  if (!iso) return ''
  try { return new Date(iso).toLocaleString() } catch { return iso }
}

onMounted(async () => {
  const token = String(route.params.token || '')
  const { data, error } = await $supabase.rpc('dashboard_share_snapshot', { p_token: token })
  if (error || !data?.ok) { notFound.value = true; loading.value = false; return }
  snap.value = data
  loading.value = false
})
</script>
