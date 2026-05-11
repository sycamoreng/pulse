/*
  # Signal detection RPC

  1. New function
    - `detect_workspace_signals(p_workspace_id uuid)` returns jsonb
    - Scans recent events in the workspace and inserts rows into
      `customer_signals` for every rule that fires, respecting the
      unique `(workspace_id, customer_id, signal_key)` open-signal constraint.
    - Writes an `intelligence_runs` audit row.
  2. Security
    - SECURITY DEFINER, but verifies caller is workspace member OR service role.
  3. Supported rule types
    - event_count: fire if count(event) within window >= min_count.
    - event_sequence.cart_abandoned pattern: trigger event without absent event within N minutes.
    - event_sequence.returned_after_days: first event after a long gap.
    - absence: require_event present but absent_event missing since N hours/days.
*/

create or replace function public.detect_workspace_signals(p_workspace_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_member boolean;
  v_run_id uuid;
  v_signals_created int := 0;
  v_events_scanned int := 0;
  v_customers_touched int := 0;
  v_def record;
begin
  if p_workspace_id is null then
    return jsonb_build_object('ok', false, 'error', 'missing workspace');
  end if;

  select exists(
    select 1 from workspace_members wm where wm.workspace_id = p_workspace_id and wm.user_id = auth.uid()
    union all
    select 1 from workspaces w where w.id = p_workspace_id and w.owner_id = auth.uid()
  ) into v_is_member;

  if not coalesce(v_is_member, false) and coalesce((auth.jwt()->>'role'),'') <> 'service_role' then
    return jsonb_build_object('ok', false, 'error', 'not allowed');
  end if;

  insert into intelligence_runs (workspace_id, kind) values (p_workspace_id, 'detect')
  returning id into v_run_id;

  select count(*) into v_events_scanned
  from events
  where workspace_id = p_workspace_id
    and occurred_at >= now() - interval '30 days';

  for v_def in
    select * from signal_definitions where workspace_id = p_workspace_id and enabled = true
  loop
    if v_def.rule_type = 'event_count' then
      with recent as (
        select customer_id, count(*)::int as c
        from events
        where workspace_id = p_workspace_id
          and customer_id is not null
          and occurred_at >= now() - make_interval(mins => v_def.window_minutes)
          and (
            (v_def.rule->>'event_name') is null
            or name = (v_def.rule->>'event_name')
          )
        group by customer_id
      ), fires as (
        select customer_id, c from recent
        where c >= coalesce((v_def.rule->>'min_count')::int, 1)
      )
      insert into customer_signals (workspace_id, customer_id, signal_key, signal_label, category, confidence, context)
      select p_workspace_id, f.customer_id, v_def.key, v_def.label, v_def.category,
             least(1.0, 0.4 + (f.c::numeric / (coalesce((v_def.rule->>'min_count')::int,1)*4.0))),
             jsonb_build_object('count', f.c, 'window_minutes', v_def.window_minutes,
                                'event_name', v_def.rule->>'event_name')
      from fires f
      on conflict (workspace_id, customer_id, signal_key) where consumed_at is null do nothing;
      get diagnostics v_signals_created = row_count;

    elsif v_def.rule_type = 'event_sequence' and (v_def.rule ? 'trigger_event') then
      with trig as (
        select distinct on (customer_id) customer_id, occurred_at
        from events
        where workspace_id = p_workspace_id
          and customer_id is not null
          and name = (v_def.rule->>'trigger_event')
          and occurred_at >= now() - make_interval(mins => v_def.window_minutes)
        order by customer_id, occurred_at desc
      ), resolved as (
        select t.customer_id from trig t
        where exists (
          select 1 from events e
          where e.workspace_id = p_workspace_id and e.customer_id = t.customer_id
            and e.name = (v_def.rule->>'absent_event')
            and e.occurred_at between t.occurred_at and t.occurred_at + make_interval(mins => coalesce((v_def.rule->>'within_minutes')::int, 60))
        )
      ), fires as (
        select t.customer_id, t.occurred_at
        from trig t
        where not exists (select 1 from resolved r where r.customer_id = t.customer_id)
          and t.occurred_at <= now() - make_interval(mins => coalesce((v_def.rule->>'within_minutes')::int, 60))
      )
      insert into customer_signals (workspace_id, customer_id, signal_key, signal_label, category, confidence, context, expires_at)
      select p_workspace_id, f.customer_id, v_def.key, v_def.label, v_def.category,
             0.8,
             jsonb_build_object('triggered_at', f.occurred_at, 'trigger_event', v_def.rule->>'trigger_event'),
             now() + interval '72 hours'
      from fires f
      on conflict (workspace_id, customer_id, signal_key) where consumed_at is null do nothing;
      get diagnostics v_signals_created = row_count;

    elsif v_def.rule_type = 'event_sequence' and (v_def.rule ? 'returned_after_days') then
      with recent_session as (
        select distinct on (customer_id) customer_id, occurred_at as last_event
        from events
        where workspace_id = p_workspace_id and customer_id is not null
          and occurred_at >= now() - interval '48 hours'
        order by customer_id, occurred_at desc
      ), prior as (
        select rs.customer_id, rs.last_event,
               (select max(occurred_at) from events e
                 where e.workspace_id = p_workspace_id and e.customer_id = rs.customer_id
                   and e.occurred_at < rs.last_event) as previous_event
        from recent_session rs
      ), fires as (
        select customer_id, last_event, previous_event from prior
        where previous_event is not null
          and last_event - previous_event >= make_interval(days => coalesce((v_def.rule->>'returned_after_days')::int, 14))
      )
      insert into customer_signals (workspace_id, customer_id, signal_key, signal_label, category, confidence, context, expires_at)
      select p_workspace_id, f.customer_id, v_def.key, v_def.label, v_def.category,
             0.75,
             jsonb_build_object('gap_days', extract(day from (f.last_event - f.previous_event))),
             now() + interval '48 hours'
      from fires f
      on conflict (workspace_id, customer_id, signal_key) where consumed_at is null do nothing;
      get diagnostics v_signals_created = row_count;

    elsif v_def.rule_type = 'absence' then
      with base as (
        select c.id as customer_id,
               (select max(occurred_at) from events e where e.workspace_id = p_workspace_id and e.customer_id = c.id) as last_event,
               (select max(occurred_at) from events e
                  where e.workspace_id = p_workspace_id and e.customer_id = c.id and e.name = (v_def.rule->>'require_event')) as trigger_at,
               (select max(occurred_at) from events e
                  where e.workspace_id = p_workspace_id and e.customer_id = c.id and e.name = (v_def.rule->>'absent_event')) as resolve_at
        from customers c where c.workspace_id = p_workspace_id
      ), fires as (
        select customer_id
        from base
        where
          case
            when (v_def.rule ? 'quiet_days') and (v_def.rule ? 'require_prior_days') then
              last_event is not null
              and last_event <= now() - make_interval(days => (v_def.rule->>'quiet_days')::int)
              and last_event >= now() - make_interval(days => (v_def.rule->>'quiet_days')::int + (v_def.rule->>'require_prior_days')::int)
            else
              (v_def.rule->>'require_event') is not null
              and trigger_at is not null
              and (resolve_at is null or resolve_at < trigger_at)
              and trigger_at <= now() - case
                when v_def.rule ? 'since_hours' then make_interval(hours => (v_def.rule->>'since_hours')::int)
                when v_def.rule ? 'since_days' then make_interval(days => (v_def.rule->>'since_days')::int)
                else interval '24 hours'
              end
          end
      )
      insert into customer_signals (workspace_id, customer_id, signal_key, signal_label, category, confidence, context, expires_at)
      select p_workspace_id, f.customer_id, v_def.key, v_def.label, v_def.category,
             0.7,
             jsonb_build_object('rule', v_def.rule),
             now() + interval '14 days'
      from fires f
      on conflict (workspace_id, customer_id, signal_key) where consumed_at is null do nothing;
      get diagnostics v_signals_created = row_count;
    end if;
  end loop;

  select count(distinct customer_id)::int into v_customers_touched
  from customer_signals
  where workspace_id = p_workspace_id and detected_at >= (select started_at from intelligence_runs where id = v_run_id);

  update intelligence_runs
    set finished_at = now(),
        events_scanned = v_events_scanned,
        signals_created = coalesce(v_signals_created, 0),
        customers_touched = v_customers_touched
    where id = v_run_id;

  return jsonb_build_object(
    'ok', true,
    'run_id', v_run_id,
    'events_scanned', v_events_scanned,
    'customers_touched', v_customers_touched
  );
exception when others then
  update intelligence_runs set finished_at = now(), error = sqlerrm where id = v_run_id;
  return jsonb_build_object('ok', false, 'error', sqlerrm);
end;
$$;

grant execute on function public.detect_workspace_signals(uuid) to authenticated, service_role;