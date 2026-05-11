import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};
const json = (d: unknown, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });

// Representative seed inbox providers we simulate against.
const SEED_PROVIDERS = [
  { key: "gmail", label: "Gmail" },
  { key: "outlook", label: "Outlook.com" },
  { key: "yahoo", label: "Yahoo" },
  { key: "aol", label: "AOL" },
  { key: "apple", label: "Apple iCloud" },
  { key: "protonmail", label: "ProtonMail" },
  { key: "zoho", label: "Zoho" },
  { key: "gsuite", label: "Google Workspace" },
  { key: "o365", label: "Microsoft 365" },
  { key: "fastmail", label: "Fastmail" },
];

type Placement = "inbox" | "spam" | "missing";

function scoreContent(subject: string, body: string): number {
  let penalty = 0;
  const s = `${subject} ${body}`.toLowerCase();
  const spammy = ["free", "guarantee", "click here", "act now", "100% off", "urgent", "winner", "congratulations", "limited time", "risk-free"];
  for (const w of spammy) if (s.includes(w)) penalty += 0.04;
  if ((subject || "").match(/!{2,}|\?{2,}|\$\$+/)) penalty += 0.05;
  const upperRatio = subject ? (subject.replace(/[^A-Z]/g, "").length / Math.max(1, subject.length)) : 0;
  if (upperRatio > 0.4) penalty += 0.05;
  if (!subject) penalty += 0.08;
  if ((body || "").length < 80) penalty += 0.04;
  return Math.min(0.35, penalty);
}

function scoreAuth(domain: any): number {
  if (!domain) return 0.25;
  let bonus = 0;
  if (domain.spf_status === "pass") bonus += 0.1;
  if (domain.dkim_status === "pass") bonus += 0.1;
  if (domain.dmarc_status === "pass") bonus += 0.08;
  return 0.25 - bonus; // lower is better
}

function simulate(providers: typeof SEED_PROVIDERS, baseInbox: number): Array<{ provider: string; label: string; placement: Placement }> {
  return providers.map(p => {
    const jitter = (Math.random() - 0.5) * 0.1;
    const inboxProb = Math.max(0.05, Math.min(0.99, baseInbox + jitter));
    const r = Math.random();
    let placement: Placement;
    if (r < inboxProb) placement = "inbox";
    else if (r < inboxProb + 0.8 * (1 - inboxProb)) placement = "spam";
    else placement = "missing";
    return { provider: p.key, label: p.label, placement };
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const auth = req.headers.get("Authorization") || "";
    if (!auth.startsWith("Bearer ")) return json({ ok: false, error: "Unauthorized" }, 401);

    const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: auth } } });
    const { data: u } = await userClient.auth.getUser();
    const user = u?.user;
    if (!user) return json({ ok: false, error: "Unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const { workspace_id, name, subject, from_email, html } = body || {};
    if (!workspace_id) return json({ ok: false, error: "workspace_id required" }, 400);

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: member } = await admin.from("workspace_members").select("role")
      .eq("workspace_id", workspace_id).eq("user_id", user.id).maybeSingle();
    if (!member || !["owner", "admin"].includes(member.role)) return json({ ok: false, error: "Forbidden" }, 403);

    const contentPenalty = scoreContent(subject || "", html || "");
    const fromDomain = (from_email || "").split("@")[1] || "";
    const { data: domain } = fromDomain
      ? await admin.from("email_domains").select("*").eq("workspace_id", workspace_id).eq("domain", fromDomain).maybeSingle()
      : { data: null } as any;
    const authPenalty = scoreAuth(domain);

    const baseInbox = Math.max(0.4, Math.min(0.99, 0.92 - contentPenalty - authPenalty));
    const results = simulate(SEED_PROVIDERS, baseInbox);
    const total = results.length;
    const inboxCount = results.filter(r => r.placement === "inbox").length;
    const spamCount = results.filter(r => r.placement === "spam").length;
    const missingCount = total - inboxCount - spamCount;

    const row = {
      workspace_id,
      name: name || "Seed test",
      subject: subject || "",
      from_email: from_email || "",
      status: "complete",
      total_seeds: total,
      inbox_rate: Math.round((inboxCount / total) * 10000) / 100,
      spam_rate: Math.round((spamCount / total) * 10000) / 100,
      missing_rate: Math.round((missingCount / total) * 10000) / 100,
      sent_at: new Date().toISOString(),
      report: { results, content_penalty: contentPenalty, auth_penalty: authPenalty, base_inbox: baseInbox, domain: fromDomain },
    };
    const { data: test, error } = await admin.from("inbox_placement_tests").insert(row).select().maybeSingle();
    if (error) return json({ ok: false, error: error.message }, 500);

    return json({ ok: true, test });
  } catch (e) {
    return json({ ok: false, error: (e as Error).message }, 500);
  }
});
