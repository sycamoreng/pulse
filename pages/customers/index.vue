<template>
  <div>
    <PageHeader title="Customers" subtitle="Every user across your apps, unified.">
      <template #actions>
        <NuxtLink to="/imports" class="btn-secondary"><Icon name="upload"/>Import CSV</NuxtLink>
        <button @click="openNew = true" class="btn-primary"><Icon name="plus"/>Add customer</button>
      </template>
    </PageHeader>

    <div class="p-8 space-y-4">
      <div class="card p-4 flex flex-wrap gap-3 items-center">
        <div class="relative flex-1 min-w-[240px]">
          <Icon name="search" class="absolute left-3 top-1/2 -translate-y-1/2 text-ink-500"/>
          <input v-model="q" class="input pl-9" placeholder="Search by email, name, external id…"/>
        </div>
        <select v-model="platformFilter" class="input w-auto">
          <option value="">All platforms</option>
          <option value="web">Web</option>
          <option value="ios">iOS</option>
          <option value="android">Android</option>
        </select>
        <select v-model="blacklistFilter" class="input w-auto">
          <option value="">All customers</option>
          <option value="no">Active only</option>
          <option value="yes">Blacklisted</option>
        </select>
        <div class="text-sm text-ink-500 ml-auto">{{ total }} customers</div>
      </div>

      <div class="card overflow-hidden">
        <table class="w-full">
          <thead><tr>
            <th class="table-th">Customer</th>
            <th class="table-th">Contact</th>
            <th class="table-th">Location</th>
            <th class="table-th">Platform</th>
            <th class="table-th">Last seen</th>
            <th class="table-th"></th>
          </tr></thead>
          <tbody>
            <template v-if="loading">
              <tr v-for="i in 6" :key="'sk'+i">
                <td class="table-td"><div class="flex items-center gap-3"><Skeleton width="32px" height="32px" rounded="rounded-full"/><div class="space-y-1"><Skeleton width="140px" height="14px"/><Skeleton width="100px" height="10px"/></div></div></td>
                <td class="table-td"><Skeleton width="180px" height="14px"/></td>
                <td class="table-td"><Skeleton width="120px" height="14px"/></td>
                <td class="table-td"><Skeleton width="60px" height="20px" rounded="rounded-full"/></td>
                <td class="table-td"><Skeleton width="80px" height="14px"/></td>
                <td class="table-td"></td>
              </tr>
            </template>
            <tr v-else v-for="c in customers" :key="c.id" class="hover:bg-ink-50 cursor-pointer" @click="navigateTo(`/customers/${c.id}`)">
              <td class="table-td">
                <div class="flex items-center gap-3">
                  <div class="w-8 h-8 rounded-full bg-brand-100/50 text-brand-700 flex items-center justify-center text-xs font-semibold">{{ (c.first_name?.[0] || c.email?.[0] || '?').toUpperCase() }}</div>
                  <div>
                    <div class="font-medium text-ink-900">{{ c.first_name }} {{ c.last_name }}</div>
                    <div class="text-xs text-ink-500 font-mono">{{ c.external_id }}</div>
                  </div>
                  <span v-if="c.is_blacklisted" class="chip bg-red-50 text-red-600">Blacklisted</span>
                </div>
              </td>
              <td class="table-td"><div class="text-sm">{{ c.email }}</div><div class="text-xs text-ink-500">{{ c.phone }}</div></td>
              <td class="table-td text-sm">{{ c.city }} <span class="text-ink-500">{{ c.country }}</span></td>
              <td class="table-td"><span class="chip bg-ink-100 text-ink-700 capitalize">{{ c.platform || 'unknown' }}</span></td>
              <td class="table-td text-sm text-ink-500">{{ timeAgo(c.last_seen_at) }}</td>
              <td class="table-td text-right"><Icon name="chevronRight" class="text-ink-300"/></td>
            </tr>
          </tbody>
        </table>
        <EmptyState v-if="!loading && !customers.length" icon="users" title="No customers yet" subtitle="Add your first customer or import a CSV file to get started.">
          <button @click="openNew = true" class="btn-primary"><Icon name="plus"/>Add customer</button>
        </EmptyState>
        <Pagination v-model:page="page" v-model:pageSize="pageSize" :total="total"/>
      </div>
    </div>

    <Modal v-model="openNew" title="Add customer" subtitle="Create a new customer profile.">
      <form id="newcf" @submit.prevent="createCustomer" class="space-y-3">
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label">External ID *</label><input v-model="form.external_id" class="input" required/></div>
          <div><label class="label">Email</label><input v-model="form.email" class="input" type="email"/></div>
          <div><label class="label">First name</label><input v-model="form.first_name" class="input"/></div>
          <div><label class="label">Last name</label><input v-model="form.last_name" class="input"/></div>
          <div><label class="label">Phone</label><input v-model="form.phone" class="input"/></div>
          <div><label class="label">Platform</label>
            <select v-model="form.platform" class="input">
              <option value="web">Web</option><option value="ios">iOS</option><option value="android">Android</option>
            </select>
          </div>
          <div><label class="label">City</label><input v-model="form.city" class="input"/></div>
          <div><label class="label">Country</label><input v-model="form.country" class="input"/></div>
        </div>
      </form>
      <template #footer>
        <button @click="openNew = false" class="btn-secondary">Cancel</button>
        <button form="newcf" type="submit" :disabled="saving" class="btn-primary">{{ saving ? 'Saving…' : 'Create' }}</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const customers = ref<any[]>([])
const total = ref(0)
const q = ref('')
const platformFilter = ref('')
const blacklistFilter = ref('')
const loading = ref(true)
const openNew = ref(false)
const saving = ref(false)
const page = ref(1)
const pageSize = ref(50)
const form = reactive({ external_id: '', email: '', first_name: '', last_name: '', phone: '', platform: 'web', city: '', country: '' })

async function load() {
  if (!workspaceId.value) return
  loading.value = true
  const from = (page.value - 1) * pageSize.value
  const to = from + pageSize.value - 1
  let query = supabase.from('customers').select('*', { count: 'exact' }).eq('workspace_id', workspaceId.value).order('created_at', { ascending: false }).range(from, to)
  if (q.value) query = query.or(`email.ilike.%${q.value}%,first_name.ilike.%${q.value}%,last_name.ilike.%${q.value}%,external_id.ilike.%${q.value}%`)
  if (platformFilter.value) query = query.eq('platform', platformFilter.value)
  if (blacklistFilter.value === 'yes') query = query.eq('is_blacklisted', true)
  if (blacklistFilter.value === 'no') query = query.eq('is_blacklisted', false)
  const { data, count } = await query
  customers.value = data || []
  total.value = count || 0
  loading.value = false
}

async function createCustomer() {
  saving.value = true
  await supabase.from('customers').insert({ ...form, workspace_id: workspaceId.value })
  saving.value = false
  openNew.value = false
  Object.assign(form, { external_id: '', email: '', first_name: '', last_name: '', phone: '', platform: 'web', city: '', country: '' })
  await load()
}

watch([q, platformFilter, blacklistFilter, pageSize], () => { page.value = 1 })
watch([workspaceId, q, platformFilter, blacklistFilter, page, pageSize], load, { immediate: true })
</script>
