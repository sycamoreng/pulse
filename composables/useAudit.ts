import { useAuthStore } from '~/stores/auth'

export const useAudit = () => {
  const { $supabase } = useNuxtApp()
  const auth = useAuthStore()

  async function log(
    action: string,
    entity_type: string,
    entity_id: string | null,
    entity_name: string,
    diff: Record<string, any> = {},
  ) {
    const wid = auth.workspace?.id
    if (!wid) return
    let user_agent = ''
    let request_id = ''
    if (typeof window !== 'undefined') {
      user_agent = navigator.userAgent || ''
      request_id = (crypto?.randomUUID?.() || `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`)
    }
    await $supabase.from('audit_logs').insert({
      workspace_id: wid,
      actor_id: auth.user?.id || null,
      actor_email: auth.user?.email || '',
      action,
      entity_type,
      entity_id: entity_id ? String(entity_id) : null,
      entity_name,
      diff,
      user_agent,
      request_id,
    })
  }

  return { log }
}
