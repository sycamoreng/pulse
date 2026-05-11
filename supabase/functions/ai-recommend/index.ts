import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

type Reco = {
  kind: string;
  channel: string;
  headline: string;
  body: string;
  cta: string;
  products: Array<{ id?: string; name?: string; url?: string; reason?: string }>;
  reasoning: string;
  confidence: number;
};

const INDUSTRY_GUIDANCE: Record<string, string> = {
  fintech:
    "This is a FINTECH product (banking, wallets, investing, lending). NEVER use retail cart/checkout framing. Favour language like account, deposit, balance, card, KYC, savings, statement, portfolio. Be precise, trustworthy, calm, and compliant — no exaggerated claims, no emojis, no urgency tactics for money. For security-category signals, stay neutral and factual; do not alarm.",
  saas:
    "This is a B2B SaaS product. Speak to productivity, team outcomes, time-to-value, and integrations. Reference trial stage, workspace, seats, or usage where relevant.",
  media:
    "This is a MEDIA / content product. Speak to stories, series, reading/listening/watching. Reference what they have consumed. Avoid commerce framing.",
  commerce:
    "This is an ECOMMERCE product. Cart/product/checkout framing is appropriate. Respect inventory and pricing sensitivity.",
  healthtech:
    "This is a HEALTHTECH product. Be warm, non-judgemental, and encouraging. NEVER give medical advice. Do not reference clinical details you were not given. Respect privacy and sensitivity of the category.",
  edtech:
    "This is an EDTECH / learning product. Celebrate progress, reduce friction, encourage consistency. Reference courses, lessons, streaks.",
  marketplace:
    "This is a MARKETPLACE (two-sided). Tailor to whether the customer is a buyer or a seller based on their events.",
  gaming:
    "This is a GAMING product. Match player tone, celebrate progression, and respect play patterns. Avoid predatory monetisation framing.",
  travel:
    "This is a TRAVEL product. Speak to destinations, trips, and anticipation. Respect seasonality and plans already in motion.",
  generic:
    "Use neutral, cross-industry language. Do NOT assume ecommerce, finance, or any specific vertical unless events clearly indicate it.",
};

async function callClaude(apiKey: string, industry: string, payload: unknown): Promise<Reco | null> {
  const industryGuidance = INDUSTRY_GUIDANCE[industry] || INDUSTRY_GUIDANCE.generic;
  const systemPrompt = `You are a senior behavioural-engagement strategist for a customer engagement platform.
Given a workspace's brand, a customer, their recent events, and an active behavioural signal,
produce ONE concrete next-best message tailored to that context.

INDUSTRY CONTEXT:
${industryGuidance}

Output STRICT JSON only, matching:
{
  "kind": "message" | "product" | "journey_branch",
  "channel": "email" | "push" | "sms" | "in_app",
  "headline": string (under 60 chars, warm, specific, no clickbait),
  "body": string (under 280 chars, plain language, one clear idea),
  "cta": string (under 24 chars, verb-led),
  "products": [{"name": string, "reason": string}] (optional, max 3, only when the industry has a product/catalogue concept),
  "reasoning": string (under 240 chars, why this for this customer now),
  "confidence": number between 0 and 1
}

Rules:
- Never fabricate facts about the customer; only use provided events and attributes.
- Respect the industry context above — do not use retail framing for non-retail industries.
- Respect the signal's category. Match channel to urgency and category conventions.
- Match brand voice tokens if provided.
- No emojis unless the brand voice requests them.`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-5",
      max_tokens: 700,
      system: systemPrompt,
      messages: [
        {
          role: "user",
          content: `Context:\n${JSON.stringify(payload, null, 2)}\n\nReturn ONLY the JSON object.`,
        },
      ],
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error("Claude error", res.status, text);
    return null;
  }
  const data = await res.json();
  const text = (data?.content?.[0]?.text || "").trim();
  const match = text.match(/\{[\s\S]*\}$/) || text.match(/\{[\s\S]*\}/);
  if (!match) return null;
  try {
    const parsed = JSON.parse(match[0]) as Reco;
    return parsed;
  } catch {
    return null;
  }
}

function heuristicFallback(signalKey: string, industry: string, customer: Record<string, unknown>): Reco {
  const name = (customer?.first_name as string) || (customer?.email as string) || "there";
  const first = typeof name === "string" ? name.split("@")[0] : "there";

  const fintech: Record<string, Reco> = {
    kyc_stalled: {
      kind: "message", channel: "in_app",
      headline: "A few steps to finish verification",
      body: "Your account is almost ready — we just need to verify your details to unlock transfers and card features. Takes under two minutes.",
      cta: "Finish verification", products: [], reasoning: "KYC started but not completed within 24h.", confidence: 0.78,
    },
    first_deposit_pending: {
      kind: "message", channel: "email",
      headline: `Welcome aboard, ${first}`,
      body: "Your account is ready. Add your first deposit whenever you're ready — even a small amount lets you try transfers, cards, and savings.",
      cta: "Add your first deposit", products: [], reasoning: "Account opened, no deposit yet.", confidence: 0.74,
    },
    card_activation_missed: {
      kind: "message", channel: "push",
      headline: "Your card is ready to use",
      body: "Activate your card in-app to start spending and access card controls. It takes a few seconds.",
      cta: "Activate card", products: [], reasoning: "Card issued, not activated after 7 days.", confidence: 0.72,
    },
    low_balance_drift: {
      kind: "message", channel: "in_app",
      headline: "A small nudge toward your goal",
      body: "Setting aside even a little at a time adds up. Want to schedule an automatic top-up?",
      cta: "Set up auto-save", products: [], reasoning: "Balance has trended low.", confidence: 0.6,
    },
    high_value_deposit: {
      kind: "message", channel: "email",
      headline: "Make your money work harder",
      body: "Idle cash can earn more. See how investing a portion of your balance could grow it over time — no lock-in.",
      cta: "Explore investing", products: [], reasoning: "Recent high-value deposit.", confidence: 0.66,
    },
    savings_goal_stalled: {
      kind: "message", channel: "push",
      headline: "Keep your goal moving",
      body: "You set a goal a couple of weeks ago. A small contribution today keeps it on track.",
      cta: "Add to your goal", products: [], reasoning: "Goal created, no contributions in 14d.", confidence: 0.62,
    },
    cross_sell_investment: {
      kind: "message", channel: "email",
      headline: "Ready for the next step?",
      body: "You've built a steady saving habit. Our simple investing options might be a good fit whenever you're ready to go further.",
      cta: "Learn more", products: [], reasoning: "Consistent deposits with idle balance.", confidence: 0.6,
    },
    suspicious_pattern: {
      kind: "message", channel: "push",
      headline: "New sign-in detected",
      body: "We noticed a sign-in from a new device. If that was you, no action is needed. If not, secure your account now.",
      cta: "Review activity", products: [], reasoning: "Login from a new device.", confidence: 0.8,
    },
  };

  const saas: Record<string, Reco> = {
    trial_midpoint: { kind: "message", channel: "email",
      headline: "You're halfway through your trial",
      body: "Here are the three things teams usually set up next — each one unlocks a bit more value before your trial ends.",
      cta: "See next steps", products: [], reasoning: "Halfway through trial.", confidence: 0.7 },
    trial_ending_soon: { kind: "message", channel: "email",
      headline: "Your trial ends in a few days",
      body: "Keep what you've built — upgrading now preserves your data and unlocks the full feature set.",
      cta: "Upgrade plan", products: [], reasoning: "Trial ending.", confidence: 0.8 },
    integration_not_connected: { kind: "message", channel: "in_app",
      headline: "Connect your first integration",
      body: "Most of the value here comes from connecting your existing tools. It takes about a minute.",
      cta: "Connect now", products: [], reasoning: "No integration connected.", confidence: 0.7 },
    seats_unused: { kind: "message", channel: "email",
      headline: "Your team hasn't joined yet",
      body: "Resend the invite — teams get the most value when everyone's in the same workspace.",
      cta: "Resend invites", products: [], reasoning: "Invited seats unused.", confidence: 0.65 },
    feature_limit_near: { kind: "message", channel: "in_app",
      headline: "You're close to your plan limit",
      body: "You'll hit your plan ceiling soon. Upgrade to keep going without interruption.",
      cta: "See plans", products: [], reasoning: "Usage near plan limit.", confidence: 0.75 },
  };

  const media: Record<string, Reco> = {
    binge_session: { kind: "message", channel: "in_app",
      headline: "More stories you'll enjoy",
      body: "You've been reading a lot today — here's a curated list based on what you've loved.",
      cta: "Keep reading", products: [], reasoning: "Binge session in progress.", confidence: 0.68 },
    story_completion_drop: { kind: "message", channel: "in_app",
      headline: "Shorter reads, same depth",
      body: "Here are some quicker stories we think match what you were looking for.",
      cta: "Browse short reads", products: [], reasoning: "High abandonment rate.", confidence: 0.6 },
    subscription_lapse_risk: { kind: "message", channel: "email",
      headline: "We miss you",
      body: "Here's a short recap of what you've missed lately — a few things we thought you'd like.",
      cta: "Catch up", products: [], reasoning: "Reading frequency down.", confidence: 0.7 },
  };

  const commerce: Record<string, Reco> = {
    cart_abandoned: {
      kind: "message", channel: "email",
      headline: `Still thinking it over, ${first}?`,
      body: "You left a few items in your cart. We saved them for you — finish up whenever the timing is right.",
      cta: "Return to cart", products: [], reasoning: "Cart abandonment within the last hour.", confidence: 0.72,
    },
    price_hesitation: {
      kind: "message", channel: "email",
      headline: "Questions about pricing?",
      body: "We noticed you've been comparing options. Happy to walk you through what's included — no pressure.",
      cta: "Chat with us", products: [], reasoning: "Repeat product/pricing views.", confidence: 0.65,
    },
    post_purchase_cross_sell: {
      kind: "message", channel: "email",
      headline: "Pairs well with what you just bought",
      body: "Here are a few things our customers often add next. No rush.",
      cta: "Take a look", products: [], reasoning: "Post-purchase window.", confidence: 0.6,
    },
  };

  const generic: Record<string, Reco> = {
    onboarding_stalled: {
      kind: "message", channel: "in_app",
      headline: "A quick win to get started",
      body: "Finish setting up — it takes under two minutes and unlocks the rest of the experience.",
      cta: "Finish setup", products: [], reasoning: "Signed up but not activated.", confidence: 0.7,
    },
    power_user: {
      kind: "message", channel: "email",
      headline: "You're getting a lot out of this",
      body: "Know someone else who'd enjoy it? Your referral link is ready whenever you are.",
      cta: "Share your link", products: [], reasoning: "Very active recently.", confidence: 0.65,
    },
    churn_risk: {
      kind: "message", channel: "email",
      headline: "We miss you",
      body: "It's been a couple of weeks. Here's a short recap of what changed while you were away.",
      cta: "See what's new", products: [], reasoning: "Quiet for 14+ days.", confidence: 0.66,
    },
    reengagement_window: {
      kind: "message", channel: "push",
      headline: "Welcome back",
      body: "Great to see you again. Here's a quick catch-up on what changed.",
      cta: "Catch up", products: [], reasoning: "Returned after absence.", confidence: 0.7,
    },
    content_deep_dive: {
      kind: "message", channel: "in_app",
      headline: "Go deeper",
      body: "You've been exploring a lot today — here's a curated follow-up.",
      cta: "Keep going", products: [], reasoning: "5+ content views in a session.", confidence: 0.6,
    },
    feature_discovery_stalled: {
      kind: "message", channel: "in_app",
      headline: "Try this next",
      body: "Most people on your plan get the biggest win from this one feature. Takes about a minute.",
      cta: "Try it now", products: [], reasoning: "Active without touching core feature.", confidence: 0.62,
    },
  };

  const packs: Record<string, Record<string, Reco>> = {
    fintech, saas, media, commerce, generic,
  };

  const pack = packs[industry] || generic;
  const templates: Record<string, Reco> = { ...generic, ...pack };
  return (
    templates[signalKey] || {
      kind: "message",
      channel: "email",
      headline: "Thought you'd like this",
      body: `A quick, personal note for you, ${first}, based on your recent activity.`,
      cta: "Take a look",
      products: [],
      reasoning: `Signal ${signalKey} fired.`,
      confidence: 0.5,
    }
  );
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY") || "";

    const body = await req.json().catch(() => ({}));
    const workspaceId: string | undefined = body.workspace_id;
    const limit: number = Math.min(Math.max(Number(body.limit) || 25, 1), 100);
    const signalIds: string[] | undefined = body.signal_ids;

    if (!workspaceId) {
      return new Response(JSON.stringify({ ok: false, error: "workspace_id required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: runRow } = await supabase
      .from("intelligence_runs")
      .insert({ workspace_id: workspaceId, kind: "recommend" })
      .select()
      .maybeSingle();

    const { data: workspace } = await supabase
      .from("workspaces")
      .select("name, brand_primary, brand_accent, commerce_enabled, industry")
      .eq("id", workspaceId)
      .maybeSingle();
    const industry: string = (workspace?.industry as string) || "generic";

    let query = supabase
      .from("customer_signals")
      .select("*")
      .eq("workspace_id", workspaceId)
      .is("consumed_at", null)
      .order("detected_at", { ascending: false })
      .limit(limit);
    if (signalIds && signalIds.length) query = query.in("id", signalIds);

    const { data: signals } = await query;
    if (!signals || !signals.length) {
      if (runRow?.id) {
        await supabase
          .from("intelligence_runs")
          .update({ finished_at: new Date().toISOString(), recommendations_created: 0 })
          .eq("id", runRow.id);
      }
      return new Response(JSON.stringify({ ok: true, created: 0 }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const customerIds = Array.from(new Set(signals.map((s) => s.customer_id)));
    const { data: customers } = await supabase
      .from("customers")
      .select("id, email, first_name, last_name, attributes, last_seen_at")
      .in("id", customerIds);
    const customerMap = new Map((customers || []).map((c) => [c.id, c]));

    const { data: recentEvents } = await supabase
      .from("events")
      .select("customer_id, name, occurred_at, properties")
      .eq("workspace_id", workspaceId)
      .in("customer_id", customerIds)
      .order("occurred_at", { ascending: false })
      .limit(500);

    const eventsByCustomer = new Map<string, typeof recentEvents>();
    for (const ev of recentEvents || []) {
      const arr = eventsByCustomer.get(ev.customer_id) || [];
      if (arr.length < 12) arr.push(ev);
      eventsByCustomer.set(ev.customer_id, arr);
    }

    let created = 0;
    let firstInsertError: string | null = null;
    let claudeErrors = 0;
    let missingCustomer = 0;
    for (const signal of signals) {
      const customer = customerMap.get(signal.customer_id);
      if (!customer) { missingCustomer += 1; continue; }

      const payload = {
        brand: {
          name: workspace?.name,
          primary: workspace?.brand_primary,
          accent: workspace?.brand_accent,
          commerce_enabled: workspace?.commerce_enabled,
          industry,
        },
        customer: {
          email: customer.email,
          first_name: customer.first_name,
          last_name: customer.last_name,
          attributes: customer.attributes,
          last_seen_at: customer.last_seen_at,
        },
        signal: {
          key: signal.signal_key,
          label: signal.signal_label,
          category: signal.category,
          confidence: signal.confidence,
          context: signal.context,
          detected_at: signal.detected_at,
        },
        recent_events: eventsByCustomer.get(signal.customer_id) || [],
      };

      let reco: Reco | null = null;
      if (anthropicKey) {
        reco = await callClaude(anthropicKey, industry, payload);
        if (!reco) claudeErrors += 1;
      }
      if (!reco) reco = heuristicFallback(signal.signal_key, industry, customer);

      const { error } = await supabase.from("ai_recommendations").insert({
        workspace_id: workspaceId,
        customer_id: signal.customer_id,
        signal_id: signal.id,
        signal_key: signal.signal_key,
        kind: reco.kind || "message",
        channel: reco.channel || "email",
        headline: (reco.headline || "").slice(0, 160),
        body: (reco.body || "").slice(0, 1000),
        cta: (reco.cta || "").slice(0, 48),
        products: reco.products || [],
        payload,
        reasoning: (reco.reasoning || "").slice(0, 600),
        model: anthropicKey ? "claude-sonnet-4-5" : "heuristic",
        confidence: Math.min(1, Math.max(0, Number(reco.confidence) || 0.5)),
      });
      if (error) {
        console.error("ai_recommendations insert failed", error);
        if (!firstInsertError) firstInsertError = error.message || JSON.stringify(error);
      } else {
        created += 1;
      }
    }

    if (runRow?.id) {
      await supabase
        .from("intelligence_runs")
        .update({
          finished_at: new Date().toISOString(),
          recommendations_created: created,
          customers_touched: customerIds.length,
        })
        .eq("id", runRow.id);
    }

    return new Response(
      JSON.stringify({
        ok: true,
        created,
        signals_considered: signals.length,
        claude_errors: claudeErrors,
        insert_error: firstInsertError,
        used_model: anthropicKey ? "claude" : "heuristic",
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: (e as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
