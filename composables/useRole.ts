import { useAuthStore } from '~/stores/auth'

type Permissions = Record<string, Record<string, boolean>>

const state = reactive({
  roleName: '' as string,
  permissions: {} as Permissions,
  isOwner: false,
  loaded: false,
})

export const useRole = () => {
  const auth = useAuthStore()
  const { $supabase } = useNuxtApp()

  async function load() {
    state.loaded = false
    state.roleName = ''
    state.permissions = {}
    state.isOwner = false
    if (!auth.user || !auth.workspace) { state.loaded = true; return }

    if (auth.workspace.owner_id === auth.user.id) {
      state.isOwner = true
      state.roleName = 'Owner'
      const { data: ownerRole } = await $supabase
        .from('workspace_roles')
        .select('permissions')
        .eq('workspace_id', auth.workspace.id)
        .eq('name', 'Owner')
        .maybeSingle()
      state.permissions = (ownerRole?.permissions as Permissions) || {}
      state.loaded = true
      return
    }

    const { data: mem } = await $supabase
      .from('workspace_members')
      .select('role_id, workspace_roles:role_id(name, permissions)')
      .eq('workspace_id', auth.workspace.id)
      .eq('user_id', auth.user.id)
      .maybeSingle()
    const role: any = (mem as any)?.workspace_roles
    if (role) {
      state.roleName = role.name
      state.permissions = role.permissions || {}
    }
    state.loaded = true
  }

  function can(resource: string, action: string) {
    if (state.isOwner) return true
    const group = state.permissions?.[resource]
    if (!group) return false
    return !!group[action]
  }

  async function requestApproval(entityType: string, entityId: string, entityName: string, notes = '') {
    if (!auth.workspace || !auth.user) return
    await $supabase.from('approvals').insert({
      workspace_id: auth.workspace.id,
      entity_type: entityType,
      entity_id: entityId,
      entity_name: entityName,
      requested_by: auth.user.id,
      status: 'pending',
      notes,
    })
  }

  return {
    state: readonly(state),
    load,
    can,
    requestApproval,
  }
}
