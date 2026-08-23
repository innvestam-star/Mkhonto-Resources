create or replace function private.assert_mrcip_ai_stage14_runtime_gate(
  p_organisation_id uuid,
  p_provider_config_id uuid,
  p_prompt_version_id uuid,
  p_protected_context boolean,
  p_requester_id uuid,
  p_execution_id uuid default null
)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare
  rc public.mrcip_ai_runtime_controls%rowtype;
  rp public.mrcip_ai_release_plans%rowtype;
  o public.mrcip_ai_provider_onboarding%rowtype;
  cfg public.mrcip_ai_provider_configs%rowtype;
  pv public.mrcip_ai_prompt_versions%rowtype;
  rate public.mrcip_ai_provider_rates%rowtype;
  bud public.mrcip_ai_budget_policies%rowtype;
  pred public.mrcip_ai_release_plans%rowtype;
  latest_onboarding_id uuid;
  hourly_count integer:=0;
  daily_count integer:=0;
  protected_count integer:=0;
  pilot_count integer:=0;
  pilot_protected_count integer:=0;
  month_spend numeric:=0;
  day_spend numeric:=0;
  over_exec integer:=0;
begin
  if p_requester_id is null then raise exception 'Stage 14 requester identity is required'; end if;
  select * into rc from public.mrcip_ai_runtime_controls where organisation_id=p_organisation_id and provider_config_id=p_provider_config_id;
  if not found or rc.runtime_state not in ('pilot','production') or rc.emergency_stop or rc.active_release_plan_id is null then raise exception 'Stage 14 runtime is not enabled for this provider'; end if;
  select * into rp from public.mrcip_ai_release_plans where organisation_id=p_organisation_id and id=rc.active_release_plan_id and provider_config_id=p_provider_config_id;
  if not found or rp.status<>'approved' or rp.release_scope<>rc.runtime_state then raise exception 'Stage 14 active release plan is invalid'; end if;
  if rp.prompt_version_id<>p_prompt_version_id then raise exception 'Execution prompt is not the active Stage 14 release prompt'; end if;
  if not exists (
    select 1 from public.organisation_memberships om
    left join public.mrcip_user_roles mur on mur.organisation_id=om.organisation_id and mur.membership_id=om.id
    where om.organisation_id=p_organisation_id and om.user_id=p_requester_id and om.status='active'
      and (om.role='owner' or mur.role_key=any(rp.allowed_role_keys))
  ) then raise exception 'Requester is outside the active Stage 14 release role allowlist'; end if;
  select * into o from public.mrcip_ai_provider_onboarding where organisation_id=p_organisation_id and id=rp.onboarding_id and provider_config_id=p_provider_config_id;
  if not found or o.status<>'production_approved' or o.prompt_version_id<>rp.prompt_version_id then raise exception 'Stage 13 onboarding approval is no longer valid'; end if;
  select id into latest_onboarding_id from public.mrcip_ai_provider_onboarding where organisation_id=p_organisation_id and provider_config_id=p_provider_config_id and status='production_approved' order by revision_no desc limit 1;
  if latest_onboarding_id is distinct from rp.onboarding_id then raise exception 'A newer Stage 13 onboarding approval requires a new Stage 14 release decision'; end if;
  if rp.release_scope='production' then
    select * into pred from public.mrcip_ai_release_plans where organisation_id=p_organisation_id and id=rp.predecessor_release_plan_id and provider_config_id=p_provider_config_id;
    if not found or pred.release_scope<>'pilot' or pred.status not in ('approved','retired') then raise exception 'Production release pilot evidence is no longer valid'; end if;
  end if;
  select * into cfg from public.mrcip_ai_provider_configs where organisation_id=p_organisation_id and id=p_provider_config_id;
  if not found or cfg.status<>'active' or cfg.connection_status<>'verified' or cfg.credential_status<>'configured_external_secret' then raise exception 'Provider is not active, verified and credential-ready'; end if;
  select * into pv from public.mrcip_ai_prompt_versions where organisation_id=p_organisation_id and id=p_prompt_version_id;
  if not found or pv.status<>'approved' then raise exception 'Stage 14 release prompt is no longer approved'; end if;
  if p_protected_context and (not rp.protected_data_allowed or not o.protected_data_approved or not cfg.protected_data_allowed or not pv.protected_data_approved) then raise exception 'Protected execution exceeds current Stage 13/14 approvals'; end if;
  select * into rate from public.mrcip_ai_provider_rates where organisation_id=p_organisation_id and id=o.rate_card_id and provider_config_id=p_provider_config_id and status='active' and effective_from<=now() and (effective_to is null or effective_to>now());
  select * into bud from public.mrcip_ai_budget_policies where organisation_id=p_organisation_id and id=o.budget_policy_id and provider_config_id=p_provider_config_id and status='active' and effective_from<=now() and (effective_to is null or effective_to>now());
  if rate.id is null or bud.id is null or rate.currency<>bud.currency then raise exception 'Current Stage 13 rate/budget controls are unavailable'; end if;
  if pv.max_output_tokens>bud.max_output_tokens_per_execution then raise exception 'Prompt output cap exceeds current AI budget policy'; end if;
  select count(*)::integer into hourly_count from public.mrcip_ai_executions e where e.organisation_id=p_organisation_id and e.provider_config_id=p_provider_config_id and e.prepared_at>=now()-interval '1 hour' and e.status in ('prepared','running','completed') and (p_execution_id is null or e.id<>p_execution_id);
  select count(*)::integer into daily_count from public.mrcip_ai_executions e where e.organisation_id=p_organisation_id and e.provider_config_id=p_provider_config_id and e.prepared_at>=date_trunc('day',now()) and e.status in ('prepared','running','completed') and (p_execution_id is null or e.id<>p_execution_id);
  select count(*)::integer into protected_count from public.mrcip_ai_executions e where e.organisation_id=p_organisation_id and e.provider_config_id=p_provider_config_id and e.prepared_at>=date_trunc('day',now()) and e.protected_context and e.status in ('prepared','running','completed') and (p_execution_id is null or e.id<>p_execution_id);
  if hourly_count>=bud.max_executions_per_hour then raise exception 'Stage 14 start blocked: hourly execution limit reached'; end if;
  if daily_count>=bud.max_executions_per_day then raise exception 'Stage 14 start blocked: daily execution limit reached'; end if;
  if p_protected_context and protected_count>=bud.max_protected_executions_per_day then raise exception 'Stage 14 start blocked: protected-context daily execution limit reached'; end if;
  select coalesce(sum(e.cost_amount),0) into month_spend from public.mrcip_ai_executions e where e.organisation_id=p_organisation_id and e.provider_config_id=p_provider_config_id and e.status='completed' and e.cost_currency=bud.currency and e.finished_at>=date_trunc('month',now()) and (p_execution_id is null or e.id<>p_execution_id);
  if month_spend>=bud.monthly_budget then raise exception 'Stage 14 start blocked: monthly AI budget reached'; end if;
  if bud.daily_budget is not null then
    select coalesce(sum(e.cost_amount),0) into day_spend from public.mrcip_ai_executions e where e.organisation_id=p_organisation_id and e.provider_config_id=p_provider_config_id and e.status='completed' and e.cost_currency=bud.currency and e.finished_at>=date_trunc('day',now()) and (p_execution_id is null or e.id<>p_execution_id);
    if day_spend>=bud.daily_budget then raise exception 'Stage 14 start blocked: daily AI budget reached'; end if;
  end if;
  select count(*)::integer into over_exec from public.mrcip_ai_executions e where e.organisation_id=p_organisation_id and e.provider_config_id=p_provider_config_id and e.status='completed' and e.finished_at>=date_trunc('month',now()) and e.cost_currency=bud.currency and e.cost_amount>bud.max_cost_per_execution and (p_execution_id is null or e.id<>p_execution_id);
  if over_exec>0 then raise exception 'Stage 14 start blocked: execution-cost breach requires review'; end if;
  if rc.runtime_state='pilot' then
    select count(*)::integer into pilot_count from public.mrcip_ai_execution_release_links l where l.organisation_id=p_organisation_id and l.release_plan_id=rp.id and (p_execution_id is null or l.execution_id<>p_execution_id);
    select count(*)::integer into pilot_protected_count from public.mrcip_ai_execution_release_links l join public.mrcip_ai_executions e on e.organisation_id=l.organisation_id and e.id=l.execution_id where l.organisation_id=p_organisation_id and l.release_plan_id=rp.id and e.protected_context and (p_execution_id is null or e.id<>p_execution_id);
    if pilot_count>=rp.pilot_execution_limit then raise exception 'Stage 14 pilot execution limit reached'; end if;
    if p_protected_context and pilot_protected_count>=rp.pilot_protected_execution_limit then raise exception 'Stage 14 pilot protected-execution limit reached'; end if;
  end if;
  return rp.id;
end; $$;
revoke all on function private.assert_mrcip_ai_stage14_runtime_gate(uuid,uuid,uuid,boolean,uuid,uuid) from public,anon,authenticated;
grant execute on function private.assert_mrcip_ai_stage14_runtime_gate(uuid,uuid,uuid,boolean,uuid,uuid) to service_role;

create or replace function private.enforce_mrcip_ai_stage14_execution_gate()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  perform private.assert_mrcip_ai_stage14_runtime_gate(new.organisation_id,new.provider_config_id,new.prompt_version_id,new.protected_context,new.requested_by,null);
  return new;
end; $$;
revoke all on function private.enforce_mrcip_ai_stage14_execution_gate() from public,anon,authenticated;
create trigger zz_mrcip_ai_executions_stage14_release_gate_bi before insert on public.mrcip_ai_executions for each row execute function private.enforce_mrcip_ai_stage14_execution_gate();

create or replace function private.link_mrcip_ai_stage14_execution_release()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare rc public.mrcip_ai_runtime_controls%rowtype;
begin
  select * into rc from public.mrcip_ai_runtime_controls where organisation_id=new.organisation_id and provider_config_id=new.provider_config_id;
  if not found or rc.active_release_plan_id is null or rc.runtime_state not in ('pilot','production') or rc.emergency_stop then raise exception 'Stage 14 runtime changed before execution release linkage'; end if;
  insert into public.mrcip_ai_execution_release_links(organisation_id,execution_id,release_plan_id,runtime_state_snapshot)
  values(new.organisation_id,new.id,rc.active_release_plan_id,rc.runtime_state);
  return new;
end; $$;
revoke all on function private.link_mrcip_ai_stage14_execution_release() from public,anon,authenticated;
create trigger zz_mrcip_ai_executions_stage14_release_link_ai after insert on public.mrcip_ai_executions for each row execute function private.link_mrcip_ai_stage14_execution_release();

create or replace function private.enforce_mrcip_ai_stage14_start_gate()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare rid uuid; linked_rid uuid;
begin
  if old.status='prepared' and new.status='running' then
    rid:=private.assert_mrcip_ai_stage14_runtime_gate(old.organisation_id,old.provider_config_id,old.prompt_version_id,old.protected_context,old.requested_by,old.id);
    select release_plan_id into linked_rid from public.mrcip_ai_execution_release_links where organisation_id=old.organisation_id and execution_id=old.id;
    if linked_rid is null or linked_rid<>rid then raise exception 'Stage 14 execution release provenance changed before provider start'; end if;
  end if;
  return new;
end; $$;
revoke all on function private.enforce_mrcip_ai_stage14_start_gate() from public,anon,authenticated;
create trigger zz_mrcip_ai_executions_stage14_start_gate_bu before update on public.mrcip_ai_executions for each row execute function private.enforce_mrcip_ai_stage14_start_gate();

create or replace function private.auto_pause_mrcip_ai_stage14_execution()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare l public.mrcip_ai_execution_release_links%rowtype; rp public.mrcip_ai_release_plans%rowtype; rc public.mrcip_ai_runtime_controls%rowtype; terminal_count integer:=0; failed_count integer:=0; failure_rate numeric:=0; event_name text; reason_text text;
begin
  if old.status is distinct from new.status and new.status in ('completed','failed','blocked') then
    select * into l from public.mrcip_ai_execution_release_links where organisation_id=new.organisation_id and execution_id=new.id;
    if not found then return new; end if;
    select * into rp from public.mrcip_ai_release_plans where organisation_id=new.organisation_id and id=l.release_plan_id;
    select * into rc from public.mrcip_ai_runtime_controls where organisation_id=new.organisation_id and provider_config_id=new.provider_config_id and active_release_plan_id=l.release_plan_id;
    if rp.id is null or rc.id is null or rc.runtime_state not in ('pilot','production') or rc.emergency_stop then return new; end if;
    if coalesce((new.provider_telemetry->>'stage13_budget_breach')::boolean,false) then
      event_name:='auto_paused_budget'; reason_text:='Automatic Stage 14 pause: Stage 13 execution budget breach recorded';
    elsif rc.runtime_state='pilot' then
      select count(*) filter (where e.status in ('completed','failed','blocked'))::integer,count(*) filter (where e.status in ('failed','blocked'))::integer into terminal_count,failed_count from public.mrcip_ai_execution_release_links x join public.mrcip_ai_executions e on e.organisation_id=x.organisation_id and e.id=x.execution_id where x.organisation_id=new.organisation_id and x.release_plan_id=rp.id;
      failure_rate:=case when terminal_count=0 then 0 else failed_count::numeric/terminal_count::numeric end;
      if terminal_count>=3 and failure_rate>rp.max_pilot_failure_rate then event_name:='auto_paused_failure_rate'; reason_text:='Automatic Stage 14 pause: pilot failure-rate threshold exceeded'; end if;
    end if;
    if event_name is not null then
      perform set_config('app.mrcip_ai_runtime_system_write','on',true);
      update public.mrcip_ai_runtime_controls set runtime_state='paused',emergency_stop=true,transition_reason=left(reason_text,4000),updated_by=null where id=rc.id;
      perform set_config('app.mrcip_ai_runtime_system_event_write','on',true);
      insert into public.mrcip_ai_runtime_events(organisation_id,provider_config_id,release_plan_id,execution_id,event_type,actor_kind,actor_user_id,reason,details)
      values(new.organisation_id,new.provider_config_id,rp.id,new.id,event_name,'system',null,reason_text,jsonb_build_object('terminal_count',terminal_count,'failed_count',failed_count,'failure_rate',failure_rate));
    end if;
  end if;
  return new;
end; $$;
revoke all on function private.auto_pause_mrcip_ai_stage14_execution() from public,anon,authenticated;
create trigger zz_mrcip_ai_executions_stage14_auto_pause_au after update on public.mrcip_ai_executions for each row execute function private.auto_pause_mrcip_ai_stage14_execution();

create or replace function private.auto_pause_mrcip_ai_stage14_protection_review()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare e public.mrcip_ai_executions%rowtype; l public.mrcip_ai_execution_release_links%rowtype; rc public.mrcip_ai_runtime_controls%rowtype;
begin
  if new.protection_check_passed=false then
    select e0.* into e from public.mrcip_ai_responses r join public.mrcip_ai_executions e0 on e0.organisation_id=r.organisation_id and e0.id=r.execution_id where r.organisation_id=new.organisation_id and r.id=new.response_id;
    if e.id is null then return new; end if;
    select * into l from public.mrcip_ai_execution_release_links where organisation_id=e.organisation_id and execution_id=e.id;
    if l.id is null then return new; end if;
    select * into rc from public.mrcip_ai_runtime_controls where organisation_id=e.organisation_id and provider_config_id=e.provider_config_id and active_release_plan_id=l.release_plan_id;
    if rc.id is null or rc.runtime_state not in ('pilot','production') or rc.emergency_stop then return new; end if;
    perform set_config('app.mrcip_ai_runtime_system_write','on',true);
    update public.mrcip_ai_runtime_controls set runtime_state='paused',emergency_stop=true,transition_reason='Automatic Stage 14 pause: human protection review failed',updated_by=null where id=rc.id;
    perform set_config('app.mrcip_ai_runtime_system_event_write','on',true);
    insert into public.mrcip_ai_runtime_events(organisation_id,provider_config_id,release_plan_id,execution_id,event_type,actor_kind,actor_user_id,reason,details)
    values(e.organisation_id,e.provider_config_id,l.release_plan_id,e.id,'auto_paused_protection','system',null,'Automatic Stage 14 pause: human protection review failed',jsonb_build_object('review_id',new.id,'response_id',new.response_id,'reviewer_id',new.reviewer_id));
  end if;
  return new;
end; $$;
revoke all on function private.auto_pause_mrcip_ai_stage14_protection_review() from public,anon,authenticated;
create trigger zz_mrcip_ai_reviews_stage14_protection_pause_ai after insert on public.mrcip_ai_reviews for each row execute function private.auto_pause_mrcip_ai_stage14_protection_review();