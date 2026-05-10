<template>
  <div class="min-h-screen bg-ink-900 text-white flex items-center justify-center px-6 relative overflow-hidden">
    <div class="absolute -top-40 -right-40 w-[500px] h-[500px] rounded-full bg-brand-500/10 blur-3xl"></div>
    <div class="absolute -bottom-40 -left-40 w-[500px] h-[500px] rounded-full bg-accent-500/10 blur-3xl"></div>

    <div class="relative w-full max-w-md">
      <div class="flex items-center gap-2 mb-10 justify-center">
        <div class="w-10 h-10 rounded-lg bg-brand-500 flex items-center justify-center">
          <svg class="w-5 h-5 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M2 12h3l2-8 4 16 3-10 2 5h6"/></svg>
        </div>
        <div>
          <div class="font-bold text-lg leading-tight">Pulse</div>
          <div class="text-[10px] text-white/50 uppercase tracking-wider">Platform console</div>
        </div>
      </div>

      <div class="bg-white/5 backdrop-blur border border-white/10 rounded-2xl p-8">
        <div class="flex items-center gap-2 text-xs text-white/60 mb-1">
          <Icon name="shield" class="w-3.5 h-3.5"/> Internal access only
        </div>
        <h1 class="text-2xl font-bold">Platform sign-in</h1>
        <p class="text-sm text-white/60 mt-2 leading-relaxed">This console is restricted to the Pulse operations team. All access is logged and audited.</p>

        <form @submit.prevent="submit" class="mt-6 space-y-3">
          <div>
            <label class="text-xs text-white/60 font-medium">Work email</label>
            <input v-model="email" type="email" autocomplete="email" required class="mt-1 w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2.5 text-sm text-white placeholder-white/30 focus:outline-none focus:border-brand-500" placeholder="you@pulse.app"/>
          </div>
          <div>
            <label class="text-xs text-white/60 font-medium">Password</label>
            <input v-model="password" type="password" autocomplete="current-password" required class="mt-1 w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2.5 text-sm text-white placeholder-white/30 focus:outline-none focus:border-brand-500"/>
          </div>
          <div v-if="error" class="text-sm text-red-300 bg-red-500/10 border border-red-500/20 rounded-lg px-3 py-2">{{ error }}</div>
          <button type="submit" :disabled="loading" class="w-full bg-brand-500 hover:bg-brand-700 disabled:opacity-50 text-white font-semibold px-4 py-2.5 rounded-lg transition-colors flex items-center justify-center gap-2">
            <span v-if="loading">Verifying...</span>
            <span v-else>Sign in</span>
          </button>
        </form>

        <div class="mt-6 pt-6 border-t border-white/10 text-xs text-white/40 leading-relaxed">
          Tenant? You want <a href="/login" class="text-brand-500 hover:underline">the customer sign-in</a>. This page will not accept your account.
        </div>
      </div>

      <div class="mt-6 text-center text-[11px] text-white/40">
        Unauthorized access attempts are logged with IP and user agent.
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: false })
import { useAuthStore } from '~/stores/auth'

const { $supabase } = useNuxtApp()
const auth = useAuthStore()
const email = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)

onMounted(async () => {
  await auth.init()
  if (auth.user) {
    const { data } = await $supabase.from('platform_admins').select('id').eq('user_id', auth.user.id).maybeSingle()
    if (data) return navigateTo('/admin')
  }
})

async function submit() {
  error.value = ''
  loading.value = true
  try {
    const { data, error: signInError } = await $supabase.auth.signInWithPassword({
      email: email.value.trim().toLowerCase(),
      password: password.value,
    })
    if (signInError || !data.user) {
      error.value = 'Invalid credentials.'
      return
    }
    const { data: adminRow } = await $supabase.from('platform_admins').select('id').eq('user_id', data.user.id).maybeSingle()
    if (!adminRow) {
      await $supabase.auth.signOut()
      error.value = 'This account does not have platform access.'
      return
    }
    await auth.init()
    await navigateTo('/admin')
  } catch (e: any) {
    error.value = e?.message || 'Sign-in failed.'
  } finally {
    loading.value = false
  }
}
</script>
