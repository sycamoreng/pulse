<template>
  <div>
    <PageHeader title="Platform overview" subtitle="High-level view of every tenant on Pulse."/>
    <div class="p-8 space-y-6">
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <div class="card p-5">
          <div class="text-xs uppercase tracking-wider text-ink-500">Workspaces</div>
          <div class="text-3xl font-bold text-ink-900 mt-1">{{ stats.workspaces }}</div>
        </div>
        <div class="card p-5">
          <div class="text-xs uppercase tracking-wider text-ink-500">Active emails (30d)</div>
          <div class="text-3xl font-bold text-ink-900 mt-1">{{ stats.sent.toLocaleString() }}</div>
        </div>
        <div class="card p-5">
          <div class="text-xs uppercase tracking-wider text-ink-500">Bounces (30d)</div>
          <div class="text-3xl font-bold text-red-600 mt-1">{{ stats.bounces.toLocaleString() }}</div>
        </div>
        <div class="card p-5">
          <div class="text-xs uppercase tracking-wider text-ink-500">Suppressions</div>
          <div class="text-3xl font-bold text-ink-900 mt-1">{{ stats.suppressions.toLocaleString() }}</div>
        </div>
      </div>

      <div class="card p-6">
        <div class="font-semibold text-ink-900 mb-4">Plan distribution</div>
        <div class="space-y-2">
          <div v-for="p in planBreakdown" :key="p.code" class="flex items-center gap-3 text-sm">
            <div class="w-28 text-ink-700 font-medium">{{ p.name }}</div>
            <div class="flex-1 h-2 bg-ink-100 rounded overflow-hidden"><div class="h-full bg-brand-500" :style="{ width: (p.count / Math.max(1, stats.workspaces) * 100) + '%' }"></div></div>
            <div class="w-12 text-right text-ink-500">{{ p.count }}</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })
const { $supabase } = useNuxtApp()
const stats = ref({ workspaces: 0, sent: 0, bounces: 0, suppressions: 0 })
const planBreakdown = ref<any[]>([])
onMounted(async () => {
  const since = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString()
  const [ws, sent, bounces, supp, plans] = await Promise.all([
    $supabase.from('workspaces').select('id, plan_id', { count: 'exact', head: false }),
    $supabase.from('transactional_sends').select('id', { count: 'exact', head: true }).eq('status', 'sent').gte('created_at', since),
    $supabase.from('email_suppressions').select('id', { count: 'exact', head: true }).eq('reason', 'hard_bounce').gte('created_at', since),
    $supabase.from('email_suppressions').select('id', { count: 'exact', head: true }),
    $supabase.from('plans').select('*').order('sort_order'),
  ])
  const workspaces = ws.data || []
  stats.value = {
    workspaces: workspaces.length,
    sent: sent.count || 0,
    bounces: bounces.count || 0,
    suppressions: supp.count || 0,
  }
  planBreakdown.value = (plans.data || []).map((p: any) => ({
    code: p.code, name: p.name,
    count: workspaces.filter((w: any) => w.plan_id === p.id).length,
  }))
})
</script>
