import { defineStore } from 'pinia'

const LS_KEY = 'pulse.activeWorkspaceId'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null as any,
    workspace: null as any,
    workspaces: [] as any[],
    loading: true,
    initialized: false,
  }),
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
    async loadWorkspaces() {
      const { $supabase } = useNuxtApp()
      const { data: owned } = await $supabase.from('workspaces').select('*').eq('owner_id', this.user.id)
      const { data: memberships } = await $supabase.from('workspace_members').select('workspace_id, role_id, workspaces:workspaces(*)').eq('user_id', this.user.id)
      const joined = (memberships || []).map((m: any) => m.workspaces).filter(Boolean)
      const all = [...(owned || []), ...joined]
      const unique = Array.from(new Map(all.map((w: any) => [w.id, w])).values())
      this.workspaces = unique

      if (!unique.length) {
        await this.createWorkspace()
        return
      }
      const savedId = typeof window !== 'undefined' ? localStorage.getItem(LS_KEY) : null
      const active = unique.find((w: any) => w.id === savedId) || unique[0]
      await this.setActiveWorkspace(active.id)
    },
    async setActiveWorkspace(id: string) {
      const ws = this.workspaces.find((w: any) => w.id === id)
      if (!ws) return
      this.workspace = ws
      if (typeof window !== 'undefined') localStorage.setItem(LS_KEY, id)
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
    async createWorkspace(name?: string) {
      const { $supabase } = useNuxtApp()
      const wsName = name || (this.user.email?.split('@')[0] + "'s Workspace")
      const slug = `ws-${Math.random().toString(36).slice(2, 8)}`
      const { data: ws, error } = await $supabase.from('workspaces').insert({
        name: wsName, slug, owner_id: this.user.id
      }).select().maybeSingle()
      if (error) { console.error('createWorkspace error', error); throw error }
      if (!ws) return null
      this.workspaces = [...this.workspaces, ws]
      await this.setActiveWorkspace(ws.id)
      return ws
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
