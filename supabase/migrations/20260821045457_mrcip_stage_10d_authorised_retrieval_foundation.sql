create or replace function private.mrcip_retrieval_candidates(
  p_organisation_id uuid,
  p_query text,
  p_entity_types text[],
  p_include_protected boolean,
  p_limit integer
)
returns table(
  result_rank integer,
  entity_type text,
  entity_id uuid,
  title text,
  subtitle text,
  relevance_score numeric,
  protected_context boolean,
  metadata jsonb
)
language sql
stable
security invoker
set search_path=''
as $$
with params as (
  select lower(btrim(p_query)) as q,
    coalesce(p_entity_types,array['counterparty','mine','laboratory','buyer_requirement','seller_offer','opportunity']::text[]) as types
), candidates as (
  select 'counterparty'::text as entity_type,cp.id as entity_id,
    coalesce(nullif(cp.trading_name,''),cp.legal_name) as title,
    concat_ws(' · ',nullif(cp.country_of_incorporation,''),nullif(cp.headquarters,'')) as subtitle,
    concat_ws(' ',cp.legal_name,cp.trading_name,cp.website_domain,cp.registration_number,cp.country_of_incorporation,cp.headquarters) as search_text,
    false as protected_context,
    jsonb_build_object('legal_name',cp.legal_name,'trading_name',cp.trading_name,'country',cp.country_of_incorporation,'verification_status',cp.verification_status,'confidence_score',cp.confidence_score) as metadata
  from public.counterparties cp,params p
  where cp.organisation_id=p_organisation_id and 'counterparty'=any(p.types)

  union all
  select 'mine',m.id,m.name,
    concat_ws(' · ',nullif(m.nearest_town,''),nullif(m.province_state,''),nullif(m.country,'')),
    concat_ws(' ',m.name,m.nearest_town,m.province_state,m.country,m.public_location_reference,m.nearest_port),
    false,
    jsonb_build_object('mine_status',m.mine_status,'mine_type',m.mine_type,'country',m.country,'province_state',m.province_state,'nearest_town',m.nearest_town,'nearest_port',m.nearest_port,'rbct_access',m.rbct_access,'verification_status',m.verification_status)
  from public.mines m,params p
  where m.organisation_id=p_organisation_id and 'mine'=any(p.types)

  union all
  select 'laboratory',l.id,l.laboratory_name,
    concat_ws(' · ',nullif(l.city,''),nullif(l.province_state,''),nullif(l.country,'')),
    concat_ws(' ',l.laboratory_name,l.city,l.province_state,l.country,l.accreditation_body,l.accreditation_number),
    false,
    jsonb_build_object('city',l.city,'province_state',l.province_state,'country',l.country,'accreditation_body',l.accreditation_body,'accreditation_number',l.accreditation_number,'accreditation_expiry',l.accreditation_expiry,'verification_status',l.verification_status)
  from public.laboratories l,params p
  where l.organisation_id=p_organisation_id and 'laboratory'=any(p.types)

  union all
  select 'buyer_requirement',r.id,
    concat_ws(' — ',r.reference,coalesce(nullif(cp.trading_name,''),cp.legal_name)),
    concat_ws(' · ',c.name,pr.name,nullif(r.destination_country,''),nullif(r.destination_location,'')),
    concat_ws(' ',r.reference,cp.legal_name,cp.trading_name,c.name,pr.name,r.destination_country,r.destination_location),
    (lower(coalesce(r.protection_status,'')) in ('protected','active','verified','complete')),
    jsonb_build_object('reference',r.reference,'status',r.status,'priority',r.priority,'commodity',c.name,'product',pr.name,'destination_country',r.destination_country,'destination_location',r.destination_location,'valid_until',r.valid_until)
  from public.buyer_requirements r
  join public.counterparties cp on cp.organisation_id=r.organisation_id and cp.id=r.buyer_counterparty_id
  join public.commodities c on c.organisation_id=r.organisation_id and c.id=r.commodity_id
  left join public.commodity_products pr on pr.organisation_id=r.organisation_id and pr.id=r.product_id
  cross join params p
  where r.organisation_id=p_organisation_id and 'buyer_requirement'=any(p.types)

  union all
  select 'seller_offer',o.id,
    concat_ws(' — ',o.reference,coalesce(nullif(cp.trading_name,''),cp.legal_name)),
    concat_ws(' · ',c.name,pr.name,nullif(o.origin_country,''),nullif(o.public_origin_reference,'')),
    concat_ws(' ',o.reference,cp.legal_name,cp.trading_name,c.name,pr.name,o.origin_country,o.origin_province_state,o.public_origin_reference),
    o.is_protected,
    jsonb_build_object('reference',o.reference,'status',o.status,'commodity',c.name,'product',pr.name,'origin_country',o.origin_country,'public_origin_reference',o.public_origin_reference,'valid_until',o.valid_until,'authority_status',o.authority_status,'mandate_status',o.mandate_status)
  from public.seller_supply_offers o
  join public.counterparties cp on cp.organisation_id=o.organisation_id and cp.id=o.seller_counterparty_id
  join public.commodities c on c.organisation_id=o.organisation_id and c.id=o.commodity_id
  left join public.commodity_products pr on pr.organisation_id=o.organisation_id and pr.id=o.product_id
  cross join params p
  where o.organisation_id=p_organisation_id and 'seller_offer'=any(p.types)

  union all
  select 'opportunity',o.id,concat_ws(' — ',o.opportunity_number,o.title),
    concat_ws(' · ',c.name,pr.name,o.stage,o.status),
    concat_ws(' ',o.opportunity_number,o.title,c.name,pr.name,o.stage,o.status),
    o.is_protected,
    jsonb_build_object('opportunity_number',o.opportunity_number,'stage',o.stage,'status',o.status,'priority',o.priority,'commodity',c.name,'product',pr.name,'next_action_due_at',o.next_action_due_at)
  from public.opportunities o
  join public.commodities c on c.organisation_id=o.organisation_id and c.id=o.commodity_id
  left join public.commodity_products pr on pr.organisation_id=o.organisation_id and pr.id=o.product_id
  cross join params p
  where o.organisation_id=p_organisation_id and 'opportunity'=any(p.types)
), scored as (
  select c.*,
    case
      when lower(c.title)=p.q then 1.0000
      when lower(c.title) like p.q||'%' then 0.9500
      when lower(c.title) like '%'||p.q||'%' then 0.9000
      else greatest(0.0000,least(0.8900,extensions.similarity(lower(c.title),p.q)))
    end::numeric(5,4) as score
  from candidates c cross join params p
  where (p_include_protected or not c.protected_context)
    and (lower(c.search_text) like '%'||p.q||'%' or extensions.similarity(lower(c.title),p.q)>=0.15)
), ranked as (
  select row_number() over(order by score desc,title,entity_type)::integer as result_rank,
    entity_type,entity_id,title,subtitle,score as relevance_score,protected_context,metadata
  from scored
)
select result_rank,entity_type,entity_id,title,subtitle,relevance_score,protected_context,metadata
from ranked
order by result_rank
limit greatest(1,least(coalesce(p_limit,20),50));
$$;
revoke all on function private.mrcip_retrieval_candidates(uuid,text,text[],boolean,integer) from public,anon;
grant execute on function private.mrcip_retrieval_candidates(uuid,text,text[],boolean,integer) to authenticated;

create or replace function private.compute_mrcip_retrieval_request()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  normalized_types text[];
  invalid_type boolean:=false;
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance']) then
    raise exception 'MRCIP retrieval authority required';
  end if;
  if length(btrim(new.query_text))>500 then raise exception 'Retrieval query exceeds 500 characters'; end if;
  if length(btrim(new.purpose))>500 then raise exception 'Retrieval purpose exceeds 500 characters'; end if;
  if new.entity_types is null or cardinality(new.entity_types)=0 then
    new.entity_types:=array['counterparty','mine','laboratory','buyer_requirement','seller_offer','opportunity']::text[];
  end if;
  select exists(select 1 from unnest(new.entity_types) x where x not in ('counterparty','mine','laboratory','buyer_requirement','seller_offer','opportunity')) into invalid_type;
  if invalid_type then raise exception 'Unsupported retrieval entity type'; end if;
  select array_agg(distinct x order by x) into normalized_types from unnest(new.entity_types) x;
  new.entity_types:=normalized_types;
  if new.include_protected and not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']) then
    raise exception 'Protected intelligence retrieval requires privileged MRCIP authority';
  end if;
  new.max_results:=greatest(1,least(coalesce(new.max_results,20),50));
  new.algorithm_version:='mrcip-retrieval-v1';
  new.requested_by:=uid;
  new.requested_at:=now();
  new.status:='completed';
  new.error_message:='';
  new.completed_at:=now();
  select count(*) into new.result_count from private.mrcip_retrieval_candidates(new.organisation_id,new.query_text,new.entity_types,new.include_protected,new.max_results);
  return new;
end; $$;
revoke all on function private.compute_mrcip_retrieval_request() from public,anon,authenticated;
create trigger mrcip_retrieval_requests_compute_bi before insert on public.mrcip_retrieval_requests for each row execute function private.compute_mrcip_retrieval_request();

create policy mrcip_retrieval_requests_select on public.mrcip_retrieval_requests for select to authenticated using (
  private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])
  and (requested_by=(select auth.uid()) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance']))
  and ((not include_protected) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);
create policy mrcip_retrieval_requests_insert on public.mrcip_retrieval_requests for insert to authenticated with check (
  requested_by=(select auth.uid())
  and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])
  and ((not include_protected) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);

revoke all on public.mrcip_retrieval_requests from anon,authenticated;
grant select,insert on public.mrcip_retrieval_requests to authenticated;

create or replace function public.search_mrcip_intelligence(
  p_organisation_id uuid,
  p_query text,
  p_purpose text,
  p_entity_types text[] default null,
  p_include_protected boolean default false,
  p_limit integer default 20
)
returns table(
  request_id uuid,
  result_rank integer,
  entity_type text,
  entity_id uuid,
  title text,
  subtitle text,
  relevance_score numeric,
  protected_context boolean,
  metadata jsonb
)
language plpgsql
security invoker
set search_path=''
as $$
declare
  req public.mrcip_retrieval_requests%rowtype;
begin
  insert into public.mrcip_retrieval_requests(organisation_id,query_text,purpose,entity_types,include_protected,max_results,requested_by)
  values(p_organisation_id,p_query,p_purpose,coalesce(p_entity_types,array['counterparty','mine','laboratory','buyer_requirement','seller_offer','opportunity']::text[]),coalesce(p_include_protected,false),coalesce(p_limit,20),(select auth.uid()))
  returning * into req;
  return query
  select req.id,c.result_rank,c.entity_type,c.entity_id,c.title,c.subtitle,c.relevance_score,c.protected_context,c.metadata
  from private.mrcip_retrieval_candidates(req.organisation_id,req.query_text,req.entity_types,req.include_protected,req.max_results) c;
end; $$;
revoke all on function public.search_mrcip_intelligence(uuid,text,text,text[],boolean,integer) from public,anon;
grant execute on function public.search_mrcip_intelligence(uuid,text,text,text[],boolean,integer) to authenticated;

create or replace view public.mrcip_retrieval_audit_summary with (security_invoker=true) as
select organisation_id,id as request_id,query_text,purpose,entity_types,include_protected,max_results,status,result_count,algorithm_version,requested_at,requested_by,completed_at
from public.mrcip_retrieval_requests;
revoke all on public.mrcip_retrieval_audit_summary from public,anon,authenticated;
grant select on public.mrcip_retrieval_audit_summary to authenticated;