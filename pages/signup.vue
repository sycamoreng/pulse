<template>
  <div class="min-h-screen flex">
    <div class="flex-1 flex items-center justify-center p-8">
      <div class="w-full max-w-md">
        <NuxtLink to="/" class="flex items-center gap-2 mb-8">
          <div class="w-9 h-9 rounded-lg bg-brand-500 flex items-center justify-center">
            <svg class="w-5 h-5 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M2 12h3l2-8 4 16 3-10 2 5h6"/></svg>
          </div>
          <span class="font-bold text-lg text-brand-900">Pulse</span>
        </NuxtLink>
        <h1 class="text-3xl font-bold text-ink-900">Create your workspace</h1>
        <p class="text-ink-500 mt-1">Free forever. No credit card required.</p>

        <form @submit.prevent="submit" class="mt-8 space-y-4">
          <div>
            <label class="label">Work email</label>
            <input v-model="email" type="email" required class="input" placeholder="you@company.com"/>
          </div>
          <div>
            <label class="label">Password</label>
            <input v-model="password" type="password" required minlength="6" class="input" placeholder="at least 6 characters"/>
          </div>
          <div v-if="error" class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-lg px-3 py-2">{{ error }}</div>
          <button type="submit" :disabled="loading" class="btn-primary w-full">{{ loading ? 'Creating…' : 'Create account' }}</button>
        </form>

        <div class="mt-6 text-sm text-ink-500 text-center">
          Already have an account? <NuxtLink to="/login" class="text-brand-500 font-semibold">Sign in</NuxtLink>
        </div>
      </div>
    </div>
    <div class="hidden lg:flex flex-1 bg-brand-900 text-white p-16 flex-col justify-between relative overflow-hidden">
      <img src="https://images.pexels.com/photos/3183150/pexels-photo-3183150.jpeg?auto=compress&cs=tinysrgb&w=1600" class="absolute inset-0 w-full h-full object-cover opacity-20" alt=""/>
      <div class="absolute inset-0 bg-gradient-to-br from-brand-900/92 via-brand-900/80 to-brand-700/70"></div>
      <div class="relative z-10">
        <div class="text-xs font-semibold uppercase tracking-wider text-brand-100/70">What's included</div>
        <ul class="mt-6 space-y-3 text-brand-100">
          <li class="flex items-start gap-2"><Icon name="check" class="text-accent-500 mt-0.5"/> Unlimited customers on the free tier</li>
          <li class="flex items-start gap-2"><Icon name="check" class="text-accent-500 mt-0.5"/> Segments, lists, blacklists, attributes</li>
          <li class="flex items-start gap-2"><Icon name="check" class="text-accent-500 mt-0.5"/> Campaigns, journeys, on-site & in-app</li>
          <li class="flex items-start gap-2"><Icon name="check" class="text-accent-500 mt-0.5"/> SDK keys for iOS, Android & Web</li>
          <li class="flex items-start gap-2"><Icon name="check" class="text-accent-500 mt-0.5"/> CSV import with column mapping</li>
        </ul>
      </div>
      <div class="relative z-10">
        <div class="flex -space-x-3">
          <img src="https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?auto=compress&cs=tinysrgb&w=96" class="w-10 h-10 rounded-full border-2 border-brand-900 object-cover" alt=""/>
          <img src="https://images.pexels.com/photos/774909/pexels-photo-774909.jpeg?auto=compress&cs=tinysrgb&w=96" class="w-10 h-10 rounded-full border-2 border-brand-900 object-cover" alt=""/>
          <img src="https://images.pexels.com/photos/697509/pexels-photo-697509.jpeg?auto=compress&cs=tinysrgb&w=96" class="w-10 h-10 rounded-full border-2 border-brand-900 object-cover" alt=""/>
          <div class="w-10 h-10 rounded-full border-2 border-brand-900 bg-white/15 backdrop-blur flex items-center justify-center text-[10px] font-bold">+2k</div>
        </div>
        <div class="text-sm text-brand-100/80 mt-3">Joined by 2,000+ product teams this month.</div>
      </div>
      <div class="absolute -right-20 -bottom-20 w-[500px] h-[500px] rounded-full bg-brand-500/30 blur-3xl"></div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: false })
const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const submit = async () => {
  loading.value = true; error.value = ''
  const { $supabase } = useNuxtApp()
  const { data, error: err } = await $supabase.auth.signUp({ email: email.value, password: password.value })
  if (err) { loading.value = false; error.value = err.message; return }
  if (data.user) {
    auth.user = data.user
    try { await auth.loadWorkspaces() } catch (e: any) {
      loading.value = false
      error.value = e?.message || 'Could not provision your workspace. Please retry.'
      return
    }
  }
  loading.value = false
  await navigateTo('/dashboard')
}
</script>
