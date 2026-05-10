import { useAuthStore } from '~/stores/auth'

export default defineNuxtRouteMiddleware(async (to) => {
  if (import.meta.server) return

  const tenantPublic = ['/login', '/signup', '/']
  const adminPublic = ['/admin/login']
  const auth = useAuthStore()
  await auth.init()
  const isAuthed = !!auth.user
  const isAdminRoute = to.path === '/admin' || to.path.startsWith('/admin/')

  // Subdomain isolation: if we're on the admin host, only /admin/* is served.
  // Configured via NUXT_PUBLIC_ADMIN_HOST (e.g. "admin.pulse.app"). When set,
  // requests for that host to non-/admin routes are forced to /admin/login.
  // Likewise, non-admin hosts cannot access /admin/* at all (404 by redirect).
  const adminHost = (useRuntimeConfig().public as any).adminHost as string | undefined
  if (adminHost && typeof window !== 'undefined') {
    const onAdminHost = window.location.host === adminHost
    if (onAdminHost && !isAdminRoute) return navigateTo('/admin/login')
    if (!onAdminHost && isAdminRoute) return navigateTo('/login')
  }

  // Admin routes: dedicated login, dedicated platform_admins gate
  if (isAdminRoute) {
    if (adminPublic.includes(to.path)) return
    if (!isAuthed) return navigateTo('/admin/login')
    const { $supabase } = useNuxtApp()
    const { data } = await $supabase.from('platform_admins').select('id').eq('user_id', auth.user.id).maybeSingle()
    if (!data) {
      await $supabase.auth.signOut()
      return navigateTo('/admin/login')
    }
    return
  }

  // Tenant routes
  if (!isAuthed && !tenantPublic.includes(to.path)) return navigateTo('/login')
  if (isAuthed && (to.path === '/login' || to.path === '/signup' || to.path === '/')) return navigateTo('/dashboard')
})
