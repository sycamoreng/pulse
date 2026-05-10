<template>
  <div>
    <PageHeader title="Blacklist" subtitle="Users who should never receive engagement."/>
    <div class="p-8">
      <div class="card overflow-hidden">
        <table class="w-full">
          <thead><tr><th class="table-th">Customer</th><th class="table-th">Email</th><th class="table-th">Added</th><th class="table-th"></th></tr></thead>
          <tbody>
            <tr v-for="c in list" :key="c.id">
              <td class="table-td">{{ c.first_name }} {{ c.last_name }}</td>
              <td class="table-td">{{ c.email }}</td>
              <td class="table-td text-xs text-ink-500">{{ timeAgo(c.created_at) }}</td>
              <td class="table-td text-right"><button @click="unblock(c)" class="btn-ghost text-sm">Unblock</button></td>
            </tr>
          </tbody>
        </table>
        <EmptyState v-if="!list.length" icon="shield" title="Nobody is blacklisted" subtitle="Blacklist a customer from their profile to exclude them."/>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId } = useWorkspace()
const list = ref<any[]>([])
async function load() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('customers').select('*').eq('workspace_id', workspaceId.value).eq('is_blacklisted', true).order('created_at', { ascending: false })
  list.value = data || []
}
async function unblock(c: any) {
  await supabase.from('customers').update({ is_blacklisted: false }).eq('id', c.id)
  await load()
}
watch(workspaceId, load, { immediate: true })
</script>
