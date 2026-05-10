<template>
  <div>
    <PageHeader title="Plans" subtitle="Pricing tiers and their limits.">
      <template #actions><button @click="edit(null)" class="btn-primary"><Icon name="plus"/>New plan</button></template>
    </PageHeader>
    <div class="p-8 grid md:grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="p in plans" :key="p.id" class="card p-5 cursor-pointer hover:shadow-md" @click="edit(p)">
        <div class="flex items-center justify-between">
          <div class="font-semibold text-ink-900">{{ p.name }}</div>
          <span v-if="!p.is_public" class="chip bg-ink-100 text-ink-700">hidden</span>
        </div>
        <div class="text-3xl font-bold text-ink-900 mt-3">${{ p.price_monthly }}<span class="text-xs text-ink-500">/mo</span></div>
        <ul class="text-xs text-ink-500 mt-4 space-y-1.5">
          <li>{{ p.email_monthly_quota.toLocaleString() }} emails/mo</li>
          <li>{{ p.sms_monthly_quota.toLocaleString() }} SMS/mo</li>
          <li>{{ p.seats }} seats</li>
        </ul>
      </div>
    </div>
    <Modal v-model="open" :title="editing?.id ? 'Edit plan' : 'New plan'" size="lg">
      <form id="plf" @submit.prevent="save" class="grid grid-cols-2 gap-3">
        <div><label class="label">Code</label><input v-model="form.code" class="input" required/></div>
        <div><label class="label">Name</label><input v-model="form.name" class="input" required/></div>
        <div class="col-span-2"><label class="label">Description</label><textarea v-model="form.description" rows="2" class="input"></textarea></div>
        <div><label class="label">Price/mo (USD)</label><input v-model.number="form.price_monthly" type="number" class="input"/></div>
        <div><label class="label">Seats</label><input v-model.number="form.seats" type="number" class="input"/></div>
        <div><label class="label">Email quota/mo</label><input v-model.number="form.email_monthly_quota" type="number" class="input"/></div>
        <div><label class="label">SMS quota/mo</label><input v-model.number="form.sms_monthly_quota" type="number" class="input"/></div>
        <div><label class="label">Push quota/mo</label><input v-model.number="form.push_monthly_quota" type="number" class="input"/></div>
        <div><label class="label">Sort order</label><input v-model.number="form.sort_order" type="number" class="input"/></div>
        <label class="flex items-center gap-2 col-span-2 mt-2"><input type="checkbox" v-model="form.is_public"/> Publicly listed</label>
      </form>
      <template #footer>
        <button @click="open = false" class="btn-secondary">Cancel</button>
        <button v-if="editing?.id" @click="remove" class="btn-ghost text-red-600 mr-auto"><Icon name="trash"/>Delete</button>
        <button form="plf" type="submit" class="btn-primary">Save</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })
const { $supabase } = useNuxtApp()
const plans = ref<any[]>([])
const open = ref(false)
const editing = ref<any>(null)
const form = reactive<any>({ code: '', name: '', description: '', price_monthly: 0, seats: 1, email_monthly_quota: 0, sms_monthly_quota: 0, push_monthly_quota: 0, sort_order: 1, is_public: true })

async function load() {
  const { data } = await $supabase.from('plans').select('*').order('sort_order')
  plans.value = data || []
}
function edit(p: any) {
  editing.value = p
  if (p) Object.assign(form, p)
  else Object.assign(form, { code: '', name: '', description: '', price_monthly: 0, seats: 1, email_monthly_quota: 0, sms_monthly_quota: 0, push_monthly_quota: 0, sort_order: 1, is_public: true })
  open.value = true
}
async function save() {
  const payload = { ...form }
  if (editing.value?.id) await $supabase.from('plans').update(payload).eq('id', editing.value.id)
  else await $supabase.from('plans').insert(payload)
  useToast().success('Plan saved')
  open.value = false; await load()
}
async function remove() {
  const ok = await useConfirm().ask({ title: 'Delete plan?', tone: 'danger', confirmText: 'Delete' })
  if (!ok) return
  await $supabase.from('plans').delete().eq('id', editing.value.id)
  useToast().success('Plan deleted')
  open.value = false; await load()
}
onMounted(load)
</script>
