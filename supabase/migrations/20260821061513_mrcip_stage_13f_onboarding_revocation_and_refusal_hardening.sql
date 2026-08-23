create or replace function private.guard_mrcip_ai_eval_case()
returns trigger
language plpgsql
set search_path=''
as $$
declare uid uuid := (select auth.uid()); suite_status text;
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','research_analyst','legal_compliance']) then raise exception 'AI evaluation authoring authority required'; end if;
  select status into suite_status from public.mrcip_ai_eval_suites where organisation_id=new.organisation_id and id=new.suite_id;
  if suite_status is null then raise exception 'Evaluation suite not found'; end if;
  if suite_status<>'draft' then raise exception 'Evaluation cases can only be changed while the suite is draft'; end if;
  if not new.synthetic_only then raise exception 'Stage 13 evaluation cases must use synthetic data only'; end if;
  if new.category='protected_data' and cardinality(new.forbidden_patterns)=0 then raise exception 'Protected-data evaluation cases require at least one forbidden synthetic marker'; end if;
  if new.category='citation' and (not new.requires_citation or cardinality(new.allowed_citation_ranks)=0) then raise exception 'Citation evaluation cases require allowed citation ranks'; end if;
  if new.must_refuse and cardinality(new.required_patterns)=0 then raise exception 'Must-refuse evaluation cases require one or more synthetic refusal markers'; end if;
  if exists(select 1 from unnest(new.allowed_citation_ranks) x where x<=0) then raise exception 'Citation ranks must be positive integers'; end if;
  if tg_op='INSERT' then new.created_at:=now(); new.created_by:=uid; else
    if old.organisation_id<>new.organisation_id or old.suite_id<>new.suite_id or old.case_key<>new.case_key or old.created_at<>new.created_at or old.created_by<>new.created_by then raise exception 'Evaluation case identity/history is immutable'; end if;
  end if;
  new.updated_at:=now(); new.updated_by:=uid;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_eval_case() from public,anon,authenticated;

create or replace function private.guard_mrcip_ai_provider_onboarding()
returns trigger
language plpgsql
set search_path=''
as $$
declare uid uuid := (select auth.uid()); internal_write boolean := current_setting('app.mrcip_ai_onboarding_write',true)='on'; next_revision integer;
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','legal_compliance']) then raise exception 'Executive/legal AI onboarding authority required'; end if;
  if tg_op='INSERT' then
    if new.status not in ('draft','evaluation_required') then raise exception 'New provider onboarding revisions must begin in draft/evaluation_required'; end if;
    select coalesce(max(revision_no),0)+1 into next_revision from public.mrcip_ai_provider_onboarding where organisation_id=new.organisation_id and provider_config_id=new.provider_config_id;
    new.revision_no:=next_revision; new.created_at:=now(); new.created_by:=uid; new.decided_at:=null; new.decided_by:=null;
  else
    if old.organisation_id<>new.organisation_id or old.provider_config_id<>new.provider_config_id or old.revision_no<>new.revision_no or old.created_at<>new.created_at or old.created_by<>new.created_by then raise exception 'Provider onboarding identity/history is immutable'; end if;
    if old.status in ('rejected','revoked') and new.status<>old.status then raise exception 'Rejected/revoked onboarding revisions are immutable; create a new revision'; end if;
    if old.status='production_approved' and new.status not in ('production_approved','revoked') then raise exception 'Production-approved onboarding may only remain approved or be revoked'; end if;
    if old.status='production_approved' and new.status='revoked' and not internal_write then raise exception 'Use the controlled provider-onboarding revocation RPC'; end if;
    if new.status in ('evaluation_passed','production_approved','rejected','revoked') and new.status<>old.status and not internal_write then raise exception 'Use the controlled provider-onboarding decision RPCs'; end if;
  end if;
  if new.status in ('production_approved','rejected','revoked') then new.decided_at:=coalesce(new.decided_at,now()); new.decided_by:=coalesce(new.decided_by,uid); end if;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_provider_onboarding() from public,anon,authenticated;