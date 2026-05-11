<template>
  <div v-if="visible" class="space-y-2">
    <div
      v-if="state.sendingPaused"
      class="rounded-xl border border-red-200 bg-red-50 p-4 flex items-start gap-3"
    >
      <div class="w-8 h-8 rounded-lg bg-red-500/15 text-red-600 flex items-center justify-center shrink-0">
        <Icon name="shield" class="w-4 h-4"/>
      </div>
      <div class="flex-1 min-w-0">
        <div class="text-sm font-semibold text-red-900">Sending paused for this workspace</div>
        <div class="text-xs text-red-700 mt-0.5">{{ state.pauseReason || 'An admin paused outbound sends. Resume to continue delivering messages.' }}</div>
      </div>
    </div>

    <div
      v-for="c in displayChannels"
      :key="c.channel"
      :class="['rounded-xl border p-4 flex items-start gap-3', toneClass(c)]"
    >
      <div :class="['w-8 h-8 rounded-lg flex items-center justify-center shrink-0', iconTone(c)]">
        <Icon :name="iconFor(c.channel)" class="w-4 h-4"/>
      </div>
      <div class="flex-1 min-w-0">
        <div class="text-sm font-semibold" :class="titleTone(c)">
          {{ channelLabel(c.channel) }} {{ c.blockers.length ? 'not ready to send' : 'needs attention' }}
        </div>
        <ul class="mt-1.5 space-y-1">
          <li v-for="(b, i) in [...c.blockers, ...c.warnings]" :key="i" class="text-xs flex items-center gap-2" :class="bodyTone(c)">
            <span>{{ b.reason }} — {{ b.fix }}</span>
            <NuxtLink :to="b.to" class="font-medium underline hover:no-underline whitespace-nowrap">{{ b.cta }}</NuxtLink>
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { ChannelKey, ChannelStatus } from '~/composables/useChannelReadiness'

const props = defineProps<{
  channels?: ChannelKey[]
  only?: ChannelKey
  compact?: boolean
  showWarnings?: boolean
}>()

const { state } = useChannelReadiness()

const channelList = computed<ChannelKey[]>(() => {
  if (props.only) return [props.only]
  return props.channels && props.channels.length ? props.channels : ['email', 'push']
})

const displayChannels = computed<ChannelStatus[]>(() => {
  return channelList.value
    .map(k => state.channels[k])
    .filter(c => {
      if (!c) return false
      if (c.blockers.length) return true
      if (props.showWarnings !== false && c.warnings.length) return true
      return false
    })
})

const visible = computed(() => state.sendingPaused || displayChannels.value.length > 0)

function iconFor(c: ChannelKey) {
  switch (c) {
    case 'email': return 'mail'
    case 'push': return 'bell'
    case 'sms': return 'message'
    case 'inapp': return 'layers'
    default: return 'activity'
  }
}
function channelLabel(c: ChannelKey) {
  return { email: 'Email', push: 'Push', sms: 'SMS', inapp: 'In-app', webhook: 'Webhook' }[c]
}
function toneClass(c: ChannelStatus) {
  return c.blockers.length ? 'border-amber-200 bg-amber-50' : 'border-ink-100 bg-ink-50'
}
function iconTone(c: ChannelStatus) {
  return c.blockers.length ? 'bg-amber-500/15 text-amber-700' : 'bg-ink-200 text-ink-700'
}
function titleTone(c: ChannelStatus) {
  return c.blockers.length ? 'text-amber-900' : 'text-ink-900'
}
function bodyTone(c: ChannelStatus) {
  return c.blockers.length ? 'text-amber-800' : 'text-ink-600'
}
</script>
