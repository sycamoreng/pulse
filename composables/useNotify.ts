export const useNotify = () => {
  const config = useRuntimeConfig()
  const supabaseUrl = config.public.supabaseUrl
  const supabaseAnonKey = config.public.supabaseAnonKey

  async function notify(opts: {
    workspace_id: string
    to_email?: string
    to_user_id?: string | null
    kind: string
    title: string
    body?: string
    link?: string
    send_email?: boolean
  }) {
    try {
      const { data: { session } } = await useNuxtApp().$supabase.auth.getSession()
      const token = session?.access_token || supabaseAnonKey
      const res = await fetch(`${supabaseUrl}/functions/v1/notify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify(opts),
      })
      return await res.json()
    } catch (e) {
      return { ok: false, error: String(e) }
    }
  }

  async function verifyDomain(domain_id: string) {
    try {
      const { data: { session } } = await useNuxtApp().$supabase.auth.getSession()
      const token = session?.access_token || supabaseAnonKey
      const res = await fetch(`${supabaseUrl}/functions/v1/verify-domain`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ domain_id }),
      })
      return await res.json()
    } catch (e) {
      return { ok: false, error: String(e) }
    }
  }

  return { notify, verifyDomain }
}
