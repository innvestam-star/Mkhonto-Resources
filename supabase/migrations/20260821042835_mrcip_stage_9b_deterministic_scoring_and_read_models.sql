create or replace function private.guard_mrcip_data_quality_issue()
returns trigger language plpgsql security definer set search_path=''
as $$
declare offe public.seller_supply_offers%rowtype; opp public.opportunities%rowtype; doc public.documents%rowtype;
begin
  if new.entity_type='seller_offer' then
    select * into offe from public.seller_supply_offers where organisation_id=new.organisation_id and id=new.seller_offer_id;
    if not found then raise exception 'Data-quality seller offer not found'; end if;
    new.protected_context:=coalesce(new.protected_context,false) or offe.is_protected;
  elsif new.entity_type='opportunity' then
    select * into opp from public.opportunities where organisation_id=new.organisation_id and id=new.opportunity_id;
    if not found then raise exception 'Data-quality opportunity not found'; end if;
    new.protected_context:=coalesce(new.protected_context,false) or opp.is_protected;
  end if;
  if new.evidence_document_id is not null and new.protected_context then
    select * into doc from public.documents where organisation_id=new.organisation_id and id=new.evidence_document_id;
    if not found or doc.category<>'mrcip_protected' then raise exception 'Protected data-quality evidence must use an mrcip_protected document'; end if;
  end if;
  if new.status='waived' and btrim(new.waiver_reason)='' then raise exception 'Waived data-quality issue requires a waiver reason'; end if;
  if new.status='resolved' and new.resolved_at is null then new.resolved_at:=now(); new.resolved_by:=(select auth.uid()); end if;
  if new.status='open' then new.resolved_at:=null; new.resolved_by:=null; end if;
  new.updated_at:=now(); new.updated_by:=coalesce((select auth.uid()),new.updated_by);
  return new;
end; $$;
revoke all on function private.guard_mrcip_data_quality_issue() from public,anon,authenticated;
create trigger mrcip_data_quality_issues_guard_biu before insert or update on public.mrcip_data_quality_issues for each row execute function private.guard_mrcip_data_quality_issue();

create or replace function private.upsert_counterparty_quality_issue(p_organisation_id uuid,p_counterparty_id uuid,p_issue_suffix text,p_dimension text,p_severity text,p_message text,p_remediation text,p_algorithm_version text)
returns text language plpgsql security definer set search_path=''
as $$
declare k text;
begin
  k:='counterparty:'||p_counterparty_id::text||':'||p_issue_suffix;
  insert into public.mrcip_data_quality_issues(organisation_id,issue_key,entity_type,counterparty_id,dimension,severity,status,message,remediation,auto_generated,algorithm_version,detected_at,last_seen_at,created_by,updated_by)
  values(p_organisation_id,k,'counterparty',p_counterparty_id,p_dimension,p_severity,'open',p_message,p_remediation,true,p_algorithm_version,now(),now(),coalesce((select auth.uid()),'00000000-0000-0000-0000-000000000000'::uuid),coalesce((select auth.uid()),'00000000-0000-0000-0000-000000000000'::uuid))
  on conflict (organisation_id,issue_key) do update
  set dimension=excluded.dimension,severity=excluded.severity,message=excluded.message,remediation=excluded.remediation,last_seen_at=now(),algorithm_version=excluded.algorithm_version,
      status=case when public.mrcip_data_quality_issues.status='resolved' then 'open' else public.mrcip_data_quality_issues.status end,
      resolved_at=case when public.mrcip_data_quality_issues.status='resolved' then null else public.mrcip_data_quality_issues.resolved_at end,
      resolved_by=case when public.mrcip_data_quality_issues.status='resolved' then null else public.mrcip_data_quality_issues.resolved_by end,
      updated_at=now(),updated_by=coalesce((select auth.uid()),public.mrcip_data_quality_issues.updated_by);
  return k;
end; $$;
revoke all on function private.upsert_counterparty_quality_issue(uuid,uuid,text,text,text,text,text,text) from public,anon,authenticated;

create or replace function private.compute_counterparty_quality_snapshot()
returns trigger language plpgsql security definer set search_path=''
as $$
declare
  cp public.counterparties%rowtype;
  contact_count int:=0; verified_contact_count int:=0; role_count int:=0; commodity_count int:=0; source_count int:=0;
  identity_penalty numeric:=0; contact_penalty numeric:=0; provenance_penalty numeric:=0; verification_penalty numeric:=0; market_penalty numeric:=0; total_penalty numeric:=0;
  detected text[]:=array[]::text[]; k text; score_v numeric;
begin
  select * into cp from public.counterparties where organisation_id=new.organisation_id and id=new.counterparty_id;
  if not found then raise exception 'Counterparty not found for quality scoring'; end if;
  select count(*),count(*) filter(where lower(verification_status)='verified') into contact_count,verified_contact_count from public.counterparty_contacts where organisation_id=new.organisation_id and counterparty_id=new.counterparty_id;
  select count(*) into role_count from public.counterparty_role_assignments where organisation_id=new.organisation_id and counterparty_id=new.counterparty_id and active;
  select count(*) into commodity_count from public.counterparty_commodities where organisation_id=new.organisation_id and counterparty_id=new.counterparty_id and active;
  select count(*) into source_count from public.intelligence_sources where organisation_id=new.organisation_id and counterparty_id=new.counterparty_id;

  if btrim(cp.registration_number)='' then identity_penalty:=identity_penalty+15; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'registration_missing','identity','high','Registration number is missing','Verify and record the legal registration number',new.algorithm_version); detected:=array_append(detected,k); end if;
  if btrim(cp.country_of_incorporation)='' and btrim(cp.headquarters)='' then identity_penalty:=identity_penalty+5; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'location_missing','identity','medium','Country of incorporation and headquarters are missing','Record an evidence-backed incorporation country or headquarters',new.algorithm_version); detected:=array_append(detected,k); end if;
  if btrim(cp.website)='' and btrim(cp.website_domain)='' then identity_penalty:=identity_penalty+5; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'website_missing','identity','low','Website/domain is missing','Record a verified corporate website or domain when available',new.algorithm_version); detected:=array_append(detected,k); end if;

  if contact_count=0 then contact_penalty:=15; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'contact_missing','contact','high','No counterparty contact is recorded','Add at least one evidence-backed contact',new.algorithm_version); detected:=array_append(detected,k);
  elsif verified_contact_count=0 then contact_penalty:=7; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'verified_contact_missing','contact','medium','No verified counterparty contact is recorded','Verify at least one relevant contact',new.algorithm_version); detected:=array_append(detected,k); end if;

  if source_count=0 then provenance_penalty:=15; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'provenance_missing','provenance','high','No intelligence source/provenance is linked','Attach a source record with verification metadata',new.algorithm_version); detected:=array_append(detected,k); end if;

  if lower(cp.verification_status)<>'verified' then verification_penalty:=verification_penalty+10; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'verification_incomplete','verification','high','Counterparty verification is not complete','Complete evidence-backed counterparty verification',new.algorithm_version); detected:=array_append(detected,k); end if;
  if cp.last_verified_at is null or cp.last_verified_at < now()-interval '180 days' then verification_penalty:=verification_penalty+10; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'verification_stale','verification','medium','Counterparty verification is missing or older than 180 days','Refresh the verification record and evidence',new.algorithm_version); detected:=array_append(detected,k); end if;

  if role_count=0 then market_penalty:=market_penalty+10; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'role_missing','commercial','medium','No counterparty market role is assigned','Assign one or more verified buyer/seller/producer/trader/lab/logistics roles',new.algorithm_version); detected:=array_append(detected,k); end if;
  if commodity_count=0 then market_penalty:=market_penalty+10; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'commodity_relationship_missing','commercial','medium','No commodity relationship is recorded','Link the counterparty to relevant commodities/products',new.algorithm_version); detected:=array_append(detected,k); end if;

  update public.mrcip_data_quality_issues q set status='resolved',resolved_at=now(),resolved_by=coalesce((select auth.uid()),q.updated_by),updated_at=now(),updated_by=coalesce((select auth.uid()),q.updated_by)
  where q.organisation_id=new.organisation_id and q.entity_type='counterparty' and q.counterparty_id=new.counterparty_id and q.auto_generated and q.algorithm_version=new.algorithm_version and q.status='open' and not (q.issue_key=any(detected));

  total_penalty:=least(100,identity_penalty+contact_penalty+provenance_penalty+verification_penalty+market_penalty);
  score_v:=greatest(0,100-total_penalty);
  new.score:=round(score_v,2);
  new.grade:=case when score_v>=90 then 'A' when score_v>=80 then 'B' when score_v>=65 then 'C' when score_v>=50 then 'D' else 'E' end;
  new.components:=jsonb_build_object(
    'identity',jsonb_build_object('penalty',identity_penalty,'registration_present',btrim(cp.registration_number)<>'','location_present',(btrim(cp.country_of_incorporation)<>'' or btrim(cp.headquarters)<>''),'website_present',(btrim(cp.website)<>'' or btrim(cp.website_domain)<>'')),
    'contacts',jsonb_build_object('penalty',contact_penalty,'contact_count',contact_count,'verified_contact_count',verified_contact_count),
    'provenance',jsonb_build_object('penalty',provenance_penalty,'source_count',source_count),
    'verification',jsonb_build_object('penalty',verification_penalty,'status',cp.verification_status,'last_verified_at',cp.last_verified_at),
    'market_profile',jsonb_build_object('penalty',market_penalty,'role_count',role_count,'commodity_relationship_count',commodity_count),
    'total_penalty',total_penalty
  );
  select count(*) into new.open_issue_count from public.mrcip_data_quality_issues where organisation_id=new.organisation_id and entity_type='counterparty' and counterparty_id=new.counterparty_id and status='open';
  new.algorithm_version:='counterparty-quality-v1'; new.generated_at:=now(); new.generated_by:=coalesce((select auth.uid()),new.generated_by);
  return new;
end; $$;
revoke all on function private.compute_counterparty_quality_snapshot() from public,anon,authenticated;
create trigger counterparty_quality_snapshots_compute_bi before insert on public.counterparty_quality_snapshots for each row execute function private.compute_counterparty_quality_snapshot();

create or replace function private.guard_counterparty_risk_flag()
returns trigger language plpgsql security definer set search_path=''
as $$
declare doc public.documents%rowtype;
begin
  new.protected_context:=true;
  if new.evidence_document_id is not null then
    select * into doc from public.documents where organisation_id=new.organisation_id and id=new.evidence_document_id;
    if not found or doc.category<>'mrcip_protected' then raise exception 'Risk-flag evidence must use an mrcip_protected document'; end if;
  end if;
  if tg_op='UPDATE' then
    if old.organisation_id<>new.organisation_id or old.counterparty_id<>new.counterparty_id or old.category<>new.category or old.severity<>new.severity or old.title<>new.title or old.description<>new.description or old.source_id is distinct from new.source_id or old.evidence_document_id is distinct from new.evidence_document_id or old.flagged_at<>new.flagged_at or old.flagged_by<>new.flagged_by then
      raise exception 'Risk flag identity/evidence is immutable; create a new flag for corrected evidence';
    end if;
    if old.status in ('resolved','false_positive') and new.status<>old.status then raise exception 'Closed risk flags cannot be reopened'; end if;
  end if;
  if new.status in ('resolved','false_positive') and new.resolved_at is null then new.resolved_at:=now(); new.resolved_by:=(select auth.uid()); end if;
  new.updated_at:=now(); new.updated_by:=coalesce((select auth.uid()),new.updated_by);
  return new;
end; $$;
revoke all on function private.guard_counterparty_risk_flag() from public,anon,authenticated;
create trigger counterparty_risk_flags_guard_biu before insert or update on public.counterparty_risk_flags for each row execute function private.guard_counterparty_risk_flag();

create or replace function private.audit_counterparty_risk_flag()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  insert into public.audit_events(organisation_id,entity_type,entity_id,action,summary,metadata,actor_id)
  values(new.organisation_id,'counterparty_risk_flag',new.id,case when tg_op='INSERT' then 'risk_flag_created' else 'risk_flag_status_changed' end,'Counterparty risk flag recorded or changed',jsonb_build_object('counterparty_id',new.counterparty_id,'category',new.category,'severity',new.severity,'status',new.status),coalesce((select auth.uid()),new.updated_by));
  return new;
end; $$;
revoke all on function private.audit_counterparty_risk_flag() from public,anon,authenticated;
create trigger counterparty_risk_flags_audit_aiu after insert or update of status on public.counterparty_risk_flags for each row execute function private.audit_counterparty_risk_flag();

create or replace function private.compute_counterparty_risk_snapshot()
returns trigger language plpgsql security definer set search_path=''
as $$
declare cp public.counterparties%rowtype; verification_points numeric:=0; confidence_points numeric:=0; identity_points numeric:=0; recency_points numeric:=0; flag_points numeric:=0; total numeric:=0; flag_json jsonb:='[]'::jsonb;
begin
  select * into cp from public.counterparties where organisation_id=new.organisation_id and id=new.counterparty_id;
  if not found then raise exception 'Counterparty not found for risk scoring'; end if;
  verification_points:=case lower(cp.verification_status) when 'verified' then 0 when 'failed' then 40 when 'rejected' then 40 when 'pending' then 10 else 15 end;
  confidence_points:=case when cp.confidence_score<40 then 25 when cp.confidence_score<60 then 15 when cp.confidence_score<80 then 5 else 0 end;
  identity_points:=case when btrim(cp.registration_number)='' then 10 else 0 end;
  recency_points:=case when cp.last_verified_at is null or cp.last_verified_at<now()-interval '180 days' then 10 else 0 end;
  select coalesce(sum(case status when 'open' then case severity when 'low' then 5 when 'medium' then 15 when 'high' then 30 else 50 end when 'mitigated' then case severity when 'low' then 2.5 when 'medium' then 7.5 when 'high' then 15 else 25 end else 0 end),0),
         coalesce(jsonb_agg(jsonb_build_object('id',id,'category',category,'severity',severity,'status',status,'points',case status when 'open' then case severity when 'low' then 5 when 'medium' then 15 when 'high' then 30 else 50 end when 'mitigated' then case severity when 'low' then 2.5 when 'medium' then 7.5 when 'high' then 15 else 25 end else 0 end) order by flagged_at) filter(where status in ('open','mitigated')),'[]'::jsonb)
  into flag_points,flag_json from public.counterparty_risk_flags where organisation_id=new.organisation_id and counterparty_id=new.counterparty_id;
  flag_points:=least(70,flag_points);
  total:=least(100,verification_points+confidence_points+identity_points+recency_points+flag_points);
  new.risk_score:=round(total,2);
  new.risk_band:=case when total<20 then 'low' when total<45 then 'moderate' when total<70 then 'high' else 'critical' end;
  new.baseline_components:=jsonb_build_object('verification_points',verification_points,'confidence_points',confidence_points,'identity_points',identity_points,'verification_recency_points',recency_points,'counterparty_verification_status',cp.verification_status,'confidence_score',cp.confidence_score,'last_verified_at',cp.last_verified_at);
  new.flag_components:=flag_json;
  select count(*) into new.open_flag_count from public.counterparty_risk_flags where organisation_id=new.organisation_id and counterparty_id=new.counterparty_id and status in ('open','mitigated');
  new.protected_context:=true; new.algorithm_version:='counterparty-risk-v1'; new.generated_at:=now(); new.generated_by:=coalesce((select auth.uid()),new.generated_by);
  return new;
end; $$;
revoke all on function private.compute_counterparty_risk_snapshot() from public,anon,authenticated;
create trigger counterparty_risk_snapshots_compute_bi before insert on public.counterparty_risk_snapshots for each row execute function private.compute_counterparty_risk_snapshot();

create or replace function private.compute_opportunity_score_snapshot()
returns trigger language plpgsql security definer set search_path=''
as $$
declare
  opp public.opportunities%rowtype; mt public.commodity_matches%rowtype; req public.buyer_requirements%rowtype; offe public.seller_supply_offers%rowtype; proto public.opportunity_protocol_controls%rowtype;
  bq public.counterparty_quality_snapshots%rowtype; sq public.counterparty_quality_snapshots%rowtype; br public.counterparty_risk_snapshots%rowtype; sr public.counterparty_risk_snapshots%rowtype;
  kyc public.opportunity_kyc_cases%rowtype;
  mscore numeric:=0; bscore numeric:=0; sscore numeric:=0; pscore numeric:=0; escore numeric:=0; lscore numeric:=0; cscore numeric:=0; rpen numeric:=0; total numeric:=0;
  cert_ok boolean:=false; inspection_ok boolean:=false; freight_ok boolean:=false; negotiation_ok boolean:=false; finance_ok boolean:=false;
begin
  select * into opp from public.opportunities where organisation_id=new.organisation_id and id=new.opportunity_id;
  if not found then raise exception 'Opportunity not found for scoring'; end if;
  select * into mt from public.commodity_matches where organisation_id=new.organisation_id and id=opp.match_id;
  select * into req from public.buyer_requirements where organisation_id=new.organisation_id and id=opp.buyer_requirement_id;
  select * into offe from public.seller_supply_offers where organisation_id=new.organisation_id and id=opp.seller_offer_id;
  select * into proto from public.opportunity_protocol_controls where organisation_id=new.organisation_id and opportunity_id=opp.id;

  if new.buyer_quality_snapshot_id is null then select id into new.buyer_quality_snapshot_id from public.counterparty_quality_snapshots where organisation_id=new.organisation_id and counterparty_id=opp.buyer_counterparty_id order by generated_at desc limit 1; end if;
  if new.seller_quality_snapshot_id is null then select id into new.seller_quality_snapshot_id from public.counterparty_quality_snapshots where organisation_id=new.organisation_id and counterparty_id=opp.seller_counterparty_id order by generated_at desc limit 1; end if;
  if new.buyer_risk_snapshot_id is null then select id into new.buyer_risk_snapshot_id from public.counterparty_risk_snapshots where organisation_id=new.organisation_id and counterparty_id=opp.buyer_counterparty_id order by generated_at desc limit 1; end if;
  if new.seller_risk_snapshot_id is null then select id into new.seller_risk_snapshot_id from public.counterparty_risk_snapshots where organisation_id=new.organisation_id and counterparty_id=opp.seller_counterparty_id order by generated_at desc limit 1; end if;
  if new.buyer_quality_snapshot_id is null or new.seller_quality_snapshot_id is null or new.buyer_risk_snapshot_id is null or new.seller_risk_snapshot_id is null then raise exception 'Refresh buyer and seller quality/risk snapshots before scoring the opportunity'; end if;
  select * into bq from public.counterparty_quality_snapshots where organisation_id=new.organisation_id and id=new.buyer_quality_snapshot_id;
  select * into sq from public.counterparty_quality_snapshots where organisation_id=new.organisation_id and id=new.seller_quality_snapshot_id;
  select * into br from public.counterparty_risk_snapshots where organisation_id=new.organisation_id and id=new.buyer_risk_snapshot_id;
  select * into sr from public.counterparty_risk_snapshots where organisation_id=new.organisation_id and id=new.seller_risk_snapshot_id;
  if bq.counterparty_id<>opp.buyer_counterparty_id or sq.counterparty_id<>opp.seller_counterparty_id or br.counterparty_id<>opp.buyer_counterparty_id or sr.counterparty_id<>opp.seller_counterparty_id then raise exception 'Opportunity score snapshot references must match opportunity buyer/seller identities'; end if;

  mscore:=round(coalesce(mt.total_score,0)*0.30,2);
  select * into kyc from public.opportunity_kyc_cases where organisation_id=new.organisation_id and opportunity_id=opp.id and party_role='buyer' order by created_at desc limit 1;
  if found then
    bscore:=bscore+(case when lower(kyc.status)='verified' then 5 else 0 end)+(case when kyc.registration_verified then 2 else 0 end)+(case when kyc.authority_verified then 3 else 0 end)+(case when lower(kyc.sanctions_screening_status)='clear' then 2 else 0 end)+(case when lower(kyc.pep_screening_status) in ('clear','not_applicable') then 1 else 0 end)+(case when lower(kyc.capability_evidence_status) in ('verified','satisfactory','provided') then 2 else 0 end);
  end if;
  bscore:=least(15,bscore);

  sscore:=sscore+(case when lower(offe.authority_status) in ('verified','confirmed','authorised','authorized') then 5 else 0 end)+(case when lower(offe.mandate_status) in ('verified','active','executed','confirmed') then 5 else 0 end)+(case when lower(offe.protection_status) in ('protected','verified','active','complete') then 3 else 0 end)+(case when offe.source_id is not null then 2 else 0 end);
  sscore:=least(15,sscore);

  pscore:=case lower(coalesce(proto.protocol_step,'protect')) when 'contract' then 15 when 'disclose' then 11 when 'verify' then 7 else 3 end;
  if coalesce(proto.disclosure_eligible,false) and pscore<15 then pscore:=least(15,pscore+1); end if;

  select exists(select 1 from public.laboratory_certificates c join public.laboratory_test_orders o on o.organisation_id=c.organisation_id and o.id=c.order_id join public.commodity_sampling_requests r on r.organisation_id=o.organisation_id and r.id=o.request_id where c.organisation_id=new.organisation_id and c.verified_at is not null and (r.opportunity_id=opp.id or r.seller_offer_id=opp.seller_offer_id)) into cert_ok;
  select exists(select 1 from public.commodity_inspections i join public.commodity_sampling_requests r on r.organisation_id=i.organisation_id and r.id=i.request_id where i.organisation_id=new.organisation_id and i.verified_at is not null and (r.opportunity_id=opp.id or r.seller_offer_id=opp.seller_offer_id)) into inspection_ok;
  escore:=(case when cert_ok then 5 else 0 end)+(case when inspection_ok then 5 else 0 end);

  select exists(select 1 from public.opportunity_freight_links where organisation_id=new.organisation_id and opportunity_id=opp.id) into freight_ok;
  lscore:=(case when btrim(req.destination_location)<>'' then 1 else 0 end)+(case when btrim(offe.loading_location)<>'' then 1 else 0 end)+(case when btrim(req.transport_mode)<>'' and btrim(offe.transport_mode)<>'' then 1 else 0 end)+(case when freight_ok then 2 else 0 end);
  lscore:=least(5,lscore);

  select exists(select 1 from public.opportunity_negotiation_links where organisation_id=new.organisation_id and opportunity_id=opp.id) into negotiation_ok;
  select exists(select 1 from public.opportunity_finance_links where organisation_id=new.organisation_id and opportunity_id=opp.id) into finance_ok;
  cscore:=(case when btrim(req.payment_terms)<>'' or btrim(req.payment_instrument)<>'' then 2 else 0 end)+(case when btrim(offe.payment_terms)<>'' or btrim(offe.payment_instrument)<>'' then 2 else 0 end)+(case when negotiation_ok then 3 else 0 end)+(case when finance_ok then 3 else 0 end);
  cscore:=least(10,cscore);

  rpen:=round(greatest(br.risk_score,sr.risk_score)*0.15,2);
  total:=greatest(0,least(100,mscore+bscore+sscore+pscore+escore+lscore+cscore-rpen));
  new.match_score:=mscore; new.buyer_readiness_score:=bscore; new.seller_readiness_score:=sscore; new.protocol_score:=pscore; new.evidence_score:=escore; new.logistics_score:=lscore; new.commercial_score:=cscore; new.risk_penalty:=rpen; new.total_score:=round(total,2);
  new.readiness_band:=case when total>=80 then 'high' when total>=65 then 'strong' when total>=50 then 'developing' else 'early' end;
  new.protected_context:=true;
  new.algorithm_version:='opportunity-readiness-v1'; new.generated_at:=now(); new.generated_by:=coalesce((select auth.uid()),new.generated_by);
  new.explanation:=jsonb_build_object('formula','match(30)+buyer(15)+seller(15)+protocol(15)+evidence(10)+logistics(5)+commercial(10)-risk_penalty(15 max)','match_source_score',coalesce(mt.total_score,0),'buyer_quality_score',bq.score,'seller_quality_score',sq.score,'buyer_risk_score',br.risk_score,'seller_risk_score',sr.risk_score,'certificate_verified',cert_ok,'inspection_verified',inspection_ok,'freight_linked',freight_ok,'negotiation_linked',negotiation_ok,'finance_linked',finance_ok,'component_scores',jsonb_build_object('match',mscore,'buyer_readiness',bscore,'seller_readiness',sscore,'protocol',pscore,'evidence',escore,'logistics',lscore,'commercial',cscore,'risk_penalty',rpen));
  return new;
end; $$;
revoke all on function private.compute_opportunity_score_snapshot() from public,anon,authenticated;
create trigger opportunity_score_snapshots_compute_bi before insert on public.opportunity_score_snapshots for each row execute function private.compute_opportunity_score_snapshot();

create or replace function public.refresh_counterparty_quality(p_counterparty_id uuid)
returns uuid language plpgsql security invoker set search_path=''
as $$ declare cp public.counterparties%rowtype; sid uuid; begin
  select * into cp from public.counterparties where id=p_counterparty_id;
  if not found then raise exception 'Counterparty not found or not accessible'; end if;
  insert into public.counterparty_quality_snapshots(organisation_id,counterparty_id,generated_by) values(cp.organisation_id,cp.id,(select auth.uid())) returning id into sid;
  return sid;
end; $$;
revoke all on function public.refresh_counterparty_quality(uuid) from public,anon; grant execute on function public.refresh_counterparty_quality(uuid) to authenticated;

create or replace function public.refresh_counterparty_risk(p_counterparty_id uuid)
returns uuid language plpgsql security invoker set search_path=''
as $$ declare cp public.counterparties%rowtype; sid uuid; begin
  select * into cp from public.counterparties where id=p_counterparty_id;
  if not found then raise exception 'Counterparty not found or not accessible'; end if;
  insert into public.counterparty_risk_snapshots(organisation_id,counterparty_id,generated_by) values(cp.organisation_id,cp.id,(select auth.uid())) returning id into sid;
  return sid;
end; $$;
revoke all on function public.refresh_counterparty_risk(uuid) from public,anon; grant execute on function public.refresh_counterparty_risk(uuid) to authenticated;

create or replace function public.refresh_opportunity_score(p_opportunity_id uuid)
returns uuid language plpgsql security invoker set search_path=''
as $$ declare opp public.opportunities%rowtype; bq uuid; sq uuid; br uuid; sr uuid; sid uuid; begin
  select * into opp from public.opportunities where id=p_opportunity_id;
  if not found then raise exception 'Opportunity not found or not accessible'; end if;
  bq:=public.refresh_counterparty_quality(opp.buyer_counterparty_id); sq:=public.refresh_counterparty_quality(opp.seller_counterparty_id);
  br:=public.refresh_counterparty_risk(opp.buyer_counterparty_id); sr:=public.refresh_counterparty_risk(opp.seller_counterparty_id);
  insert into public.opportunity_score_snapshots(organisation_id,opportunity_id,buyer_quality_snapshot_id,seller_quality_snapshot_id,buyer_risk_snapshot_id,seller_risk_snapshot_id,generated_by)
  values(opp.organisation_id,opp.id,bq,sq,br,sr,(select auth.uid())) returning id into sid;
  return sid;
end; $$;
revoke all on function public.refresh_opportunity_score(uuid) from public,anon; grant execute on function public.refresh_opportunity_score(uuid) to authenticated;

create policy mrcip_data_quality_issues_select on public.mrcip_data_quality_issues for select to authenticated using (((not protected_context) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']));
create policy mrcip_data_quality_issues_update on public.mrcip_data_quality_issues for update to authenticated using (((not protected_context) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])) with check (updated_by=(select auth.uid()) and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));

create policy counterparty_risk_flags_select on public.counterparty_risk_flags for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']));
create policy counterparty_risk_flags_insert on public.counterparty_risk_flags for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']) and flagged_by=(select auth.uid()) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy counterparty_risk_flags_update on public.counterparty_risk_flags for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])) with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']) and updated_by=(select auth.uid()));

create policy counterparty_quality_snapshots_select on public.counterparty_quality_snapshots for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance']));
create policy counterparty_quality_snapshots_insert on public.counterparty_quality_snapshots for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance']) and generated_by=(select auth.uid()));

create policy counterparty_risk_snapshots_select on public.counterparty_risk_snapshots for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']));
create policy counterparty_risk_snapshots_insert on public.counterparty_risk_snapshots for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']) and generated_by=(select auth.uid()));

create policy opportunity_score_snapshots_select on public.opportunity_score_snapshots for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']));
create policy opportunity_score_snapshots_insert on public.opportunity_score_snapshots for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']) and generated_by=(select auth.uid()));

revoke all on public.mrcip_data_quality_issues,public.counterparty_risk_flags,public.counterparty_quality_snapshots,public.counterparty_risk_snapshots,public.opportunity_score_snapshots from anon,authenticated;
grant select,update on public.mrcip_data_quality_issues to authenticated;
grant select,insert,update on public.counterparty_risk_flags to authenticated;
grant select,insert on public.counterparty_quality_snapshots to authenticated;
grant select,insert on public.counterparty_risk_snapshots to authenticated;
grant select,insert on public.opportunity_score_snapshots to authenticated;

create or replace view public.mrcip_counterparty_operational_summary with (security_invoker=true) as
select cp.organisation_id,cp.id as counterparty_id,cp.legal_name,cp.trading_name,cp.company_status,cp.verification_status,cp.confidence_score,cp.last_verified_at,
  coalesce((select array_agg(distinct cra.role_key order by cra.role_key) from public.counterparty_role_assignments cra where cra.organisation_id=cp.organisation_id and cra.counterparty_id=cp.id and cra.active),array[]::text[]) as roles,
  coalesce((select count(*) from public.counterparty_contacts c where c.organisation_id=cp.organisation_id and c.counterparty_id=cp.id),0) as contact_count,
  coalesce((select count(*) from public.counterparty_commodities cc where cc.organisation_id=cp.organisation_id and cc.counterparty_id=cp.id and cc.active),0) as commodity_relationship_count,
  q.score as quality_score,q.grade as quality_grade,q.open_issue_count,
  r.risk_score,r.risk_band,r.open_flag_count,
  coalesce((select count(*) from public.crm_tasks t where t.organisation_id=cp.organisation_id and t.counterparty_id=cp.id and t.status in ('open','in_progress')),0) as open_task_count,
  (select min(t.due_at) from public.crm_tasks t where t.organisation_id=cp.organisation_id and t.counterparty_id=cp.id and t.status in ('open','in_progress') and t.due_at is not null) as next_task_due_at,
  (select max(a.occurred_at) from public.crm_activities a where a.organisation_id=cp.organisation_id and a.counterparty_id=cp.id) as last_activity_at
from public.counterparties cp
left join lateral (select s.score,s.grade,s.open_issue_count from public.counterparty_quality_snapshots s where s.organisation_id=cp.organisation_id and s.counterparty_id=cp.id order by s.generated_at desc limit 1) q on true
left join lateral (select s.risk_score,s.risk_band,s.open_flag_count from public.counterparty_risk_snapshots s where s.organisation_id=cp.organisation_id and s.counterparty_id=cp.id order by s.generated_at desc limit 1) r on true;
revoke all on public.mrcip_counterparty_operational_summary from public,anon,authenticated; grant select on public.mrcip_counterparty_operational_summary to authenticated;

create or replace view public.mrcip_opportunity_operational_summary with (security_invoker=true) as
select o.organisation_id,o.id as opportunity_id,o.opportunity_number,o.title,o.stage,o.status,o.priority,o.is_protected,o.disclosure_locked,o.buyer_counterparty_id,o.seller_counterparty_id,o.commodity_id,o.product_id,
  c.name as commodity_name,p.name as product_name,m.total_score as match_total_score,m.status as match_status,
  pc.protocol_step,pc.protection_status,pc.verification_status as protocol_verification_status,pc.disclosure_eligible,pc.disclosure_status,pc.contract_status,
  s.total_score as readiness_score,s.readiness_band,s.risk_penalty,s.generated_at as score_generated_at,
  coalesce((select count(*) from public.crm_tasks t where t.organisation_id=o.organisation_id and t.opportunity_id=o.id and t.status in ('open','in_progress')),0) as open_task_count,
  (select min(t.due_at) from public.crm_tasks t where t.organisation_id=o.organisation_id and t.opportunity_id=o.id and t.status in ('open','in_progress') and t.due_at is not null) as next_task_due_at,
  (select max(a.occurred_at) from public.crm_activities a where a.organisation_id=o.organisation_id and a.opportunity_id=o.id) as last_activity_at,
  o.next_action,o.next_action_due_at,o.relationship_owner,o.updated_at
from public.opportunities o
join public.commodities c on c.organisation_id=o.organisation_id and c.id=o.commodity_id
left join public.commodity_products p on p.organisation_id=o.organisation_id and p.id=o.product_id
left join public.commodity_matches m on m.organisation_id=o.organisation_id and m.id=o.match_id
left join public.opportunity_protocol_controls pc on pc.organisation_id=o.organisation_id and pc.opportunity_id=o.id
left join lateral (select x.total_score,x.readiness_band,x.risk_penalty,x.generated_at from public.opportunity_score_snapshots x where x.organisation_id=o.organisation_id and x.opportunity_id=o.id order by x.generated_at desc limit 1) s on true;
revoke all on public.mrcip_opportunity_operational_summary from public,anon,authenticated; grant select on public.mrcip_opportunity_operational_summary to authenticated;

create or replace view public.mrcip_pipeline_operational_summary with (security_invoker=true) as
select o.organisation_id,o.commodity_id,c.name as commodity_name,o.stage,o.status,count(*) as opportunity_count,
  round(avg(s.total_score),2) as average_readiness_score,
  count(*) filter(where pc.disclosure_eligible) as disclosure_eligible_count,
  count(*) filter(where o.next_action_due_at is not null and o.next_action_due_at<now()) as overdue_next_action_count
from public.opportunities o
join public.commodities c on c.organisation_id=o.organisation_id and c.id=o.commodity_id
left join public.opportunity_protocol_controls pc on pc.organisation_id=o.organisation_id and pc.opportunity_id=o.id
left join lateral (select x.total_score from public.opportunity_score_snapshots x where x.organisation_id=o.organisation_id and x.opportunity_id=o.id order by x.generated_at desc limit 1) s on true
group by o.organisation_id,o.commodity_id,c.name,o.stage,o.status;
revoke all on public.mrcip_pipeline_operational_summary from public,anon,authenticated; grant select on public.mrcip_pipeline_operational_summary to authenticated;