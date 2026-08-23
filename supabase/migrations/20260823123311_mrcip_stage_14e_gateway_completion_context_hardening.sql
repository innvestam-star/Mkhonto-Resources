create or replace function private.guard_mrcip_ai_response()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  req public.mrcip_ai_requests%rowtype;
  cfg public.mrcip_ai_provider_configs%rowtype;
  ex public.mrcip_ai_executions%rowtype;
  actual_context_count integer:=0;
  next_version integer:=1;
  internal_execution boolean:=false;
begin
  internal_execution := (new.response_origin='external_model' and current_user='service_role' and new.execution_id is not null and current_setting('app.mrcip_ai_execution_id',true)=new.execution_id::text);
  if not internal_execution then
    if uid is null then raise exception 'Authenticated user required'; end if;
  end if;
  select * into req from public.mrcip_ai_requests where organisation_id=new.organisation_id and id=new.request_id;
  if not found then raise exception 'AI request not found or not accessible'; end if;
  if not internal_execution then
    if req.requested_by<>uid and not private.has_mrcip_role(req.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']) then
      raise exception 'AI response submission requires request ownership or authorised supervisory authority';
    end if;
  end if;
  select count(*)::integer into actual_context_count from public.mrcip_ai_context_items where organisation_id=req.organisation_id and request_id=req.id;
  if actual_context_count<>req.context_count then raise exception 'Frozen AI context is incomplete or inconsistent with the audited retrieval'; end if;
  if new.evidence_state='supported' and actual_context_count=0 then raise exception 'A supported response requires at least one frozen context item'; end if;
  if new.response_origin='external_model' then
    if not internal_execution then raise exception 'External-model responses may be created only by the Stage 12 execution gateway'; end if;
    if new.provider_config_id is null or new.execution_id is null then raise exception 'External-model responses require provider and execution provenance'; end if;
    select * into ex from public.mrcip_ai_executions where organisation_id=req.organisation_id and id=new.execution_id;
    if not found or ex.request_id<>req.id or ex.provider_config_id<>new.provider_config_id or ex.status<>'running' then raise exception 'External-model execution provenance is invalid or not running'; end if;
    select * into cfg from public.mrcip_ai_provider_configs where organisation_id=req.organisation_id and id=new.provider_config_id;
    if not found then raise exception 'AI provider configuration not found'; end if;
    if btrim(new.provider_request_id)='' then raise exception 'External-model response requires provider request ID'; end if;
    new.provider_key:=ex.provider_key_snapshot;
    new.model_name:=ex.model_name_snapshot;
    new.generated_by:=ex.requested_by;
  else
    if new.provider_config_id is not null or new.execution_id is not null then raise exception 'Human/deterministic responses must not attach provider execution provenance'; end if;
    new.provider_key:=''; new.model_name:=''; new.provider_request_id:=''; new.generated_by:=uid;
  end if;
  select coalesce(max(response_version),0)+1 into next_version from public.mrcip_ai_responses where organisation_id=req.organisation_id and request_id=req.id;
  new.response_version:=next_version;
  new.protected_context:=req.protected_context;
  new.status:='review_required';
  new.policy_version:=req.policy_version;
  new.answer_fingerprint:=md5(concat_ws('|',req.id::text,next_version::text,new.response_origin,new.provider_key,new.model_name,coalesce(new.execution_id::text,''),new.answer_text,new.evidence_state,req.policy_version));
  new.generated_at:=now();
  new.reviewed_at:=null; new.reviewed_by:=null; new.review_summary:='';
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_response() from public,anon,authenticated;