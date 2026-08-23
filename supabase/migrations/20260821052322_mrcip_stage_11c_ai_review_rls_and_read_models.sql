create or replace function private.guard_mrcip_ai_review()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  resp public.mrcip_ai_responses%rowtype;
  req public.mrcip_ai_requests%rowtype;
  citation_count integer:=0;
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  select * into resp from public.mrcip_ai_responses where organisation_id=new.organisation_id and id=new.response_id;
  if not found then raise exception 'AI response not found or not accessible'; end if;
  select * into req from public.mrcip_ai_requests where organisation_id=resp.organisation_id and id=resp.request_id;
  if not found then raise exception 'AI request not found or not accessible'; end if;
  if resp.status<>'review_required' then
    raise exception 'Only review-required AI responses may receive a final review; create a new response version for changes';
  end if;
  if not private.has_mrcip_role(resp.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']) then
    raise exception 'AI response review requires supervisory MRCIP authority';
  end if;
  if (resp.protected_context or req.output_type='risk_summary') and not private.has_mrcip_role(resp.organisation_id,array['super_admin','managing_director','legal_compliance']) then
    raise exception 'Protected or risk-summary AI review requires executive or legal/compliance authority';
  end if;
  select count(*)::integer into citation_count from public.mrcip_ai_citations where organisation_id=resp.organisation_id and response_id=resp.id;
  if resp.evidence_state='supported' and citation_count=0 then
    raise exception 'Supported AI responses require at least one frozen-context citation before review';
  end if;
  if new.decision='approve' and not (new.citation_check_passed and new.factuality_check_passed and new.protection_check_passed) then
    raise exception 'Approval requires citation, factuality and protection checks to pass';
  end if;
  if new.decision in ('changes_requested','reject') and btrim(new.notes)='' then
    raise exception 'Changes-requested or rejected reviews require explanatory notes';
  end if;
  new.reviewer_id:=uid;
  new.reviewed_at:=now();
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_review() from public,anon,authenticated;
create trigger mrcip_ai_reviews_guard_bi before insert on public.mrcip_ai_reviews for each row execute function private.guard_mrcip_ai_review();

create or replace function private.sync_mrcip_ai_request_after_response()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  update public.mrcip_ai_requests
  set status='review_required'
  where organisation_id=new.organisation_id and id=new.request_id and status not in ('approved','cancelled');
  return new;
end; $$;
revoke all on function private.sync_mrcip_ai_request_after_response() from public,anon,authenticated;
create trigger mrcip_ai_responses_sync_request_ai after insert on public.mrcip_ai_responses for each row execute function private.sync_mrcip_ai_request_after_response();

create or replace function private.apply_mrcip_ai_review()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  resp public.mrcip_ai_responses%rowtype;
  next_status text;
begin
  select * into resp from public.mrcip_ai_responses where organisation_id=new.organisation_id and id=new.response_id;
  if not found then raise exception 'AI response missing during review application'; end if;
  next_status:=case new.decision when 'approve' then 'approved' when 'changes_requested' then 'changes_requested' else 'rejected' end;
  if new.decision='approve' then
    update public.mrcip_ai_responses
    set status='superseded'
    where organisation_id=resp.organisation_id and request_id=resp.request_id and id<>resp.id and status='approved';
  end if;
  update public.mrcip_ai_responses
  set status=next_status,reviewed_at=new.reviewed_at,reviewed_by=new.reviewer_id,review_summary=new.notes
  where organisation_id=resp.organisation_id and id=resp.id;
  update public.mrcip_ai_requests
  set status=next_status
  where organisation_id=resp.organisation_id and id=resp.request_id;
  return new;
end; $$;
revoke all on function private.apply_mrcip_ai_review() from public,anon,authenticated;
create trigger mrcip_ai_reviews_apply_ai after insert on public.mrcip_ai_reviews for each row execute function private.apply_mrcip_ai_review();

create policy mrcip_ai_provider_configs_select on public.mrcip_ai_provider_configs for select to authenticated using (
  private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])
);
create policy mrcip_ai_provider_configs_insert on public.mrcip_ai_provider_configs for insert to authenticated with check (
  created_by=(select auth.uid()) and updated_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director'])
);
create policy mrcip_ai_provider_configs_update on public.mrcip_ai_provider_configs for update to authenticated using (
  private.has_mrcip_role(organisation_id,array['super_admin','managing_director'])
) with check (
  updated_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director'])
);

create policy mrcip_ai_requests_select on public.mrcip_ai_requests for select to authenticated using (
  private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])
  and (requested_by=(select auth.uid()) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']))
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);
create policy mrcip_ai_requests_insert on public.mrcip_ai_requests for insert to authenticated with check (
  requested_by=(select auth.uid())
  and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);

create policy mrcip_ai_context_items_select on public.mrcip_ai_context_items for select to authenticated using (
  exists (select 1 from public.mrcip_ai_requests r where r.organisation_id=mrcip_ai_context_items.organisation_id and r.id=mrcip_ai_context_items.request_id)
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);
create policy mrcip_ai_context_items_insert on public.mrcip_ai_context_items for insert to authenticated with check (
  captured_by=(select auth.uid())
  and exists (select 1 from public.mrcip_ai_requests r where r.organisation_id=mrcip_ai_context_items.organisation_id and r.id=mrcip_ai_context_items.request_id and r.requested_by=(select auth.uid()) and r.retrieval_request_id=mrcip_ai_context_items.retrieval_request_id)
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);

create policy mrcip_ai_responses_select on public.mrcip_ai_responses for select to authenticated using (
  exists (select 1 from public.mrcip_ai_requests r where r.organisation_id=mrcip_ai_responses.organisation_id and r.id=mrcip_ai_responses.request_id)
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);
create policy mrcip_ai_responses_insert on public.mrcip_ai_responses for insert to authenticated with check (
  generated_by=(select auth.uid())
  and exists (
    select 1 from public.mrcip_ai_requests r
    where r.organisation_id=mrcip_ai_responses.organisation_id and r.id=mrcip_ai_responses.request_id
      and (r.requested_by=(select auth.uid()) or private.has_mrcip_role(r.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']))
  )
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);

create policy mrcip_ai_citations_select on public.mrcip_ai_citations for select to authenticated using (
  exists (select 1 from public.mrcip_ai_responses r where r.organisation_id=mrcip_ai_citations.organisation_id and r.id=mrcip_ai_citations.response_id)
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);
create policy mrcip_ai_citations_insert on public.mrcip_ai_citations for insert to authenticated with check (
  created_by=(select auth.uid())
  and exists (
    select 1 from public.mrcip_ai_responses r
    where r.organisation_id=mrcip_ai_citations.organisation_id and r.id=mrcip_ai_citations.response_id
      and (r.generated_by=(select auth.uid()) or private.has_mrcip_role(r.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']))
  )
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);

create policy mrcip_ai_reviews_select on public.mrcip_ai_reviews for select to authenticated using (
  exists (select 1 from public.mrcip_ai_responses r where r.organisation_id=mrcip_ai_reviews.organisation_id and r.id=mrcip_ai_reviews.response_id)
);
create policy mrcip_ai_reviews_insert on public.mrcip_ai_reviews for insert to authenticated with check (
  reviewer_id=(select auth.uid())
  and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance'])
);

revoke all on public.mrcip_ai_provider_configs,public.mrcip_ai_requests,public.mrcip_ai_context_items,public.mrcip_ai_responses,public.mrcip_ai_citations,public.mrcip_ai_reviews from anon,authenticated;
grant select,insert,update on public.mrcip_ai_provider_configs to authenticated;
grant select,insert on public.mrcip_ai_requests to authenticated;
grant select,insert on public.mrcip_ai_context_items to authenticated;
grant select,insert on public.mrcip_ai_responses to authenticated;
grant select,insert on public.mrcip_ai_citations to authenticated;
grant select,insert on public.mrcip_ai_reviews to authenticated;

create or replace function public.review_mrcip_ai_response(
  p_response_id uuid,
  p_decision text,
  p_citation_check_passed boolean,
  p_factuality_check_passed boolean,
  p_protection_check_passed boolean,
  p_notes text default ''
)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare
  resp public.mrcip_ai_responses%rowtype;
  review_id uuid;
begin
  select * into resp from public.mrcip_ai_responses where id=p_response_id;
  if not found then raise exception 'AI response not found or not accessible'; end if;
  insert into public.mrcip_ai_reviews(organisation_id,response_id,decision,citation_check_passed,factuality_check_passed,protection_check_passed,notes,reviewer_id)
  values(resp.organisation_id,resp.id,p_decision,coalesce(p_citation_check_passed,false),coalesce(p_factuality_check_passed,false),coalesce(p_protection_check_passed,false),coalesce(p_notes,''),(select auth.uid()))
  returning id into review_id;
  return review_id;
end; $$;
revoke all on function public.review_mrcip_ai_response(uuid,text,boolean,boolean,boolean,text) from public,anon;
grant execute on function public.review_mrcip_ai_response(uuid,text,boolean,boolean,boolean,text) to authenticated;

create or replace view public.mrcip_ai_request_summary with (security_invoker=true) as
select r.organisation_id,r.id as request_id,r.request_text,r.purpose,r.output_type,r.include_protected,r.max_context_items,r.context_count,r.protected_context,r.status as request_status,r.policy_version,r.requested_at,r.requested_by,
  lr.id as latest_response_id,lr.response_version as latest_response_version,lr.response_origin as latest_response_origin,lr.provider_key as latest_provider_key,lr.model_name as latest_model_name,lr.evidence_state as latest_evidence_state,lr.status as latest_response_status,lr.generated_at as latest_generated_at,lr.generated_by as latest_generated_by,lr.reviewed_at as latest_reviewed_at,lr.reviewed_by as latest_reviewed_by,
  coalesce(lr.citation_count,0) as latest_citation_count,coalesce(lr.review_count,0) as latest_review_count
from public.mrcip_ai_requests r
left join lateral (
  select x.id,x.response_version,x.response_origin,x.provider_key,x.model_name,x.evidence_state,x.status,x.generated_at,x.generated_by,x.reviewed_at,x.reviewed_by,
    (select count(*)::integer from public.mrcip_ai_citations c where c.organisation_id=x.organisation_id and c.response_id=x.id) as citation_count,
    (select count(*)::integer from public.mrcip_ai_reviews v where v.organisation_id=x.organisation_id and v.response_id=x.id) as review_count
  from public.mrcip_ai_responses x
  where x.organisation_id=r.organisation_id and x.request_id=r.id
  order by x.response_version desc limit 1
) lr on true;
revoke all on public.mrcip_ai_request_summary from public,anon,authenticated;
grant select on public.mrcip_ai_request_summary to authenticated;

create or replace view public.mrcip_ai_citation_trace with (security_invoker=true) as
select resp.organisation_id,resp.id as response_id,resp.request_id,resp.response_version,resp.status as response_status,resp.evidence_state,resp.protected_context as response_protected,
  c.id as citation_id,c.citation_order,c.citation_kind,c.claim_anchor,c.protected_context as citation_protected,
  ctx.id as context_item_id,ctx.result_rank,ctx.entity_type,ctx.entity_id,ctx.title,ctx.subtitle,ctx.relevance_score,ctx.metadata,ctx.context_fingerprint,ctx.captured_at
from public.mrcip_ai_responses resp
join public.mrcip_ai_citations c on c.organisation_id=resp.organisation_id and c.response_id=resp.id
join public.mrcip_ai_context_items ctx on ctx.organisation_id=c.organisation_id and ctx.id=c.context_item_id;
revoke all on public.mrcip_ai_citation_trace from public,anon,authenticated;
grant select on public.mrcip_ai_citation_trace to authenticated;