import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};
const json = (d: unknown, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });

function addCadence(from: Date, cadence: string): Date {
  const d = new Date(from);
  if (cadence === "weekly") d.setUTCDate(d.getUTCDate() + 7);
  else if (cadence === "monthly") d.setUTCMonth(d.getUTCMonth() + 1);
  else d.setUTCDate(d.getUTCDate() + 1);
  return d;
}

async function buildSnapshot(sb: any, workspaceId: string) {
  const since30 = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString();
  const [c, e, s, camp, sent, opened, clicked] = await Promise.all([
    sb.from("customers").select("id", { count: "exact", head: true }).eq("workspace_id", workspaceId),
    sb.from("events").select("id", { count: "exact", head: true }).eq("workspace_id", workspaceId).gte("occurred_at", since30),
    sb.from("segments").select("id", { count: "exact", head: true }).eq("workspace_id", workspaceId),
    sb.from("campaigns").select("id", { count: "exact", head: true }).eq("workspace_id", workspaceId),
    sb.from("campaign_messages").select("id", { count: "exact", head: true }).eq("workspace_id", workspaceId).gte("sent_at", since30),
    sb.from("campaign_messages").select("id", { count: "exact", head: true }).eq("workspace_id", workspaceId).gte("opened_at", since30),
    sb.from("campaign_messages").select("id", { count: "exact", head: true }).eq("workspace_id", workspaceId).gte("clicked_at", since30),
  ]);
  return {
    customers: c.count || 0,
    events_30d: e.count || 0,
    segments: s.count || 0,
    campaigns: camp.count || 0,
    sent_30d: sent.count || 0,
    opened_30d: opened.count || 0,
    clicked_30d: clicked.count || 0,
  };
}

function renderHtml(workspace: any, snap: any, label: string): string {
  const row = (k: string, v: number) => `<tr><td style="padding:10px 14px;border-bottom:1px solid #edf2f5;color:#4f6a76;font-size:13px">${k}</td><td style="padding:10px 14px;border-bottom:1px solid #edf2f5;color:#0a445c;font-weight:600;text-align:right">${v.toLocaleString()}</td></tr>`;
  return `<!doctype html><html><body style="margin:0;background:#f7fafb;font-family:-apple-system,Segoe UI,Roboto,sans-serif;color:#0a445c">
  <div style="max-width:560px;margin:24px auto;background:#fff;border-radius:16px;overflow:hidden;border:1px solid #e6eef1">
    <div style="padding:20px 24px;background:linear-gradient(135deg,#0a445c,#0f6b85);color:#fff">
      <div style="font-size:12px;text-transform:uppercase;letter-spacing:.14em;opacity:.75">${label}</div>
      <div style="font-size:22px;font-weight:700;margin-top:4px">${workspace?.name || "Your workspace"}</div>
    </div>
    <table style="width:100%;border-collapse:collapse">
      ${row("Customers", snap.customers)}
      ${row("Events (30d)", snap.events_30d)}
      ${row("Segments", snap.segments)}
      ${row("Campaigns", snap.campaigns)}
      ${row("Sent (30d)", snap.sent_30d)}
      ${row("Opened (30d)", snap.opened_30d)}
      ${row("Clicked (30d)", snap.clicked_30d)}
    </table>
    <div style="padding:16px 24px;color:#86a0ab;font-size:11px;text-align:center">Pulse Engagement Platform</div>
  </div></body></html>`;
}

async function runOne(sb: any, report: any) {
  const { data: ws } = await sb.from("workspaces").select("id, name, industry").eq("id", report.workspace_id).maybeSingle();
  const snap = await buildSnapshot(sb, report.workspace_id);
  const html = renderHtml(ws, snap, report.name || "Engagement report");
  const subject = `${ws?.name || "Pulse"} — ${report.name || "Engagement report"}`;

  const recipients: string[] = Array.isArray(report.recipients) ? report.recipients.filter(Boolean) : [];
  const sendResults: Array<{ to: string; ok: boolean; error?: string }> = [];

  const url = `${Deno.env.get("SUPABASE_URL")}/functions/v1/notify`;
  for (const to of recipients) {
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
        },
        body: JSON.stringify({
          workspace_id: report.workspace_id,
          to_email: to,
          kind: "scheduled_report",
          title: subject,
          body: `Your ${report.cadence || "daily"} engagement report is ready.`,
          send_email: true,
          html_override: html,
        }),
      });
      sendResults.push({ to, ok: res.ok, error: res.ok ? undefined : await res.text() });
    } catch (e) {
      sendResults.push({ to, ok: false, error: (e as Error).message });
    }
  }

  const anyError = sendResults.find(r => !r.ok);
  const next = addCadence(new Date(), report.cadence || "daily").toISOString();
  await sb.from("scheduled_reports").update({
    last_run_at: new Date().toISOString(),
    next_run_at: next,
    last_status: anyError ? "partial" : "ok",
    last_error: anyError?.error || "",
    updated_at: new Date().toISOString(),
  }).eq("id", report.id);

  return { report_id: report.id, sent: sendResults.filter(r => r.ok).length, failed: sendResults.filter(r => !r.ok).length };
}

async function authorizeMember(req: Request, workspaceId: string): Promise<{ ok: boolean; status?: number; error?: string; isService?: boolean }> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const auth = req.headers.get("Authorization") || "";
  if (!auth.startsWith("Bearer ")) return { ok: false, status: 401, error: "Unauthorized" };
  const token = auth.slice(7).trim();
  if (token === serviceKey) return { ok: true, isService: true };
  const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: auth } } });
  const { data: u } = await userClient.auth.getUser();
  const user = u?.user;
  if (!user) return { ok: false, status: 401, error: "Unauthorized" };
  const admin = createClient(supabaseUrl, serviceKey);
  const { data: member } = await admin.from("workspace_members").select("role")
    .eq("workspace_id", workspaceId).eq("user_id", user.id).maybeSingle();
  if (!member || !["owner", "admin"].includes(member.role)) return { ok: false, status: 403, error: "Forbidden" };
  return { ok: true };
}

function isServiceRole(req: Request): boolean {
  const auth = req.headers.get("Authorization") || "";
  return auth.slice(7).trim() === (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const body = await req.json().catch(() => ({}));
    const { report_id, run_due } = body || {};

    if (report_id) {
      const { data: rep } = await sb.from("scheduled_reports").select("*").eq("id", report_id).maybeSingle();
      if (!rep) return json({ ok: false, error: "report not found" }, 404);
      const authz = await authorizeMember(req, rep.workspace_id);
      if (!authz.ok) return json({ ok: false, error: authz.error }, authz.status || 401);
      const out = await runOne(sb, rep);
      return json({ ok: true, ...out });
    }

    if (run_due) {
      if (!isServiceRole(req)) return json({ ok: false, error: "Unauthorized" }, 401);
      const nowIso = new Date().toISOString();
      const { data: due } = await sb.from("scheduled_reports").select("*")
        .eq("is_active", true).lte("next_run_at", nowIso).limit(50);
      const results = [];
      for (const r of due || []) results.push(await runOne(sb, r));
      return json({ ok: true, processed: results.length, results });
    }

    return json({ ok: false, error: "Provide report_id or run_due:true" }, 400);
  } catch (e) {
    return json({ ok: false, error: (e as Error).message }, 500);
  }
});
