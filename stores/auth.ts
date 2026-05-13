import { defineStore } from 'pinia'

const LS_KEY = 'pulse.activeWorkspaceId'
const LS_ENV_KEY = 'pulse.envPreference'

function readEnvPref(): 'production' | 'test' {
  if (typeof window === 'undefined') return 'production'
  const v = localStorage.getItem(LS_ENV_KEY)
  return v === 'test' ? 'test' : 'production'
}
function writeEnvPref(env: 'production' | 'test') {
  if (typeof window !== 'undefined') localStorage.setItem(LS_ENV_KEY, env)
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null as any,
    workspace: null as any,
    workspaces: [] as any[],
    loading: true,
    initialized: false,
  }),
  getters: {
    displayWorkspace(state): any {
      const ws = state.workspace
      if (!ws) return null
      if (ws.environment !== 'test' || !ws.parent_workspace_id) return ws
      const parent = state.workspaces.find((w: any) => w.id === ws.parent_workspace_id)
      if (!parent) return { ...ws, name: ws.name.replace(/\s*\(Test\)\s*$/, '') }
      return {
        ...parent,
        id: ws.id,
        environment: 'test',
        parent_workspace_id: parent.id,
        demo_seeded: ws.demo_seeded,
      }
    },
    productionWorkspaceList(state): any[] {
      return state.workspaces.filter((w: any) => w.environment !== 'test')
    },
  },
  actions: {
    async init() {
      if (this.initialized) return
      this.initialized = true
      const { $supabase } = useNuxtApp()
      const { data } = await $supabase.auth.getSession()
      this.user = data.session?.user ?? null
      if (this.user) await this.loadWorkspaces()
      this.loading = false
      $supabase.auth.onAuthStateChange((event, session) => {
        (async () => {
          if (event === 'TOKEN_REFRESHED' || event === 'USER_UPDATED') {
            this.user = session?.user ?? this.user
            return
          }
          if (event === 'SIGNED_OUT') {
            this.user = null
            this.workspace = null
            this.workspaces = []
            return
          }
          if (event === 'SIGNED_IN') {
            const nextId = session?.user?.id
            if (!nextId) return
            if (this.user?.id === nextId && this.workspaces.length) return
            this.user = session!.user
            await this.loadWorkspaces()
          }
        })()
      })
    },
    async loadWorkspaces(opts?: { preferredPlanId?: string; bootstrapIfMissing?: boolean }) {
      const { $supabase } = useNuxtApp()
      const { data: owned } = await $supabase.from('workspaces').select('*').eq('owner_id', this.user.id)
      const { data: memberships } = await $supabase.from('workspace_members').select('workspace_id, role_id, workspaces:workspaces(*)').eq('user_id', this.user.id)
      const joined = (memberships || []).map((m: any) => m.workspaces).filter(Boolean)
      const all = [...(owned || []), ...joined]
      const unique = Array.from(new Map(all.map((w: any) => [w.id, w])).values())
      this.workspaces = unique

      if (!unique.length) {
        // Only bootstrap a workspace when the caller explicitly asks (signup / onboarding flow).
        // Logging in without a workspace must NOT silently provision one - that creates ghost
        // tenants for accounts that only exist for platform admin or pending invites.
        if (!opts?.bootstrapIfMissing) return
        const { data: bootstrapped } = await $supabase.rpc('bootstrap_workspace_for_current_user', {
          p_name: opts?.preferredPlanId ? null : null,
          p_plan_id: opts?.preferredPlanId ?? null,
        })
        if (bootstrapped) {
          const { data: owned2 } = await $supabase.from('workspaces').select('*').eq('owner_id', this.user.id)
          const { data: m2 } = await $supabase.from('workspace_members').select('workspace_id, role_id, workspaces:workspaces(*)').eq('user_id', this.user.id)
          const joined2 = (m2 || []).map((m: any) => m.workspaces).filter(Boolean)
          const merged = Array.from(new Map([...(owned2 || []), ...joined2].map((w: any) => [w.id, w])).values())
          this.workspaces = merged
          if (merged.length) await this.setActiveWorkspace(merged[0].id)
        }
        return
      }
      const savedId = typeof window !== 'undefined' ? localStorage.getItem(LS_KEY) : null
      const envPref = readEnvPref()
      let active = unique.find((w: any) => w.id === savedId) || unique[0]
      if (active) {
        const parentId = active.environment === 'test' ? active.parent_workspace_id : active.id
        if (envPref === 'test') {
          const testSibling = unique.find((w: any) => w.environment === 'test' && w.parent_workspace_id === parentId)
          if (testSibling) active = testSibling
        } else {
          const prodSibling = unique.find((w: any) => w.environment !== 'test' && w.id === parentId) || unique.find((w: any) => w.environment !== 'test')
          if (prodSibling) active = prodSibling
        }
      }
      await this.setActiveWorkspace(active.id)
    },
    async setActiveWorkspace(id: string) {
      const ws = this.workspaces.find((w: any) => w.id === id)
      if (!ws) return
      this.workspace = ws
      if (typeof window !== 'undefined') localStorage.setItem(LS_KEY, id)
      writeEnvPref(ws.environment === 'test' ? 'test' : 'production')
      if (ws.owner_id === this.user?.id && !ws.demo_seeded) {
        this.seedInBackground(ws.id)
      }
    },
    seedInBackground(wsId: string) {
      const { $supabase } = useNuxtApp()
      ;(async () => {
        try {
          const { seedDemoData } = useSeed()
          await seedDemoData(wsId)
        } catch (e) {
          console.error('seed failed', e)
        } finally {
          await $supabase.from('workspaces').update({ demo_seeded: true }).eq('id', wsId)
          const { data } = await $supabase.from('workspaces').select('*').eq('id', wsId).maybeSingle()
          if (data) {
            if (this.workspace?.id === data.id) this.workspace = data
            this.workspaces = this.workspaces.map((w: any) => w.id === data.id ? data : w)
          }
        }
      })()
    },
    async createWorkspace(name?: string, preferredPlanId?: string) {
      const { $supabase } = useNuxtApp()
      const { data: ws, error } = await $supabase.rpc('bootstrap_workspace_for_current_user', {
        p_name: name ?? null,
        p_plan_id: preferredPlanId ?? null,
      })
      if (error) { console.error('createWorkspace error', error); throw error }
      if (!ws) return null
      const { data: owned } = await $supabase.from('workspaces').select('*').eq('owner_id', this.user.id)
      const { data: memberships } = await $supabase.from('workspace_members').select('workspace_id, role_id, workspaces:workspaces(*)').eq('user_id', this.user.id)
      const joined = (memberships || []).map((m: any) => m.workspaces).filter(Boolean)
      this.workspaces = Array.from(new Map([...(owned || []), ...joined].map((w: any) => [w.id, w])).values())
      await this.setActiveWorkspace(ws.id)
      return ws
    },
    async switchEnvironment(env: 'production' | 'test') {
      const current = this.workspace
      if (!current) return
      if (current.environment === env) return
      let target: any = null
      if (env === 'test') {
        target = this.workspaces.find((w: any) => w.parent_workspace_id === current.id && w.environment === 'test')
        if (!target && current.owner_id === this.user?.id) {
          const { $supabase } = useNuxtApp()
          const { data: testWs } = await $supabase.from('workspaces').insert({
            name: `${current.name} (Test)`,
            slug: `${current.slug}-test`,
            owner_id: this.user.id,
            environment: 'test',
            parent_workspace_id: current.id,
            brand_primary: current.brand_primary,
            brand_accent: current.brand_accent,
            demo_seeded: true,
          }).select().maybeSingle()
          if (testWs) {
            this.workspaces = [...this.workspaces, testWs]
            target = testWs
          }
        }
      } else {
        target = this.workspaces.find((w: any) => w.id === current.parent_workspace_id && w.environment === 'production')
      }
      if (target) await this.setActiveWorkspace(target.id)
    },
    async signOut() {
      const { $supabase } = useNuxtApp()
      await $supabase.auth.signOut()
      this.user = null
      this.workspace = null
      this.workspaces = []
      if (typeof window !== 'undefined') localStorage.removeItem(LS_KEY)
      navigateTo('/login')
    }
  }
})
