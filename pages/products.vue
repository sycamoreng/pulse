<template>
  <div>
    <PageHeader title="Products" subtitle="Your product catalog. Used for recommendations, abandoned cart, and attribution.">
      <template #actions>
        <button @click="edit(null)" class="btn-primary"><Icon name="plus"/>Add product</button>
      </template>
    </PageHeader>

    <div class="p-8 space-y-4">
      <div class="card p-4 flex items-center gap-3">
        <input v-model="search" placeholder="Search by title" class="input flex-1 max-w-sm"/>
        <div class="text-xs text-ink-500 ml-auto">
          Sync products automatically by hooking your store's <span class="font-mono">order_created</span> and <span class="font-mono">product_updated</span> webhooks to
          <span class="font-mono">{{ webhookUrl }}</span>
        </div>
      </div>

      <div v-if="!products.length" class="card">
        <EmptyState icon="box" title="No products yet" subtitle="Add a product or connect your store to start recommending.">
          <button @click="edit(null)" class="btn-primary"><Icon name="plus"/>Add product</button>
        </EmptyState>
      </div>
      <div v-else class="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div v-for="p in filtered" :key="p.id" class="card overflow-hidden hover:shadow-md transition cursor-pointer" @click="edit(p)">
          <div class="aspect-square bg-ink-100 overflow-hidden">
            <img v-if="p.image_url" :src="p.image_url" :alt="p.title" class="w-full h-full object-cover"/>
            <div v-else class="w-full h-full flex items-center justify-center text-ink-300"><Icon name="box" class="w-10 h-10"/></div>
          </div>
          <div class="p-3">
            <div class="text-sm font-semibold text-ink-900 truncate">{{ p.title || 'Untitled' }}</div>
            <div class="text-xs text-ink-500">{{ p.currency }} {{ Number(p.price).toFixed(2) }}</div>
            <div class="mt-1 flex items-center gap-1">
              <span v-if="!p.in_stock" class="chip bg-red-100 text-red-700 text-[10px]">out of stock</span>
              <span v-else class="chip bg-accent-500/10 text-accent-500 text-[10px]">in stock</span>
              <span class="chip bg-ink-100 text-ink-700 text-[10px] capitalize">{{ p.source }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <Modal v-model="open" :title="editing?.id ? editing.title : 'Add product'" size="lg">
      <form id="prodf" @submit.prevent="save" class="grid grid-cols-2 gap-3">
        <div class="col-span-2"><label class="label">Title *</label><input v-model="form.title" class="input" required/></div>
        <div class="col-span-2"><label class="label">Description</label><textarea v-model="form.description" rows="3" class="input"></textarea></div>
        <div><label class="label">Price</label><input v-model.number="form.price" type="number" step="0.01" min="0" class="input"/></div>
        <div><label class="label">Currency</label><input v-model="form.currency" class="input"/></div>
        <div class="col-span-2"><label class="label">Image URL</label><input v-model="form.image_url" class="input" placeholder="https://..."/></div>
        <div class="col-span-2"><label class="label">Product URL</label><input v-model="form.product_url" class="input" placeholder="https://..."/></div>
        <div><label class="label">External ID</label><input v-model="form.external_id" class="input" required/></div>
        <div><label class="label">Source</label><input v-model="form.source" class="input"/></div>
        <label class="flex items-center gap-2 col-span-2"><input type="checkbox" v-model="form.in_stock"/> In stock</label>
      </form>
      <template #footer>
        <button v-if="editing?.id" @click="remove" class="btn-ghost text-red-600 mr-auto"><Icon name="trash"/>Delete</button>
        <button @click="open = false" class="btn-secondary">Cancel</button>
        <button form="prodf" type="submit" class="btn-primary">Save</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'
const { supabase, workspaceId } = useWorkspace()
const auth = useAuthStore()
watchEffect(() => {
  if (auth.workspace && !auth.workspace.commerce_enabled) navigateTo('/settings')
})
const products = ref<any[]>([])
const search = ref('')
const open = ref(false)
const editing = ref<any>(null)
const form = reactive<any>({ title: '', description: '', price: 0, currency: 'USD', image_url: '', product_url: '', external_id: '', source: 'manual', in_stock: true })

const webhookUrl = computed(() => `${useRuntimeConfig().public.supabaseUrl}/functions/v1/commerce-webhook?workspace_id=${workspaceId.value || ''}&source=shopify`)

const filtered = computed(() => {
  const q = search.value.toLowerCase().trim()
  if (!q) return products.value
  return products.value.filter((p: any) => (p.title || '').toLowerCase().includes(q))
})

async function load() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('commerce_products').select('*').eq('workspace_id', workspaceId.value).order('updated_at', { ascending: false }).limit(200)
  products.value = data || []
}
function edit(p: any) {
  editing.value = p
  if (p) Object.assign(form, p)
  else Object.assign(form, { title: '', description: '', price: 0, currency: 'USD', image_url: '', product_url: '', external_id: `manual-${Date.now()}`, source: 'manual', in_stock: true })
  open.value = true
}
async function save() {
  const payload: any = { ...form, workspace_id: workspaceId.value, updated_at: new Date().toISOString() }
  const { error } = editing.value?.id
    ? await supabase.from('commerce_products').update(payload).eq('id', editing.value.id)
    : await supabase.from('commerce_products').upsert(payload, { onConflict: 'workspace_id,source,external_id' })
  if (error) { useToast().error('Save failed', error.message); return }
  useToast().success('Product saved')
  open.value = false
  await load()
}
async function remove() {
  const ok = await useConfirm().ask({ title: 'Remove product?', tone: 'danger', confirmText: 'Remove' })
  if (!ok) return
  await supabase.from('commerce_products').delete().eq('id', editing.value.id)
  open.value = false; await load()
}
watch(workspaceId, load, { immediate: true })
</script>
