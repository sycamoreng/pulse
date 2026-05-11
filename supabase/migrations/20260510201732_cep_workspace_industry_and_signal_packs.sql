/*
  # Industry-aware signals

  1. Schema changes
    - `workspaces.industry` (text) — one of: 'generic','fintech','saas','media','commerce','healthtech','edtech','marketplace','gaming','travel'.
      Defaults to 'generic'. Used to tailor signal library and AI prompts.
    - `signal_definitions.industry` (text) — the pack this definition belongs to
      ('generic' applies to all, or a specific industry). Default 'generic'.

  2. Signal packs
    - `seed_signal_definitions(workspace_id)` is expanded to seed the generic pack
      plus the pack for the workspace's industry.
    - Fintech pack: kyc_stalled, first_deposit_pending, low_balance_drift,
      high_value_deposit, card_activation_missed, suspicious_pattern,
      savings_goal_stalled, cross_sell_investment.
    - SaaS pack: trial_midpoint, trial_ending_soon, integration_not_connected,
      seats_unused, feature_limit_near.
    - Media pack: binge_session, story_completion_drop, subscription_lapse_risk.
    - Commerce pack (existing): retained.
    - Generic pack: reengagement_window, content_deep_dive, power_user,
      onboarding_stalled, churn_risk, feature_discovery_stalled.

  3. Notes
    - Existing signal rows are preserved. New packs are additive.
    - Changing industry later will seed the matching pack (idempotent).
*/

alter table workspaces add column if not exists industry text not null default 'generic';
alter table signal_definitions add column if not exists industry text not null default 'generic';

create or replace function public.seed_signal_definitions(p_workspace_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_industry text;
begin
  select coalesce(industry, 'generic') into v_industry from workspaces where id = p_workspace_id;

  -- GENERIC (applies to every workspace)
  insert into signal_definitions (workspace_id, key, label, description, rule_type, rule, window_minutes, priority, category, industry, enabled) values
    (p_workspace_id, 'onboarding_stalled', 'Onboarding stalled',
     'Signed up but has not completed a core activation event.',
     'absence',
     jsonb_build_object('require_event','signup','absent_event','activated','since_hours',24),
     4320, 85, 'lifecycle', 'generic', true),
    (p_workspace_id, 'power_user', 'Power user',
     'Highly active in the last week — prime candidate for advocacy or upsell.',
     'event_count',
     jsonb_build_object('min_count',20),
     10080, 40, 'engagement', 'generic', true),
    (p_workspace_id, 'churn_risk', 'Churn risk',
     'Previously active, now quiet for 14+ days.',
     'absence',
     jsonb_build_object('require_prior_days',30,'quiet_days',14),
     43200, 80, 'retention', 'generic', true),
    (p_workspace_id, 'reengagement_window', 'Re-engagement window',
     'Returning user after a long absence.',
     'event_sequence',
     jsonb_build_object('returned_after_days',14),
     1440, 75, 'retention', 'generic', true),
    (p_workspace_id, 'content_deep_dive', 'Content deep dive',
     'Viewed 5+ pieces of content in a single session.',
     'event_count',
     jsonb_build_object('event_name','content_viewed','min_count',5),
     120, 50, 'engagement', 'generic', true),
    (p_workspace_id, 'feature_discovery_stalled', 'Feature discovery stalled',
     'Active but has not tried a key feature yet.',
     'absence',
     jsonb_build_object('require_event','session_start','absent_event','feature_used','since_days',7),
     20160, 55, 'product', 'generic', true)
  on conflict (workspace_id, key) do nothing;

  -- COMMERCE pack
  if v_industry = 'commerce' then
    insert into signal_definitions (workspace_id, key, label, description, rule_type, rule, window_minutes, priority, category, industry, enabled) values
      (p_workspace_id, 'cart_abandoned', 'Cart abandoned',
       'Added to cart but did not purchase within 60 minutes.',
       'event_sequence',
       jsonb_build_object('trigger_event','add_to_cart','absent_event','purchase','within_minutes',60),
       120, 90, 'commerce', 'commerce', true),
      (p_workspace_id, 'price_hesitation', 'Price hesitation',
       'Repeatedly viewed the same product or pricing page without buying.',
       'event_count',
       jsonb_build_object('event_name','product_viewed','min_count',3),
       1440, 70, 'commerce', 'commerce', true),
      (p_workspace_id, 'post_purchase_cross_sell', 'Post-purchase cross-sell window',
       'Recent purchaser — ideal window for complementary items.',
       'event_count',
       jsonb_build_object('event_name','purchase','min_count',1),
       1440, 55, 'commerce', 'commerce', true)
    on conflict (workspace_id, key) do nothing;
  end if;

  -- FINTECH pack
  if v_industry = 'fintech' then
    insert into signal_definitions (workspace_id, key, label, description, rule_type, rule, window_minutes, priority, category, industry, enabled) values
      (p_workspace_id, 'kyc_stalled', 'KYC verification stalled',
       'Started KYC but did not complete within 24 hours.',
       'event_sequence',
       jsonb_build_object('trigger_event','kyc_started','absent_event','kyc_completed','within_minutes',1440),
       4320, 95, 'onboarding', 'fintech', true),
      (p_workspace_id, 'first_deposit_pending', 'First deposit pending',
       'Account funded flow started but no deposit yet.',
       'absence',
       jsonb_build_object('require_event','account_opened','absent_event','deposit_completed','since_hours',48),
       10080, 90, 'activation', 'fintech', true),
      (p_workspace_id, 'card_activation_missed', 'Card activation missed',
       'Card issued but not activated after 7 days.',
       'absence',
       jsonb_build_object('require_event','card_issued','absent_event','card_activated','since_days',7),
       30240, 80, 'activation', 'fintech', true),
      (p_workspace_id, 'low_balance_drift', 'Low-balance drift',
       'Balance has stayed low — surface a savings or top-up nudge.',
       'event_count',
       jsonb_build_object('event_name','balance_low','min_count',3),
       10080, 60, 'wellbeing', 'fintech', true),
      (p_workspace_id, 'high_value_deposit', 'High-value deposit',
       'Unusually large deposit — ideal moment for wealth or investment cross-sell.',
       'event_count',
       jsonb_build_object('event_name','deposit_large','min_count',1),
       10080, 70, 'cross_sell', 'fintech', true),
      (p_workspace_id, 'savings_goal_stalled', 'Savings goal stalled',
       'Set a goal but no contributions in two weeks.',
       'absence',
       jsonb_build_object('require_event','goal_created','absent_event','goal_contribution','since_days',14),
       43200, 55, 'wellbeing', 'fintech', true),
      (p_workspace_id, 'cross_sell_investment', 'Investment cross-sell opening',
       'Consistent deposits with idle cash — good fit for investing.',
       'event_count',
       jsonb_build_object('event_name','deposit_completed','min_count',4),
       43200, 50, 'cross_sell', 'fintech', true),
      (p_workspace_id, 'suspicious_pattern', 'Unusual activity',
       'Pattern deviates from historical behaviour — security nudge.',
       'event_count',
       jsonb_build_object('event_name','login_new_device','min_count',1),
       1440, 92, 'security', 'fintech', true)
    on conflict (workspace_id, key) do nothing;
  end if;

  -- SAAS pack
  if v_industry = 'saas' then
    insert into signal_definitions (workspace_id, key, label, description, rule_type, rule, window_minutes, priority, category, industry, enabled) values
      (p_workspace_id, 'trial_midpoint', 'Trial midpoint reached',
       'Halfway through trial — highlight value to drive conversion.',
       'event_count',
       jsonb_build_object('event_name','trial_day_reached','min_count',1),
       43200, 80, 'lifecycle', 'saas', true),
      (p_workspace_id, 'trial_ending_soon', 'Trial ending soon',
       'Trial ends within 3 days — conversion push moment.',
       'event_count',
       jsonb_build_object('event_name','trial_ending','min_count',1),
       4320, 92, 'lifecycle', 'saas', true),
      (p_workspace_id, 'integration_not_connected', 'Integration not connected',
       'Signed up but has not connected a key integration.',
       'absence',
       jsonb_build_object('require_event','workspace_created','absent_event','integration_connected','since_days',3),
       10080, 70, 'activation', 'saas', true),
      (p_workspace_id, 'seats_unused', 'Invited seats unused',
       'Teammates were invited but have not logged in.',
       'absence',
       jsonb_build_object('require_event','seat_invited','absent_event','seat_accepted','since_days',5),
       20160, 55, 'expansion', 'saas', true),
      (p_workspace_id, 'feature_limit_near', 'Approaching plan limit',
       'Usage is close to plan limits — good time to discuss upgrade.',
       'event_count',
       jsonb_build_object('event_name','limit_warning','min_count',1),
       10080, 75, 'expansion', 'saas', true)
    on conflict (workspace_id, key) do nothing;
  end if;

  -- MEDIA pack
  if v_industry = 'media' then
    insert into signal_definitions (workspace_id, key, label, description, rule_type, rule, window_minutes, priority, category, industry, enabled) values
      (p_workspace_id, 'binge_session', 'Binge session',
       'Consuming content aggressively in a single sitting — recommend more.',
       'event_count',
       jsonb_build_object('event_name','content_viewed','min_count',5),
       180, 65, 'engagement', 'media', true),
      (p_workspace_id, 'story_completion_drop', 'Completion drop-off',
       'Starts content but rarely finishes — surface shorter or related formats.',
       'event_count',
       jsonb_build_object('event_name','content_abandoned','min_count',3),
       10080, 55, 'engagement', 'media', true),
      (p_workspace_id, 'subscription_lapse_risk', 'Subscription lapse risk',
       'Reading frequency down sharply — retention window.',
       'absence',
       jsonb_build_object('require_prior_days',30,'quiet_days',10),
       30240, 80, 'retention', 'media', true)
    on conflict (workspace_id, key) do nothing;
  end if;

  -- HEALTHTECH pack
  if v_industry = 'healthtech' then
    insert into signal_definitions (workspace_id, key, label, description, rule_type, rule, window_minutes, priority, category, industry, enabled) values
      (p_workspace_id, 'appointment_missed', 'Appointment missed',
       'Booked but did not attend — offer reschedule.',
       'event_sequence',
       jsonb_build_object('trigger_event','appointment_booked','absent_event','appointment_attended','within_minutes',10080),
       43200, 85, 'adherence', 'healthtech', true),
      (p_workspace_id, 'medication_adherence_drop', 'Adherence dropping',
       'Logged intake has fallen behind plan.',
       'event_count',
       jsonb_build_object('event_name','intake_missed','min_count',3),
       10080, 80, 'adherence', 'healthtech', true),
      (p_workspace_id, 'assessment_stalled', 'Assessment stalled',
       'Started a health assessment but did not finish.',
       'event_sequence',
       jsonb_build_object('trigger_event','assessment_started','absent_event','assessment_completed','within_minutes',2880),
       4320, 70, 'onboarding', 'healthtech', true)
    on conflict (workspace_id, key) do nothing;
  end if;

  -- EDTECH pack
  if v_industry = 'edtech' then
    insert into signal_definitions (workspace_id, key, label, description, rule_type, rule, window_minutes, priority, category, industry, enabled) values
      (p_workspace_id, 'course_stalled', 'Course stalled',
       'Enrolled in a course but no progress in 5 days.',
       'absence',
       jsonb_build_object('require_event','course_enrolled','absent_event','lesson_completed','since_days',5),
       20160, 80, 'progress', 'edtech', true),
      (p_workspace_id, 'lesson_streak', 'Lesson streak',
       'Long learning streak — reinforce with encouragement.',
       'event_count',
       jsonb_build_object('event_name','lesson_completed','min_count',5),
       10080, 50, 'engagement', 'edtech', true),
      (p_workspace_id, 'assignment_overdue', 'Assignment overdue',
       'Assignment due but not submitted.',
       'event_count',
       jsonb_build_object('event_name','assignment_overdue','min_count',1),
       4320, 75, 'progress', 'edtech', true)
    on conflict (workspace_id, key) do nothing;
  end if;

  -- MARKETPLACE pack
  if v_industry = 'marketplace' then
    insert into signal_definitions (workspace_id, key, label, description, rule_type, rule, window_minutes, priority, category, industry, enabled) values
      (p_workspace_id, 'first_listing_pending', 'First listing pending',
       'Seller signed up but has not created a listing.',
       'absence',
       jsonb_build_object('require_event','seller_signup','absent_event','listing_created','since_days',3),
       10080, 80, 'supply', 'marketplace', true),
      (p_workspace_id, 'abandoned_search', 'Abandoned search',
       'Searched but did not engage with any result.',
       'event_sequence',
       jsonb_build_object('trigger_event','search','absent_event','listing_viewed','within_minutes',30),
       180, 60, 'demand', 'marketplace', true)
    on conflict (workspace_id, key) do nothing;
  end if;

  -- GAMING pack
  if v_industry = 'gaming' then
    insert into signal_definitions (workspace_id, key, label, description, rule_type, rule, window_minutes, priority, category, industry, enabled) values
      (p_workspace_id, 'level_stuck', 'Stuck on level',
       'Multiple failed attempts on the same level — offer tips or boost.',
       'event_count',
       jsonb_build_object('event_name','level_failed','min_count',3),
       180, 70, 'progression', 'gaming', true),
      (p_workspace_id, 'first_purchase_window', 'First purchase window',
       'Engaged free player who has never purchased.',
       'absence',
       jsonb_build_object('require_event','session_start','absent_event','iap_completed','since_days',3),
       20160, 65, 'monetisation', 'gaming', true)
    on conflict (workspace_id, key) do nothing;
  end if;

  -- TRAVEL pack
  if v_industry = 'travel' then
    insert into signal_definitions (workspace_id, key, label, description, rule_type, rule, window_minutes, priority, category, industry, enabled) values
      (p_workspace_id, 'search_without_book', 'Search without booking',
       'Repeated destination searches with no booking.',
       'event_count',
       jsonb_build_object('event_name','search','min_count',3),
       4320, 70, 'demand', 'travel', true),
      (p_workspace_id, 'trip_upcoming', 'Trip upcoming',
       'Booked a trip happening soon — offer add-ons.',
       'event_count',
       jsonb_build_object('event_name','trip_upcoming','min_count',1),
       4320, 60, 'ancillary', 'travel', true)
    on conflict (workspace_id, key) do nothing;
  end if;
end;
$$;

grant execute on function public.seed_signal_definitions(uuid) to authenticated, service_role;

-- Re-seed all existing workspaces to adopt the new structure
do $$
declare w record;
begin
  for w in select id from workspaces loop
    perform public.seed_signal_definitions(w.id);
  end loop;
end $$;

-- RPC so a user can change their workspace industry from the UI
create or replace function public.set_workspace_industry(p_workspace_id uuid, p_industry text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_allowed boolean;
begin
  if p_industry not in ('generic','fintech','saas','media','commerce','healthtech','edtech','marketplace','gaming','travel') then
    return jsonb_build_object('ok', false, 'error', 'invalid industry');
  end if;
  select exists(
    select 1 from workspace_members wm where wm.workspace_id = p_workspace_id and wm.user_id = auth.uid() and wm.role in ('owner','admin')
    union all
    select 1 from workspaces w where w.id = p_workspace_id and w.owner_id = auth.uid()
  ) into v_allowed;
  if not coalesce(v_allowed,false) then
    return jsonb_build_object('ok', false, 'error', 'not allowed');
  end if;
  update workspaces set industry = p_industry where id = p_workspace_id;
  perform public.seed_signal_definitions(p_workspace_id);
  return jsonb_build_object('ok', true, 'industry', p_industry);
end;
$$;

grant execute on function public.set_workspace_industry(uuid, text) to authenticated;