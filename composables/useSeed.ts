export const useSeed = () => {
  const { $supabase } = useNuxtApp()

  async function seedDemoData(wid: string) {
    await $supabase.from('workspaces').update({
      name: 'Sycamore',
      industry: 'fintech',
    }).eq('id', wid)

    // Customers and event activity are no longer seeded; workspaces start with
    // an empty audience. Import via CSV or the track API instead. We still seed
    // an event catalog so segment/journey builders have useful dropdowns.
    void cities

    const eventNames = [
      'app_opened',
      'signup_started',
      'signup_completed',
      'bvn_verified',
      'nin_verified',
      'kyc_tier_upgraded',
      'wallet_funded',
      'transfer_sent',
      'transfer_received',
      'bill_paid',
      'airtime_purchased',
      'data_purchased',
      'card_created',
      'card_funded',
      'savings_plan_created',
      'investment_made',
      'loan_requested',
      'loan_approved',
      'loan_repaid',
      'referral_sent',
      'referral_completed',
      'pin_changed',
      'login_failed',
    ]
    for (const n of eventNames) {
      await $supabase.from('event_definitions').upsert({ workspace_id: wid, name: n, category: 'behavior' }, { onConflict: 'workspace_id,name' })
    }

    const segments = [
      { name: 'Lagos customers', description: 'Customers based in Lagos', rules: { conditions: [{ field: 'city', op: 'eq', value: 'Lagos' }] } },
      { name: 'Tier 3 fully KYCed', description: 'BVN + NIN verified, upgraded to Tier 3', rules: { conditions: [{ field: 'attributes.kyc_tier', op: 'eq', value: 3 }] } },
      { name: 'Unverified tier 1', description: 'Not yet BVN verified', rules: { conditions: [{ field: 'attributes.kyc_tier', op: 'eq', value: 1 }] } },
      { name: 'High balance wallets', description: 'Wallet balance above NGN 1M', rules: { conditions: [{ field: 'attributes.wallet_balance_ngn', op: 'gte', value: 1000000 }] } },
      { name: 'Android users', description: 'Customers on Android devices', rules: { conditions: [{ field: 'platform', op: 'eq', value: 'android' }] } },
      { name: 'Dormant 14 days', description: 'Have not opened the app in 14 days', rules: { conditions: [{ field: 'last_seen_at', op: 'before', value: '14d' }] } },
    ]
    for (const s of segments) {
      await $supabase.from('segments').upsert({ workspace_id: wid, ...s, estimated_count: 0 }, { onConflict: 'workspace_id,name' })
    }

    const lists = [
      { name: 'VIP customers', description: 'Priority support and private banking prospects' },
      { name: 'Referral champions', description: 'Customers who referred 3 or more users' },
      { name: 'Loan allowlist', description: 'Pre-approved for instant loans' },
      { name: 'Savings superstars', description: 'Active SafeLock and Target savers' },
    ]
    for (const l of lists) {
      await $supabase.from('lists').upsert({ workspace_id: wid, ...l }, { onConflict: 'workspace_id,name' })
    }

    const campaigns = [
      {
        name: 'Complete your BVN verification',
        channel: 'email',
        status: 'sent',
        subject: 'Unlock the full Sycamore experience',
        content: 'Hi {{first_name}}, verify your BVN to upgrade to Tier 2 and enjoy higher transfer limits.',
        audience_type: 'segment',
        sent_count: 1200, open_count: 612, click_count: 198,
      },
      {
        name: 'Salary is in — save 10%',
        channel: 'push',
        status: 'scheduled',
        subject: '',
        content: 'Lock away 10% of your salary in SafeLock at 14% per annum.',
        audience_type: 'all',
      },
      {
        name: 'USD card early access',
        channel: 'email',
        status: 'draft',
        subject: 'Your USD card is almost here',
        content: 'Hi {{first_name}}, join the waitlist for our Sycamore USD Mastercard.',
        audience_type: 'segment',
      },
      {
        name: 'Airtime cashback Friday',
        channel: 'sms',
        status: 'sent',
        subject: '',
        content: 'Buy airtime today and get 3% cashback to your wallet. Only on Sycamore.',
        audience_type: 'all',
        sent_count: 4800, open_count: 0, click_count: 640,
      },
      {
        name: 'You have a pre-approved loan',
        channel: 'inapp',
        status: 'sent',
        subject: 'NGN 250,000 pre-approved for you',
        content: '{{first_name}}, get funds in under 2 minutes. No paperwork.',
        audience_type: 'segment',
        sent_count: 860, open_count: 410, click_count: 152,
      },
    ]
    for (const c of campaigns) {
      await $supabase.from('campaigns').upsert({ workspace_id: wid, ...c }, { onConflict: 'workspace_id,name' })
    }

    const templates = [
      { name: 'BVN verification nudge', channel: 'email', category: 'onboarding', subject: 'Finish setting up your Sycamore account', content: 'Hi {{first_name}}, one step away from unlocking transfers up to NGN 200,000 daily. Verify your BVN now.', preview_text: 'Unlock higher limits' },
      { name: 'Transfer receipt', channel: 'email', category: 'transactional', subject: 'Transfer of NGN {{amount}} successful', content: 'Hi {{first_name}}, your transfer of NGN {{amount}} to {{beneficiary}} was successful. Reference: {{reference}}.', preview_text: 'Transfer successful' },
      { name: 'Savings goal reminder', channel: 'push', category: 'retention', subject: '', content: 'Stay on track, {{first_name}}. Top up your SafeLock today.', preview_text: '' },
      { name: 'Loan due tomorrow', channel: 'sms', category: 'collections', subject: '', content: 'Reminder: your loan repayment of NGN {{amount}} is due tomorrow. Repay early to build your Sycamore score.', preview_text: '' },
      { name: 'Birthday bonus', channel: 'email', category: 'retention', subject: 'Happy birthday from Sycamore', content: 'Enjoy free transfers all day today and a 500 naira airtime gift on us, {{first_name}}.', preview_text: 'A little gift from us' },
    ]
    for (const t of templates) {
      await $supabase.from('templates').upsert({ workspace_id: wid, ...t }, { onConflict: 'workspace_id,name' })
    }

    const funnels = [
      { name: 'Activation funnel', description: 'Signup to first funded transfer', steps: [{ event: 'signup_started' }, { event: 'signup_completed' }, { event: 'bvn_verified' }, { event: 'wallet_funded' }, { event: 'transfer_sent' }], window_days: 7 },
      { name: 'Loan conversion', description: 'Loan request to disbursement', steps: [{ event: 'loan_requested' }, { event: 'loan_approved' }, { event: 'wallet_funded' }], window_days: 3 },
      { name: 'Savings adoption', description: 'Wallet funded to first savings plan', steps: [{ event: 'wallet_funded' }, { event: 'savings_plan_created' }], window_days: 14 },
    ]
    for (const f of funnels) {
      await $supabase.from('funnels').upsert({ workspace_id: wid, ...f }, { onConflict: 'workspace_id,name' })
    }

    await $supabase.from('cohorts').upsert({
      workspace_id: wid, name: 'New signup retention', description: 'Do new signups come back?',
      cohort_type: 'signup', retention_event: 'app_opened', period: 'week'
    }, { onConflict: 'workspace_id,name' })

    await $supabase.from('rfm_configs').upsert({
      workspace_id: wid, name: 'Transfer RFM', monetary_event: 'transfer_sent', monetary_property: 'amount_ngn', window_days: 90
    }, { onConflict: 'workspace_id,name' })

    await $supabase.from('workspaces').update({ demo_seeded: true }).eq('id', wid)
  }

  return { seedDemoData }
}
