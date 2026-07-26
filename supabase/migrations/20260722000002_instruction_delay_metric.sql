-- Additive metric: instruction_delay_ms = time from the first instruction
-- being shown to the option grid appearing (Color Selector's
-- instruction-reading delay). Null for modules with no instruction_shown
-- event, and jsonb_strip_nulls drops it there, so every existing session's
-- metrics stay byte-identical and all existing fixtures pass unchanged.

create or replace function public.compute_session_metrics(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_t0 int; v_t1 int;
  v_stim int; v_hidden int; v_instr int;
  v_reaction int; v_recall int; v_instr_delay int;
  v_correct int; v_error int;
  v_hes_count int; v_idle int; v_longest int;
  v_mean numeric; v_median numeric; v_fastest int; v_slowest int;
begin
  if not exists (select 1 from public.sessions where id = p_session_id) then
    raise exception 'compute_session_metrics: unknown session %', p_session_id;
  end if;

  select min(t_ms), max(t_ms) into v_t0, v_t1
    from public.session_events where session_id = p_session_id;

  if v_t0 is null then
    raise exception 'compute_session_metrics: session % has no events', p_session_id;
  end if;

  select min(t_ms) into v_stim
    from public.session_events
   where session_id = p_session_id
     and event_type in ('sequence_display_started', 'question_displayed');

  select min(t_ms) into v_hidden
    from public.session_events
   where session_id = p_session_id and event_type = 'sequence_hidden';

  select min(t_ms) into v_instr
    from public.session_events
   where session_id = p_session_id and event_type = 'instruction_shown';

  -- Instruction-reading delay: first instruction shown -> first stimulus.
  if v_instr is not null and v_stim is not null then
    v_instr_delay := v_stim - v_instr;
  end if;

  select min(t_ms) - v_stim into v_reaction
    from public.session_events
   where session_id = p_session_id and event_type = 'tap_registered'
     and v_stim is not null and t_ms >= v_stim;

  select min(t_ms) - v_hidden into v_recall
    from public.session_events
   where session_id = p_session_id and event_type = 'tap_registered'
     and v_hidden is not null and t_ms >= v_hidden;

  select count(*) filter (where (payload ->> 'is_correct')::boolean),
         count(*) filter (where not (payload ->> 'is_correct')::boolean)
    into v_correct, v_error
    from public.session_events
   where session_id = p_session_id
     and event_type in ('tap_registered', 'answer_submitted')
     and payload ? 'is_correct';

  with taps as (
    select t_ms from public.session_events
     where session_id = p_session_id and event_type = 'tap_registered'
     order by seq
  ),
  gaps as (
    select t_ms - lag(t_ms) over (order by t_ms) as gap from taps
  ),
  g as (select gap from gaps where gap is not null)
  select count(*) filter (where gap > 3000),
         coalesce(sum(gap) filter (where gap > 3000), 0),
         max(gap),
         avg(gap),
         percentile_cont(0.5) within group (order by gap),
         min(gap),
         max(gap)
    into v_hes_count, v_idle, v_longest, v_mean, v_median, v_fastest, v_slowest
    from g;

  insert into public.session_metrics
    (session_id, metrics_version, total_time_ms, accuracy, error_count, extra)
  values
    (p_session_id,
     1,
     v_t1 - v_t0,
     case when coalesce(v_correct, 0) + coalesce(v_error, 0) = 0 then null
          else round(v_correct::numeric / (v_correct + v_error), 4) end,
     coalesce(v_error, 0),
     jsonb_strip_nulls(jsonb_build_object(
       'correct_count', coalesce(v_correct, 0),
       'reaction_time_ms', v_reaction,
       'recall_time_ms', v_recall,
       'instruction_delay_ms', v_instr_delay,
       'hesitation_count', coalesce(v_hes_count, 0),
       'total_idle_time_ms', coalesce(v_idle, 0),
       'longest_pause_ms', v_longest,
       'mean_decision_ms', round(v_mean, 2),
       'median_decision_ms', v_median,
       'fastest_decision_ms', v_fastest,
       'slowest_decision_ms', v_slowest
     )))
  on conflict (session_id, metrics_version) do update
    set computed_at = now(),
        total_time_ms = excluded.total_time_ms,
        accuracy = excluded.accuracy,
        error_count = excluded.error_count,
        extra = excluded.extra;

  update public.sessions set status = 'validated' where id = p_session_id;
end;
$$;

revoke execute on function public.compute_session_metrics(uuid) from anon, authenticated, public;
