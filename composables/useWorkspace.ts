import { useAuthStore } from '~/stores/auth'

export const useWorkspace = () => {
  const auth = useAuthStore()
  const { $supabase } = useNuxtApp()
  const workspaceId = computed(() => auth.workspace?.id)
  const ready = computed(() => !!auth.workspace?.id)
  return { auth, supabase: $supabase, workspaceId, ready }
}

export const formatDate = (d: string | null | undefined) => {
  if (!d) return '—'
  const date = new Date(d)
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

export const formatDateTime = (d: string | null | undefined) => {
  if (!d) return '—'
  return new Date(d).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

export const timeAgo = (d: string | null | undefined) => {
  if (!d) return '—'
  const diff = Date.now() - new Date(d).getTime()
  const s = Math.floor(diff / 1000)
  if (s < 60) return `${s}s ago`
  const m = Math.floor(s / 60)
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  const days = Math.floor(h / 24)
  if (days < 30) return `${days}d ago`
  return formatDate(d)
}
