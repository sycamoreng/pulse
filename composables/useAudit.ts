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
    await $supabase.from('audit_logs').insert({
      workspace_id: wid,
      actor_id: auth.user?.id || null,
      actor_email: auth.user?.email || '',
      action,
      entity_type,
      entity_id: entity_id ? String(entity_id) : null,
      entity_name,
      diff,
    })
  }

  return { log }
}
