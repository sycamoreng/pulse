export const useEngagement = () => {
  const { $supabase } = useNuxtApp()

  async function resolveAudience(workspaceId: string, type: string, id: string | null): Promise<string[]> {
    if (type === 'all') {
      const { data } = await $supabase.from('customers').select('id').eq('workspace_id', workspaceId).eq('is_blacklisted', false)
      return (data || []).map((c: any) => c.id)
    }
    if (type === 'list' && id) {
      const { data } = await $supabase.from('list_members').select('customer_id, customer:customers!inner(is_blacklisted)').eq('list_id', id)
      return (data || []).filter((m: any) => !m.customer?.is_blacklisted).map((m: any) => m.customer_id)
    }
    if (type === 'segment' && id) {
      const { data: seg } = await $supabase.from('segments').select('rules').eq('id', id).maybeSingle()
      let q = $supabase.from('customers').select('id').eq('workspace_id', workspaceId).eq('is_blacklisted', false)
      const conds = seg?.rules?.conditions || []
      for (const c of conds) {
        if (!c.value && c.op !== 'eq') continue
        if (c.op === 'eq') q = q.eq(c.field, c.value === 'true' ? true : c.value === 'false' ? false : c.value)
        else if (c.op === 'neq') q = q.neq(c.field, c.value)
        else if (c.op === 'ilike') q = q.ilike(c.field, `%${c.value}%`)
      }
      const { data } = await q
      return (data || []).map((c: any) => c.id)
    }
    return []
  }

  async function computeSendTimes(workspaceId: string, customerIds: string[], mode: string, respectTz: boolean): Promise<Record<string, string | null>> {
    const result: Record<string, string | null> = {}
    if (mode !== 'optimized' && mode !== 'timezone') {
      for (const cid of customerIds) result[cid] = null
      return result
    }

    // Pull last 60 days of events for this audience in batches
    const since = new Date(Date.now() - 60 * 24 * 3600 * 1000).toISOString()
    const batches: string[][] = []
    const size = 200
    for (let i = 0; i < customerIds.length; i += size) batches.push(customerIds.slice(i, i + size))

    const hourHits: Record<string, number[]> = {}
    for (const batch of batches) {
      const { data } = await $supabase
        .from('events')
        .select('customer_id, created_at')
        .eq('workspace_id', workspaceId)
        .in('customer_id', batch)
        .gte('created_at', since)
        .limit(5000)
      for (const e of (data || [])) {
        const arr = hourHits[e.customer_id] || (hourHits[e.customer_id] = new Array(24).fill(0))
        arr[new Date(e.created_at).getUTCHours()]++
      }
    }

    // Customer timezone offsets (city/country → rough offset)
    let tzMap: Record<string, number> = {}
    if (respectTz) {
      const { data: custs } = await $supabase
        .from('customers')
        .select('id, country')
        .in('id', customerIds)
      for (const c of (custs || [])) tzMap[c.id] = tzOffsetFor(c.country || 'UTC')
    }

    const now = new Date()
    const todayUtc = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()))

    for (const cid of customerIds) {
      let hourUtc: number
      if (mode === 'optimized' && hourHits[cid]) {
        // Pick the peak active hour from the customer's history
        const hits = hourHits[cid]
        let best = 10, bestCount = -1
        for (let h = 0; h < 24; h++) if (hits[h] > bestCount) { bestCount = hits[h]; best = h }
        hourUtc = best
      } else if (mode === 'timezone') {
        // Target 10:00 local, convert to UTC
        const offset = tzMap[cid] || 0
        hourUtc = ((10 - offset) % 24 + 24) % 24
      } else {
        // Fallback global average: 10:00 UTC
        hourUtc = 10
      }
      // Schedule for today at hourUtc; if it has already passed, pick tomorrow
      let target = new Date(todayUtc.getTime() + hourUtc * 3600 * 1000)
      if (target.getTime() <= now.getTime() + 60 * 1000) target = new Date(target.getTime() + 24 * 3600 * 1000)
      result[cid] = target.toISOString()
    }
    return result
  }

  function tzOffsetFor(key: string): number {
    const k = (key || '').toLowerCase()
    const table: Record<string, number> = {
      'africa/lagos': 1, 'ng': 1, 'nigeria': 1,
      'africa/nairobi': 3, 'ke': 3, 'kenya': 3,
      'africa/johannesburg': 2, 'za': 2,
      'europe/london': 0, 'gb': 0, 'uk': 0,
      'europe/paris': 1, 'fr': 1, 'de': 1,
      'america/new_york': -5, 'us': -5,
      'america/los_angeles': -8,
      'asia/dubai': 4, 'ae': 4,
      'asia/singapore': 8, 'sg': 8,
      'asia/tokyo': 9, 'jp': 9,
      'utc': 0,
    }
    return table[k] ?? 0
  }

  async function loadChannelPolicy(workspaceId: string, channel: string) {
    const { data } = await $supabase
      .from('messaging_policies')
      .select('*')
      .eq('workspace_id', workspaceId)
      .eq('channel', channel)
      .maybeSingle()
    return data
  }

  function applyQuietHours(iso: string | null, quietStart?: string, quietEnd?: string): string | null {
    if (!iso || !quietStart || !quietEnd) return iso
    const d = new Date(iso)
    const h = d.getUTCHours()
    const [qs] = quietStart.split(':').map(Number)
    const [qe] = quietEnd.split(':').map(Number)
    const inQuiet = qs > qe ? (h >= qs || h < qe) : (h >= qs && h < qe)
    if (!inQuiet) return iso
    // Shift to the end of quiet window
    const target = new Date(d)
    target.setUTCHours(qe, 0, 0, 0)
    if (target.getTime() <= d.getTime()) target.setUTCDate(target.getUTCDate() + 1)
    return target.toISOString()
  }

  async function sendCampaign(campaign: any) {
    const ids = await resolveAudience(campaign.workspace_id, campaign.audience_type, campaign.audience_id)
    if (!ids.length) {
      await $supabase.from('campaigns').update({ status: 'sent', sent_count: 0 }).eq('id', campaign.id)
      return { sent: 0 }
    }

    // Apply holdout
    const holdoutPct = Math.max(0, Math.min(50, Number(campaign.holdout_percent) || 0))
    const shuffled = ids.slice().sort(() => Math.random() - 0.5)
    const holdoutCount = Math.floor(shuffled.length * (holdoutPct / 100))
    let recipients = shuffled.slice(holdoutCount)
    const heldOut = shuffled.slice(0, holdoutCount)

    // Persist the holdout set so we can measure lift later.
    if (heldOut.length) {
      const rows = heldOut.map((cid: string) => ({ workspace_id: campaign.workspace_id, campaign_id: campaign.id, customer_id: cid }))
      await $supabase.from('campaign_holdouts').upsert(rows, { onConflict: 'campaign_id,customer_id', ignoreDuplicates: true })
    }

    // Policy lookup for quiet-hours enforcement
    const policy = await loadChannelPolicy(campaign.workspace_id, campaign.channel)

    // Cross-channel frequency capping at enqueue. Skip for transactional overrides.
    const dayCap = Number(policy?.max_per_day) || 0
    const weekCap = Number(policy?.max_per_week) || 0
    if ((dayCap > 0 || weekCap > 0) && recipients.length) {
      const [{ data: d24 }, { data: d7 }] = await Promise.all([
        dayCap > 0 ? $supabase.rpc('customer_send_counts', { p_workspace_id: campaign.workspace_id, p_customer_ids: recipients, p_hours: 24 }) : Promise.resolve({ data: [] }),
        weekCap > 0 ? $supabase.rpc('customer_send_counts', { p_workspace_id: campaign.workspace_id, p_customer_ids: recipients, p_hours: 168 }) : Promise.resolve({ data: [] }),
      ])
      const daily = new Map<string, number>((d24 || []).map((r: any) => [r.customer_id, Number(r.sends) || 0]))
      const weekly = new Map<string, number>((d7 || []).map((r: any) => [r.customer_id, Number(r.sends) || 0]))
      recipients = recipients.filter((cid: string) => {
        if (dayCap > 0 && (daily.get(cid) || 0) >= dayCap) return false
        if (weekCap > 0 && (weekly.get(cid) || 0) >= weekCap) return false
        return true
      })
    }
    const mode: string = campaign.send_time_mode || 'immediate'
    const respectTz = mode === 'timezone' || !!policy?.respect_time_zone
    const effectiveMode = mode === 'immediate' && policy?.send_time_optimization ? 'optimized' : mode

    await $supabase.from('campaigns').update({ status: 'sending' }).eq('id', campaign.id)

    const schedules = await computeSendTimes(campaign.workspace_id, recipients, effectiveMode, respectTz)

    // Load variant distribution
    const { data: variants } = await $supabase.from('campaign_variants').select('*').eq('campaign_id', campaign.id).order('label')
    const variantList = variants || []
    const pickVariant = () => {
      if (!variantList.length) return null
      const total = variantList.reduce((a: number, v: any) => a + (v.weight || 0), 0) || 1
      let r = Math.random() * total
      for (const v of variantList) { r -= (v.weight || 0); if (r <= 0) return v }
      return variantList[0]
    }

    const records = recipients.map((cid: string) => {
      const v = pickVariant()
      const scheduled = applyQuietHours(schedules[cid], policy?.quiet_start, policy?.quiet_end)
      const isImmediate = !scheduled
      return {
        workspace_id: campaign.workspace_id,
        campaign_id: campaign.id,
        customer_id: cid,
        status: isImmediate ? 'sent' : 'scheduled',
        sent_at: isImmediate ? new Date().toISOString() : null,
        scheduled_at: scheduled,
        variant_label: v?.label || null,
      }
    })
    if (records.length) await $supabase.from('campaign_messages').insert(records)

    // Enqueue real delivery alongside the in-app message rows. The queue-worker
    // edge function will flush these, calling notify/push-dispatch/etc. with
    // retry + backoff. Test-mode workspaces skip the queue — they should look
    // like a send happened but never talk to a provider.
    try {
      const { data: ws } = await $supabase.from('workspaces').select('environment').eq('id', campaign.workspace_id).maybeSingle()
      const isTest = ws?.environment === 'test'
      if (!isTest && records.length) {
        const { data: customers } = await $supabase.from('customers').select('id, email').eq('workspace_id', campaign.workspace_id).in('id', records.map((r: any) => r.customer_id))
        const emailById = new Map<string, string>((customers || []).map((c: any) => [c.id, c.email]))
        const queueRows = records
          .filter((r: any) => r.status === 'sent' || r.status === 'scheduled')
          .map((r: any) => {
            const variantContent = variantList.find((v: any) => v.label === r.variant_label)
            const subject = variantContent?.subject || campaign.subject
            const content = variantContent?.content || campaign.content
            const toEmail = emailById.get(r.customer_id)
            return {
              workspace_id: campaign.workspace_id,
              channel: campaign.channel,
              campaign_id: campaign.id,
              customer_id: r.customer_id,
              status: 'queued',
              next_attempt_at: r.scheduled_at || new Date().toISOString(),
              payload: {
                kind: 'campaign',
                title: subject,
                body: content,
                amp_html: campaign.amp_html || '',
                to_email: toEmail,
                to_user_id: r.customer_id,
              },
            }
          })
          .filter((q: any) => q.channel !== 'email' || q.payload.to_email)
        if (queueRows.length) await $supabase.from('delivery_queue').insert(queueRows)
      }
    } catch (e) {
      // Queue failures must not break the campaign send flow — the in-app
      // message rows are the source of truth for the UI.
      console.warn('[useEngagement] delivery_queue enqueue failed', e)
    }

    // Simulate engagement only on messages actually "sent" right now
    const immediateIds = records.filter((r: any) => r.status === 'sent').map((r: any) => r.customer_id)
    const openCount = Math.floor(immediateIds.length * (0.25 + Math.random() * 0.35))
    const clickCount = Math.floor(openCount * (0.1 + Math.random() * 0.3))
    const openIds = immediateIds.slice().sort(() => Math.random() - 0.5).slice(0, openCount)
    const clickIds = openIds.slice(0, clickCount)
    if (openIds.length) {
      await $supabase.from('campaign_messages').update({ opened_at: new Date().toISOString(), status: 'opened' }).eq('campaign_id', campaign.id).in('customer_id', openIds)
    }
    if (clickIds.length) {
      await $supabase.from('campaign_messages').update({ clicked_at: new Date().toISOString(), status: 'clicked' }).eq('campaign_id', campaign.id).in('customer_id', clickIds)
    }

    const scheduledCount = records.length - immediateIds.length
    const finalStatus = scheduledCount > 0 && immediateIds.length === 0 ? 'scheduled' : 'sent'
    await $supabase.from('campaigns').update({
      status: finalStatus,
      sent_count: immediateIds.length,
      open_count: openCount,
      click_count: clickCount,
    }).eq('id', campaign.id)

    // Per-variant aggregate
    if (variantList.length) {
      const byLabel: Record<string, { sent: number; opened: number; clicked: number }> = {}
      for (const r of records) {
        if (r.status !== 'sent' || !r.variant_label) continue
        const key = r.variant_label
        const agg = byLabel[key] || (byLabel[key] = { sent: 0, opened: 0, clicked: 0 })
        agg.sent++
        if (openIds.includes(r.customer_id)) agg.opened++
        if (clickIds.includes(r.customer_id)) agg.clicked++
      }
      for (const v of variantList) {
        const agg = byLabel[v.label]
        if (!agg) continue
        await $supabase.from('campaign_variants').update({
          sent_count: (v.sent_count || 0) + agg.sent,
          open_count: (v.open_count || 0) + agg.opened,
          click_count: (v.click_count || 0) + agg.clicked,
        }).eq('id', v.id)
      }
    }

    const events = [
      ...openIds.map((cid: string) => ({ workspace_id: campaign.workspace_id, customer_id: cid, name: 'campaign_opened', properties: { campaign_id: campaign.id, campaign_name: campaign.name } })),
      ...clickIds.map((cid: string) => ({ workspace_id: campaign.workspace_id, customer_id: cid, name: 'campaign_clicked', properties: { campaign_id: campaign.id, campaign_name: campaign.name } })),
    ]
    if (events.length) await $supabase.from('events').insert(events)

    const capped = shuffled.length - holdoutCount - recipients.length
    return {
      sent: immediateIds.length,
      scheduled: scheduledCount,
      held_out: heldOut.length,
      capped,
      opened: openCount,
      clicked: clickCount,
    }
  }

  async function computeCampaignLift(campaignId: string) {
    const { data, error } = await $supabase.rpc('compute_campaign_lift', { p_campaign_id: campaignId })
    if (error) throw error
    return data
  }

  async function enrollJourney(journey: any, customerIds: string[]) {
    if (!customerIds.length) return { enrolled: 0 }
    const holdoutPct = Math.max(0, Math.min(50, Number(journey.holdout_percent) || 0))
    const shuffled = customerIds.slice().sort(() => Math.random() - 0.5)
    const holdoutCount = Math.floor(shuffled.length * (holdoutPct / 100))
    const enrolling = shuffled.slice(holdoutCount)
    const rows = enrolling.map((cid: string) => ({ workspace_id: journey.workspace_id, journey_id: journey.id, customer_id: cid }))
    const { data } = await $supabase.from('journey_enrollments').upsert(rows, { onConflict: 'journey_id,customer_id', ignoreDuplicates: true }).select('id')
    const completed = Math.floor(enrolling.length * (0.3 + Math.random() * 0.4))
    const { count } = await $supabase.from('journey_enrollments').select('id', { count: 'exact', head: true }).eq('journey_id', journey.id)
    await $supabase.from('journeys').update({
      entered_count: count || enrolling.length,
      completed_count: (journey.completed_count || 0) + completed,
      status: 'active',
    }).eq('id', journey.id)
    return { enrolled: data?.length || 0, completed, held_out: holdoutCount }
  }

  return { resolveAudience, sendCampaign, enrollJourney, computeSendTimes, computeCampaignLift }
}
