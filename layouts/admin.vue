<template>
  <div class="min-h-screen bg-ink-50">
    <NetworkIndicator/>
    <aside class="fixed left-0 top-0 bottom-0 w-60 bg-ink-900 text-white flex flex-col">
      <div class="px-5 py-5 border-b border-white/10">
        <div class="flex items-center gap-2">
          <img src="/pulse-app-icon.svg" alt="Pulse" class="w-8 h-8 rounded-lg"/>
          <div>
            <div class="font-bold text-sm">Pulse Admin</div>
            <div class="text-[10px] text-white/50">Internal · platform ops</div>
          </div>
        </div>
      </div>
      <nav class="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto text-sm">
        <NuxtLink v-for="item in nav" :key="item.to" :to="item.to"
          class="flex items-center gap-3 px-3 py-2 rounded-lg text-white/70 hover:text-white hover:bg-white/5"
          active-class="!text-white !bg-white/10">
          <Icon :name="item.icon" class="w-4 h-4"/>
          <span>{{ item.label }}</span>
        </NuxtLink>
      </nav>
      <div class="px-3 pb-4 border-t border-white/10 pt-3 text-xs text-white/50">
        <div class="px-2 truncate">{{ auth.user?.email }}</div>
        <button @click="signOut" class="mt-2 w-full flex items-center gap-2 px-2 py-1.5 text-white/70 hover:text-white">
          <Icon name="arrow-left" class="w-3.5 h-3.5"/>Sign out
        </button>
      </div>
    </aside>
    <main class="pl-60 min-h-screen">
      <slot/>
    </main>
  </div>
</template>

<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const { $supabase } = useNuxtApp()
async function signOut() {
  await $supabase.auth.signOut()
  await navigateTo('/admin/login')
}
const nav = [
  { to: '/admin', label: 'Overview', icon: 'dashboard' },
  { to: '/admin/customers', label: 'Customers', icon: 'users' },
  { to: '/admin/plans', label: 'Plans', icon: 'box' },
  { to: '/admin/providers', label: 'Sending providers', icon: 'send' },
  { to: '/admin/suppressions', label: 'Suppressions', icon: 'shield' },
  { to: '/admin/admins', label: 'Team', icon: 'users' },
]
</script>
