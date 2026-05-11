<template>
  <div class="min-h-screen flex flex-col items-center justify-center px-4 py-10 bg-gradient-to-br from-ink-50 via-white to-brand-100/40 dark:from-[color:var(--surface-app)] dark:via-[color:var(--surface-app)] dark:to-[color:var(--surface-muted)] transition-colors">
    <div class="w-full max-w-xl">
      <!-- Loading -->
      <div v-if="loading" class="card p-10 text-center">
        <div class="w-10 h-10 rounded-full border-2 border-ink-200 dark:border-[color:var(--border-subtle)] border-t-brand-500 animate-spin mx-auto"></div>
        <div class="mt-4 text-sm text-ink-500 dark:text-[color:var(--text-tertiary)]">Loading survey…</div>
      </div>

      <!-- Not available -->
      <div v-else-if="notFound" class="card p-10 text-center">
        <div class="w-14 h-14 rounded-full bg-red-100 dark:bg-red-500/15 text-red-600 dark:text-red-400 flex items-center justify-center mx-auto">
          <Icon name="alert" class="w-6 h-6"/>
        </div>
        <div class="mt-4 text-lg font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">This survey isn't available</div>
        <div class="mt-1 text-sm text-ink-500 dark:text-[color:var(--text-tertiary)]">It may have ended or the link is invalid.</div>
      </div>

      <!-- Submitted -->
      <div v-else-if="submitted" class="card p-10 text-center">
        <div class="relative w-16 h-16 mx-auto">
          <div class="absolute inset-0 rounded-full bg-accent-500/15 animate-ping"></div>
          <div class="relative w-16 h-16 rounded-full bg-accent-500/20 dark:bg-accent-500/25 text-accent-500 flex items-center justify-center">
            <Icon name="check" class="w-7 h-7"/>
          </div>
        </div>
        <div class="mt-5 text-xl font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">{{ thankYou }}</div>
        <div class="mt-1 text-sm text-ink-500 dark:text-[color:var(--text-tertiary)]">Your response was recorded. You can close this tab.</div>
      </div>

      <!-- Step-by-step form -->
      <div v-else class="card p-0 overflow-hidden">
        <!-- Progress bar -->
        <div class="h-1 bg-ink-100 dark:bg-[color:var(--surface-muted)]">
          <div class="h-full bg-brand-500 transition-all duration-500" :style="{ width: progressPct + '%' }"></div>
        </div>

        <div class="p-8">
          <div class="flex items-center justify-between mb-2">
            <div class="text-[11px] font-semibold uppercase tracking-[0.2em] text-brand-500">{{ typeLabel }}</div>
            <div class="text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)]">{{ currentStep + 1 }} of {{ totalSteps }}</div>
          </div>
          <div class="text-xl font-semibold text-ink-900 dark:text-[color:var(--text-primary)] leading-snug">{{ survey.name }}</div>
          <div v-if="survey.description && currentStep === 0" class="text-sm text-ink-500 dark:text-[color:var(--text-tertiary)] mt-2">{{ survey.description }}</div>

          <transition
            :name="transitionDir === 'forward' ? 'slide-fwd' : 'slide-back'"
            mode="out-in"
          >
            <div :key="currentStep" class="mt-6">
              <template v-if="currentStep < fields.length">
                <label class="block">
                  <span class="text-base font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">{{ currentField.label }}<span v-if="currentField.required" class="text-red-500"> *</span></span>
                  <span v-if="currentField.help" class="block text-xs text-ink-500 dark:text-[color:var(--text-tertiary)] mt-1">{{ currentField.help }}</span>
                </label>

                <div class="mt-5">
                  <!-- Scale -->
                  <div v-if="currentField.type === 'scale'">
                    <div class="flex gap-1 flex-wrap">
                      <button
                        v-for="n in scaleRange(currentField)"
                        :key="n"
                        type="button"
                        class="flex-1 min-w-[36px] h-11 rounded-md border text-sm font-medium transition active:scale-95"
                        :class="answers[currentField.id] === n
                          ? 'bg-brand-500 text-white border-brand-500 shadow-soft'
                          : 'bg-white dark:bg-[color:var(--surface-card)] text-ink-700 dark:text-[color:var(--text-secondary)] border-ink-100 dark:border-[color:var(--border-subtle)] hover:border-brand-500'"
                        @click="pickAndAdvance(currentField, n)"
                      >{{ n }}</button>
                    </div>
                    <div v-if="currentField.min_label || currentField.max_label" class="flex justify-between text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)] mt-2">
                      <span>{{ currentField.min_label }}</span><span>{{ currentField.max_label }}</span>
                    </div>
                  </div>

                  <!-- Emoji rating -->
                  <div v-else-if="currentField.type === 'rating'" class="flex gap-3 justify-between">
                    <button
                      v-for="n in (currentField.max || 5)"
                      :key="n"
                      type="button"
                      class="flex-1 aspect-square rounded-full border-2 flex items-center justify-center text-3xl transition active:scale-95"
                      :class="answers[currentField.id] === n
                        ? 'border-brand-500 bg-brand-500/10 dark:bg-brand-500/20 scale-105'
                        : 'border-ink-100 dark:border-[color:var(--border-subtle)] hover:border-brand-500'"
                      @click="pickAndAdvance(currentField, n)"
                    >{{ ratingEmoji(n, currentField.max || 5) }}</button>
                  </div>

                  <!-- Short text -->
                  <input
                    v-else-if="currentField.type === 'short_text'"
                    v-model="answers[currentField.id]"
                    :placeholder="currentField.placeholder || ''"
                    class="input !text-base !py-3"
                    @keydown.enter.prevent="next"
                  />

                  <!-- Long text -->
                  <textarea
                    v-else-if="currentField.type === 'long_text'"
                    v-model="answers[currentField.id]"
                    rows="5"
                    :placeholder="currentField.placeholder || 'Type your answer…'"
                    class="input !text-base"
                  ></textarea>

                  <!-- Single choice -->
                  <div v-else-if="currentField.type === 'single_choice'" class="space-y-2">
                    <button
                      v-for="opt in (currentField.options || [])"
                      :key="opt"
                      type="button"
                      class="w-full text-left px-4 py-3 rounded-lg border-2 transition active:scale-[.99]"
                      :class="answers[currentField.id] === opt
                        ? 'border-brand-500 bg-brand-500/5 dark:bg-brand-500/15 text-ink-900 dark:text-[color:var(--text-primary)]'
                        : 'border-ink-100 dark:border-[color:var(--border-subtle)] text-ink-800 dark:text-[color:var(--text-secondary)] hover:border-brand-500'"
                      @click="pickAndAdvance(currentField, opt)"
                    >
                      <span class="text-sm font-medium">{{ opt }}</span>
                    </button>
                  </div>

                  <!-- Multi choice -->
                  <div v-else-if="currentField.type === 'multi_choice'" class="space-y-2">
                    <button
                      v-for="opt in (currentField.options || [])"
                      :key="opt"
                      type="button"
                      class="w-full text-left px-4 py-3 rounded-lg border-2 transition flex items-center gap-3"
                      :class="(answers[currentField.id] || []).includes(opt)
                        ? 'border-brand-500 bg-brand-500/5 dark:bg-brand-500/15'
                        : 'border-ink-100 dark:border-[color:var(--border-subtle)] hover:border-brand-500'"
                      @click="toggleMulti(currentField.id, opt)"
                    >
                      <span class="w-5 h-5 rounded flex items-center justify-center border-2"
                        :class="(answers[currentField.id] || []).includes(opt) ? 'bg-brand-500 border-brand-500 text-white' : 'border-ink-300 dark:border-[color:var(--border-subtle)]'">
                        <Icon v-if="(answers[currentField.id] || []).includes(opt)" name="check" class="w-3 h-3"/>
                      </span>
                      <span class="text-sm font-medium text-ink-800 dark:text-[color:var(--text-secondary)]">{{ opt }}</span>
                    </button>
                  </div>

                  <!-- Email -->
                  <input
                    v-else-if="currentField.type === 'email'"
                    v-model="answers[currentField.id]"
                    type="email"
                    :placeholder="currentField.placeholder || 'you@example.com'"
                    class="input !text-base !py-3"
                    @keydown.enter.prevent="next"
                  />

                  <!-- Number -->
                  <input
                    v-else-if="currentField.type === 'number'"
                    v-model.number="answers[currentField.id]"
                    type="number"
                    :min="currentField.min"
                    :max="currentField.max"
                    :placeholder="currentField.placeholder || ''"
                    class="input !text-base !py-3"
                    @keydown.enter.prevent="next"
                  />
                </div>
              </template>
              <template v-else-if="currentStep === fields.length && showEmailStep">
                <label class="block">
                  <span class="text-base font-semibold text-ink-900 dark:text-[color:var(--text-primary)]">One last thing (optional)</span>
                  <span class="block text-xs text-ink-500 dark:text-[color:var(--text-tertiary)] mt-1">Share your email so we can follow up if needed.</span>
                </label>
                <input v-model="respondentEmail" type="email" class="input !text-base !py-3 mt-4" placeholder="you@example.com"/>
              </template>
            </div>
          </transition>

          <div v-if="error" class="mt-4 text-xs text-red-600 dark:text-red-400">{{ error }}</div>

          <!-- Nav buttons -->
          <div class="mt-7 flex items-center justify-between gap-3">
            <button
              type="button"
              class="btn-ghost text-sm"
              :disabled="currentStep === 0"
              @click="back"
            >
              <Icon name="arrow-left" class="w-4 h-4"/>Back
            </button>

            <div class="flex items-center gap-2">
              <span class="hidden md:inline text-[11px] text-ink-500 dark:text-[color:var(--text-tertiary)]">
                <kbd class="px-1.5 py-0.5 rounded bg-ink-100 dark:bg-[color:var(--surface-muted)] border border-ink-200 dark:border-[color:var(--border-subtle)] text-[10px] font-sans">Enter</kbd>
                to continue
              </span>
              <button
                v-if="!isLastStep"
                type="button"
                class="btn-primary"
                :disabled="!stepValid"
                @click="next"
              >
                Next
                <Icon name="arrowRight" class="w-4 h-4"/>
              </button>
              <button
                v-else
                type="button"
                class="btn-primary"
                :disabled="submitting || !stepValid"
                @click="submit"
              >
                {{ submitting ? 'Submitting…' : 'Submit' }}
                <Icon v-if="!submitting" name="check" class="w-4 h-4"/>
              </button>
            </div>
          </div>
        </div>
      </div>

      <div class="text-center text-[11px] text-ink-400 dark:text-[color:var(--text-muted)] mt-6">Powered by Pulse</div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'blank' })

const route = useRoute()
const { $supabase } = useNuxtApp()

const loading = ref(true)
const notFound = ref(false)
const submitted = ref(false)
const submitting = ref(false)
const error = ref('')
const survey = ref<any>(null)
const thankYou = ref('Thanks for your feedback!')
const answers = reactive<Record<string, any>>({})
const respondentEmail = ref('')

const currentStep = ref(0)
const transitionDir = ref<'forward' | 'back'>('forward')

const surveyId = computed(() => String(route.params.id))
const customerId = computed(() => (route.query.cid as string) || null)

const typeLabel = computed(() => ({
  nps: 'Net Promoter Score',
  csat: 'Customer Satisfaction',
  ces: 'Customer Effort Score',
  open: 'Feedback',
} as any)[survey.value?.survey_type] || 'Survey')

const fields = computed<any[]>(() => {
  const schema = survey.value?.form_schema
  if (Array.isArray(schema) && schema.length) return schema
  return buildLegacyFields(survey.value)
})

const showEmailStep = computed(() => !customerId.value && !fields.value.some(f => f.type === 'email'))
const totalSteps = computed(() => fields.value.length + (showEmailStep.value ? 1 : 0))
const isLastStep = computed(() => currentStep.value === totalSteps.value - 1)
const currentField = computed(() => fields.value[currentStep.value])
const progressPct = computed(() => totalSteps.value ? ((currentStep.value + 1) / totalSteps.value) * 100 : 0)

const stepValid = computed(() => {
  if (currentStep.value >= fields.value.length) return true
  const f = currentField.value
  if (!f?.required) return true
  const v = answers[f.id]
  if (v === undefined || v === null || v === '') return false
  if (Array.isArray(v) && !v.length) return false
  return true
})

function buildLegacyFields(s: any): any[] {
  if (!s) return []
  const q = s.question || 'Your feedback'
  const follow = s.follow_up || 'Anything else to share?'
  switch (s.survey_type) {
    case 'nps':
      return [
        { id: 'score', type: 'scale', label: q, required: true, min: 0, max: 10, min_label: 'Not likely', max_label: 'Extremely likely' },
        { id: 'comment', type: 'long_text', label: follow, required: false, placeholder: 'Optional — tell us more…' },
      ]
    case 'csat':
      return [
        { id: 'score', type: 'rating', label: q, required: true, max: 5 },
        { id: 'comment', type: 'long_text', label: follow, required: false },
      ]
    case 'ces':
      return [
        { id: 'score', type: 'scale', label: q, required: true, min: 1, max: 7, min_label: 'Very difficult', max_label: 'Very easy' },
        { id: 'comment', type: 'long_text', label: follow, required: false },
      ]
    default:
      return [
        { id: 'answer', type: 'long_text', label: q, required: true, placeholder: 'Type your feedback…' },
      ]
  }
}

function scaleRange(f: any) {
  const min = f.min ?? 0
  const max = f.max ?? 10
  const arr: number[] = []
  for (let i = min; i <= max; i++) arr.push(i)
  return arr
}
function ratingEmoji(n: number, max: number) {
  if (max === 5) return ['\u{1F622}','\u{1F610}','\u{1F642}','\u{1F600}','\u{1F929}'][n - 1]
  if (max === 3) return ['\u{1F641}','\u{1F610}','\u{1F600}'][n - 1]
  return String(n)
}
function toggleMulti(fid: string, opt: string) {
  const cur = Array.isArray(answers[fid]) ? [...answers[fid]] : []
  const idx = cur.indexOf(opt)
  if (idx >= 0) cur.splice(idx, 1); else cur.push(opt)
  answers[fid] = cur
}
function pickAndAdvance(f: any, value: any) {
  answers[f.id] = value
  if (f.type === 'scale' || f.type === 'rating' || f.type === 'single_choice') {
    setTimeout(() => next(), 180)
  }
}
function next() {
  if (!stepValid.value) return
  if (isLastStep.value) { submit(); return }
  transitionDir.value = 'forward'
  currentStep.value += 1
}
function back() {
  if (currentStep.value === 0) return
  transitionDir.value = 'back'
  currentStep.value -= 1
}

async function load() {
  loading.value = true
  const { data } = await $supabase.rpc('public_get_survey', { p_id: surveyId.value })
  const row = Array.isArray(data) ? data[0] : data
  if (!row) { notFound.value = true; loading.value = false; return }
  survey.value = row
  thankYou.value = row.thank_you || thankYou.value
  for (const f of fields.value) {
    if (f.type === 'multi_choice') answers[f.id] = []
    else answers[f.id] = null
  }
  await $supabase.rpc('increment_survey_impression', { p_id: surveyId.value })
  loading.value = false
}

async function submit() {
  if (submitting.value) return
  submitting.value = true
  error.value = ''
  const { data, error: rpcErr } = await $supabase.rpc('submit_survey_form_response', {
    p_survey_id: surveyId.value,
    p_answers: answers,
    p_customer_id: customerId.value,
    p_customer_email: respondentEmail.value || null,
  })
  submitting.value = false
  if (rpcErr) { error.value = rpcErr.message; return }
  if (!(data as any)?.ok) { error.value = (data as any)?.error || 'Could not submit'; return }
  thankYou.value = (data as any).thank_you || thankYou.value
  submitted.value = true
}

function onKey(e: KeyboardEvent) {
  if (loading.value || submitted.value || notFound.value) return
  if (e.key === 'Enter' && !(e.target instanceof HTMLTextAreaElement)) {
    e.preventDefault()
    if (isLastStep.value) submit(); else next()
  }
}

onMounted(() => {
  load()
  window.addEventListener('keydown', onKey)
})
onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
</script>

<style scoped>
.slide-fwd-enter-active, .slide-fwd-leave-active,
.slide-back-enter-active, .slide-back-leave-active {
  transition: all 260ms cubic-bezier(.4, 0, .2, 1);
}
.slide-fwd-enter-from { opacity: 0; transform: translateX(16px); }
.slide-fwd-leave-to   { opacity: 0; transform: translateX(-16px); }
.slide-back-enter-from { opacity: 0; transform: translateX(-16px); }
.slide-back-leave-to   { opacity: 0; transform: translateX(16px); }
</style>
