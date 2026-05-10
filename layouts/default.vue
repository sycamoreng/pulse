<template>
  <div class="min-h-screen bg-ink-50">
    <aside class="fixed top-0 left-0 bottom-0 w-64 bg-white border-r border-ink-100 flex flex-col z-40">
      <div class="px-4 py-4 border-b border-ink-100 shrink-0">
        <div class="flex items-center gap-2 mb-3">
          <div class="w-8 h-8 rounded-lg bg-brand-500 flex items-center justify-center">
            <svg class="w-5 h-5 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M2 12h3l2-8 4 16 3-10 2 5h6"/></svg>
          </div>
          <div>
            <div class="font-bold text-ink-900 leading-tight">Pulse</div>
            <div class="text-[10px] text-ink-500 uppercase tracking-wider">Engagement Cloud</div>
          </div>
        </div>
        <div class="relative">
          <button @click="wsOpen = !wsOpen" class="w-full flex items-center gap-2 p-2 rounded-lg border border-ink-100 hover:bg-ink-50 text-left">
            <div class="w-7 h-7 rounded-md flex items-center justify-center text-white text-xs font-bold shrink-0" :style="{ background: auth.workspace?.brand_primary || '#3087B9' }">{{ (auth.workspace?.name || 'W')[0].toUpperCase() }}</div>
            <div class="flex-1 min-w-0">
              <div class="text-xs font-semibold text-ink-900 truncate">{{ auth.workspace?.name || 'Workspace' }}</div>
              <div class="text-[10px] text-ink-500 truncate">{{ auth.workspaces.length }} workspace{{ auth.workspaces.length === 1 ? '' : 's' }}</div>
            </div>
            <Icon name="chevronDown" class="w-3 h-3 text-ink-500"/>
          </button>
          <div v-if="wsOpen" class="absolute left-0 right-0 top-full mt-1 bg-white rounded-lg border border-ink-100 shadow-soft z-50 max-h-72 overflow-y-auto">
            <button v-for="w in auth.workspaces" :key="w.id" @click="pick(w.id)"
              class="w-full flex items-center gap-2 p-2 hover:bg-ink-50 text-left border-b border-ink-100 last:border-0">
              <div class="w-6 h-6 rounded flex items-center justify-center text-white text-[10px] font-bold" :style="{ background: w.brand_primary || '#3087B9' }">{{ (w.name || 'W')[0].toUpperCase() }}</div>
              <div class="flex-1 min-w-0">
                <div class="text-xs font-semibold text-ink-900 truncate">{{ w.name }}</div>
                <div class="text-[10px] text-ink-500">{{ w.owner_id === auth.user?.id ? 'Owner' : 'Member' }}</div>
              </div>
              <Icon v-if="w.id === auth.workspace?.id" name="check" class="w-3 h-3 text-accent-500"/>
            </button>
            <NuxtLink @click="wsOpen = false" to="/settings" class="block p-2 text-xs font-semibold text-brand-500 hover:bg-ink-50">
              Manage workspaces →
            </NuxtLink>
          </div>
        </div>
      </div>

      <nav class="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto min-h-0">
        <div class="px-3 pt-2 pb-1 text-[10px] font-semibold text-ink-300 uppercase tracking-wider">Overview</div>
        <NuxtLink to="/dashboard" class="nav-link" active-class="nav-link-active"><Icon name="home"/>Dashboard</NuxtLink>

        <div class="px-3 pt-4 pb-1 text-[10px] font-semibold text-ink-300 uppercase tracking-wider">Audience</div>
        <NuxtLink to="/customers" class="nav-link" active-class="nav-link-active"><Icon name="users"/>Customers</NuxtLink>
        <NuxtLink to="/segments" class="nav-link" active-class="nav-link-active"><Icon name="segment"/>Segments</NuxtLink>
        <NuxtLink to="/lists" class="nav-link" active-class="nav-link-active"><Icon name="list"/>Lists</NuxtLink>
        <NuxtLink to="/blacklist" class="nav-link" active-class="nav-link-active"><Icon name="shield"/>Blacklist</NuxtLink>
        <NuxtLink to="/attributes" class="nav-link" active-class="nav-link-active"><Icon name="tag"/>Attributes</NuxtLink>
        <NuxtLink to="/imports" class="nav-link" active-class="nav-link-active"><Icon name="upload"/>Imports</NuxtLink>

        <div class="px-3 pt-4 pb-1 text-[10px] font-semibold text-ink-300 uppercase tracking-wider">Analytics</div>
        <NuxtLink to="/events" class="nav-link" active-class="nav-link-active"><Icon name="activity"/>Events</NuxtLink>
        <NuxtLink to="/funnels" class="nav-link" active-class="nav-link-active"><Icon name="filter"/>Funnels</NuxtLink>
        <NuxtLink to="/cohorts" class="nav-link" active-class="nav-link-active"><Icon name="layers"/>Cohorts</NuxtLink>
        <NuxtLink to="/rfm" class="nav-link" active-class="nav-link-active"><Icon name="trending"/>RFM Analysis</NuxtLink>

        <div class="px-3 pt-4 pb-1 text-[10px] font-semibold text-ink-300 uppercase tracking-wider">Engagement</div>
        <NuxtLink to="/campaigns" class="nav-link" active-class="nav-link-active"><Icon name="send"/>Campaigns</NuxtLink>
        <NuxtLink to="/journeys" class="nav-link" active-class="nav-link-active"><Icon name="route"/>Journeys</NuxtLink>
        <NuxtLink to="/templates" class="nav-link" active-class="nav-link-active"><Icon name="copy"/>Templates</NuxtLink>
        <NuxtLink to="/onsite" class="nav-link" active-class="nav-link-active"><Icon name="monitor"/>On-Site Messages</NuxtLink>
        <NuxtLink to="/banners" class="nav-link" active-class="nav-link-active"><Icon name="smartphone"/>In-App Banners</NuxtLink>
        <NuxtLink to="/surveys" class="nav-link" active-class="nav-link-active"><Icon name="activity"/>Surveys & NPS</NuxtLink>

        <div class="px-3 pt-4 pb-1 text-[10px] font-semibold text-ink-300 uppercase tracking-wider">Settings</div>
        <NuxtLink to="/apps" class="nav-link" active-class="nav-link-active"><Icon name="box"/>Apps & SDKs</NuxtLink>
        <NuxtLink to="/settings" class="nav-link" active-class="nav-link-active"><Icon name="settings"/>Settings</NuxtLink>
      </nav>

      <div class="p-3 border-t border-ink-100 shrink-0">
        <div class="flex items-center gap-3 p-2">
          <div class="w-8 h-8 rounded-full bg-brand-900 text-white flex items-center justify-center text-xs font-semibold">{{ initials }}</div>
          <div class="flex-1 min-w-0">
            <div class="text-xs font-semibold text-ink-900 truncate">{{ auth.user?.email }}</div>
            <div class="text-[10px] text-ink-500 truncate">{{ role.state.roleName || auth.workspace?.name }}</div>
          </div>
          <button @click="auth.signOut()" class="text-ink-500 hover:text-ink-900 p-1" title="Sign out">
            <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9"/></svg>
          </button>
        </div>
      </div>
    </aside>

    <main class="pl-64 min-h-screen">
      <slot/>
    </main>

    <div class="fixed top-4 right-6 z-50">
      <div class="relative">
        <button @click="notifOpen = !notifOpen" class="w-10 h-10 rounded-full bg-white border border-ink-100 shadow-soft flex items-center justify-center text-ink-700 hover:text-brand-500 relative">
          <Icon name="bell" class="w-5 h-5"/>
          <span v-if="unreadCount" class="absolute -top-1 -right-1 min-w-[18px] h-[18px] rounded-full bg-red-500 text-white text-[10px] font-bold flex items-center justify-center px-1">{{ unreadCount > 9 ? '9+' : unreadCount }}</span>
        </button>
        <div v-if="notifOpen" class="absolute right-0 top-full mt-2 w-96 bg-white rounded-xl shadow-soft border border-ink-100 overflow-hidden">
          <div class="px-4 py-3 border-b border-ink-100 flex items-center justify-between">
            <div class="font-semibold text-ink-900 text-sm">Notifications</div>
            <button v-if="unreadCount" @click="markAllRead" class="text-[11px] text-brand-500 hover:underline">Mark all read</button>
          </div>
          <div class="max-h-96 overflow-y-auto">
            <div v-if="!notifications.length" class="p-8 text-center text-xs text-ink-500">You're all caught up.</div>
            <button v-for="n in notifications" :key="n.id" @click="openNotif(n)"
              class="w-full text-left px-4 py-3 border-b border-ink-100 last:border-0 hover:bg-ink-50 flex items-start gap-3"
              :class="!n.is_read ? 'bg-brand-100/20' : ''">
              <div class="w-8 h-8 rounded-lg flex items-center justify-center shrink-0" :class="notifBg(n.kind)">
                <Icon :name="notifIcon(n.kind)" class="w-4 h-4"/>
              </div>
              <div class="flex-1 min-w-0">
                <div class="text-sm font-semibold text-ink-900">{{ n.title }}</div>
                <div v-if="n.body" class="text-xs text-ink-500 line-clamp-2 mt-0.5">{{ n.body }}</div>
                <div class="text-[10px] text-ink-500 mt-1">{{ timeAgo(n.created_at) }}</div>
              </div>
              <span v-if="!n.is_read" class="w-2 h-2 rounded-full bg-brand-500 mt-1.5 shrink-0"></span>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const role = useRole()
const { supabase } = useWorkspace()
const initials = computed(() => (auth.user?.email || 'U').slice(0, 2).toUpperCase())
const wsOpen = ref(false)
const notifOpen = ref(false)
const notifications = ref<any[]>([])
const unreadCount = computed(() => notifications.value.filter((n: any) => !n.is_read).length)

async function pick(id: string) {
  wsOpen.value = false
  if (id === auth.workspace?.id) return
  await auth.setActiveWorkspace(id)
}

async function loadNotifications() {
  if (!auth.workspace?.id) return
  const { data } = await supabase
    .from('notifications')
    .select('*')
    .eq('workspace_id', auth.workspace.id)
    .order('created_at', { ascending: false })
    .limit(30)
  notifications.value = data || []
}

async function openNotif(n: any) {
  if (!n.is_read) {
    await supabase.from('notifications').update({ is_read: true }).eq('id', n.id)
    n.is_read = true
  }
  notifOpen.value = false
  if (n.link) {
    try { const url = new URL(n.link); if (url.origin === window.location.origin) { await navigateTo(url.pathname); return } } catch {}
    if (n.link.startsWith('/')) await navigateTo(n.link)
  }
}

async function markAllRead() {
  if (!auth.workspace?.id) return
  await supabase.from('notifications').update({ is_read: true }).eq('workspace_id', auth.workspace.id).eq('is_read', false)
  notifications.value = notifications.value.map((n: any) => ({ ...n, is_read: true }))
}

function notifBg(kind: string) {
  if (kind?.startsWith('approval_approved')) return 'bg-accent-500/10 text-accent-500'
  if (kind?.startsWith('approval_rejected')) return 'bg-red-100 text-red-600'
  if (kind === 'invite') return 'bg-brand-100/40 text-brand-500'
  if (kind === 'export_ready') return 'bg-accent-500/10 text-accent-500'
  return 'bg-ink-100 text-ink-700'
}
function notifIcon(kind: string) {
  if (kind === 'invite') return 'users'
  if (kind === 'export_ready') return 'upload'
  if (kind?.startsWith('approval_')) return 'shield'
  return 'bell'
}

let notifTimer: any = null
watch(() => auth.workspace?.id, async () => {
  await role.load()
  await loadNotifications()
}, { immediate: true })

onMounted(() => {
  loadNotifications()
  notifTimer = setInterval(loadNotifications, 30000)
})
onBeforeUnmount(() => { if (notifTimer) clearInterval(notifTimer) })
</script>
