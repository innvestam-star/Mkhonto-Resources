create or replace function private.guard_mrcip_ai_release_plan()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  internal_write boolean := current_setting('app.mrcip_ai_release_write',true)='on';
  next_revision integer;
  o public.mrcip_ai_provider_onboarding%rowtype;
  p public.mrcip_ai_release_plans%rowtype;
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','legal_compliance']) then raise exception 'Executive/legal release authority required'; end if;
  select * into o from public.mrcip_ai_provider_onboarding where organisation_id=new.organisation_id and id=new.onboarding_id and provider_config_id=new.provider_config_id;
  if not found or o.status<>'production_approved' or o.prompt_version_id<>new.prompt_version_id then raise exception 'Release plan must reference the current Stage 13 production-approved onboarding and evaluated prompt'; end if;
  if tg_op='INSERT' then
    if new.status<>'draft' then raise exception 'New release plans must begin in draft'; end if;
    select coalesce(max(revision_no),0)+1 into next_revision from public.mrcip_ai_release_plans where organisation_id=new.organisation_id and provider_config_id=new.provider_config_id;
    new.revision_no:=next_revision;
    new.created_at:=now(); new.created_by:=uid; new.approved_at:=null; new.approved_by:=null; new.revoked_at:=null; new.revoked_by:=null;
    if new.release_scope='production' then
      select * into p from public.mrcip_ai_release_plans where organisation_id=new.organisation_id and id=new.predecessor_release_plan_id and provider_config_id=new.provider_config_id;
      if not found or p.release_scope<>'pilot' or p.status not in ('approved','retired') then raise exception 'Production release requires an approved/retired pilot predecessor for the same provider'; end if;
    end if;
  else
    if old.organisation_id<>new.organisation_id or old.provider_config_id<>new.provider_config_id or old.onboarding_id<>new.onboarding_id or old.prompt_version_id<>new.prompt_version_id or old.predecessor_release_plan_id is distinct from new.predecessor_release_plan_id or old.revision_no<>new.revision_no or old.release_scope<>new.release_scope or old.protected_data_allowed<>new.protected_data_allowed or old.allowed_role_keys<>new.allowed_role_keys or old.pilot_execution_limit<>new.pilot_execution_limit or old.pilot_protected_execution_limit<>new.pilot_protected_execution_limit or old.min_pilot_completed_executions<>new.min_pilot_completed_executions or old.max_pilot_failure_rate<>new.max_pilot_failure_rate or old.require_human_review<>new.require_human_review or old.created_at<>new.created_at or old.created_by<>new.created_by then raise exception 'Release-plan control terms are immutable; create a new revision'; end if;
    if old.status<>new.status and not internal_write then raise exception 'Use controlled release-plan decision RPCs'; end if;
    if old.status in ('retired','revoked') and new.status<>old.status then raise exception 'Retired/revoked release plans are final'; end if;
  end if;
  if new.status='approved' then new.approved_at:=coalesce(new.approved_at,now()); new.approved_by:=coalesce(new.approved_by,uid); end if;
  if new.status='revoked' then new.revoked_at:=coalesce(new.revoked_at,now()); new.revoked_by:=coalesce(new.revoked_by,uid); end if;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_release_plan() from public,anon,authenticated;
create trigger mrcip_ai_release_plans_guard_biu before insert or update on public.mrcip_ai_release_plans for each row execute function private.guard_mrcip_ai_release_plan();

create or replace function private.guard_mrcip_ai_runtime_control()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  user_write boolean := current_setting('app.mrcip_ai_runtime_write',true)='on';
  system_write boolean := current_setting('app.mrcip_ai_runtime_system_write',true)='on' and current_user='postgres';
  rp public.mrcip_ai_release_plans%rowtype;
begin
  if not user_write and not system_write then raise exception 'Use controlled AI runtime transition RPCs'; end if;
  if user_write then
    if uid is null then raise exception 'Authenticated user required'; end if;
    if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','legal_compliance','commodity_manager']) then raise exception 'AI runtime transition authority required'; end if;
    new.updated_by:=uid;
  end if;
  if tg_op='UPDATE' and (old.organisation_id<>new.organisation_id or old.provider_config_id<>new.provider_config_id or old.id<>new.id) then raise exception 'Runtime-control identity is immutable'; end if;
  if new.active_release_plan_id is not null then
    select * into rp from public.mrcip_ai_release_plans where organisation_id=new.organisation_id and id=new.active_release_plan_id and provider_config_id=new.provider_config_id;
    if not found then raise exception 'Active release plan does not belong to this provider'; end if;
    if new.runtime_state in ('pilot','production') then
      if rp.status<>'approved' then raise exception 'Only an approved release plan may be executable'; end if;
      if rp.release_scope<>new.runtime_state then raise exception 'Runtime state must match release scope'; end if;
    end if;
  end if;
  new.updated_at:=now();
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_runtime_control() from public,anon,authenticated;
create trigger mrcip_ai_runtime_controls_guard_biu before insert or update on public.mrcip_ai_runtime_controls for each row execute function private.guard_mrcip_ai_runtime_control();

create or replace function private.guard_mrcip_ai_runtime_event()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  user_write boolean := current_setting('app.mrcip_ai_runtime_event_write',true)='on';
  system_write boolean := current_setting('app.mrcip_ai_runtime_system_event_write',true)='on' and current_user='postgres';
begin
  if tg_op<>'INSERT' then raise exception 'AI runtime events are append-only'; end if;
  if not user_write and not system_write then raise exception 'Runtime events may only be written by controlled workflows'; end if;
  if user_write then
    if uid is null then raise exception 'Authenticated user required'; end if;
    if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','legal_compliance','commodity_manager']) then raise exception 'Runtime event authority required'; end if;
    new.actor_kind:='user'; new.actor_user_id:=uid;
  elsif system_write then
    new.actor_kind:='system'; new.actor_user_id:=null;
  end if;
  new.created_at:=now();
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_runtime_event() from public,anon,authenticated;
create trigger mrcip_ai_runtime_events_guard_bi before insert on public.mrcip_ai_runtime_events for each row execute function private.guard_mrcip_ai_runtime_event();

create or replace function private.prevent_mrcip_ai_runtime_event_mutation()
returns trigger
language plpgsql
set search_path=''
as $$ begin raise exception 'AI runtime event history is append-only'; end; $$;
revoke all on function private.prevent_mrcip_ai_runtime_event_mutation() from public,anon,authenticated;
create trigger mrcip_ai_runtime_events_no_ud before update or delete on public.mrcip_ai_runtime_events for each row execute function private.prevent_mrcip_ai_runtime_event_mutation();

create or replace function public.prepare_mrcip_ai_release_plan(
  p_provider_config_id uuid,
  p_release_scope text,
  p_predecessor_release_plan_id uuid default null,
  p_protected_data_allowed boolean default false,
  p_allowed_role_keys text[] default array['super_admin','managing_director','commodity_manager','research_analyst','legal_compliance']::text[],
  p_pilot_execution_limit integer default 25,
  p_pilot_protected_execution_limit integer default 0,
  p_min_pilot_completed_executions integer default 10,
  p_max_pilot_failure_rate numeric default 0.10,
  p_decision_notes text default ''
)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare cfg public.mrcip_ai_provider_configs%rowtype; o public.mrcip_ai_provider_onboarding%rowtype; rid uuid;
begin
  select * into cfg from public.mrcip_ai_provider_configs where id=p_provider_config_id;
  if not found then raise exception 'Provider configuration not found or not accessible'; end if;
  if not private.has_mrcip_role(cfg.organisation_id,array['super_admin','managing_director','legal_compliance']) then raise exception 'Executive/legal release authority required'; end if;
  if p_release_scope not in ('pilot','production') then raise exception 'Release scope must be pilot or production'; end if;
  if cfg.status not in ('integration_ready','active') or cfg.connection_status<>'verified' or cfg.credential_status<>'configured_external_secret' then raise exception 'Stage 13 provider connection and credential approval must remain valid'; end if;
  select * into o from public.mrcip_ai_provider_onboarding where organisation_id=cfg.organisation_id and provider_config_id=cfg.id and status='production_approved' order by revision_no desc limit 1;
  if not found or o.prompt_version_id is null then raise exception 'Stage 13 production-approved onboarding is required before release planning'; end if;
  if coalesce(p_protected_data_allowed,false) and not o.protected_data_approved then raise exception 'Release cannot exceed Stage 13 protected-data approval'; end if;
  insert into public.mrcip_ai_release_plans(organisation_id,provider_config_id,onboarding_id,prompt_version_id,predecessor_release_plan_id,revision_no,release_scope,status,protected_data_allowed,allowed_role_keys,pilot_execution_limit,pilot_protected_execution_limit,min_pilot_completed_executions,max_pilot_failure_rate,require_human_review,decision_notes,created_by)
  values(cfg.organisation_id,cfg.id,o.id,o.prompt_version_id,p_predecessor_release_plan_id,1,p_release_scope,'draft',coalesce(p_protected_data_allowed,false),coalesce(p_allowed_role_keys,array['super_admin','managing_director','commodity_manager','research_analyst','legal_compliance']::text[]),coalesce(p_pilot_execution_limit,25),coalesce(p_pilot_protected_execution_limit,0),coalesce(p_min_pilot_completed_executions,10),coalesce(p_max_pilot_failure_rate,0.10),true,left(coalesce(p_decision_notes,''),6000),(select auth.uid())) returning id into rid;
  perform set_config('app.mrcip_ai_runtime_event_write','on',true);
  insert into public.mrcip_ai_runtime_events(organisation_id,provider_config_id,release_plan_id,event_type,actor_kind,actor_user_id,reason,details)
  values(cfg.organisation_id,cfg.id,rid,'release_prepared','user',(select auth.uid()),left(coalesce(p_decision_notes,''),4000),jsonb_build_object('release_scope',p_release_scope));
  return rid;
end; $$;
revoke all on function public.prepare_mrcip_ai_release_plan(uuid,text,uuid,boolean,text[],integer,integer,integer,numeric,text) from public,anon;

create or replace function public.approve_mrcip_ai_release_plan(p_release_plan_id uuid,p_decision_notes text default '')
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare rp public.mrcip_ai_release_plans%rowtype; o public.mrcip_ai_provider_onboarding%rowtype; cfg public.mrcip_ai_provider_configs%rowtype; pv public.mrcip_ai_prompt_versions%rowtype; rate public.mrcip_ai_provider_rates%rowtype; bud public.mrcip_ai_budget_policies%rowtype; pred public.mrcip_ai_release_plans%rowtype; completed_count integer:=0; failed_count integer:=0; terminal_count integer:=0; failure_rate numeric:=0; unreviewed_count integer:=0; protection_failures integer:=0; budget_breaches integer:=0;
begin
  select * into rp from public.mrcip_ai_release_plans where id=p_release_plan_id;
  if not found then raise exception 'Release plan not found or not accessible'; end if;
  if not private.has_mrcip_role(rp.organisation_id,array['super_admin','managing_director']) then raise exception 'Executive authority required to approve AI release'; end if;
  if rp.status<>'draft' then raise exception 'Only draft release plans may be approved'; end if;
  select * into o from public.mrcip_ai_provider_onboarding where organisation_id=rp.organisation_id and id=rp.onboarding_id and provider_config_id=rp.provider_config_id;
  select * into cfg from public.mrcip_ai_provider_configs where organisation_id=rp.organisation_id and id=rp.provider_config_id;
  select * into pv from public.mrcip_ai_prompt_versions where organisation_id=rp.organisation_id and id=rp.prompt_version_id;
  if o.id is null or o.status<>'production_approved' or o.prompt_version_id<>rp.prompt_version_id then raise exception 'Stage 13 onboarding approval is no longer valid'; end if;
  if cfg.id is null or cfg.status not in ('integration_ready','active') or cfg.connection_status<>'verified' or cfg.credential_status<>'configured_external_secret' then raise exception 'Provider is no longer connection/credential ready'; end if;
  if pv.id is null or pv.status<>'approved' then raise exception 'Release prompt is no longer approved'; end if;
  if rp.protected_data_allowed and (not o.protected_data_approved or not pv.protected_data_approved) then raise exception 'Protected-data release exceeds Stage 13/prompt approval'; end if;
  select * into rate from public.mrcip_ai_provider_rates where organisation_id=rp.organisation_id and id=o.rate_card_id and provider_config_id=rp.provider_config_id and status='active' and effective_from<=now() and (effective_to is null or effective_to>now());
  select * into bud from public.mrcip_ai_budget_policies where organisation_id=rp.organisation_id and id=o.budget_policy_id and provider_config_id=rp.provider_config_id and status='active' and effective_from<=now() and (effective_to is null or effective_to>now());
  if rate.id is null or bud.id is null or rate.currency<>bud.currency then raise exception 'Current Stage 13 rate/budget controls are required'; end if;
  if rp.release_scope='production' then
    select * into pred from public.mrcip_ai_release_plans where organisation_id=rp.organisation_id and id=rp.predecessor_release_plan_id and provider_config_id=rp.provider_config_id;
    if pred.id is null or pred.release_scope<>'pilot' or pred.status not in ('approved','retired') then raise exception 'Valid pilot predecessor is required for production approval'; end if;
    select count(*) filter (where e.status='completed')::integer,count(*) filter (where e.status in ('failed','blocked'))::integer,count(*) filter (where e.status in ('completed','failed','blocked'))::integer into completed_count,failed_count,terminal_count from public.mrcip_ai_execution_release_links l join public.mrcip_ai_executions e on e.organisation_id=l.organisation_id and e.id=l.execution_id where l.organisation_id=rp.organisation_id and l.release_plan_id=pred.id;
    if completed_count<rp.min_pilot_completed_executions then raise exception 'Production approval requires at least % completed pilot executions',rp.min_pilot_completed_executions; end if;
    failure_rate:=case when terminal_count=0 then 1 else failed_count::numeric/terminal_count::numeric end;
    if failure_rate>rp.max_pilot_failure_rate then raise exception 'Pilot failure rate exceeds production threshold'; end if;
    select count(*)::integer into unreviewed_count from public.mrcip_ai_execution_release_links l join public.mrcip_ai_executions e on e.organisation_id=l.organisation_id and e.id=l.execution_id left join public.mrcip_ai_responses r on r.organisation_id=e.organisation_id and r.id=e.response_id where l.organisation_id=rp.organisation_id and l.release_plan_id=pred.id and e.status='completed' and (r.id is null or r.status<>'approved');
    if unreviewed_count>0 then raise exception 'Every completed pilot execution must pass mandatory human review before production approval'; end if;
    select count(*)::integer into protection_failures from public.mrcip_ai_execution_release_links l join public.mrcip_ai_executions e on e.organisation_id=l.organisation_id and e.id=l.execution_id join public.mrcip_ai_reviews rv on rv.organisation_id=e.organisation_id and rv.response_id=e.response_id where l.organisation_id=rp.organisation_id and l.release_plan_id=pred.id and rv.protection_check_passed=false;
    if protection_failures>0 then raise exception 'Pilot protection-review failure blocks production approval'; end if;
    select count(*)::integer into budget_breaches from public.mrcip_ai_execution_release_links l join public.mrcip_ai_executions e on e.organisation_id=l.organisation_id and e.id=l.execution_id where l.organisation_id=rp.organisation_id and l.release_plan_id=pred.id and coalesce((e.provider_telemetry->>'stage13_budget_breach')::boolean,false);
    if budget_breaches>0 then raise exception 'Pilot budget breach blocks production approval'; end if;
  end if;
  perform set_config('app.mrcip_ai_release_write','on',true);
  update public.mrcip_ai_release_plans set status='approved',decision_notes=left(coalesce(p_decision_notes,decision_notes),6000),approved_at=now(),approved_by=(select auth.uid()) where id=rp.id;
  perform set_config('app.mrcip_ai_runtime_event_write','on',true);
  insert into public.mrcip_ai_runtime_events(organisation_id,provider_config_id,release_plan_id,event_type,actor_kind,actor_user_id,reason,details)
  values(rp.organisation_id,rp.provider_config_id,rp.id,'release_approved','user',(select auth.uid()),left(coalesce(p_decision_notes,''),4000),jsonb_build_object('release_scope',rp.release_scope,'pilot_completed',completed_count,'pilot_failure_rate',failure_rate));
  return rp.id;
end; $$;
revoke all on function public.approve_mrcip_ai_release_plan(uuid,text) from public,anon;

create or replace function public.activate_mrcip_ai_release_plan(p_release_plan_id uuid,p_reason text default '')
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare rp public.mrcip_ai_release_plans%rowtype; o public.mrcip_ai_provider_onboarding%rowtype; cfg public.mrcip_ai_provider_configs%rowtype; rc public.mrcip_ai_runtime_controls%rowtype; event_name text;
begin
  select * into rp from public.mrcip_ai_release_plans where id=p_release_plan_id;
  if not found then raise exception 'Release plan not found or not accessible'; end if;
  if not private.has_mrcip_role(rp.organisation_id,array['super_admin','managing_director']) then raise exception 'Executive authority required to activate AI runtime'; end if;
  if rp.status<>'approved' then raise exception 'Only an approved release plan may be activated'; end if;
  select * into o from public.mrcip_ai_provider_onboarding where organisation_id=rp.organisation_id and id=rp.onboarding_id and provider_config_id=rp.provider_config_id;
  select * into cfg from public.mrcip_ai_provider_configs where organisation_id=rp.organisation_id and id=rp.provider_config_id;
  if o.id is null or o.status<>'production_approved' then raise exception 'Stage 13 onboarding approval is no longer valid'; end if;
  if cfg.id is null or cfg.status<>'active' or cfg.connection_status<>'verified' or cfg.credential_status<>'configured_external_secret' then raise exception 'Provider must be Stage 13 active, verified and credential-ready before runtime activation'; end if;
  if rp.protected_data_allowed and (not o.protected_data_approved or not cfg.protected_data_allowed) then raise exception 'Protected runtime activation exceeds current Stage 13 approval'; end if;
  select * into rc from public.mrcip_ai_runtime_controls where organisation_id=rp.organisation_id and provider_config_id=rp.provider_config_id;
  event_name:=case when rc.id is not null and rc.active_release_plan_id=rp.id and rc.runtime_state in ('paused','stopped') then 'resumed' when rp.release_scope='pilot' then 'pilot_activated' else 'production_activated' end;
  perform set_config('app.mrcip_ai_runtime_write','on',true);
  insert into public.mrcip_ai_runtime_controls(organisation_id,provider_config_id,active_release_plan_id,runtime_state,emergency_stop,transition_reason,updated_by)
  values(rp.organisation_id,rp.provider_config_id,rp.id,rp.release_scope,false,left(coalesce(p_reason,''),4000),(select auth.uid()))
  on conflict (organisation_id,provider_config_id) do update set active_release_plan_id=excluded.active_release_plan_id,runtime_state=excluded.runtime_state,emergency_stop=false,transition_reason=excluded.transition_reason,updated_by=excluded.updated_by;
  perform set_config('app.mrcip_ai_runtime_event_write','on',true);
  insert into public.mrcip_ai_runtime_events(organisation_id,provider_config_id,release_plan_id,event_type,actor_kind,actor_user_id,reason,details)
  values(rp.organisation_id,rp.provider_config_id,rp.id,event_name,'user',(select auth.uid()),left(coalesce(p_reason,''),4000),jsonb_build_object('runtime_state',rp.release_scope));
  return rp.id;
end; $$;
revoke all on function public.activate_mrcip_ai_release_plan(uuid,text) from public,anon;

create or replace function public.pause_mrcip_ai_runtime(p_provider_config_id uuid,p_reason text)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare rc public.mrcip_ai_runtime_controls%rowtype;
begin
  select * into rc from public.mrcip_ai_runtime_controls where provider_config_id=p_provider_config_id;
  if not found then raise exception 'AI runtime control not found or not accessible'; end if;
  if not private.has_mrcip_role(rc.organisation_id,array['super_admin','managing_director','legal_compliance','commodity_manager']) then raise exception 'Runtime pause authority required'; end if;
  if rc.runtime_state not in ('pilot','production') then raise exception 'Only active pilot/production runtime may be paused'; end if;
  if btrim(coalesce(p_reason,''))='' then raise exception 'Pause reason is required'; end if;
  perform set_config('app.mrcip_ai_runtime_write','on',true);
  update public.mrcip_ai_runtime_controls set runtime_state='paused',emergency_stop=true,transition_reason=left(p_reason,4000),updated_by=(select auth.uid()) where id=rc.id;
  perform set_config('app.mrcip_ai_runtime_event_write','on',true);
  insert into public.mrcip_ai_runtime_events(organisation_id,provider_config_id,release_plan_id,event_type,actor_kind,actor_user_id,reason,details)
  values(rc.organisation_id,rc.provider_config_id,rc.active_release_plan_id,'paused','user',(select auth.uid()),left(p_reason,4000),'{}'::jsonb);
  return rc.id;
end; $$;
revoke all on function public.pause_mrcip_ai_runtime(uuid,text) from public,anon;

create or replace function public.stop_mrcip_ai_runtime(p_provider_config_id uuid,p_reason text)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare rc public.mrcip_ai_runtime_controls%rowtype;
begin
  select * into rc from public.mrcip_ai_runtime_controls where provider_config_id=p_provider_config_id;
  if not found then raise exception 'AI runtime control not found or not accessible'; end if;
  if not private.has_mrcip_role(rc.organisation_id,array['super_admin','managing_director','legal_compliance','commodity_manager']) then raise exception 'Emergency-stop authority required'; end if;
  if btrim(coalesce(p_reason,''))='' then raise exception 'Stop reason is required'; end if;
  perform set_config('app.mrcip_ai_runtime_write','on',true);
  update public.mrcip_ai_runtime_controls set runtime_state='stopped',emergency_stop=true,transition_reason=left(p_reason,4000),updated_by=(select auth.uid()) where id=rc.id;
  perform set_config('app.mrcip_ai_runtime_event_write','on',true);
  insert into public.mrcip_ai_runtime_events(organisation_id,provider_config_id,release_plan_id,event_type,actor_kind,actor_user_id,reason,details)
  values(rc.organisation_id,rc.provider_config_id,rc.active_release_plan_id,'stopped','user',(select auth.uid()),left(p_reason,4000),'{}'::jsonb);
  return rc.id;
end; $$;
revoke all on function public.stop_mrcip_ai_runtime(uuid,text) from public,anon;

create or replace function public.revoke_mrcip_ai_release_plan(p_release_plan_id uuid,p_reason text)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare rp public.mrcip_ai_release_plans%rowtype; rc public.mrcip_ai_runtime_controls%rowtype;
begin
  select * into rp from public.mrcip_ai_release_plans where id=p_release_plan_id;
  if not found then raise exception 'Release plan not found or not accessible'; end if;
  if not private.has_mrcip_role(rp.organisation_id,array['super_admin','managing_director']) then raise exception 'Executive authority required to revoke AI release'; end if;
  if rp.status in ('revoked','retired') then raise exception 'Release plan is already final'; end if;
  if btrim(coalesce(p_reason,''))='' then raise exception 'Revocation reason is required'; end if;
  perform set_config('app.mrcip_ai_release_write','on',true);
  update public.mrcip_ai_release_plans set status='revoked',decision_notes=left(p_reason,6000),revoked_at=now(),revoked_by=(select auth.uid()) where id=rp.id;
  select * into rc from public.mrcip_ai_runtime_controls where organisation_id=rp.organisation_id and provider_config_id=rp.provider_config_id and active_release_plan_id=rp.id;
  if rc.id is not null then
    perform set_config('app.mrcip_ai_runtime_write','on',true);
    update public.mrcip_ai_runtime_controls set runtime_state='stopped',emergency_stop=true,transition_reason=left('Release revoked: '||p_reason,4000),updated_by=(select auth.uid()) where id=rc.id;
  end if;
  perform set_config('app.mrcip_ai_runtime_event_write','on',true);
  insert into public.mrcip_ai_runtime_events(organisation_id,provider_config_id,release_plan_id,event_type,actor_kind,actor_user_id,reason,details)
  values(rp.organisation_id,rp.provider_config_id,rp.id,'release_revoked','user',(select auth.uid()),left(p_reason,4000),jsonb_build_object('runtime_stopped',rc.id is not null));
  return rp.id;
end; $$;
revoke all on function public.revoke_mrcip_ai_release_plan(uuid,text) from public,anon;