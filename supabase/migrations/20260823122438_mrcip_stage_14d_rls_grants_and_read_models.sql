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
  if not internal_write then raise exception 'Use controlled release-plan workflow RPCs'; end if;
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
    if old.status in ('retired','revoked') and new.status<>old.status then raise exception 'Retired/revoked release plans are final'; end if;
  end if;
  if new.status='approved' then new.approved_at:=coalesce(new.approved_at,now()); new.approved_by:=coalesce(new.approved_by,uid); end if;
  if new.status='revoked' then new.revoked_at:=coalesce(new.revoked_at,now()); new.revoked_by:=coalesce(new.revoked_by,uid); end if;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_release_plan() from public,anon,authenticated;

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
  perform set_config('app.mrcip_ai_release_write','on',true);
  insert into public.mrcip_ai_release_plans(organisation_id,provider_config_id,onboarding_id,prompt_version_id,predecessor_release_plan_id,revision_no,release_scope,status,protected_data_allowed,allowed_role_keys,pilot_execution_limit,pilot_protected_execution_limit,min_pilot_completed_executions,max_pilot_failure_rate,require_human_review,decision_notes,created_by)
  values(cfg.organisation_id,cfg.id,o.id,o.prompt_version_id,p_predecessor_release_plan_id,1,p_release_scope,'draft',coalesce(p_protected_data_allowed,false),coalesce(p_allowed_role_keys,array['super_admin','managing_director','commodity_manager','research_analyst','legal_compliance']::text[]),coalesce(p_pilot_execution_limit,25),coalesce(p_pilot_protected_execution_limit,0),coalesce(p_min_pilot_completed_executions,10),coalesce(p_max_pilot_failure_rate,0.10),true,left(coalesce(p_decision_notes,''),6000),(select auth.uid())) returning id into rid;
  perform set_config('app.mrcip_ai_runtime_event_write','on',true);
  insert into public.mrcip_ai_runtime_events(organisation_id,provider_config_id,release_plan_id,event_type,actor_kind,actor_user_id,reason,details)
  values(cfg.organisation_id,cfg.id,rid,'release_prepared','user',(select auth.uid()),left(coalesce(p_decision_notes,''),4000),jsonb_build_object('release_scope',p_release_scope));
  return rid;
end; $$;

create or replace function private.prevent_mrcip_ai_execution_release_link_mutation()
returns trigger
language plpgsql
set search_path=''
as $$ begin raise exception 'AI execution release provenance is immutable'; end; $$;
revoke all on function private.prevent_mrcip_ai_execution_release_link_mutation() from public,anon,authenticated;
create trigger mrcip_ai_execution_release_links_no_ud before update or delete on public.mrcip_ai_execution_release_links for each row execute function private.prevent_mrcip_ai_execution_release_link_mutation();

create policy mrcip_ai_release_plans_select on public.mrcip_ai_release_plans for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance','commodity_manager']));
create policy mrcip_ai_release_plans_insert on public.mrcip_ai_release_plans for insert to authenticated with check (created_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance']));
create policy mrcip_ai_release_plans_update on public.mrcip_ai_release_plans for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director'])) with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director']));

create policy mrcip_ai_runtime_controls_select on public.mrcip_ai_runtime_controls for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance','commodity_manager']));
create policy mrcip_ai_runtime_controls_insert on public.mrcip_ai_runtime_controls for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director']));
create policy mrcip_ai_runtime_controls_update on public.mrcip_ai_runtime_controls for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance','commodity_manager'])) with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance','commodity_manager']));

create policy mrcip_ai_execution_release_links_select on public.mrcip_ai_execution_release_links for select to authenticated using (
  exists (
    select 1 from public.mrcip_ai_executions e
    where e.organisation_id=mrcip_ai_execution_release_links.organisation_id and e.id=mrcip_ai_execution_release_links.execution_id
      and private.has_mrcip_role(e.organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])
      and (e.requested_by=(select auth.uid()) or private.has_mrcip_role(e.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']))
      and ((not e.protected_context) or private.has_mrcip_role(e.organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
  )
);

create policy mrcip_ai_runtime_events_select on public.mrcip_ai_runtime_events for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance','commodity_manager']));
create policy mrcip_ai_runtime_events_insert on public.mrcip_ai_runtime_events for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance','commodity_manager']));

revoke all on public.mrcip_ai_release_plans from anon,authenticated;
grant select,insert,update on public.mrcip_ai_release_plans to authenticated;
revoke all on public.mrcip_ai_runtime_controls from anon,authenticated;
grant select,insert,update on public.mrcip_ai_runtime_controls to authenticated;
revoke all on public.mrcip_ai_execution_release_links from anon,authenticated;
grant select on public.mrcip_ai_execution_release_links to authenticated;
revoke all on public.mrcip_ai_runtime_events from anon,authenticated;
grant select,insert on public.mrcip_ai_runtime_events to authenticated;

revoke all on function public.prepare_mrcip_ai_release_plan(uuid,text,uuid,boolean,text[],integer,integer,integer,numeric,text) from public,anon;
revoke all on function public.approve_mrcip_ai_release_plan(uuid,text) from public,anon;
revoke all on function public.activate_mrcip_ai_release_plan(uuid,text) from public,anon;
revoke all on function public.pause_mrcip_ai_runtime(uuid,text) from public,anon;
revoke all on function public.stop_mrcip_ai_runtime(uuid,text) from public,anon;
revoke all on function public.revoke_mrcip_ai_release_plan(uuid,text) from public,anon;
grant execute on function public.prepare_mrcip_ai_release_plan(uuid,text,uuid,boolean,text[],integer,integer,integer,numeric,text) to authenticated;
grant execute on function public.approve_mrcip_ai_release_plan(uuid,text) to authenticated;
grant execute on function public.activate_mrcip_ai_release_plan(uuid,text) to authenticated;
grant execute on function public.pause_mrcip_ai_runtime(uuid,text) to authenticated;
grant execute on function public.stop_mrcip_ai_runtime(uuid,text) to authenticated;
grant execute on function public.revoke_mrcip_ai_release_plan(uuid,text) to authenticated;

create view public.mrcip_ai_runtime_status
with (security_invoker=true)
as
select
  rc.organisation_id,
  rc.provider_config_id,
  cfg.provider_key,
  cfg.model_name,
  rc.active_release_plan_id,
  rp.revision_no as release_revision_no,
  rp.release_scope,
  rp.status as release_status,
  rp.protected_data_allowed,
  rp.allowed_role_keys,
  rc.runtime_state,
  rc.emergency_stop,
  rc.transition_reason,
  rc.updated_at,
  rc.updated_by,
  coalesce(x.total_executions,0)::integer as release_executions,
  coalesce(x.completed_executions,0)::integer as completed_executions,
  coalesce(x.failed_executions,0)::integer as failed_executions,
  coalesce(x.protected_executions,0)::integer as protected_executions,
  case when coalesce(x.terminal_executions,0)=0 then 0::numeric else x.failed_executions::numeric/x.terminal_executions::numeric end as failure_rate
from public.mrcip_ai_runtime_controls rc
join public.mrcip_ai_provider_configs cfg on cfg.organisation_id=rc.organisation_id and cfg.id=rc.provider_config_id
left join public.mrcip_ai_release_plans rp on rp.organisation_id=rc.organisation_id and rp.id=rc.active_release_plan_id
left join lateral (
  select count(*)::integer total_executions,
         count(*) filter (where e.status='completed')::integer completed_executions,
         count(*) filter (where e.status in ('failed','blocked'))::integer failed_executions,
         count(*) filter (where e.status in ('completed','failed','blocked'))::integer terminal_executions,
         count(*) filter (where e.protected_context)::integer protected_executions
  from public.mrcip_ai_execution_release_links l
  join public.mrcip_ai_executions e on e.organisation_id=l.organisation_id and e.id=l.execution_id
  where l.organisation_id=rc.organisation_id and l.release_plan_id=rc.active_release_plan_id
) x on true;

create view public.mrcip_ai_release_readiness
with (security_invoker=true)
as
select
  rp.organisation_id,
  rp.id as release_plan_id,
  rp.provider_config_id,
  cfg.provider_key,
  cfg.model_name,
  rp.revision_no,
  rp.release_scope,
  rp.status,
  rp.predecessor_release_plan_id,
  rp.protected_data_allowed,
  rp.pilot_execution_limit,
  rp.min_pilot_completed_executions,
  rp.max_pilot_failure_rate,
  o.status as onboarding_status,
  er.status as evaluation_status,
  er.passed as evaluation_passed,
  rate.status as rate_status,
  bud.status as budget_status,
  cfg.status as provider_status,
  cfg.connection_status,
  cfg.credential_status,
  pv.status as prompt_status,
  coalesce(x.completed_executions,0)::integer as pilot_completed_executions,
  coalesce(x.failed_executions,0)::integer as pilot_failed_executions,
  coalesce(x.unapproved_responses,0)::integer as unapproved_responses,
  coalesce(x.protection_failures,0)::integer as protection_failures,
  coalesce(x.budget_breaches,0)::integer as budget_breaches,
  case when coalesce(x.terminal_executions,0)=0 then 0::numeric else x.failed_executions::numeric/x.terminal_executions::numeric end as pilot_failure_rate
from public.mrcip_ai_release_plans rp
join public.mrcip_ai_provider_configs cfg on cfg.organisation_id=rp.organisation_id and cfg.id=rp.provider_config_id
join public.mrcip_ai_provider_onboarding o on o.organisation_id=rp.organisation_id and o.id=rp.onboarding_id
left join public.mrcip_ai_eval_runs er on er.organisation_id=o.organisation_id and er.id=o.evaluation_run_id
left join public.mrcip_ai_provider_rates rate on rate.organisation_id=o.organisation_id and rate.id=o.rate_card_id
left join public.mrcip_ai_budget_policies bud on bud.organisation_id=o.organisation_id and bud.id=o.budget_policy_id
join public.mrcip_ai_prompt_versions pv on pv.organisation_id=rp.organisation_id and pv.id=rp.prompt_version_id
left join lateral (
  select count(*) filter (where e.status='completed')::integer completed_executions,
         count(*) filter (where e.status in ('failed','blocked'))::integer failed_executions,
         count(*) filter (where e.status in ('completed','failed','blocked'))::integer terminal_executions,
         count(*) filter (where e.status='completed' and (r.id is null or r.status<>'approved'))::integer unapproved_responses,
         count(*) filter (where rv.protection_check_passed=false)::integer protection_failures,
         count(*) filter (where coalesce((e.provider_telemetry->>'stage13_budget_breach')::boolean,false))::integer budget_breaches
  from public.mrcip_ai_execution_release_links l
  join public.mrcip_ai_executions e on e.organisation_id=l.organisation_id and e.id=l.execution_id
  left join public.mrcip_ai_responses r on r.organisation_id=e.organisation_id and r.id=e.response_id
  left join public.mrcip_ai_reviews rv on rv.organisation_id=e.organisation_id and rv.response_id=e.response_id
  where l.organisation_id=rp.organisation_id and l.release_plan_id=coalesce(rp.predecessor_release_plan_id,rp.id)
) x on true;

revoke all on public.mrcip_ai_runtime_status from public,anon,authenticated;
revoke all on public.mrcip_ai_release_readiness from public,anon,authenticated;
grant select on public.mrcip_ai_runtime_status to authenticated;
grant select on public.mrcip_ai_release_readiness to authenticated;