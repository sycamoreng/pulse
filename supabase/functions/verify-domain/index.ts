import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const DOH = "https://cloudflare-dns.com/dns-query";

async function dnsQuery(name: string, type: string): Promise<string[]> {
  try {
    const res = await fetch(`${DOH}?name=${encodeURIComponent(name)}&type=${type}`, {
      headers: { Accept: "application/dns-json" },
    });
    if (!res.ok) return [];
    const json = await res.json();
    return (json.Answer || []).map((a: any) => String(a.data || "").replace(/^"|"$/g, "").replace(/"\s+"/g, ""));
  } catch {
    return [];
  }
}

function checkSpf(records: string[]): boolean {
  return records.some(r => /v=spf1/i.test(r) && (/include:.*pulse/i.test(r) || /include:.*amazonses/i.test(r) || /include:.*sendgrid/i.test(r) || /\+a/i.test(r)));
}
function checkDkim(records: string[], expectedKey: string): boolean {
  if (!records.length) return false;
  const joined = records.join("").replace(/\s+/g, "");
  if (!expectedKey) return /v=DKIM1/i.test(joined) && /p=[A-Za-z0-9+/=]{20,}/i.test(joined);
  return joined.includes(expectedKey.replace(/\s+/g, "").slice(0, 40));
}
function checkDmarc(records: string[]): boolean {
  return records.some(r => /v=DMARC1/i.test(r) && /p=(none|quarantine|reject)/i.test(r));
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const { domain_id } = await req.json();
    if (!domain_id) {
      return new Response(JSON.stringify({ error: "domain_id required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: d, error } = await supabase.from("email_domains").select("*").eq("id", domain_id).maybeSingle();
    if (error || !d) {
      return new Response(JSON.stringify({ error: "Domain not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const [spf, dkim, dmarc] = await Promise.all([
      dnsQuery(d.domain, "TXT"),
      dnsQuery(`${d.dkim_selector}._domainkey.${d.domain}`, "TXT"),
      dnsQuery(`_dmarc.${d.domain}`, "TXT"),
    ]);

    const spfOk = checkSpf(spf);
    const dkimOk = checkDkim(dkim, d.dkim_public_key || "");
    const dmarcOk = checkDmarc(dmarc);
    const allOk = spfOk && dkimOk && dmarcOk;

    const update: any = {
      spf_status: spfOk ? "verified" : "failed",
      dkim_status: dkimOk ? "verified" : "failed",
      dmarc_status: dmarcOk ? "verified" : "failed",
      status: allOk ? "verified" : "failed",
      last_checked_at: new Date().toISOString(),
    };
    if (allOk) update.verified_at = new Date().toISOString();

    await supabase.from("email_domains").update(update).eq("id", domain_id);

    return new Response(
      JSON.stringify({
        ok: allOk,
        spf: spfOk, dkim: dkimOk, dmarc: dmarcOk,
        spf_records: spf, dkim_records: dkim, dmarc_records: dmarc,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
