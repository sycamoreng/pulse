<template>
  <div class="min-h-screen flex">
    <div class="flex-1 flex items-center justify-center p-8">
      <div class="w-full max-w-md">
        <NuxtLink to="/" class="flex items-center gap-2 mb-8">
          <img src="/pulse-app-icon.svg" alt="Pulse" class="w-9 h-9 rounded-lg"/>
          <span class="font-bold text-lg text-brand-900">Pulse</span>
        </NuxtLink>

        <div v-if="state === 'loading'" class="space-y-3">
          <h1 class="text-2xl font-bold text-ink-900">Verifying your invitation…</h1>
          <p class="text-ink-500">Hang tight, this only takes a moment.</p>
        </div>

        <div v-else-if="state === 'error'" class="space-y-4">
          <h1 class="text-2xl font-bold text-ink-900">This link isn't valid</h1>
          <p class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-lg px-3 py-2">{{ error }}</p>
          <p class="text-sm text-ink-500">Ask the workspace admin to send a fresh registration link.</p>
          <NuxtLink to="/login" class="btn-secondary inline-flex">Go to sign in</NuxtLink>
        </div>

        <div v-else-if="state === 'form'">
          <h1 class="text-3xl font-bold text-ink-900">Finish setting up your account</h1>
          <p class="text-ink-500 mt-1">You've been invited to <span class="font-semibold text-ink-900">{{ workspaceName || 'Pulse' }}</span>. Choose a password to continue.</p>

          <form @submit.prevent="submit" class="mt-8 space-y-4">
            <div>
              <label class="label">Email</label>
              <input :value="email" type="email" disabled class="input bg-ink-50 cursor-not-allowed"/>
            </div>
            <div>
              <label class="label">New password</label>
              <input v-model="password" type="password" required minlength="8" class="input" placeholder="at least 8 characters" autocomplete="new-password"/>
            </div>
            <div>
              <label class="label">Confirm password</label>
              <input v-model="confirm" type="password" required minlength="8" class="input" placeholder="re-enter your password" autocomplete="new-password"/>
            </div>
            <div v-if="formError" class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-lg px-3 py-2">{{ formError }}</div>
            <button type="submit" :disabled="saving" class="btn-primary w-full">{{ saving ? 'Creating account…' : 'Create password & continue' }}</button>
          </form>
        </div>
      </div>
    </div>
    <div class="hidden lg:flex flex-1 bg-brand-900 text-white p-16 flex-col justify-between relative overflow-hidden">
      <img src="https://images.pexels.com/photos/3183150/pexels-photo-3183150.jpeg?auto=compress&cs=tinysrgb&w=1600" class="absolute inset-0 w-full h-full object-cover opacity-20" alt=""/>
      <div class="absolute inset-0 bg-gradient-to-br from-brand-900/92 via-brand-900/80 to-brand-700/70"></div>
      <div class="relative z-10">
        <div class="text-xs font-semibold uppercase tracking-wider text-brand-100/70">You're invited</div>
        <div class="mt-4 text-3xl font-bold leading-tight max-w-md">Welcome to the team.</div>
        <ul class="mt-8 space-y-3 text-brand-100 text-sm">
          <li class="flex items-start gap-2"><Icon name="check" class="text-accent-500 mt-0.5"/> Your account is already linked to the workspace</li>
          <li class="flex items-start gap-2"><Icon name="check" class="text-accent-500 mt-0.5"/> Set a password now to sign in anytime</li>
          <li class="flex items-start gap-2"><Icon name="check" class="text-accent-500 mt-0.5"/> Your admin controls what you can access</li>
        </ul>
      </div>
      <div class="absolute -right-20 -bottom-20 w-[500px] h-[500px] rounded-full bg-brand-500/30 blur-3xl"></div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'

definePageMeta({ layout: false })

const { $supabase } = useNuxtApp()
const route = useRoute()
const auth = useAuthStore()

const state = ref<'loading' | 'form' | 'error'>('loading')
const error = ref('')
const formError = ref('')
const email = ref('')
const password = ref('')
const confirm = ref('')
const saving = ref(false)
const workspaceName = ref('')

function parseHashParams(hash: string) {
  const out: Record<string, string> = {}
  const clean = hash.replace(/^#/, '')
  for (const part of clean.split('&')) {
    const [k, v] = part.split('=')
    if (k) out[decodeURIComponent(k)] = decodeURIComponent(v || '')
  }
  return out
}

onMounted(async () => {
  try {
    // 1. If Supabase returned the session directly in the URL hash
    const hashParams = typeof window !== 'undefined' ? parseHashParams(window.location.hash) : {}
    if (hashParams.error_description) {
      state.value = 'error'
      error.value = hashParams.error_description
      return
    }
    if (hashParams.access_token && hashParams.refresh_token) {
      const { error: setErr } = await $supabase.auth.setSession({
        access_token: hashParams.access_token,
        refresh_token: hashParams.refresh_token,
      })
      if (setErr) throw setErr
    } else {
      // 2. Query-param flow (token_hash)
      const token_hash = (route.query.token_hash || route.query.token) as string | undefined
      const type = (route.query.type as string | undefined) || 'invite'
      if (token_hash) {
        const { error: vErr } = await $supabase.auth.verifyOtp({ token_hash, type: type as any })
        if (vErr) throw vErr
      }
    }

    const { data } = await $supabase.auth.getUser()
    if (!data.user) throw new Error('Your invitation could not be verified. Please ask for a new link.')
    email.value = data.user.email || ''

    // Look up workspace name for warmth
    const { data: member } = await $supabase
      .from('workspace_members')
      .select('workspace_id, workspaces:workspaces(name)')
      .eq('user_id', data.user.id)
      .limit(1)
      .maybeSingle()
    workspaceName.value = (member as any)?.workspaces?.name || ''

    state.value = 'form'
  } catch (e: any) {
    state.value = 'error'
    error.value = e?.message || 'Your invitation link is invalid or has expired.'
  } finally {
    if (typeof window !== 'undefined' && window.location.hash) {
      history.replaceState(null, '', window.location.pathname + window.location.search)
    }
  }
})

async function submit() {
  formError.value = ''
  if (password.value !== confirm.value) { formError.value = "Those passwords don't match."; return }
  if (password.value.length < 8) { formError.value = 'Use at least 8 characters.'; return }
  saving.value = true
  try {
    const { error: upErr } = await $supabase.auth.updateUser({ password: password.value })
    if (upErr) throw upErr
    auth.user = (await $supabase.auth.getUser()).data.user as any
    try { await $supabase.rpc('mark_member_activated', { p_workspace: null }) } catch {}
    try { await auth.loadWorkspaces() } catch {}
    await navigateTo('/dashboard')
  } catch (e: any) {
    formError.value = e?.message || 'Could not save your password. Try again.'
  } finally {
    saving.value = false
  }
}
</script>
