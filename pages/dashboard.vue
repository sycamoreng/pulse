<template>
  <div>
    <PageHeader title="Dashboard" subtitle="Your engagement at a glance." :breadcrumb="displayWs?.name"/>

    <div class="p-8 space-y-6">
      <TestModeBanner v-if="isTest"/>
      <div v-else class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-brand-700 via-brand-500 to-brand-900 text-white">
        <img src="https://images.pexels.com/photos/3184465/pexels-photo-3184465.jpeg?auto=compress&cs=tinysrgb&w=1600" class="absolute inset-0 w-full h-full object-cover opacity-20" alt=""/>
        <div class="absolute -right-20 -top-20 w-[320px] h-[320px] rounded-full bg-accent-500/30 blur-3xl"></div>
        <div class="relative px-6 py-6 md:px-8 md:py-8 flex items-center gap-6 flex-wrap">
          <div class="flex-1 min-w-[260px]">
            <div class="text-xs font-semibold uppercase tracking-[0.2em] text-white/70">{{ greeting }}</div>
            <h2 class="mt-2 text-2xl md:text-3xl font-bold tracking-tight">{{ displayWs?.name || 'Your workspace' }} is live.</h2>
            <p class="mt-1 text-sm text-white/80 max-w-xl">Here's how your engagement is tracking today. Dig in, ship a campaign, or shape a journey.</p>
            <div class="mt-4 flex items-center gap-2 flex-wrap">
              <NuxtLink to="/campaigns" style="background-color:#ffffff;color:#0A445C" class="inline-flex items-center gap-2 font-semibold text-sm px-4 py-2 rounded-lg hover:opacity-90 transition-opacity shadow-sm"><Icon name="send" class="w-4 h-4"/>New campaign</NuxtLink>
              <NuxtLink to="/journeys" class="inline-flex items-center gap-2 bg-white/10 backdrop-blur border border-white/20 text-white font-semibold text-sm px-4 py-2 rounded-lg hover:bg-white/20 transition-colors"><Icon name="route" class="w-4 h-4"/>Build journey</NuxtLink>
            </div>
          </div>
          <div class="hidden md:flex items-center gap-3 rounded-xl bg-white/10 backdrop-blur border border-white/15 px-5 py-4">
            <div class="flex -space-x-3">
              <img src="https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?auto=compress&cs=tinysrgb&w=96" class="w-9 h-9 rounded-full border-2 border-brand-700 object-cover" alt=""/>
              <img src="https://images.pexels.com/photos/774909/pexels-photo-774909.jpeg?auto=compress&cs=tinysrgb&w=96" class="w-9 h-9 rounded-full border-2 border-brand-700 object-cover" alt=""/>
              <img src="https://images.pexels.com/photos/697509/pexels-photo-697509.jpeg?auto=compress&cs=tinysrgb&w=96" class="w-9 h-9 rounded-full border-2 border-brand-700 object-cover" alt=""/>
            </div>
            <div>
              <div class="text-xs text-white/70">Active now</div>
              <div class="font-semibold">{{ liveUsers }} users online</div>
            </div>
          </div>
        </div>
      </div>

      <ChannelReadiness :channels="['email','push']" :show-warnings="false"/>

      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div v-for="s in stats" :key="s.label" class="card p-5">
          <div class="flex items-center justify-between">
            <div class="text-xs font-semibold text-ink-500 uppercase tracking-wider">{{ s.label }}</div>
            <div class="w-8 h-8 rounded-lg flex items-center justify-center" :class="s.bg"><Icon :name="s.icon"/></div>
          </div>
          <div v-if="loading" class="mt-3"><Skeleton height="2rem" width="60%"/></div>
          <div v-else class="mt-3 text-3xl font-bold text-ink-900">{{ s.value.toLocaleString() }}</div>
          <div class="mt-1 text-xs text-ink-500">{{ s.hint }}</div>
        </div>
      </div>

      <div class="grid lg:grid-cols-3 gap-6">
        <div class="card p-6 lg:col-span-2">
          <div class="flex items-center justify-between mb-4">
            <div>
              <div class="font-semibold text-ink-900">Events over time</div>
              <div class="text-xs text-ink-500">Last 14 days</div>
            </div>
          </div>
          <div v-if="loading" class="space-y-2 h-56">
            <div class="flex items-end gap-2 h-48">
              <Skeleton v-for="i in 14" :key="i" :height="`${30 + (i*7)%60}%`" rounded="rounded-t"/>
            </div>
          </div>
          <div v-else class="h-56 flex flex-col">
            <div class="flex-1 flex items-end gap-2">
              <div v-for="(v,i) in chart" :key="i" class="group flex-1 h-full flex flex-col justify-end items-center relative">
                <div class="absolute -top-8 opacity-0 group-hover:opacity-100 transition bg-ink-900 text-white text-[10px] px-2 py-1 rounded pointer-events-none whitespace-nowrap z-10">
                  {{ v }} events · {{ dayLabel(i) }}
                </div>
                <div class="w-full rounded-t bg-gradient-to-t from-brand-500 to-brand-700 group-hover:from-accent-500 group-hover:to-accent-500 transition-all duration-300"
                  :style="{ height: `${Math.max(2, (v / maxChart) * 100)}%` }"></div>
              </div>
            </div>
            <div class="flex gap-2 pt-2">
              <div v-for="(_,i) in chart" :key="i" class="flex-1 text-center text-[10px] text-ink-300">{{ dayTick(i) }}</div>
            </div>
          </div>
        </div>

        <div class="card p-6">
          <div class="flex items-center justify-between mb-4">
            <div class="font-semibold text-ink-900">Recent activity</div>
            <span v-if="recentEvents.length" class="inline-flex items-center gap-1.5 text-[11px] text-ink-500"><span class="w-1.5 h-1.5 rounded-full bg-accent-500 animate-pulse"></span>Live</span>
          </div>
          <div v-if="!recentEvents.length" class="flex flex-col items-center text-center py-6">
            <div class="w-14 h-14 rounded-full bg-brand-100/40 text-brand-500 flex items-center justify-center mb-3"><Icon name="activity" class="w-6 h-6"/></div>
            <div class="text-sm text-ink-500">No events yet. Start tracking to see them stream in.</div>
          </div>
          <div v-else class="space-y-3">
            <div v-for="(e, i) in recentEvents" :key="e.id" class="flex items-start gap-3">
              <div class="w-8 h-8 rounded-lg flex items-center justify-center shrink-0" :class="eventStyles[i % eventStyles.length].bg">
                <Icon :name="eventStyles[i % eventStyles.length].icon" class="w-4 h-4"/>
              </div>
              <div class="flex-1 min-w-0">
                <div class="text-sm font-medium text-ink-900 truncate">{{ e.name }}</div>
                <div class="text-xs text-ink-500">{{ timeAgo(e.occurred_at) }}</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div v-if="auth.workspace?.sending_paused" class="card p-4 border-l-4 border-red-500 bg-red-50 flex items-center gap-3">
        <Icon name="shield" class="text-red-600 w-5 h-5"/>
        <div class="flex-1">
          <div class="font-semibold text-red-900">Sending paused</div>
          <div class="text-xs text-red-700">{{ auth.workspace.sending_paused_reason || 'Paused by admin.' }}</div>
        </div>
        <NuxtLink to="/settings" class="btn-secondary !py-1.5 !text-xs">Review</NuxtLink>
      </div>

      <div class="card p-6">
        <div class="flex items-center justify-between mb-4">
          <div>
            <div class="font-semibold text-ink-900">Deliverability health</div>
            <div class="text-xs text-ink-500">SPF, DKIM, and DMARC status across your sending domains</div>
          </div>
          <NuxtLink to="/settings" class="text-xs text-brand-500 font-semibold">Manage →</NuxtLink>
        </div>
        <div v-if="!health.total" class="text-sm text-ink-500 py-4">No sending domains connected yet. Add one in Settings to start sending from your own domain.</div>
        <div v-else class="grid grid-cols-4 gap-4">
          <div class="flex flex-col items-start">
            <div class="text-xs font-semibold text-ink-500 uppercase tracking-wider">Verified</div>
            <div class="mt-2 text-2xl font-bold text-ink-900">{{ health.verified }}<span class="text-sm font-medium text-ink-500"> / {{ health.total }}</span></div>
          </div>
          <div v-for="check in healthChecks" :key="check.key" class="flex flex-col items-start">
            <div class="flex items-center gap-2">
              <span class="w-2 h-2 rounded-full" :class="check.value === health.total ? 'bg-accent-500' : check.value === 0 ? 'bg-red-500' : 'bg-amber-500'"></span>
              <div class="text-xs font-semibold text-ink-500 uppercase tracking-wider">{{ check.label }}</div>
            </div>
            <div class="mt-2 text-2xl font-bold text-ink-900">{{ check.value }}<span class="text-sm font-medium text-ink-500"> / {{ health.total }}</span></div>
            <div class="text-[11px] text-ink-500 mt-0.5">{{ check.hint }}</div>
          </div>
        </div>
      </div>

      <div class="grid lg:grid-cols-2 gap-6">
        <div class="card p-6">
          <div class="flex items-center justify-between mb-4">
            <div class="font-semibold text-ink-900">Top campaigns</div>
            <NuxtLink to="/campaigns" class="text-xs text-brand-500 font-semibold">View all →</NuxtLink>
          </div>
          <div v-if="!topCampaigns.length" class="text-sm text-ink-500">No campaigns yet.</div>
          <div v-else class="space-y-2">
            <div v-for="c in topCampaigns" :key="c.id" class="flex items-center justify-between p-3 rounded-lg hover:bg-ink-50">
              <div>
                <div class="font-medium text-ink-900 text-sm">{{ c.name }}</div>
                <div class="text-xs text-ink-500 capitalize">{{ c.channel }} · {{ c.status }}</div>
              </div>
              <div class="text-right">
                <div class="font-semibold text-ink-900 text-sm">{{ c.sent_count }}</div>
                <div class="text-[10px] text-ink-500">sent</div>
              </div>
            </div>
          </div>
        </div>

        <div class="card p-6">
          <div class="flex items-center justify-between mb-4">
            <div class="font-semibold text-ink-900">Active journeys</div>
            <NuxtLink to="/journeys" class="text-xs text-brand-500 font-semibold">View all →</NuxtLink>
          </div>
          <div v-if="!topJourneys.length" class="text-sm text-ink-500">No journeys yet.</div>
          <div v-else class="space-y-2">
            <div v-for="j in topJourneys" :key="j.id" class="flex items-center justify-between p-3 rounded-lg hover:bg-ink-50">
              <div>
                <div class="font-medium text-ink-900 text-sm">{{ j.name }}</div>
                <div class="text-xs text-ink-500">Trigger: {{ j.trigger_event || 'manual' }}</div>
              </div>
              <span class="chip" :class="j.status === 'active' ? 'bg-accent-500/10 text-accent-500' : 'bg-ink-100 text-ink-700'">{{ j.status }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { auth, supabase, workspaceId } = useWorkspace()
const displayWs = computed<any>(() => auth.displayWorkspace)
const isTest = computed(() => auth.workspace?.environment === 'test')
const stats = ref([
  { label: 'Customers', value: 0, hint: 'in your database', icon: 'users', bg: 'bg-brand-100/40 text-brand-500' },
  { label: 'Events (30d)', value: 0, hint: 'total tracked', icon: 'activity', bg: 'bg-accent-500/10 text-accent-500' },
  { label: 'Segments', value: 0, hint: 'active targeting', icon: 'segment', bg: 'bg-brand-100/40 text-brand-500' },
  { label: 'Campaigns', value: 0, hint: 'all time', icon: 'send', bg: 'bg-brand-100/40 text-brand-500' },
])
const chart = ref<number[]>(Array(14).fill(0))
const maxChart = computed(() => Math.max(1, ...chart.value))
const recentEvents = ref<any[]>([])
const topCampaigns = ref<any[]>([])
const topJourneys = ref<any[]>([])
const loading = ref(true)
const onlineMembers = ref(0)
const liveUsers = computed(() => onlineMembers.value.toLocaleString())
const eventStyles = [
  { bg: 'bg-brand-100/40 text-brand-500', icon: 'activity' },
  { bg: 'bg-accent-500/15 text-accent-500', icon: 'send' },
  { bg: 'bg-amber-500/15 text-amber-600', icon: 'bell' },
  { bg: 'bg-brand-100/40 text-brand-500', icon: 'users' },
]
const greeting = computed(() => {
  const h = new Date().getHours()
  if (h < 12) return 'Good morning'
  if (h < 18) return 'Good afternoon'
  return 'Good evening'
})
const health = ref<any>({ total: 0, verified: 0, spf_pass: 0, dkim_pass: 0, dmarc_pass: 0 })
const healthChecks = computed(() => [
  { key: 'spf', label: 'SPF', value: health.value.spf_pass, hint: 'authorizes senders' },
  { key: 'dkim', label: 'DKIM', value: health.value.dkim_pass, hint: 'signs messages' },
  { key: 'dmarc', label: 'DMARC', value: health.value.dmarc_pass, hint: 'enforces policy' },
])
const dayLabel = (i: number) => {
  const d = new Date(Date.now() - (13 - i) * 24 * 3600 * 1000)
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}
const dayTick = (i: number) => {
  if (i % 2 !== 0 && i !== 13) return ''
  const d = new Date(Date.now() - (13 - i) * 24 * 3600 * 1000)
  return d.toLocaleDateString('en-US', { day: 'numeric' })
}

async function load() {
  if (!workspaceId.value) return
  loading.value = true
  const wid = workspaceId.value
  const [c, e, s, camp, re, tc, tj] = await Promise.all([
    supabase.from('customers').select('id', { count: 'exact', head: true }).eq('workspace_id', wid),
    supabase.from('events').select('id', { count: 'exact', head: true }).eq('workspace_id', wid).gte('occurred_at', new Date(Date.now() - 30*24*3600*1000).toISOString()),
    supabase.from('segments').select('id', { count: 'exact', head: true }).eq('workspace_id', wid),
    supabase.from('campaigns').select('id', { count: 'exact', head: true }).eq('workspace_id', wid),
    supabase.from('events').select('*').eq('workspace_id', wid).order('occurred_at', { ascending: false }).limit(6),
    supabase.from('campaigns').select('*').eq('workspace_id', wid).order('created_at', { ascending: false }).limit(5),
    supabase.from('journeys').select('*').eq('workspace_id', wid).order('created_at', { ascending: false }).limit(5),
  ])
  stats.value[0].value = c.count || 0
  stats.value[1].value = e.count || 0
  stats.value[2].value = s.count || 0
  stats.value[3].value = camp.count || 0
  recentEvents.value = re.data || []
  topCampaigns.value = tc.data || []
  topJourneys.value = tj.data || []
  const { data: evs } = await supabase.from('events').select('occurred_at').eq('workspace_id', wid).gte('occurred_at', new Date(Date.now() - 14*24*3600*1000).toISOString())
  const buckets = Array(14).fill(0)
  ;(evs || []).forEach((x: any) => {
    const days = Math.floor((Date.now() - new Date(x.occurred_at).getTime()) / (24*3600*1000))
    if (days >= 0 && days < 14) buckets[13 - days]++
  })
  chart.value = buckets
  const { data: hv } = await supabase.from('email_domain_health_v').select('*').eq('workspace_id', wid).maybeSingle()
  health.value = hv || { total: 0, verified: 0, spf_pass: 0, dkim_pass: 0, dmarc_pass: 0 }
  await refreshOnline()
  loading.value = false
}

async function refreshOnline() {
  if (!workspaceId.value) return
  const { data } = await supabase.rpc('workspace_online_customers', {
    p_workspace_id: workspaceId.value,
    p_minutes: 10,
  })
  onlineMembers.value = Number(data) || 0
}

let onlineTimer: any = null
onMounted(() => { onlineTimer = setInterval(refreshOnline, 60_000) })
onBeforeUnmount(() => { if (onlineTimer) clearInterval(onlineTimer) })

watch(workspaceId, load, { immediate: true })
</script>
