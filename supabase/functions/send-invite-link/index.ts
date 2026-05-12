import { createClient } from 'npm:@supabase/supabase-js@2.39.7'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
}

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 200, headers: corsHeaders })
  if (req.method !== 'POST') return json(405, { ok: false, error: 'method not allowed' })

  try {
    const auth = req.headers.get('Authorization') || ''
    const token = auth.replace(/^Bearer\s+/i, '')
    if (!token) return json(401, { ok: false, error: 'missing bearer token' })

    const url = Deno.env.get('SUPABASE_URL')!
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const userClient = createClient(url, anon, { global: { headers: { Authorization: `Bearer ${token}` } } })
    const { data: userData, error: userErr } = await userClient.auth.getUser()
    if (userErr || !userData.user) return json(401, { ok: false, error: 'invalid session' })

    const body = await req.json().catch(() => ({}))
    const workspace_id = String(body.workspace_id || '')
    const email = String(body.email || '').trim().toLowerCase()
    const mode = body.mode === 'copy' ? 'copy' : 'send'
    if (!workspace_id || !email) return json(400, { ok: false, error: 'workspace_id and email are required' })

    const isLocal = (u: string) => /^https?:\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0)(:|\/|$)/i.test(u)
    const serverBase = (
      Deno.env.get('NUXT_PUBLIC_APP_URL') ||
      Deno.env.get('PULSE_SITE_URL') ||
      ''
    ).replace(/\/+$/, '')
    const requestedRedirect = String(body.redirect_to || '')
    let redirect_to = ''
    if (serverBase && !isLocal(serverBase)) {
      redirect_to = `${serverBase}/welcome`
    } else if (requestedRedirect && !isLocal(requestedRedirect)) {
      redirect_to = requestedRedirect
    } else {
      return json(400, { ok: false, error: 'No public app URL configured. Set NUXT_PUBLIC_APP_URL (or PULSE_SITE_URL) as an edge function secret to a non-localhost URL.' })
    }

    const admin = createClient(url, service)

    const { data: member, error: memErr } = await admin
      .from('workspace_members')
      .select('id, role, role_id')
      .eq('workspace_id', workspace_id)
      .eq('user_id', userData.user.id)
      .maybeSingle()
    if (memErr) return json(500, { ok: false, error: memErr.message })
    if (!member || !['owner', 'admin'].includes(String(member.role))) {
      return json(403, { ok: false, error: 'only workspace admins can send registration links' })
    }

    const { data: ws } = await admin.from('workspaces').select('name').eq('id', workspace_id).maybeSingle()
    const workspaceName = ws?.name || 'your workspace'

    let actionLink: string | null = null
    let linkKind: 'invite' | 'magiclink' = 'invite'
    const { data: link, error: linkErr } = await admin.auth.admin.generateLink({
      type: 'invite',
      email,
      options: redirect_to ? { redirectTo: redirect_to } : {},
    })
    if (link?.properties?.action_link) {
      actionLink = link.properties.action_link
    } else {
      const msg = linkErr?.message || ''
      const alreadyExists = /already|exists|registered/i.test(msg)
      if (alreadyExists) {
        const { data: magic, error: magicErr } = await admin.auth.admin.generateLink({
          type: 'magiclink',
          email,
          options: redirect_to ? { redirectTo: redirect_to } : {},
        })
        if (magicErr || !magic?.properties?.action_link) {
          return json(500, { ok: false, error: magicErr?.message || msg || 'could not generate link' })
        }
        actionLink = magic.properties.action_link
        linkKind = 'magiclink'
      } else {
        return json(500, { ok: false, error: msg || 'could not generate link' })
      }
    }

    if (mode === 'send') {
      const { error: notifyErr } = await admin.functions.invoke('notify', {
        body: {
          workspace_id,
          to_email: email,
          kind: 'invite',
          title: `You have been invited to ${workspaceName}`,
          body: `You've been added to ${workspaceName} on Pulse. Click the link below to finish creating your account.\n\n${actionLink}\n\nThis link will expire soon — if it does, ask an admin to send another.`,
          link: actionLink,
          send_email: true,
        },
      })
      if (notifyErr) return json(500, { ok: false, error: notifyErr.message })
    }

    return json(200, { ok: true, link: actionLink, mode, kind: linkKind })
  } catch (e: any) {
    return json(500, { ok: false, error: e?.message || 'unexpected error' })
  }
})
