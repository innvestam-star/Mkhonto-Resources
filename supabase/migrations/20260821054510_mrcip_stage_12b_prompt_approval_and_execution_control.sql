alter table public.mrcip_ai_executions
  add column gateway_policy_version text not null default 'mrcip-ai-gateway-v1';

create or replace function private.has_mrcip_role_for_user(p_organisation_id uuid,p_user_id uuid,p_allowed_roles text[])
returns boolean
language sql
stable
set search_path=''
as $$
  select exists (
    select 1
    from public.organisation_memberships om
    left join public.mrcip_user_roles mur
      on mur.organisation_id=om.organisation_id and mur.membership_id=om.id
    where om.organisation_id=p_organisation_id
      and om.user_id=p_user_id
      and (om.role='owner' or mur.role_key=any(p_allowed_roles))
  );
$$;
revoke all on function private.has_mrcip_role_for_user(uuid,uuid,text[]) from public,anon,authenticated;

create or replace function private.guard_mrcip_ai_prompt_template()
returns trigger
language plpgsql
set search_path=''
as $$
declare uid uuid := (select auth.uid());
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','commodity_manager','research_analyst','legal_compliance']) then
    raise exception 'MRCIP prompt-authoring authority required';
  end if;
  if tg_op='UPDATE' then
    if old.organisation_id<>new.organisation_id or old.prompt_key<>new.prompt_key or old.created_at<>new.created_at or old.created_by<>new.created_by then
      raise exception 'Prompt template identity and creation history are immutable';
    end if;
    if old.status='retired' and new.status<>'retired' then raise exception 'Retired prompt templates cannot be reactivated'; end if;
  else
    new.created_at:=now();
    new.created_by:=uid;
  end if;
  new.updated_at:=now();
  new.updated_by:=uid;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_prompt_template() from public,anon,authenticated;
create trigger mrcip_ai_prompt_templates_guard_biu before insert or update on public.mrcip_ai_prompt_templates for each row execute function private.guard_mrcip_ai_prompt_template();

create or replace function private.guard_mrcip_ai_prompt_version()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  tmpl public.mrcip_ai_prompt_templates%rowtype;
  next_version integer;
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','commodity_manager','research_analyst','legal_compliance']) then
    raise exception 'MRCIP prompt-authoring authority required';
  end if;
  select * into tmpl from public.mrcip_ai_prompt_templates where organisation_id=new.organisation_id and id=new.template_id;
  if not found then raise exception 'Prompt template not found or not accessible'; end if;
  if tg_op='INSERT' then
    if tmpl.status<>'active' then raise exception 'New prompt versions require an active prompt template'; end if;
    select coalesce(max(version_no),0)+1 into next_version from public.mrcip_ai_prompt_versions where organisation_id=new.organisation_id and template_id=new.template_id;
    new.version_no:=next_version;
    new.created_at:=now();
    new.created_by:=uid;
    new.approved_at:=null;
    new.approved_by:=null;
  else
    if old.organisation_id<>new.organisation_id or old.template_id<>new.template_id or old.version_no<>new.version_no or old.system_instructions<>new.system_instructions or old.response_instructions<>new.response_instructions or old.max_output_tokens<>new.max_output_tokens or old.content_fingerprint<>new.content_fingerprint or old.created_at<>new.created_at or old.created_by<>new.created_by then
      raise exception 'Prompt version content and creation history are immutable; create a new version instead';
    end if;
    if old.status='approved' and new.status not in ('approved','retired') then raise exception 'Approved prompt versions may only remain approved or be retired'; end if;
    if old.status='retired' and new.status<>'retired' then raise exception 'Retired prompt versions cannot be reactivated'; end if;
    if old.status='approved' and new.protected_data_approved is distinct from old.protected_data_approved then raise exception 'Protected-data approval is immutable after prompt approval'; end if;
    if old.status='draft' and new.status='approved' and not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','legal_compliance']) then
      raise exception 'Prompt approval requires executive or legal/compliance authority';
    end if;
    if old.status='draft' and new.status='retired' and not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','legal_compliance']) then
      raise exception 'Prompt retirement requires executive or legal/compliance authority';
    end if;
  end if;
  new.content_fingerprint:=md5(concat_ws('|',new.organisation_id::text,new.template_id::text,new.version_no::text,new.system_instructions,new.response_instructions,new.max_output_tokens::text));
  if new.status='approved' then
    if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','legal_compliance']) then raise exception 'Prompt approval requires executive or legal/compliance authority'; end if;
    new.approved_at:=coalesce(new.approved_at,now());
    new.approved_by:=coalesce(new.approved_by,uid);
  elsif new.status='draft' then
    new.approved_at:=null;
    new.approved_by:=null;
    new.protected_data_approved:=false;
  end if;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_prompt_version() from public,anon,authenticated;
create trigger mrcip_ai_prompt_versions_guard_biu before insert or update on public.mrcip_ai_prompt_versions for each row execute function private.guard_mrcip_ai_prompt_version();

create or replace function private.guard_mrcip_ai_provider_config()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  internal_verify boolean := (current_user='service_role' and current_setting('app.mrcip_ai_provider_verification',true)='on');
  runtime_changed boolean:=false;
begin
  if internal_verify then
    if tg_op<>'UPDATE' then raise exception 'Gateway verification may only update an existing provider configuration'; end if;
    new.organisation_id:=old.organisation_id;
    new.provider_key:=old.provider_key;
    new.model_name:=old.model_name;
    new.adapter_key:=old.adapter_key;
    new.credential_secret_ref:=old.credential_secret_ref;
    new.external_processing_location:=old.external_processing_location;
    new.data_handling_notes:=old.data_handling_notes;
    new.created_at:=old.created_at;
    new.created_by:=old.created_by;
    new.approved_at:=old.approved_at;
    new.approved_by:=old.approved_by;
    if new.connection_status='failed' then
      if old.status='active' then new.status:='integration_ready'; else new.status:=old.status; end if;
      new.protected_data_allowed:=false;
      if new.last_connection_error like 'SECRET_MISSING:%' then new.credential_status:='not_configured'; else new.credential_status:=old.credential_status; end if;
    elsif new.connection_status='verified' then
      new.status:=old.status;
      new.protected_data_allowed:=old.protected_data_allowed;
      new.credential_status:=old.credential_status;
      new.connection_verified_at:=coalesce(new.connection_verified_at,now());
    elsif new.connection_status='revoked' then
      new.status:='revoked';
      new.credential_status:='revoked';
      new.protected_data_allowed:=false;
    else
      raise exception 'Gateway verification may record only verified, failed or revoked state';
    end if;
    new.updated_at:=now();
    new.updated_by:=old.updated_by;
    return new;
  end if;

  if uid is null then raise exception 'Authenticated user required'; end if;
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director']) then
    raise exception 'Executive MRCIP authority required to configure AI providers';
  end if;
  if tg_op='UPDATE' then
    if old.organisation_id<>new.organisation_id or old.provider_key<>new.provider_key or old.model_name<>new.model_name or old.created_at<>new.created_at or old.created_by<>new.created_by then
      raise exception 'Provider identity and creation history are immutable; create a new provider configuration instead';
    end if;
    runtime_changed := old.adapter_key is distinct from new.adapter_key or old.credential_secret_ref is distinct from new.credential_secret_ref;
    if runtime_changed then
      if old.status in ('active','revoked') then raise exception 'Deactivate or replace an active/revoked provider before changing runtime configuration'; end if;
      new.connection_status:='not_tested';
      new.connection_verified_at:=null;
      new.connection_verification_ref:='';
      new.last_connection_error:='';
    end if;
  end if;
  if new.status in ('integration_ready','active') then
    if new.credential_status<>'configured_external_secret' then raise exception 'Provider cannot be integration-ready or active without an externally configured credential'; end if;
    if new.adapter_key='unconfigured' or btrim(new.credential_secret_ref)='' then raise exception 'Provider cannot be integration-ready or active without an approved runtime adapter and MRCIP AI secret reference'; end if;
  end if;
  if new.status='active' and new.connection_status<>'verified' then raise exception 'Provider cannot be active until the Stage 12 gateway verifies the configured connection'; end if;
  if new.status='active' then
    new.approved_at:=coalesce(new.approved_at,now());
    new.approved_by:=coalesce(new.approved_by,uid);
  end if;
  if new.protected_data_allowed and new.status<>'active' then raise exception 'Protected-data processing may be enabled only for an active approved provider'; end if;
  if new.status='revoked' then
    new.credential_status:='revoked';
    new.connection_status:='revoked';
    new.protected_data_allowed:=false;
  end if;
  if new.credential_status='revoked' and new.status<>'revoked' then raise exception 'A revoked credential requires provider status revoked'; end if;
  new.updated_at:=now();
  new.updated_by:=uid;
  if tg_op='INSERT' then
    new.created_by:=uid;
    new.created_at:=now();
    if new.status='active' then raise exception 'New provider configurations must be verified before activation'; end if;
  end if;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_provider_config() from public,anon,authenticated;

create or replace function private.guard_mrcip_ai_execution()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  req public.mrcip_ai_requests%rowtype;
  cfg public.mrcip_ai_provider_configs%rowtype;
  pv public.mrcip_ai_prompt_versions%rowtype;
  tmpl public.mrcip_ai_prompt_templates%rowtype;
  actual_count integer:=0;
  ctx_fp text;
  next_no integer;
begin
  if tg_op<>'INSERT' then raise exception 'AI execution history is immutable to authenticated clients'; end if;
  if uid is null then raise exception 'Authenticated user required'; end if;
  select * into req from public.mrcip_ai_requests where organisation_id=new.organisation_id and id=new.request_id;
  if not found then raise exception 'AI request not found or not accessible'; end if;
  if req.requested_by<>uid then raise exception 'Only the AI requester may prepare provider execution for this request'; end if;
  if req.status not in ('context_ready','changes_requested') then raise exception 'AI request is not in an executable state'; end if;
  select count(*)::integer,md5(coalesce(string_agg(context_fingerprint,'|' order by result_rank),'')) into actual_count,ctx_fp from public.mrcip_ai_context_items where organisation_id=req.organisation_id and request_id=req.id;
  if actual_count<>req.context_count then raise exception 'Frozen AI context is incomplete or inconsistent with the audited retrieval'; end if;
  select * into cfg from public.mrcip_ai_provider_configs where organisation_id=req.organisation_id and id=new.provider_config_id;
  if not found then raise exception 'AI provider configuration not found or not accessible'; end if;
  if cfg.status<>'active' or cfg.credential_status<>'configured_external_secret' or cfg.connection_status<>'verified' then raise exception 'AI provider is not active, externally credential-ready and gateway-verified'; end if;
  if cfg.adapter_key='unconfigured' or btrim(cfg.credential_secret_ref)='' then raise exception 'AI provider runtime adapter/secret reference is not configured'; end if;
  if req.protected_context and not cfg.protected_data_allowed then raise exception 'Selected provider is not approved for protected MRCIP context'; end if;
  select * into pv from public.mrcip_ai_prompt_versions where organisation_id=req.organisation_id and id=new.prompt_version_id;
  if not found then raise exception 'Prompt version not found or not accessible'; end if;
  select * into tmpl from public.mrcip_ai_prompt_templates where organisation_id=req.organisation_id and id=pv.template_id;
  if not found or tmpl.status<>'active' then raise exception 'Prompt template is not active'; end if;
  if pv.status<>'approved' then raise exception 'Provider execution requires an approved prompt version'; end if;
  if tmpl.output_type<>req.output_type then raise exception 'Prompt output type must match the AI request output type'; end if;
  if req.protected_context and not pv.protected_data_approved then raise exception 'Protected AI context requires a prompt version explicitly approved for protected data'; end if;
  if exists(select 1 from public.mrcip_ai_executions e where e.organisation_id=req.organisation_id and e.request_id=req.id and e.status='running') then raise exception 'Another provider execution is already running for this AI request'; end if;
  select coalesce(max(execution_no),0)+1 into next_no from public.mrcip_ai_executions where organisation_id=req.organisation_id and request_id=req.id;
  new.execution_no:=next_no;
  new.status:='prepared';
  new.protected_context:=req.protected_context;
  new.policy_version:=req.policy_version;
  new.gateway_policy_version:='mrcip-ai-gateway-v1';
  new.provider_key_snapshot:=cfg.provider_key;
  new.model_name_snapshot:=cfg.model_name;
  new.adapter_key_snapshot:=cfg.adapter_key;
  new.prompt_version_no:=pv.version_no;
  new.prompt_fingerprint:=pv.content_fingerprint;
  new.context_fingerprint:=ctx_fp;
  new.input_fingerprint:=md5(concat_ws('|',req.id::text,cfg.id::text,cfg.provider_key,cfg.model_name,cfg.adapter_key,pv.id::text,pv.content_fingerprint,ctx_fp,req.policy_version,'mrcip-ai-gateway-v1'));
  new.provider_request_id:='';
  new.response_id:=null;
  new.response_fingerprint:='';
  new.input_tokens:=null; new.output_tokens:=null; new.total_tokens:=null; new.latency_ms:=null; new.cost_amount:=null; new.cost_currency:=''; new.cost_source:='unknown'; new.provider_telemetry:='{}'::jsonb; new.failure_code:=''; new.failure_message:='';
  new.prepared_at:=now(); new.started_at:=null; new.finished_at:=null; new.requested_by:=uid;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_execution() from public,anon,authenticated;
create trigger mrcip_ai_executions_guard_bi before insert on public.mrcip_ai_executions for each row execute function private.guard_mrcip_ai_execution();

create or replace function private.log_mrcip_ai_execution_prepared()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  insert into public.mrcip_ai_execution_events(organisation_id,execution_id,event_type,event_status,actor_kind,actor_user_id,details)
  values(new.organisation_id,new.id,'prepared','recorded','user',new.requested_by,jsonb_build_object('execution_no',new.execution_no,'input_fingerprint',new.input_fingerprint,'gateway_policy_version',new.gateway_policy_version));
  return new;
end; $$;
revoke all on function private.log_mrcip_ai_execution_prepared() from public,anon,authenticated;
create trigger mrcip_ai_executions_log_prepared_ai after insert on public.mrcip_ai_executions for each row execute function private.log_mrcip_ai_execution_prepared();

create or replace function public.prepare_mrcip_ai_execution(p_request_id uuid,p_provider_config_id uuid,p_prompt_version_id uuid)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare req public.mrcip_ai_requests%rowtype; exec_id uuid;
begin
  select * into req from public.mrcip_ai_requests where id=p_request_id;
  if not found then raise exception 'AI request not found or not accessible'; end if;
  insert into public.mrcip_ai_executions(organisation_id,request_id,provider_config_id,prompt_version_id,provider_key_snapshot,model_name_snapshot,adapter_key_snapshot,prompt_version_no,prompt_fingerprint,context_fingerprint,input_fingerprint,requested_by)
  values(req.organisation_id,req.id,p_provider_config_id,p_prompt_version_id,'pending','pending','pending',1,'pending','pending','pending',(select auth.uid()))
  returning id into exec_id;
  return exec_id;
end; $$;
revoke all on function public.prepare_mrcip_ai_execution(uuid,uuid,uuid) from public,anon;
grant execute on function public.prepare_mrcip_ai_execution(uuid,uuid,uuid) to authenticated;

create or replace function public.approve_mrcip_ai_prompt_version(p_prompt_version_id uuid,p_protected_data_approved boolean default false)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare pv public.mrcip_ai_prompt_versions%rowtype;
begin
  select * into pv from public.mrcip_ai_prompt_versions where id=p_prompt_version_id;
  if not found then raise exception 'Prompt version not found or not accessible'; end if;
  if pv.status<>'draft' then raise exception 'Only draft prompt versions may be approved'; end if;
  update public.mrcip_ai_prompt_versions set status='approved',protected_data_approved=coalesce(p_protected_data_approved,false) where organisation_id=pv.organisation_id and id=pv.id;
  return pv.id;
end; $$;
revoke all on function public.approve_mrcip_ai_prompt_version(uuid,boolean) from public,anon;
grant execute on function public.approve_mrcip_ai_prompt_version(uuid,boolean) to authenticated;

create or replace function public.authorize_mrcip_ai_provider_verification(p_provider_config_id uuid)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare cfg public.mrcip_ai_provider_configs%rowtype;
begin
  select * into cfg from public.mrcip_ai_provider_configs where id=p_provider_config_id;
  if not found then raise exception 'AI provider configuration not found or not accessible'; end if;
  if not private.has_mrcip_role(cfg.organisation_id,array['super_admin','managing_director']) then raise exception 'Executive MRCIP authority required to verify AI providers'; end if;
  if cfg.status not in ('integration_ready','active') then raise exception 'Provider must be integration-ready or active for connection verification'; end if;
  if cfg.credential_status<>'configured_external_secret' or cfg.adapter_key='unconfigured' or btrim(cfg.credential_secret_ref)='' then raise exception 'Provider runtime/credential metadata is incomplete'; end if;
  return cfg.id;
end; $$;
revoke all on function public.authorize_mrcip_ai_provider_verification(uuid) from public,anon;
grant execute on function public.authorize_mrcip_ai_provider_verification(uuid) to authenticated;

create or replace function public.mrcip_ai_gateway_get_provider_config(p_provider_config_id uuid,p_requester_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path=''
as $$
declare cfg public.mrcip_ai_provider_configs%rowtype;
begin
  if current_user<>'service_role' then raise exception 'Gateway service role required'; end if;
  select * into cfg from public.mrcip_ai_provider_configs where id=p_provider_config_id;
  if not found then raise exception 'Provider configuration not found'; end if;
  if not private.has_mrcip_role_for_user(cfg.organisation_id,p_requester_id,array['super_admin','managing_director']) then raise exception 'Requester is not authorised to verify provider connections'; end if;
  if cfg.status not in ('integration_ready','active') then raise exception 'Provider is not ready for verification'; end if;
  return jsonb_build_object('provider_config_id',cfg.id,'organisation_id',cfg.organisation_id,'provider_key',cfg.provider_key,'model_name',cfg.model_name,'adapter_key',cfg.adapter_key,'credential_secret_ref',cfg.credential_secret_ref,'connection_status',cfg.connection_status);
end; $$;
revoke all on function public.mrcip_ai_gateway_get_provider_config(uuid,uuid) from public,anon,authenticated;
grant execute on function public.mrcip_ai_gateway_get_provider_config(uuid,uuid) to service_role;

create or replace function public.mrcip_ai_gateway_record_provider_check(p_provider_config_id uuid,p_requester_id uuid,p_success boolean,p_verification_ref text default '',p_error_code text default '',p_error_message text default '')
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare cfg public.mrcip_ai_provider_configs%rowtype; err text;
begin
  if current_user<>'service_role' then raise exception 'Gateway service role required'; end if;
  select * into cfg from public.mrcip_ai_provider_configs where id=p_provider_config_id;
  if not found then raise exception 'Provider configuration not found'; end if;
  if not private.has_mrcip_role_for_user(cfg.organisation_id,p_requester_id,array['super_admin','managing_director']) then raise exception 'Requester is not authorised to verify provider connections'; end if;
  err:=case when coalesce(p_error_code,'')='' then left(coalesce(p_error_message,''),1800) else left(p_error_code||':'||coalesce(p_error_message,''),1800) end;
  perform set_config('app.mrcip_ai_provider_verification','on',true);
  update public.mrcip_ai_provider_configs
  set connection_status=case when p_success then 'verified' else 'failed' end,
      connection_verified_at=case when p_success then now() else null end,
      connection_verification_ref=left(coalesce(p_verification_ref,''),500),
      last_connection_error=case when p_success then '' else err end
  where id=cfg.id;
  return cfg.id;
end; $$;
revoke all on function public.mrcip_ai_gateway_record_provider_check(uuid,uuid,boolean,text,text,text) from public,anon,authenticated;
grant execute on function public.mrcip_ai_gateway_record_provider_check(uuid,uuid,boolean,text,text,text) to service_role;

create or replace function public.mrcip_ai_gateway_start_execution(p_execution_id uuid,p_requester_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path=''
as $$
declare
  e public.mrcip_ai_executions%rowtype;
  req public.mrcip_ai_requests%rowtype;
  cfg public.mrcip_ai_provider_configs%rowtype;
  pv public.mrcip_ai_prompt_versions%rowtype;
  ctx jsonb;
begin
  if current_user<>'service_role' then raise exception 'Gateway service role required'; end if;
  select * into e from public.mrcip_ai_executions where id=p_execution_id for update;
  if not found then raise exception 'AI execution not found'; end if;
  if e.requested_by<>p_requester_id then raise exception 'Execution requester mismatch'; end if;
  if e.status<>'prepared' then raise exception 'AI execution must be prepared before start'; end if;
  select * into req from public.mrcip_ai_requests where organisation_id=e.organisation_id and id=e.request_id;
  select * into cfg from public.mrcip_ai_provider_configs where organisation_id=e.organisation_id and id=e.provider_config_id;
  select * into pv from public.mrcip_ai_prompt_versions where organisation_id=e.organisation_id and id=e.prompt_version_id;
  if cfg.status<>'active' or cfg.connection_status<>'verified' or cfg.credential_status<>'configured_external_secret' then raise exception 'Provider is no longer executable'; end if;
  if req.protected_context and (not cfg.protected_data_allowed or not pv.protected_data_approved) then raise exception 'Protected execution approval is no longer valid'; end if;
  update public.mrcip_ai_executions set status='running',started_at=now() where id=e.id;
  insert into public.mrcip_ai_execution_events(organisation_id,execution_id,event_type,event_status,actor_kind,actor_user_id,details)
  values(e.organisation_id,e.id,'started','recorded','gateway',p_requester_id,jsonb_build_object('provider_key',e.provider_key_snapshot,'model_name',e.model_name_snapshot,'adapter_key',e.adapter_key_snapshot));
  select coalesce(jsonb_agg(jsonb_build_object('context_item_id',c.id,'rank',c.result_rank,'entity_type',c.entity_type,'entity_id',c.entity_id,'title',c.title,'subtitle',c.subtitle,'relevance_score',c.relevance_score,'metadata',c.metadata,'fingerprint',c.context_fingerprint) order by c.result_rank),'[]'::jsonb)
  into ctx from public.mrcip_ai_context_items c where c.organisation_id=e.organisation_id and c.request_id=e.request_id;
  return jsonb_build_object(
    'execution_id',e.id,'requester_id',e.requested_by,'provider_config_id',e.provider_config_id,'provider_key',e.provider_key_snapshot,'model_name',e.model_name_snapshot,'adapter_key',e.adapter_key_snapshot,'credential_secret_ref',cfg.credential_secret_ref,
    'request_id',req.id,'request_text',req.request_text,'purpose',req.purpose,'output_type',req.output_type,'protected_context',req.protected_context,'policy_version',req.policy_version,'policy_snapshot',req.policy_snapshot,
    'gateway_policy_version',e.gateway_policy_version,'input_fingerprint',e.input_fingerprint,'prompt_version_id',pv.id,'prompt_version_no',pv.version_no,'system_instructions',pv.system_instructions,'response_instructions',pv.response_instructions,'max_output_tokens',pv.max_output_tokens,'context',ctx,
    'gateway_policy_overlay','Use only the supplied frozen MRCIP context. Do not fabricate sources, parties, specifications, prices, legal/compliance conclusions or citations. Never disclose information outside the supplied context. Return a JSON object with answer, evidence_state (supported|insufficient|conflicted), and citation_ranks (array of supplied context ranks). A supported answer with context must cite at least one supplied rank. No autonomous outreach, disclosure, negotiation, contracting, trading, scoring changes, payment or Finance/Freight mutation is authorised.'
  );
end; $$;
revoke all on function public.mrcip_ai_gateway_start_execution(uuid,uuid) from public,anon,authenticated;
grant execute on function public.mrcip_ai_gateway_start_execution(uuid,uuid) to service_role;

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
  if not internal_execution and uid is null then raise exception 'Authenticated user required'; end if;
  select * into req from public.mrcip_ai_requests where organisation_id=new.organisation_id and id=new.request_id;
  if not found then raise exception 'AI request not found or not accessible'; end if;
  if not internal_execution and req.requested_by<>uid and not private.has_mrcip_role(req.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']) then
    raise exception 'AI response submission requires request ownership or authorised supervisory authority';
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

create or replace function private.guard_mrcip_ai_citation()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  resp public.mrcip_ai_responses%rowtype;
  ctx public.mrcip_ai_context_items%rowtype;
  internal_execution boolean:=false;
begin
  select * into resp from public.mrcip_ai_responses where organisation_id=new.organisation_id and id=new.response_id;
  if not found then raise exception 'AI response not found or not accessible'; end if;
  internal_execution := (resp.response_origin='external_model' and resp.execution_id is not null and current_user='service_role' and current_setting('app.mrcip_ai_execution_id',true)=resp.execution_id::text);
  if not internal_execution then
    if uid is null then raise exception 'Authenticated user required'; end if;
    if resp.generated_by<>uid and not private.has_mrcip_role(resp.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']) then raise exception 'Citation creation requires response ownership or authorised supervisory authority'; end if;
  end if;
  select * into ctx from public.mrcip_ai_context_items where organisation_id=resp.organisation_id and id=new.context_item_id;
  if not found then raise exception 'AI context item not found or not accessible'; end if;
  if ctx.request_id<>resp.request_id then raise exception 'Citation context must belong to the same AI request as the response'; end if;
  new.protected_context:=resp.protected_context or ctx.protected_context;
  new.created_at:=now();
  new.created_by:=case when internal_execution then resp.generated_by else uid end;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_citation() from public,anon,authenticated;

create or replace function public.mrcip_ai_gateway_complete_execution(
  p_execution_id uuid,p_requester_id uuid,p_provider_request_id text,p_answer_text text,p_evidence_state text,p_citation_ranks integer[] default null,
  p_input_tokens integer default null,p_output_tokens integer default null,p_total_tokens integer default null,p_latency_ms integer default null,
  p_cost_amount numeric default null,p_cost_currency text default '',p_cost_source text default 'unknown',p_provider_telemetry jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path=''
as $$
declare
  e public.mrcip_ai_executions%rowtype;
  req public.mrcip_ai_requests%rowtype;
  resp_id uuid;
  valid_citations integer:=0;
  requested_citations integer:=coalesce(cardinality(p_citation_ranks),0);
  safe_telemetry jsonb;
begin
  if current_user<>'service_role' then raise exception 'Gateway service role required'; end if;
  select * into e from public.mrcip_ai_executions where id=p_execution_id for update;
  if not found then raise exception 'AI execution not found'; end if;
  if e.requested_by<>p_requester_id then raise exception 'Execution requester mismatch'; end if;
  if e.status<>'running' then raise exception 'Only a running AI execution may complete'; end if;
  select * into req from public.mrcip_ai_requests where organisation_id=e.organisation_id and id=e.request_id;
  if coalesce(p_evidence_state,'') not in ('supported','insufficient','conflicted') then raise exception 'Invalid evidence state'; end if;
  if btrim(coalesce(p_provider_request_id,''))='' then raise exception 'Provider request ID is required'; end if;
  if requested_citations>0 then
    if (select count(distinct r) from unnest(p_citation_ranks) r)<>requested_citations then raise exception 'Duplicate citation ranks are not allowed'; end if;
    select count(*)::integer into valid_citations from public.mrcip_ai_context_items c where c.organisation_id=e.organisation_id and c.request_id=e.request_id and c.result_rank=any(p_citation_ranks);
    if valid_citations<>requested_citations then raise exception 'One or more citation ranks are outside the frozen execution context'; end if;
  end if;
  if p_evidence_state='supported' and req.context_count>0 and requested_citations=0 then raise exception 'Supported provider response requires one or more frozen-context citations'; end if;
  if p_input_tokens is not null and p_input_tokens<0 or p_output_tokens is not null and p_output_tokens<0 or p_total_tokens is not null and p_total_tokens<0 or p_latency_ms is not null and p_latency_ms<0 then raise exception 'Usage and latency values cannot be negative'; end if;
  if p_cost_amount is not null and p_cost_amount<0 then raise exception 'Cost amount cannot be negative'; end if;
  if coalesce(p_cost_currency,'')<>'' and p_cost_currency !~ '^[A-Z]{3}$' then raise exception 'Cost currency must be a three-letter uppercase code'; end if;
  if coalesce(p_cost_source,'unknown') not in ('unknown','provider_reported','configured_rate') then raise exception 'Invalid cost source'; end if;
  safe_telemetry:=coalesce(p_provider_telemetry,'{}'::jsonb)-array['authorization','api_key','secret','token','request_body','response_body','output','answer_text'];
  if length(safe_telemetry::text)>16000 then raise exception 'Provider telemetry exceeds safe audit limit'; end if;
  perform set_config('app.mrcip_ai_execution_id',e.id::text,true);
  insert into public.mrcip_ai_responses(organisation_id,request_id,response_origin,provider_config_id,execution_id,provider_request_id,answer_text,evidence_state,generated_by,answer_fingerprint)
  values(e.organisation_id,e.request_id,'external_model',e.provider_config_id,e.id,left(p_provider_request_id,1000),p_answer_text,p_evidence_state,e.requested_by,'pending')
  returning id into resp_id;
  if requested_citations>0 then
    insert into public.mrcip_ai_citations(organisation_id,response_id,context_item_id,citation_order,created_by)
    select e.organisation_id,resp_id,c.id,u.ordinality::integer,e.requested_by
    from unnest(p_citation_ranks) with ordinality u(rank_value,ordinality)
    join public.mrcip_ai_context_items c on c.organisation_id=e.organisation_id and c.request_id=e.request_id and c.result_rank=u.rank_value;
  end if;
  update public.mrcip_ai_executions
  set status='completed',provider_request_id=left(p_provider_request_id,1000),response_id=resp_id,response_fingerprint=(select answer_fingerprint from public.mrcip_ai_responses where id=resp_id),
      input_tokens=p_input_tokens,output_tokens=p_output_tokens,total_tokens=coalesce(p_total_tokens,case when p_input_tokens is not null and p_output_tokens is not null then p_input_tokens+p_output_tokens else null end),latency_ms=p_latency_ms,
      cost_amount=p_cost_amount,cost_currency=coalesce(p_cost_currency,''),cost_source=coalesce(p_cost_source,'unknown'),provider_telemetry=safe_telemetry,failure_code='',failure_message='',finished_at=now()
  where id=e.id;
  insert into public.mrcip_ai_execution_events(organisation_id,execution_id,event_type,event_status,actor_kind,actor_user_id,details)
  values(e.organisation_id,e.id,'provider_response','success','gateway',p_requester_id,jsonb_build_object('provider_request_id',left(p_provider_request_id,300),'input_tokens',p_input_tokens,'output_tokens',p_output_tokens,'total_tokens',coalesce(p_total_tokens,case when p_input_tokens is not null and p_output_tokens is not null then p_input_tokens+p_output_tokens else null end),'latency_ms',p_latency_ms));
  insert into public.mrcip_ai_execution_events(organisation_id,execution_id,event_type,event_status,actor_kind,actor_user_id,details)
  values(e.organisation_id,e.id,'completed','success','gateway',p_requester_id,jsonb_build_object('response_id',resp_id,'evidence_state',p_evidence_state,'citation_count',requested_citations));
  return jsonb_build_object('execution_id',e.id,'response_id',resp_id,'status','completed','review_status','review_required');
end; $$;
revoke all on function public.mrcip_ai_gateway_complete_execution(uuid,uuid,text,text,text,integer[],integer,integer,integer,integer,numeric,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.mrcip_ai_gateway_complete_execution(uuid,uuid,text,text,text,integer[],integer,integer,integer,integer,numeric,text,text,jsonb) to service_role;

create or replace function public.mrcip_ai_gateway_fail_execution(p_execution_id uuid,p_requester_id uuid,p_terminal_status text,p_failure_code text,p_failure_message text,p_latency_ms integer default null,p_provider_telemetry jsonb default '{}'::jsonb)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare e public.mrcip_ai_executions%rowtype; safe_telemetry jsonb;
begin
  if current_user<>'service_role' then raise exception 'Gateway service role required'; end if;
  select * into e from public.mrcip_ai_executions where id=p_execution_id for update;
  if not found then raise exception 'AI execution not found'; end if;
  if e.requested_by<>p_requester_id then raise exception 'Execution requester mismatch'; end if;
  if e.status not in ('prepared','running') then raise exception 'Only prepared or running executions may be terminated'; end if;
  if p_terminal_status not in ('failed','blocked','cancelled') then raise exception 'Invalid terminal execution status'; end if;
  if btrim(coalesce(p_failure_code,''))='' then raise exception 'Failure code is required'; end if;
  safe_telemetry:=coalesce(p_provider_telemetry,'{}'::jsonb)-array['authorization','api_key','secret','token','request_body','response_body','output','answer_text'];
  if length(safe_telemetry::text)>16000 then raise exception 'Provider telemetry exceeds safe audit limit'; end if;
  update public.mrcip_ai_executions set status=p_terminal_status,failure_code=left(p_failure_code,200),failure_message=left(coalesce(p_failure_message,''),2000),latency_ms=p_latency_ms,provider_telemetry=safe_telemetry,finished_at=now() where id=e.id;
  insert into public.mrcip_ai_execution_events(organisation_id,execution_id,event_type,event_status,actor_kind,actor_user_id,details)
  values(e.organisation_id,e.id,case when p_terminal_status='blocked' then 'blocked' when p_terminal_status='cancelled' then 'cancelled' else 'failed' end,'failure','gateway',p_requester_id,jsonb_build_object('failure_code',left(p_failure_code,200),'failure_message',left(coalesce(p_failure_message,''),1000),'latency_ms',p_latency_ms));
  return e.id;
end; $$;
revoke all on function public.mrcip_ai_gateway_fail_execution(uuid,uuid,text,text,text,integer,jsonb) from public,anon,authenticated;
grant execute on function public.mrcip_ai_gateway_fail_execution(uuid,uuid,text,text,text,integer,jsonb) to service_role;