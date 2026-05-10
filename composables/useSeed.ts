export const useSeed = () => {
  const { $supabase } = useNuxtApp()

  async function seedDemoData(wid: string) {
    await $supabase.from('workspaces').update({
      name: 'Sycamore',
      industry: 'fintech',
    }).eq('id', wid)

    const first = ['Ada','Emeka','Ngozi','Tunde','Chidi','Amaka','Sade','Yemi','Kunle','Bola','Ifeoma','Uche','Femi','Obinna','Zainab','Aisha','Halima','Tobi','Seun','Chioma','Nneka','Ikenna','Folake','Musa','Bisi','Damilola','Ebuka']
    const last = ['Okafor','Balogun','Adeyemi','Okonkwo','Nwosu','Eze','Adekunle','Adebayo','Obi','Oluwaseun','Ibrahim','Mohammed','Bello','Ogunleye','Afolabi','Udoh','Akpan','Chukwu','Olanrewaju']
    const cities = [
      { city: 'Lagos', state: 'LA' },
      { city: 'Abuja', state: 'FC' },
      { city: 'Port Harcourt', state: 'RI' },
      { city: 'Ibadan', state: 'OY' },
      { city: 'Kano', state: 'KN' },
      { city: 'Benin City', state: 'ED' },
      { city: 'Enugu', state: 'EN' },
      { city: 'Kaduna', state: 'KD' },
      { city: 'Warri', state: 'DE' },
      { city: 'Owerri', state: 'IM' },
    ]
    const seen = new Set<string>()
    const customers: any[] = []
    while (customers.length < 80) {
      const f = first[Math.floor(Math.random()*first.length)]
      const l = last[Math.floor(Math.random()*last.length)]
      const ext = `${f}.${l}.${Math.floor(Math.random()*100000)}`.toLowerCase()
      if (seen.has(ext)) continue
      seen.add(ext)
      const cityRow = cities[Math.floor(Math.random()*cities.length)]
      const kycTier = Math.random() < 0.15 ? 1 : Math.random() < 0.6 ? 2 : 3
      const balance = kycTier === 1
        ? Math.floor(Math.random() * 50_000)
        : kycTier === 2
          ? Math.floor(Math.random() * 500_000)
          : Math.floor(Math.random() * 5_000_000)
      customers.push({
        workspace_id: wid,
        external_id: ext,
        email: `${ext}@sycamore.ng`,
        phone: `+234${[700,701,703,704,705,706,707,708,709,802,803,806,807,808,809,810,811,812,813,814,815,816,817,818,819][Math.floor(Math.random()*25)]}${Math.floor(1000000 + Math.random() * 8999999)}`,
        first_name: f,
        last_name: l,
        country: 'NG',
        city: cityRow.city,
        device: ['iPhone 15','iPhone 13','Pixel 8','Tecno Camon 20','Infinix Hot 40','Galaxy S24','Galaxy A15','MacBook','Windows PC'][Math.floor(Math.random()*9)],
        platform: ['ios','android','web'][Math.floor(Math.random()*3)],
        last_seen_at: new Date(Date.now() - Math.random() * 14*24*3600*1000).toISOString(),
        attributes: {
          kyc_tier: kycTier,
          bvn_verified: kycTier >= 2,
          nin_verified: kycTier === 3,
          wallet_balance_ngn: balance,
          state: cityRow.state,
          is_premium: balance > 1_000_000,
          referral_source: ['organic','instagram','twitter','referral','playstore','appstore','tiktok'][Math.floor(Math.random()*7)],
          signup_channel: ['mobile','web'][Math.floor(Math.random()*2)],
        },
      })
    }
    const { data: inserted } = await $supabase.from('customers').upsert(customers, { onConflict: 'workspace_id,external_id' }).select('id')
    let ids: string[] = (inserted || []).map((c: any) => c.id)
    if (!ids.length) {
      const { data } = await $supabase.from('customers').select('id').eq('workspace_id', wid).limit(200)
      ids = (data || []).map((c: any) => c.id)
    }

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

    const billers = ['DSTV','GOTV','StarTimes','Ikeja Electric','EKEDC','AEDC','PHED','MTN','Airtel','Glo','9mobile','LAWMA']
    const events: any[] = []
    for (let i = 0; i < 900; i++) {
      const cid = ids[Math.floor(Math.random() * ids.length)]
      if (!cid) continue
      const name = eventNames[Math.floor(Math.random()*eventNames.length)]
      let properties: Record<string, any> = { source: 'mobile' }
      if (name === 'wallet_funded') {
        properties = { amount_ngn: [500,1000,2500,5000,10000,25000,50000,100000][Math.floor(Math.random()*8)], method: ['card','bank_transfer','ussd'][Math.floor(Math.random()*3)] }
      } else if (name === 'transfer_sent' || name === 'transfer_received') {
        properties = { amount_ngn: Math.floor(500 + Math.random() * 250000), bank: ['GTBank','Access','Zenith','UBA','First Bank','Opay','PalmPay','Kuda','Moniepoint'][Math.floor(Math.random()*9)] }
      } else if (name === 'bill_paid') {
        properties = { biller: billers[Math.floor(Math.random()*billers.length)], amount_ngn: Math.floor(500 + Math.random() * 30000) }
      } else if (name === 'airtime_purchased' || name === 'data_purchased') {
        properties = { network: ['MTN','Airtel','Glo','9mobile'][Math.floor(Math.random()*4)], amount_ngn: [100,200,500,1000,2000][Math.floor(Math.random()*5)] }
      } else if (name === 'card_created') {
        properties = { card_type: Math.random() > 0.5 ? 'virtual' : 'physical', currency: Math.random() > 0.3 ? 'NGN' : 'USD' }
      } else if (name === 'investment_made') {
        properties = { product: ['Fixed Yield','Mutual Fund','Treasury Bill'][Math.floor(Math.random()*3)], amount_ngn: Math.floor(10000 + Math.random() * 990000) }
      } else if (name === 'loan_requested' || name === 'loan_approved' || name === 'loan_repaid') {
        properties = { amount_ngn: Math.floor(5000 + Math.random() * 495000), tenure_days: [30,60,90,180][Math.floor(Math.random()*4)] }
      } else if (name === 'savings_plan_created') {
        properties = { plan: ['SafeLock','Flex','Target','GroupSave'][Math.floor(Math.random()*4)], target_ngn: Math.floor(50000 + Math.random() * 950000) }
      }
      events.push({
        workspace_id: wid, customer_id: cid, name, properties,
        occurred_at: new Date(Date.now() - Math.random() * 45*24*3600*1000).toISOString(),
      })
    }
    await $supabase.from('events').insert(events)

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
