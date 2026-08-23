create or replace function private.guard_mrcip_ai_provider_config()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director']) then
    raise exception 'Executive MRCIP authority required to configure AI providers';
  end if;
  if tg_op='UPDATE' then
    if old.organisation_id<>new.organisation_id or old.provider_key<>new.provider_key or old.model_name<>new.model_name or old.created_at<>new.created_at or old.created_by<>new.created_by then
      raise exception 'Provider identity and creation history are immutable; create a new provider configuration instead';
    end if;
  end if;
  if new.status in ('integration_ready','active') and new.credential_status<>'configured_external_secret' then
    raise exception 'Provider cannot be integration-ready or active without an externally configured credential';
  end if;
  if new.status='active' then
    new.approved_at:=coalesce(new.approved_at,now());
    new.approved_by:=coalesce(new.approved_by,uid);
  end if;
  if new.protected_data_allowed and new.status<>'active' then
    raise exception 'Protected-data processing may be enabled only for an active approved provider';
  end if;
  if new.status='revoked' then
    new.credential_status:='revoked';
    new.protected_data_allowed:=false;
  end if;
  if new.credential_status='revoked' and new.status<>'revoked' then
    raise exception 'A revoked credential requires provider status revoked';
  end if;
  new.updated_at:=now();
  new.updated_by:=uid;
  if tg_op='INSERT' then
    new.created_by:=uid;
    new.created_at:=now();
  end if;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_provider_config() from public,anon,authenticated;
create trigger mrcip_ai_provider_configs_guard_biu before insert or update on public.mrcip_ai_provider_configs for each row execute function private.guard_mrcip_ai_provider_config();

create or replace function private.guard_mrcip_ai_request()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  rr public.mrcip_retrieval_requests%rowtype;
  cnt integer:=0;
  any_protected boolean:=false;
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance']) then
    raise exception 'MRCIP intelligence authority required';
  end if;
  select * into rr from public.mrcip_retrieval_requests
  where organisation_id=new.organisation_id and id=new.retrieval_request_id;
  if not found then raise exception 'Retrieval request not found or not accessible'; end if;
  if rr.requested_by<>uid then raise exception 'AI request must use a retrieval request created by the same authenticated requester'; end if;
  if rr.status<>'completed' then raise exception 'AI request requires a completed retrieval request'; end if;
  if rr.max_results>25 then raise exception 'AI context is capped at 25 retrieval items'; end if;
  if new.output_type='risk_summary' and not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','legal_compliance']) then
    raise exception 'Risk-summary AI requests require executive or legal/compliance authority';
  end if;
  select count(*)::integer,coalesce(bool_or(c.protected_context),false)
  into cnt,any_protected
  from private.mrcip_retrieval_candidates(rr.organisation_id,rr.query_text,rr.entity_types,rr.include_protected,rr.max_results) c;
  new.request_text:=rr.query_text;
  new.purpose:=rr.purpose;
  new.entity_types:=rr.entity_types;
  new.include_protected:=rr.include_protected;
  new.max_context_items:=rr.max_results;
  new.context_count:=cnt;
  new.protected_context:=any_protected or new.output_type='risk_summary';
  if new.protected_context and not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']) then
    raise exception 'Protected AI context requires privileged MRCIP authority';
  end if;
  new.status:='context_ready';
  new.policy_version:='mrcip-ai-policy-v1';
  new.policy_snapshot:=jsonb_build_object(
    'policy_version','mrcip-ai-policy-v1',
    'evidence_boundary','cite_only_frozen_context_items',
    'protected_protocol','PROTECT → VERIFY → DISCLOSE → CONTRACT',
    'no_autonomous_outreach',true,
    'no_autonomous_disclosure',true,
    'no_autonomous_contracting',true,
    'no_autonomous_trading',true,
    'no_fabricated_sources',true,
    'human_review_required',true,
    'external_rating_disclaimer',true,
    'safe_retrieval_metadata_only',true
  );
  new.requested_by:=uid;
  new.requested_at:=now();
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_request() from public,anon,authenticated;
create trigger mrcip_ai_requests_guard_bi before insert on public.mrcip_ai_requests for each row execute function private.guard_mrcip_ai_request();

create or replace function private.guard_mrcip_ai_context_item()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  req public.mrcip_ai_requests%rowtype;
  rr public.mrcip_retrieval_requests%rowtype;
  candidate record;
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  select * into req from public.mrcip_ai_requests where organisation_id=new.organisation_id and id=new.request_id;
  if not found then raise exception 'AI request not found or not accessible'; end if;
  if req.requested_by<>uid then raise exception 'Only the AI requester may freeze its retrieval context'; end if;
  if new.retrieval_request_id<>req.retrieval_request_id then raise exception 'Context retrieval request must match the AI request'; end if;
  select * into rr from public.mrcip_retrieval_requests where organisation_id=req.organisation_id and id=req.retrieval_request_id;
  if not found or rr.requested_by<>uid then raise exception 'Retrieval request is not accessible to the AI requester'; end if;
  select * into candidate
  from private.mrcip_retrieval_candidates(rr.organisation_id,rr.query_text,rr.entity_types,rr.include_protected,rr.max_results) c
  where c.result_rank=new.result_rank;
  if not found then raise exception 'Context rank does not exist in the audited retrieval result'; end if;
  new.entity_type:=candidate.entity_type;
  new.entity_id:=candidate.entity_id;
  new.title:=candidate.title;
  new.subtitle:=candidate.subtitle;
  new.relevance_score:=candidate.relevance_score;
  new.protected_context:=candidate.protected_context;
  new.metadata:=candidate.metadata;
  new.context_fingerprint:=md5(concat_ws('|',candidate.result_rank::text,candidate.entity_type,candidate.entity_id::text,candidate.title,candidate.subtitle,candidate.relevance_score::text,candidate.protected_context::text,candidate.metadata::text));
  new.captured_at:=now();
  new.captured_by:=uid;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_context_item() from public,anon,authenticated;
create trigger mrcip_ai_context_items_guard_bi before insert on public.mrcip_ai_context_items for each row execute function private.guard_mrcip_ai_context_item();

create or replace function private.guard_mrcip_ai_response()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  req public.mrcip_ai_requests%rowtype;
  cfg public.mrcip_ai_provider_configs%rowtype;
  actual_context_count integer:=0;
  next_version integer:=1;
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  select * into req from public.mrcip_ai_requests where organisation_id=new.organisation_id and id=new.request_id;
  if not found then raise exception 'AI request not found or not accessible'; end if;
  if req.requested_by<>uid and not private.has_mrcip_role(req.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']) then
    raise exception 'AI response submission requires request ownership or authorised supervisory authority';
  end if;
  select count(*)::integer into actual_context_count from public.mrcip_ai_context_items where organisation_id=req.organisation_id and request_id=req.id;
  if actual_context_count<>req.context_count then
    raise exception 'Frozen AI context is incomplete or inconsistent with the audited retrieval';
  end if;
  if new.evidence_state='supported' and actual_context_count=0 then
    raise exception 'A supported response requires at least one frozen context item';
  end if;
  if new.response_origin='external_model' then
    if new.provider_config_id is null then raise exception 'External-model responses require an approved provider configuration'; end if;
    select * into cfg from public.mrcip_ai_provider_configs where organisation_id=req.organisation_id and id=new.provider_config_id;
    if not found then raise exception 'AI provider configuration not found or not accessible'; end if;
    if cfg.status<>'active' or cfg.credential_status<>'configured_external_secret' then
      raise exception 'External-model provider is not active and credential-ready';
    end if;
    if req.protected_context and not cfg.protected_data_allowed then
      raise exception 'Selected provider is not approved for protected MRCIP context';
    end if;
    new.provider_key:=cfg.provider_key;
    new.model_name:=cfg.model_name;
  else
    if new.provider_config_id is not null then raise exception 'Human/deterministic responses must not attach an external provider configuration'; end if;
    new.provider_key:='';
    new.model_name:='';
    new.provider_request_id:='';
  end if;
  select coalesce(max(response_version),0)+1 into next_version from public.mrcip_ai_responses where organisation_id=req.organisation_id and request_id=req.id;
  new.response_version:=next_version;
  new.protected_context:=req.protected_context;
  new.status:='review_required';
  new.policy_version:=req.policy_version;
  new.answer_fingerprint:=md5(concat_ws('|',req.id::text,next_version::text,new.response_origin,new.provider_key,new.model_name,new.answer_text,new.evidence_state,req.policy_version));
  new.generated_at:=now();
  new.generated_by:=uid;
  new.reviewed_at:=null;
  new.reviewed_by:=null;
  new.review_summary:='';
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_response() from public,anon,authenticated;
create trigger mrcip_ai_responses_guard_bi before insert on public.mrcip_ai_responses for each row execute function private.guard_mrcip_ai_response();

create or replace function private.guard_mrcip_ai_citation()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  resp public.mrcip_ai_responses%rowtype;
  ctx public.mrcip_ai_context_items%rowtype;
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  select * into resp from public.mrcip_ai_responses where organisation_id=new.organisation_id and id=new.response_id;
  if not found then raise exception 'AI response not found or not accessible'; end if;
  if resp.generated_by<>uid and not private.has_mrcip_role(resp.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']) then
    raise exception 'Citation creation requires response ownership or authorised supervisory authority';
  end if;
  select * into ctx from public.mrcip_ai_context_items where organisation_id=resp.organisation_id and id=new.context_item_id;
  if not found then raise exception 'AI context item not found or not accessible'; end if;
  if ctx.request_id<>resp.request_id then raise exception 'Citation context must belong to the same AI request as the response'; end if;
  new.protected_context:=resp.protected_context or ctx.protected_context;
  new.created_at:=now();
  new.created_by:=uid;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_citation() from public,anon,authenticated;
create trigger mrcip_ai_citations_guard_bi before insert on public.mrcip_ai_citations for each row execute function private.guard_mrcip_ai_citation();

create or replace function public.prepare_mrcip_ai_request(
  p_organisation_id uuid,
  p_query text,
  p_purpose text,
  p_output_type text default 'answer',
  p_entity_types text[] default null,
  p_include_protected boolean default false,
  p_max_context_items integer default 12
)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare
  rr_id uuid;
  req_id uuid;
begin
  if p_max_context_items is null or p_max_context_items<1 or p_max_context_items>25 then
    raise exception 'AI context item limit must be between 1 and 25';
  end if;
  insert into public.mrcip_retrieval_requests(organisation_id,query_text,purpose,entity_types,include_protected,max_results,requested_by)
  values(p_organisation_id,p_query,p_purpose,coalesce(p_entity_types,array['counterparty','mine','laboratory','buyer_requirement','seller_offer','opportunity']::text[]),coalesce(p_include_protected,false),p_max_context_items,(select auth.uid()))
  returning id into rr_id;
  insert into public.mrcip_ai_requests(organisation_id,retrieval_request_id,request_text,purpose,output_type,entity_types,include_protected,max_context_items,requested_by)
  values(p_organisation_id,rr_id,p_query,p_purpose,coalesce(p_output_type,'answer'),coalesce(p_entity_types,array['counterparty','mine','laboratory','buyer_requirement','seller_offer','opportunity']::text[]),coalesce(p_include_protected,false),p_max_context_items,(select auth.uid()))
  returning id into req_id;
  insert into public.mrcip_ai_context_items(organisation_id,request_id,retrieval_request_id,result_rank,entity_type,entity_id,title,subtitle,relevance_score,protected_context,metadata,context_fingerprint,captured_by)
  select p_organisation_id,req_id,rr_id,c.result_rank,c.entity_type,c.entity_id,c.title,c.subtitle,c.relevance_score,c.protected_context,c.metadata,'pending',(select auth.uid())
  from private.mrcip_retrieval_candidates(p_organisation_id,p_query,coalesce(p_entity_types,array['counterparty','mine','laboratory','buyer_requirement','seller_offer','opportunity']::text[]),coalesce(p_include_protected,false),p_max_context_items) c;
  return req_id;
end; $$;
revoke all on function public.prepare_mrcip_ai_request(uuid,text,text,text,text[],boolean,integer) from public,anon;
grant execute on function public.prepare_mrcip_ai_request(uuid,text,text,text,text[],boolean,integer) to authenticated;

create or replace function public.submit_mrcip_ai_response(
  p_request_id uuid,
  p_answer_text text,
  p_evidence_state text default 'supported',
  p_context_item_ids uuid[] default null,
  p_response_origin text default 'human_draft',
  p_provider_config_id uuid default null,
  p_provider_request_id text default ''
)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare
  req public.mrcip_ai_requests%rowtype;
  resp_id uuid;
  duplicate_count integer:=0;
begin
  select * into req from public.mrcip_ai_requests where id=p_request_id;
  if not found then raise exception 'AI request not found or not accessible'; end if;
  if p_context_item_ids is not null then
    select cardinality(p_context_item_ids)-count(distinct x)::integer into duplicate_count from unnest(p_context_item_ids) x;
    if duplicate_count>0 then raise exception 'Duplicate citation context items are not allowed'; end if;
  end if;
  if coalesce(p_evidence_state,'supported')='supported' and req.context_count>0 and coalesce(cardinality(p_context_item_ids),0)=0 then
    raise exception 'Supported AI response requires one or more citations';
  end if;
  insert into public.mrcip_ai_responses(organisation_id,request_id,response_origin,provider_config_id,provider_request_id,answer_text,evidence_state,generated_by,answer_fingerprint)
  values(req.organisation_id,req.id,coalesce(p_response_origin,'human_draft'),p_provider_config_id,coalesce(p_provider_request_id,''),p_answer_text,coalesce(p_evidence_state,'supported'),(select auth.uid()),'pending')
  returning id into resp_id;
  if coalesce(cardinality(p_context_item_ids),0)>0 then
    insert into public.mrcip_ai_citations(organisation_id,response_id,context_item_id,citation_order,created_by)
    select req.organisation_id,resp_id,u.context_item_id,u.ordinality::integer,(select auth.uid())
    from unnest(p_context_item_ids) with ordinality as u(context_item_id,ordinality);
  end if;
  return resp_id;
end; $$;
revoke all on function public.submit_mrcip_ai_response(uuid,text,text,uuid[],text,uuid,text) from public,anon;
grant execute on function public.submit_mrcip_ai_response(uuid,text,text,uuid[],text,uuid,text) to authenticated;