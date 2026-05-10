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
        <h1 class="text-3xl font-bold text-ink-900">Welcome back</h1>
        <p class="text-ink-500 mt-1">Sign in to your workspace</p>

        <form @submit.prevent="submit" class="mt-8 space-y-4">
          <div>
            <label class="label">Email</label>
            <input v-model="email" type="email" required class="input" placeholder="you@company.com"/>
          </div>
          <div>
            <label class="label">Password</label>
            <input v-model="password" type="password" required minlength="6" class="input" placeholder="••••••••"/>
          </div>
          <div v-if="error" class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-lg px-3 py-2">{{ error }}</div>
          <button type="submit" :disabled="loading" class="btn-primary w-full">{{ loading ? 'Signing in…' : 'Sign in' }}</button>
        </form>

        <div class="mt-6 text-sm text-ink-500 text-center">
          New to Pulse? <NuxtLink to="/signup" class="text-brand-500 font-semibold">Create an account</NuxtLink>
        </div>
      </div>
    </div>
    <div class="hidden lg:flex flex-1 bg-brand-900 text-white p-16 flex-col justify-between relative overflow-hidden">
      <img src="https://images.pexels.com/photos/3184287/pexels-photo-3184287.jpeg?auto=compress&cs=tinysrgb&w=1600" class="absolute inset-0 w-full h-full object-cover opacity-25" alt=""/>
      <div class="absolute inset-0 bg-gradient-to-br from-brand-900/90 via-brand-900/80 to-brand-700/70"></div>
      <div class="relative z-10">
        <div class="text-xs font-semibold uppercase tracking-wider text-brand-100/70">Pulse</div>
        <div class="mt-4 text-3xl font-bold leading-tight max-w-md">Ship personalized experiences across every channel.</div>
      </div>
      <div class="relative z-10 space-y-5">
        <div class="rounded-xl bg-white/10 backdrop-blur border border-white/15 p-5">
          <div class="flex items-center gap-3">
            <img src="https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?auto=compress&cs=tinysrgb&w=96" class="w-10 h-10 rounded-full object-cover" alt=""/>
            <div>
              <div class="font-semibold">Adaeze Okonkwo</div>
              <div class="text-xs text-brand-100/70">Head of Growth, Northpeak</div>
            </div>
          </div>
          <p class="text-sm mt-3 text-brand-100/90 leading-relaxed">"We replaced three tools in two weeks and onboarding opens jumped from 38% to 62%."</p>
        </div>
        <div class="text-sm text-brand-100/70">Trusted by product teams to move fast without breaking trust.</div>
      </div>
      <div class="absolute -right-20 -bottom-20 w-[500px] h-[500px] rounded-full bg-brand-500/30 blur-3xl"></div>
      <div class="absolute -left-20 top-20 w-[300px] h-[300px] rounded-full bg-brand-100/10 blur-3xl"></div>
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
  const { data, error: err } = await $supabase.auth.signInWithPassword({ email: email.value, password: password.value })
  if (err) { loading.value = false; error.value = err.message; return }
  auth.user = data.user
  try {
    await auth.loadWorkspaces()
  } catch (e: any) {
    loading.value = false
    error.value = e?.message || 'Could not load your workspace. Please retry.'
    return
  }
  loading.value = false
  await navigateTo('/dashboard')
}
</script>
