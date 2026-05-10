<template>
  <div>
    <PageHeader title="Platform team" subtitle="People with admin access to Pulse itself.">
      <template #actions><button @click="open = true" class="btn-primary"><Icon name="plus"/>Add admin</button></template>
    </PageHeader>
    <div class="p-8">
      <div class="card">
        <table class="w-full text-sm">
          <thead class="text-left text-xs text-ink-500 uppercase tracking-wider border-b border-ink-100">
            <tr><th class="px-4 py-3">Email</th><th class="px-4 py-3">Role</th><th class="px-4 py-3">Added</th><th></th></tr>
          </thead>
          <tbody>
            <tr v-for="a in admins" :key="a.id" class="border-b border-ink-100 last:border-0">
              <td class="px-4 py-3 font-medium text-ink-900">{{ a.email }}</td>
              <td class="px-4 py-3"><span class="chip bg-brand-100/40 text-brand-700">{{ a.role }}</span></td>
              <td class="px-4 py-3 text-xs text-ink-500">{{ new Date(a.created_at).toLocaleDateString() }}</td>
              <td class="px-4 py-3 text-right"><button @click="remove(a)" class="text-ink-500 hover:text-red-600"><Icon name="trash"/></button></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    <Modal v-model="open" title="Add platform admin">
      <form id="af" @submit.prevent="add" class="space-y-3">
        <div><label class="label">User email</label><input v-model="form.email" type="email" class="input" required/><div class="text-[11px] text-ink-500 mt-1">User must already have a Pulse account.</div></div>
        <div><label class="label">Role</label>
          <select v-model="form.role" class="input">
            <option value="super_admin">Super admin (full access)</option>
            <option value="support">Support (read + suppress)</option>
            <option value="billing">Billing (plans + usage)</option>
          </select>
        </div>
      </form>
      <template #footer>
        <button @click="open = false" class="btn-secondary">Cancel</button>
        <button form="af" type="submit" class="btn-primary">Grant access</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })
const { $supabase } = useNuxtApp()
const admins = ref<any[]>([])
const open = ref(false)
const form = reactive({ email: '', role: 'support' })

async function load() {
  const { data } = await $supabase.from('platform_admins').select('*').order('created_at', { ascending: false })
  const rows = data || []
  const ids = rows.map((r: any) => r.user_id)
  if (ids.length) {
    const { data: users } = await $supabase.rpc('get_user_emails_by_ids', { user_ids: ids }).catch(() => ({ data: [] }))
    const map: Record<string, string> = {}
    for (const u of (users || [])) map[u.id] = u.email
    admins.value = rows.map((r: any) => ({ ...r, email: map[r.user_id] || r.user_id }))
  } else {
    admins.value = []
  }
}

async function add() {
  const { data: userRow } = await $supabase.rpc('get_user_id_by_email', { email_in: form.email.trim().toLowerCase() }).catch(() => ({ data: null }))
  if (!userRow) { useToast().error('No user with that email', 'Ask them to sign up first.'); return }
  const { error } = await $supabase.from('platform_admins').insert({ user_id: userRow, role: form.role })
  if (error) { useToast().error('Could not grant access', error.message); return }
  useToast().success('Admin added')
  form.email = ''; open.value = false; await load()
}
async function remove(a: any) {
  const ok = await useConfirm().ask({ title: 'Revoke admin access?', tone: 'danger', confirmText: 'Revoke' })
  if (!ok) return
  await $supabase.from('platform_admins').delete().eq('id', a.id)
  await load()
}
onMounted(load)
</script>
