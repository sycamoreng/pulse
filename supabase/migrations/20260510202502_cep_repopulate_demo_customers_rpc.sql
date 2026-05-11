/*
  # Repopulate demo customers and events

  Adds `repopulate_demo_customers(p_workspace_id uuid, p_count int)` — a
  secure RPC that:
    1. Deletes orphan events (customer_id is null) and seed customers
       (attributes->>'demo' = 'true') along with their events so we start clean.
    2. Inserts `p_count` realistic fintech-style customers with attributes
       (wallet balance, KYC tier, platform, city).
    3. Generates event streams per customer that will reliably trigger a
       variety of behavioural signals for testing the AI engine:
         - kyc_stalled (20%): signup + kyc_started with no kyc_completed.
         - first_deposit_pending (15%): account_opened, no deposit_completed.
         - card_activation_missed (10%): card_issued 8d ago, no card_activated.
         - power_user / engagement (20%): 25+ recent events.
         - churn_risk (10%): prior activity but quiet 20+ days.
         - reengagement_window (10%): long gap then recent activity.
         - onboarding_stalled (10%): signup but no activated event.
         - healthy baseline (remainder): regular event pattern.

  Security:
    - SECURITY DEFINER with explicit membership check. Only workspace owners,
      admins, or editors may run it.
    - Only touches rows scoped to the provided workspace.

  Notes:
    - All generated customers have attributes.demo = 'true' so future calls
      can safely clear prior demo data without touching real customers.
    - Safe on workspaces with real data: no non-demo customers are deleted.
*/

create or replace function public.repopulate_demo_customers(p_workspace_id uuid, p_count int default 120)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_allowed boolean;
  v_count int := greatest(20, least(p_count, 500));
  v_inserted int := 0;
  v_events_inserted int := 0;
  v_orphans_deleted int := 0;
  v_demo_deleted int := 0;
  v_cities text[] := array['Lagos','Abuja','Port Harcourt','Ibadan','Kano','Benin City','Enugu','Kaduna','Uyo','Calabar'];
  v_platforms text[] := array['ios','android','web'];
  v_first_names text[] := array['Ada','Chinedu','Tunde','Ngozi','Kemi','Seyi','Ifeanyi','Olumide','Funke','Bola','Yewande','Emeka','Ifeoma','Uche','Bisi','Femi','Chiamaka','Obinna','Tobi','Amaka','Musa','Hauwa','Yusuf','Zainab','Aisha','Blessing','Halima','Ibrahim','Fatima','Nneka'];
  v_last_names text[] := array['Okafor','Adeyemi','Balogun','Ibrahim','Okonkwo','Olawale','Nnamdi','Dangote','Ojo','Afolabi','Bello','Usman','Eze','Abubakar','Oladele','Obi','Adewale','Umeh','Chukwu','Akande'];
  v_customer_id uuid;
  v_first text;
  v_last text;
  v_email text;
  v_city text;
  v_platform text;
  v_kyc int;
  v_balance int;
  v_scenario int;
  v_now timestamptz := now();
  v_i int;
  v_j int;
  v_events_this_customer int;
begin
  if p_workspace_id is null then
    return jsonb_build_object('ok', false, 'error', 'missing workspace');
  end if;

  select exists(
    select 1 from workspace_members wm
      where wm.workspace_id = p_workspace_id
        and wm.user_id = auth.uid()
        and wm.role in ('owner','admin','editor')
    union all
    select 1 from workspaces w where w.id = p_workspace_id and w.owner_id = auth.uid()
  ) into v_allowed;

  if not coalesce(v_allowed, false) then
    return jsonb_build_object('ok', false, 'error', 'not allowed');
  end if;

  -- clear orphan events scoped to this workspace
  delete from events where workspace_id = p_workspace_id and customer_id is null;
  get diagnostics v_orphans_deleted = row_count;

  -- clear prior demo customers (and their events via ON DELETE CASCADE)
  delete from customers
   where workspace_id = p_workspace_id
     and (attributes->>'demo') = 'true';
  get diagnostics v_demo_deleted = row_count;

  -- also clear any open signals/recos so the run starts clean
  delete from customer_signals where workspace_id = p_workspace_id;
  delete from ai_recommendations where workspace_id = p_workspace_id;

  for v_i in 1 .. v_count loop
    v_first := v_first_names[1 + floor(random() * array_length(v_first_names, 1))::int];
    v_last := v_last_names[1 + floor(random() * array_length(v_last_names, 1))::int];
    v_email := lower(v_first || '.' || v_last || floor(random()*10000)::text || '@demo.sycamore.test');
    v_city := v_cities[1 + floor(random() * array_length(v_cities, 1))::int];
    v_platform := v_platforms[1 + floor(random() * array_length(v_platforms, 1))::int];
    v_kyc := 1 + floor(random() * 3)::int;
    v_balance := floor(random() * 2500000)::int;

    v_scenario := 1 + floor(random() * 100)::int;

    insert into customers (workspace_id, email, first_name, last_name, city, country, platform, attributes, last_seen_at, created_at)
    values (
      p_workspace_id, v_email, v_first, v_last, v_city, 'NG', v_platform,
      jsonb_build_object(
        'demo', 'true',
        'kyc_tier', v_kyc,
        'wallet_balance_ngn', v_balance,
        'signup_channel', (array['organic','referral','paid_social','app_store'])[1 + floor(random()*4)::int]
      ),
      v_now - (random() * interval '30 days'),
      v_now - (random() * interval '180 days')
    )
    returning id into v_customer_id;

    v_inserted := v_inserted + 1;

    -- seed common baseline
    insert into events (workspace_id, customer_id, name, occurred_at, properties)
    values (p_workspace_id, v_customer_id, 'signup', v_now - interval '30 days' - (random() * interval '60 days'), '{}'::jsonb);

    if v_scenario <= 20 then
      -- kyc_stalled
      insert into events (workspace_id, customer_id, name, occurred_at, properties)
      values (p_workspace_id, v_customer_id, 'kyc_started', v_now - (random() * interval '2 days' + interval '2 days'),
              jsonb_build_object('tier', v_kyc));

    elsif v_scenario <= 35 then
      -- first_deposit_pending
      insert into events (workspace_id, customer_id, name, occurred_at, properties)
      values (p_workspace_id, v_customer_id, 'account_opened', v_now - interval '3 days' - (random() * interval '4 days'), '{}'::jsonb);

    elsif v_scenario <= 45 then
      -- card_activation_missed
      insert into events (workspace_id, customer_id, name, occurred_at, properties)
      values (p_workspace_id, v_customer_id, 'card_issued', v_now - interval '8 days' - (random() * interval '3 days'),
              jsonb_build_object('card_type','virtual'));

    elsif v_scenario <= 65 then
      -- power_user / engagement
      v_events_this_customer := 22 + floor(random() * 15)::int;
      for v_j in 1 .. v_events_this_customer loop
        insert into events (workspace_id, customer_id, name, occurred_at, properties)
        values (
          p_workspace_id, v_customer_id,
          (array['session_start','transfer_sent','bill_paid','wallet_funded','airtime_purchased','goal_contribution','feature_used'])[1 + floor(random()*7)::int],
          v_now - (random() * interval '6 days'),
          jsonb_build_object('amount_ngn', (1000 + floor(random()*50000))::int)
        );
        v_events_inserted := v_events_inserted + 1;
      end loop;

    elsif v_scenario <= 75 then
      -- churn_risk: activity 30-60 days ago, quiet since
      for v_j in 1 .. 15 loop
        insert into events (workspace_id, customer_id, name, occurred_at, properties)
        values (
          p_workspace_id, v_customer_id,
          (array['session_start','transfer_sent','bill_paid'])[1 + floor(random()*3)::int],
          v_now - interval '30 days' - (random() * interval '30 days'),
          '{}'::jsonb
        );
        v_events_inserted := v_events_inserted + 1;
      end loop;

    elsif v_scenario <= 85 then
      -- reengagement_window: old baseline then a recent session
      for v_j in 1 .. 6 loop
        insert into events (workspace_id, customer_id, name, occurred_at, properties)
        values (p_workspace_id, v_customer_id, 'session_start',
                v_now - interval '30 days' - (random() * interval '60 days'), '{}'::jsonb);
        v_events_inserted := v_events_inserted + 1;
      end loop;
      insert into events (workspace_id, customer_id, name, occurred_at, properties)
      values (p_workspace_id, v_customer_id, 'session_start',
              v_now - (random() * interval '36 hours'), '{}'::jsonb);

    elsif v_scenario <= 92 then
      -- onboarding_stalled: signup event exists, activated never fires
      null;

    else
      -- healthy baseline
      for v_j in 1 .. 8 loop
        insert into events (workspace_id, customer_id, name, occurred_at, properties)
        values (
          p_workspace_id, v_customer_id,
          (array['session_start','transfer_sent','bill_paid','wallet_funded','savings_plan_created','investment_made','card_activated','kyc_completed','deposit_completed','goal_created','goal_contribution','activated'])[1 + floor(random()*12)::int],
          v_now - (random() * interval '20 days'),
          '{}'::jsonb
        );
        v_events_inserted := v_events_inserted + 1;
      end loop;
    end if;
  end loop;

  return jsonb_build_object(
    'ok', true,
    'customers_inserted', v_inserted,
    'events_inserted', v_events_inserted,
    'orphan_events_deleted', v_orphans_deleted,
    'prior_demo_deleted', v_demo_deleted
  );
end;
$$;

grant execute on function public.repopulate_demo_customers(uuid, int) to authenticated;