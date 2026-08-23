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

create or replace function private.reset_mrcip_ai_release_write_token()
returns trigger
language plpgsql
set search_path=''
as $$ begin perform set_config('app.mrcip_ai_release_write','off',true); return null; end; $$;
revoke all on function private.reset_mrcip_ai_release_write_token() from public,anon,authenticated;

drop trigger if exists z_mrcip_ai_release_plans_reset_write_token on public.mrcip_ai_release_plans;
create trigger z_mrcip_ai_release_plans_reset_write_token
after insert or update on public.mrcip_ai_release_plans
for each statement execute function private.reset_mrcip_ai_release_write_token();

create or replace function private.reset_mrcip_ai_runtime_write_tokens()
returns trigger
language plpgsql
set search_path=''
as $$ begin
  perform set_config('app.mrcip_ai_runtime_write','off',true);
  perform set_config('app.mrcip_ai_runtime_system_write','off',true);
  return null;
end; $$;
revoke all on function private.reset_mrcip_ai_runtime_write_tokens() from public,anon,authenticated;

drop trigger if exists z_mrcip_ai_runtime_controls_reset_write_tokens on public.mrcip_ai_runtime_controls;
create trigger z_mrcip_ai_runtime_controls_reset_write_tokens
after insert or update on public.mrcip_ai_runtime_controls
for each statement execute function private.reset_mrcip_ai_runtime_write_tokens();

create or replace function private.reset_mrcip_ai_runtime_event_write_tokens()
returns trigger
language plpgsql
set search_path=''
as $$ begin
  perform set_config('app.mrcip_ai_runtime_event_write','off',true);
  perform set_config('app.mrcip_ai_runtime_system_event_write','off',true);
  return null;
end; $$;
revoke all on function private.reset_mrcip_ai_runtime_event_write_tokens() from public,anon,authenticated;

drop trigger if exists z_mrcip_ai_runtime_events_reset_write_tokens on public.mrcip_ai_runtime_events;
create trigger z_mrcip_ai_runtime_events_reset_write_tokens
after insert on public.mrcip_ai_runtime_events
for each statement execute function private.reset_mrcip_ai_runtime_event_write_tokens();