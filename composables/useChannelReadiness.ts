export type ChannelKey = 'email' | 'push' | 'sms' | 'inapp' | 'webhook'

export type ChannelBlocker = {
  reason: string
  fix: string
  to: string
  cta: string
}

export type ChannelStatus = {
  channel: ChannelKey
  ready: boolean
  blockers: ChannelBlocker[]
  warnings: ChannelBlocker[]
}

export type ReadinessSnapshot = {
  loading: boolean
  sendingPaused: boolean
  pauseReason: string
  channels: Record<ChannelKey, ChannelStatus>
}

const emptyStatus = (channel: ChannelKey): ChannelStatus => ({ channel, ready: false, blockers: [], warnings: [] })

const state = reactive<ReadinessSnapshot>({
  loading: true,
  sendingPaused: false,
  pauseReason: '',
  channels: {
    email: emptyStatus('email'),
    push: emptyStatus('push'),
    sms: emptyStatus('sms'),
    inapp: emptyStatus('inapp'),
    webhook: emptyStatus('webhook'),
  },
})

let currentWorkspaceId: string | null = null

async function refresh(force = false) {
  const { supabase, workspaceId } = useWorkspace()
  const wsId = workspaceId.value
  if (!wsId) return
  if (!force && wsId === currentWorkspaceId && !state.loading) return
  currentWorkspaceId = wsId
  state.loading = true

  const [wsRes, domainsRes, sendersRes, providersRes, appsRes] = await Promise.all([
    supabase.from('workspaces').select('sending_paused,sending_paused_reason').eq('id', wsId).maybeSingle(),
    supabase.from('email_domains').select('id,status,spf_status,dkim_status,dmarc_status').eq('workspace_id', wsId),
    supabase.from('email_senders').select('id,verified,is_default,domain_id').eq('workspace_id', wsId),
    supabase.from('email_providers').select('id,is_active,stream').eq('workspace_id', wsId),
    supabase.from('apps').select('id,push_platform,vapid_public_key,fcm_server_key,apns_p8').eq('workspace_id', wsId),
  ])

  state.sendingPaused = !!wsRes.data?.sending_paused
  state.pauseReason = wsRes.data?.sending_paused_reason || ''

  // Email
  const email = emptyStatus('email')
  const verifiedDomain = (domainsRes.data || []).find(d => d.status === 'verified')
  const anyDomain = (domainsRes.data || [])[0]
  const defaultSender = (sendersRes.data || []).find(s => s.is_default) || (sendersRes.data || [])[0]
  const activeProvider = (providersRes.data || []).find(p => p.is_active)

  if (!anyDomain) {
    email.blockers.push({
      reason: 'No sending domain added',
      fix: 'Add your domain and publish the DNS records we provide.',
      to: '/settings',
      cta: 'Add domain',
    })
  } else if (!verifiedDomain) {
    email.blockers.push({
      reason: 'Domain DNS is not verified',
      fix: 'Publish SPF, DKIM, and DMARC records, then run verification.',
      to: '/settings',
      cta: 'Verify DNS',
    })
  } else {
    if (verifiedDomain.spf_status !== 'verified') email.warnings.push({ reason: 'SPF not confirmed', fix: 'Publish the SPF TXT record for best inbox placement.', to: '/settings', cta: 'Fix SPF' })
    if (verifiedDomain.dkim_status !== 'verified') email.warnings.push({ reason: 'DKIM not confirmed', fix: 'Publish the DKIM record to sign outbound mail.', to: '/settings', cta: 'Fix DKIM' })
    if (verifiedDomain.dmarc_status !== 'verified') email.warnings.push({ reason: 'DMARC not configured', fix: 'Add a DMARC policy to protect your domain.', to: '/settings', cta: 'Fix DMARC' })
  }

  if (!defaultSender) {
    email.blockers.push({
      reason: 'No sender identity',
      fix: 'Add a From address and confirm the verification email.',
      to: '/settings',
      cta: 'Add sender',
    })
  } else if (!defaultSender.verified) {
    email.blockers.push({
      reason: 'Sender email not verified',
      fix: 'Open the confirmation email we sent to your From address.',
      to: '/settings',
      cta: 'Resend verification',
    })
  }

  email.ready = email.blockers.length === 0
  state.channels.email = email

  // Push
  const push = emptyStatus('push')
  const apps = appsRes.data || []
  const webApp = apps.find(a => a.push_platform === 'web' && a.vapid_public_key)
  const mobileApp = apps.find(a => (a.push_platform === 'ios' && a.apns_p8) || (a.push_platform === 'android' && a.fcm_server_key))
  if (!apps.length) {
    push.blockers.push({
      reason: 'No push apps configured',
      fix: 'Register a web, iOS, or Android app to send push notifications.',
      to: '/apps',
      cta: 'Add app',
    })
  } else if (!webApp && !mobileApp) {
    push.blockers.push({
      reason: 'Push credentials missing',
      fix: 'Generate VAPID keys (web), upload APNs .p8 (iOS), or add your FCM server key (Android).',
      to: '/apps',
      cta: 'Configure push',
    })
  }
  push.ready = push.blockers.length === 0
  state.channels.push = push

  // SMS
  const sms = emptyStatus('sms')
  sms.blockers.push({
    reason: 'SMS not configured for this workspace',
    fix: 'Connect an SMS provider (Twilio, MessageBird, Vonage) to unlock SMS sends.',
    to: '/integrations',
    cta: 'Connect SMS provider',
  })
  sms.ready = false
  state.channels.sms = sms

  // In-app
  state.channels.inapp = { channel: 'inapp', ready: true, blockers: [], warnings: [] }

  // Webhook
  state.channels.webhook = { channel: 'webhook', ready: true, blockers: [], warnings: [] }

  state.loading = false
}

export const useChannelReadiness = () => {
  const { workspaceId } = useWorkspace()
  watch(workspaceId, () => { refresh(true) }, { immediate: true })

  const ready = (channel: ChannelKey) => !state.sendingPaused && state.channels[channel]?.ready
  const status = (channel: ChannelKey) => state.channels[channel]
  const anyBlockers = (channel: ChannelKey) => (state.channels[channel]?.blockers || []).length > 0

  return {
    state: readonly(state),
    refresh: () => refresh(true),
    ready,
    status,
    anyBlockers,
  }
}
