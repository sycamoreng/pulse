<template>
  <div>
    <PageHeader title="In-App Banners" subtitle="Mobile in-app promotions for iOS and Android.">
      <template #actions>
        <button @click="edit(null)" class="btn-primary"><Icon name="plus"/>New banner</button>
      </template>
    </PageHeader>

    <div class="p-8 grid md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="b in banners" :key="b.id" class="card overflow-hidden hover:shadow-md cursor-pointer" @click="edit(b)">
        <div class="bg-gradient-to-b from-ink-50 to-white p-6 flex justify-center">
          <div class="w-48 h-80 rounded-3xl bg-ink-900 p-2 shadow-xl relative">
            <div class="w-full h-full bg-white rounded-2xl p-3 flex flex-col">
              <div class="h-1 w-12 bg-ink-100 rounded mx-auto mb-3"></div>
              <div class="rounded-lg overflow-hidden flex-1 flex flex-col justify-end" :style="{ background: auth.workspace?.brand_primary || '#3087B9', color: 'white' }">
                <img v-if="b.image_url" :src="b.image_url" class="w-full h-16 object-cover" alt=""/>
                <div class="p-3">
                  <div class="text-xs font-bold">{{ b.title || 'Banner title' }}</div>
                  <div class="text-[9px] opacity-80 line-clamp-2 mt-0.5">{{ b.body }}</div>
                  <div v-if="b.cta_text" class="mt-2 px-2 py-1 bg-white rounded text-[9px] font-bold text-center" :style="{ color: auth.workspace?.brand_primary || '#3087B9' }">{{ b.cta_text }}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div class="p-4">
          <div class="flex items-center justify-between">
            <div class="font-semibold text-ink-900 text-sm truncate">{{ b.name }}</div>
            <span class="chip" :class="b.status === 'active' ? 'bg-accent-500/10 text-accent-500' : 'bg-ink-100 text-ink-700'">{{ b.status }}</span>
          </div>
          <div class="text-xs text-ink-500 mt-1 capitalize">{{ b.platform }} · {{ b.impressions }} views · {{ b.clicks }} clicks</div>
        </div>
      </div>
      <button @click="edit(null)" class="card p-5 border-dashed flex flex-col items-center justify-center text-ink-500 hover:text-brand-500 hover:border-brand-500 min-h-[400px]">
        <Icon name="plus"/><div class="mt-2 text-sm font-medium">Create banner</div>
      </button>
    </div>

    <Modal v-model="open" :title="editing?.id ? 'Edit banner' : 'New in-app banner'" size="xl">
      <div class="grid grid-cols-2 gap-5">
        <form id="bf" @submit.prevent="save" class="space-y-3">
          <div class="grid grid-cols-2 gap-3">
            <div class="col-span-2"><label class="label">Name *</label><input v-model="form.name" class="input" required/></div>
            <div><label class="label">Platform</label>
              <select v-model="form.platform" class="input"><option value="both">iOS & Android</option><option value="ios">iOS</option><option value="android">Android</option></select>
            </div>
            <div><label class="label">Status</label>
              <select v-model="form.status" class="input"><option value="draft">Draft</option><option value="active">Active</option><option value="paused">Paused</option></select>
            </div>
            <div class="col-span-2"><label class="label">Title</label><input v-model="form.title" class="input"/></div>
            <div class="col-span-2"><label class="label">Body</label><textarea v-model="form.body" rows="2" class="input"></textarea></div>
            <div><label class="label">CTA text</label><input v-model="form.cta_text" class="input"/></div>
            <div><label class="label">CTA action (deeplink)</label><input v-model="form.cta_action" class="input" placeholder="app://products/1"/></div>
            <div class="col-span-2"><label class="label">Image URL</label><input v-model="form.image_url" class="input" type="url" placeholder="https://images.pexels.com/..."/></div>
          </div>
        </form>

        <div class="space-y-3">
          <div class="flex items-center justify-between">
            <label class="label !mb-0">Live preview</label>
            <div class="inline-flex rounded-lg border border-ink-100 overflow-hidden text-xs">
              <button type="button" @click="previewPlatform = 'ios'" class="px-3 py-1" :class="previewPlatform === 'ios' ? 'bg-brand-500 text-white' : 'text-ink-500'">iOS</button>
              <button type="button" @click="previewPlatform = 'android'" class="px-3 py-1" :class="previewPlatform === 'android' ? 'bg-brand-500 text-white' : 'text-ink-500'">Android</button>
            </div>
          </div>
          <div class="rounded-2xl border border-ink-100 bg-ink-50 p-6 flex justify-center">
            <div class="w-60 bg-ink-900 p-2 shadow-xl" :class="previewPlatform === 'ios' ? 'rounded-[2.5rem]' : 'rounded-2xl'">
              <div class="bg-white overflow-hidden relative" :class="previewPlatform === 'ios' ? 'rounded-[2rem] aspect-[9/18]' : 'rounded-lg aspect-[9/18]'">
                <div class="h-8 bg-white flex items-center justify-between px-5 text-[10px] text-ink-700 font-semibold">
                  <span>9:41</span>
                  <span>{{ previewPlatform === 'ios' ? '•••' : '≡' }}</span>
                </div>
                <div class="px-3 pt-2 pb-3 space-y-2">
                  <div v-for="i in 3" :key="i" class="h-10 rounded-lg bg-ink-50 flex items-center px-3">
                    <div class="w-6 h-6 rounded-full bg-ink-100"></div>
                    <div class="ml-2 flex-1 space-y-1">
                      <div class="h-1.5 bg-ink-100 rounded w-3/4"></div>
                      <div class="h-1.5 bg-ink-100 rounded w-1/2"></div>
                    </div>
                  </div>
                </div>
                <div class="absolute left-3 right-3 bottom-3 rounded-xl overflow-hidden shadow-xl" :style="{ background: auth.workspace?.brand_primary || '#3087B9' }">
                  <img v-if="form.image_url" :src="form.image_url" class="w-full h-20 object-cover" alt=""/>
                  <div class="p-3 text-white">
                    <div class="text-sm font-bold leading-snug">{{ form.title || 'Banner title' }}</div>
                    <div class="text-xs opacity-90 mt-1 leading-relaxed">{{ form.body || 'Write a short benefit here — keep it under two lines.' }}</div>
                    <button v-if="form.cta_text" type="button" class="mt-3 w-full py-2 rounded-lg bg-white text-xs font-bold" :style="{ color: auth.workspace?.brand_primary || '#3087B9' }">{{ form.cta_text }}</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="text-[11px] text-ink-500 text-center">Preview uses your workspace brand color. Deeplink <span class="font-mono text-ink-700">{{ form.cta_action || '—' }}</span> fires on tap.</div>
        </div>
      </div>
      <template #footer>
        <button @click="open = false" class="btn-secondary">Cancel</button>
        <button v-if="editing?.id" @click="remove" class="btn-ghost text-red-600 mr-auto"><Icon name="trash"/>Delete</button>
        <button form="bf" type="submit" class="btn-primary">Save</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
const { supabase, workspaceId, auth } = useWorkspace()
const audit = useAudit()
const banners = ref<any[]>([])
const open = ref(false)
const editing = ref<any>(null)
const previewPlatform = ref<'ios' | 'android'>('ios')
const form = reactive({ name: '', platform: 'both', status: 'draft', title: '', body: '', cta_text: '', cta_action: '', image_url: '' })

async function load() {
  if (!workspaceId.value) return
  const { data } = await supabase.from('inapp_banners').select('*').eq('workspace_id', workspaceId.value).order('created_at', { ascending: false })
  banners.value = data || []
}
function edit(b: any) {
  editing.value = b
  if (b) Object.assign(form, b)
  else Object.assign(form, { name: '', platform: 'both', status: 'draft', title: '', body: '', cta_text: '', cta_action: '', image_url: '' })
  previewPlatform.value = form.platform === 'android' ? 'android' : 'ios'
  open.value = true
}
async function save() {
  const payload: any = { name: form.name, platform: form.platform, status: form.status, title: form.title, body: form.body, cta_text: form.cta_text, cta_action: form.cta_action, image_url: form.image_url, workspace_id: workspaceId.value }
  const { data } = editing.value?.id
    ? await supabase.from('inapp_banners').update(payload).eq('id', editing.value.id).select().maybeSingle()
    : await supabase.from('inapp_banners').insert(payload).select().maybeSingle()
  audit.log(editing.value?.id ? 'update' : 'create', 'banner', data?.id || null, form.name, { platform: form.platform, status: form.status })
  useToast().success('Banner saved')
  open.value = false; await load()
}
async function remove() {
  const ok = await useConfirm().ask({ title: 'Delete banner?', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await supabase.from('inapp_banners').delete().eq('id', editing.value.id)
  audit.log('delete', 'banner', editing.value.id, editing.value.name)
  useToast().success('Banner deleted')
  open.value = false; await load()
}
watch(workspaceId, load, { immediate: true })
</script>
