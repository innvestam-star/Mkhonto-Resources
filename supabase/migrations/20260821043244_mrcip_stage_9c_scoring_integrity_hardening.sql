create or replace function private.guard_mrcip_data_quality_issue()
returns trigger language plpgsql security definer set search_path=''
as $$
declare offe public.seller_supply_offers%rowtype; opp public.opportunities%rowtype; doc public.documents%rowtype;
begin
  if tg_op='UPDATE' and old.auto_generated then
    if old.organisation_id<>new.organisation_id or old.issue_key<>new.issue_key or old.entity_type<>new.entity_type or old.counterparty_id is distinct from new.counterparty_id or old.mine_id is distinct from new.mine_id or old.laboratory_id is distinct from new.laboratory_id or old.buyer_requirement_id is distinct from new.buyer_requirement_id or old.seller_offer_id is distinct from new.seller_offer_id or old.opportunity_id is distinct from new.opportunity_id or old.dimension<>new.dimension or old.severity<>new.severity or old.message<>new.message or old.remediation<>new.remediation or old.auto_generated<>new.auto_generated or old.algorithm_version<>new.algorithm_version or old.protected_context<>new.protected_context or old.source_id is distinct from new.source_id or old.evidence_document_id is distinct from new.evidence_document_id or old.detected_at<>new.detected_at or old.created_by<>new.created_by then
      raise exception 'Auto-generated data-quality issue evidence/content is immutable; only lifecycle status/waiver fields may change';
    end if;
  end if;
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

create or replace function private.compute_counterparty_quality_snapshot()
returns trigger language plpgsql security definer set search_path=''
as $$
declare
  cp public.counterparties%rowtype;
  contact_count int:=0; verified_contact_count int:=0; role_count int:=0; commodity_count int:=0; source_count int:=0;
  identity_penalty numeric:=0; contact_penalty numeric:=0; provenance_penalty numeric:=0; verification_penalty numeric:=0; market_penalty numeric:=0; total_penalty numeric:=0;
  detected text[]:=array[]::text[]; k text; score_v numeric;
begin
  new.algorithm_version:='counterparty-quality-v1';
  select * into cp from public.counterparties where organisation_id=new.organisation_id and id=new.counterparty_id;
  if not found then raise exception 'Counterparty not found for quality scoring'; end if;
  select count(*),count(*) filter(where lower(verification_status)='verified') into contact_count,verified_contact_count from public.counterparty_contacts where organisation_id=new.organisation_id and counterparty_id=new.counterparty_id;
  select count(*) into role_count from public.counterparty_role_assignments where organisation_id=new.organisation_id and counterparty_id=new.counterparty_id and active;
  select count(*) into commodity_count from public.counterparty_commodities where organisation_id=new.organisation_id and counterparty_id=new.counterparty_id and active;
  select count(*) into source_count from public.intelligence_sources where organisation_id=new.organisation_id and counterparty_id=new.counterparty_id;
  if btrim(cp.registration_number)='' then identity_penalty:=identity_penalty+15; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'registration_missing','identity','high','Registration number is missing','Verify and record the legal registration number',new.algorithm_version); detected:=array_append(detected,k); end if;
  if btrim(cp.country_of_incorporation)='' and btrim(cp.headquarters)='' then identity_penalty:=identity_penalty+5; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'location_missing','identity','medium','Country of incorporation and headquarters are missing','Record an evidence-backed incorporation country or headquarters',new.algorithm_version); detected:=array_append(detected,k); end if;
  if btrim(cp.website)='' and btrim(cp.website_domain)='' then identity_penalty:=identity_penalty+5; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'website_missing','identity','low','Website/domain is missing','Record a verified corporate website or domain when available',new.algorithm_version); detected:=array_append(detected,k); end if;
  if contact_count=0 then contact_penalty:=15; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'contact_missing','contact','high','No counterparty contact is recorded','Add at least one evidence-backed contact',new.algorithm_version); detected:=array_append(detected,k); elsif verified_contact_count=0 then contact_penalty:=7; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'verified_contact_missing','contact','medium','No verified counterparty contact is recorded','Verify at least one relevant contact',new.algorithm_version); detected:=array_append(detected,k); end if;
  if source_count=0 then provenance_penalty:=15; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'provenance_missing','provenance','high','No intelligence source/provenance is linked','Attach a source record with verification metadata',new.algorithm_version); detected:=array_append(detected,k); end if;
  if lower(cp.verification_status)<>'verified' then verification_penalty:=verification_penalty+10; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'verification_incomplete','verification','high','Counterparty verification is not complete','Complete evidence-backed counterparty verification',new.algorithm_version); detected:=array_append(detected,k); end if;
  if cp.last_verified_at is null or cp.last_verified_at < now()-interval '180 days' then verification_penalty:=verification_penalty+10; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'verification_stale','verification','medium','Counterparty verification is missing or older than 180 days','Refresh the verification record and evidence',new.algorithm_version); detected:=array_append(detected,k); end if;
  if role_count=0 then market_penalty:=market_penalty+10; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'role_missing','commercial','medium','No counterparty market role is assigned','Assign one or more verified buyer/seller/producer/trader/lab/logistics roles',new.algorithm_version); detected:=array_append(detected,k); end if;
  if commodity_count=0 then market_penalty:=market_penalty+10; k:=private.upsert_counterparty_quality_issue(new.organisation_id,new.counterparty_id,'commodity_relationship_missing','commercial','medium','No commodity relationship is recorded','Link the counterparty to relevant commodities/products',new.algorithm_version); detected:=array_append(detected,k); end if;
  update public.mrcip_data_quality_issues q set status='resolved',resolved_at=now(),resolved_by=coalesce((select auth.uid()),q.updated_by),updated_at=now(),updated_by=coalesce((select auth.uid()),q.updated_by)
  where q.organisation_id=new.organisation_id and q.entity_type='counterparty' and q.counterparty_id=new.counterparty_id and q.auto_generated and q.algorithm_version=new.algorithm_version and q.status='open' and not (q.issue_key=any(detected));
  total_penalty:=least(100,identity_penalty+contact_penalty+provenance_penalty+verification_penalty+market_penalty); score_v:=greatest(0,100-total_penalty);
  new.score:=round(score_v,2); new.grade:=case when score_v>=90 then 'A' when score_v>=80 then 'B' when score_v>=65 then 'C' when score_v>=50 then 'D' else 'E' end;
  new.components:=jsonb_build_object('identity',jsonb_build_object('penalty',identity_penalty,'registration_present',btrim(cp.registration_number)<>'','location_present',(btrim(cp.country_of_incorporation)<>'' or btrim(cp.headquarters)<>''),'website_present',(btrim(cp.website)<>'' or btrim(cp.website_domain)<>'')),'contacts',jsonb_build_object('penalty',contact_penalty,'contact_count',contact_count,'verified_contact_count',verified_contact_count),'provenance',jsonb_build_object('penalty',provenance_penalty,'source_count',source_count),'verification',jsonb_build_object('penalty',verification_penalty,'status',cp.verification_status,'last_verified_at',cp.last_verified_at),'market_profile',jsonb_build_object('penalty',market_penalty,'role_count',role_count,'commodity_relationship_count',commodity_count),'total_penalty',total_penalty);
  select count(*) into new.open_issue_count from public.mrcip_data_quality_issues where organisation_id=new.organisation_id and entity_type='counterparty' and counterparty_id=new.counterparty_id and status='open';
  new.generated_at:=now(); new.generated_by:=coalesce((select auth.uid()),new.generated_by); return new;
end; $$;
revoke all on function private.compute_counterparty_quality_snapshot() from public,anon,authenticated;

create or replace function private.compute_opportunity_score_snapshot()
returns trigger language plpgsql security definer set search_path=''
as $$
declare
  opp public.opportunities%rowtype; mt public.commodity_matches%rowtype; req public.buyer_requirements%rowtype; offe public.seller_supply_offers%rowtype; proto public.opportunity_protocol_controls%rowtype;
  bq public.counterparty_quality_snapshots%rowtype; sq public.counterparty_quality_snapshots%rowtype; br public.counterparty_risk_snapshots%rowtype; sr public.counterparty_risk_snapshots%rowtype; kyc public.opportunity_kyc_cases%rowtype;
  mscore numeric:=0; bscore numeric:=0; sscore numeric:=0; pscore numeric:=0; escore numeric:=0; lscore numeric:=0; cscore numeric:=0; rpen numeric:=0; total numeric:=0;
  cert_ok boolean:=false; inspection_ok boolean:=false; freight_ok boolean:=false; negotiation_ok boolean:=false; finance_ok boolean:=false;
begin
  new.algorithm_version:='opportunity-readiness-v1';
  select * into opp from public.opportunities where organisation_id=new.organisation_id and id=new.opportunity_id; if not found then raise exception 'Opportunity not found for scoring'; end if;
  select * into mt from public.commodity_matches where organisation_id=new.organisation_id and id=opp.match_id;
  select * into req from public.buyer_requirements where organisation_id=new.organisation_id and id=opp.buyer_requirement_id;
  select * into offe from public.seller_supply_offers where organisation_id=new.organisation_id and id=opp.seller_offer_id;
  select * into proto from public.opportunity_protocol_controls where organisation_id=new.organisation_id and opportunity_id=opp.id;
  if new.buyer_quality_snapshot_id is null then select id into new.buyer_quality_snapshot_id from public.counterparty_quality_snapshots where organisation_id=new.organisation_id and counterparty_id=opp.buyer_counterparty_id order by generated_at desc limit 1; end if;
  if new.seller_quality_snapshot_id is null then select id into new.seller_quality_snapshot_id from public.counterparty_quality_snapshots where organisation_id=new.organisation_id and counterparty_id=opp.seller_counterparty_id order by generated_at desc limit 1; end if;
  if new.buyer_risk_snapshot_id is null then select id into new.buyer_risk_snapshot_id from public.counterparty_risk_snapshots where organisation_id=new.organisation_id and counterparty_id=opp.buyer_counterparty_id order by generated_at desc limit 1; end if;
  if new.seller_risk_snapshot_id is null then select id into new.seller_risk_snapshot_id from public.counterparty_risk_snapshots where organisation_id=new.organisation_id and counterparty_id=opp.seller_counterparty_id order by generated_at desc limit 1; end if;
  if new.buyer_quality_snapshot_id is null or new.seller_quality_snapshot_id is null or new.buyer_risk_snapshot_id is null or new.seller_risk_snapshot_id is null then raise exception 'Refresh buyer and seller quality/risk snapshots before scoring the opportunity'; end if;
  select * into bq from public.counterparty_quality_snapshots where organisation_id=new.organisation_id and id=new.buyer_quality_snapshot_id; select * into sq from public.counterparty_quality_snapshots where organisation_id=new.organisation_id and id=new.seller_quality_snapshot_id; select * into br from public.counterparty_risk_snapshots where organisation_id=new.organisation_id and id=new.buyer_risk_snapshot_id; select * into sr from public.counterparty_risk_snapshots where organisation_id=new.organisation_id and id=new.seller_risk_snapshot_id;
  if bq.counterparty_id<>opp.buyer_counterparty_id or sq.counterparty_id<>opp.seller_counterparty_id or br.counterparty_id<>opp.buyer_counterparty_id or sr.counterparty_id<>opp.seller_counterparty_id then raise exception 'Opportunity score snapshot references must match opportunity buyer/seller identities'; end if;
  mscore:=round(coalesce(mt.total_score,0)*0.30,2);
  select * into kyc from public.opportunity_kyc_cases where organisation_id=new.organisation_id and opportunity_id=opp.id and party_role='buyer' order by created_at desc limit 1;
  if found then bscore:=bscore+(case when lower(kyc.status)='verified' then 5 else 0 end)+(case when kyc.registration_verified then 2 else 0 end)+(case when kyc.authority_verified then 3 else 0 end)+(case when lower(kyc.sanctions_screening_status)='clear' then 2 else 0 end)+(case when lower(kyc.pep_screening_status)='clear' then 1 else 0 end)+(case when lower(kyc.capability_evidence_status)='verified' then 2 else 0 end); end if; bscore:=least(15,bscore);
  sscore:=least(15,(case when lower(offe.authority_status)='verified' then 5 else 0 end)+(case when lower(offe.mandate_status)='verified' then 5 else 0 end)+(case when lower(offe.protection_status)='protected' then 3 else 0 end)+(case when offe.source_id is not null then 2 else 0 end));
  pscore:=case lower(coalesce(proto.protocol_step,'protect')) when 'complete' then 15 when 'contract' then 15 when 'disclose' then 11 when 'verify' then 7 else 3 end; if coalesce(proto.disclosure_eligible,false) and pscore<15 then pscore:=least(15,pscore+1); end if;
  select exists(select 1 from public.laboratory_certificates c join public.laboratory_test_orders o on o.organisation_id=c.organisation_id and o.id=c.order_id join public.commodity_sampling_requests r on r.organisation_id=o.organisation_id and r.id=o.request_id where c.organisation_id=new.organisation_id and c.verified_at is not null and (r.opportunity_id=opp.id or r.seller_offer_id=opp.seller_offer_id)) into cert_ok;
  select exists(select 1 from public.commodity_inspections i join public.commodity_sampling_requests r on r.organisation_id=i.organisation_id and r.id=i.request_id where i.organisation_id=new.organisation_id and i.verified_at is not null and (r.opportunity_id=opp.id or r.seller_offer_id=opp.seller_offer_id)) into inspection_ok; escore:=(case when cert_ok then 5 else 0 end)+(case when inspection_ok then 5 else 0 end);
  select exists(select 1 from public.opportunity_freight_links where organisation_id=new.organisation_id and opportunity_id=opp.id) into freight_ok; lscore:=least(5,(case when btrim(req.destination_location)<>'' then 1 else 0 end)+(case when btrim(offe.loading_location)<>'' then 1 else 0 end)+(case when btrim(req.transport_mode)<>'' and btrim(offe.transport_mode)<>'' then 1 else 0 end)+(case when freight_ok then 2 else 0 end));
  select exists(select 1 from public.opportunity_negotiation_links where organisation_id=new.organisation_id and opportunity_id=opp.id) into negotiation_ok; select exists(select 1 from public.opportunity_finance_links where organisation_id=new.organisation_id and opportunity_id=opp.id) into finance_ok; cscore:=least(10,(case when btrim(req.payment_terms)<>'' or btrim(req.payment_instrument)<>'' then 2 else 0 end)+(case when btrim(offe.payment_terms)<>'' or btrim(offe.payment_instrument)<>'' then 2 else 0 end)+(case when negotiation_ok then 3 else 0 end)+(case when finance_ok then 3 else 0 end));
  rpen:=round(greatest(br.risk_score,sr.risk_score)*0.15,2); total:=greatest(0,least(100,mscore+bscore+sscore+pscore+escore+lscore+cscore-rpen));
  new.match_score:=mscore; new.buyer_readiness_score:=bscore; new.seller_readiness_score:=sscore; new.protocol_score:=pscore; new.evidence_score:=escore; new.logistics_score:=lscore; new.commercial_score:=cscore; new.risk_penalty:=rpen; new.total_score:=round(total,2); new.readiness_band:=case when total>=80 then 'high' when total>=65 then 'strong' when total>=50 then 'developing' else 'early' end; new.protected_context:=true;
  new.generated_at:=now(); new.generated_by:=coalesce((select auth.uid()),new.generated_by); new.explanation:=jsonb_build_object('formula','match(30)+buyer(15)+seller(15)+protocol(15)+evidence(10)+logistics(5)+commercial(10)-risk_penalty(15 max)','match_source_score',coalesce(mt.total_score,0),'buyer_quality_score',bq.score,'seller_quality_score',sq.score,'buyer_risk_score',br.risk_score,'seller_risk_score',sr.risk_score,'certificate_verified',cert_ok,'inspection_verified',inspection_ok,'freight_linked',freight_ok,'negotiation_linked',negotiation_ok,'finance_linked',finance_ok,'component_scores',jsonb_build_object('match',mscore,'buyer_readiness',bscore,'seller_readiness',sscore,'protocol',pscore,'evidence',escore,'logistics',lscore,'commercial',cscore,'risk_penalty',rpen)); return new;
end; $$;
revoke all on function private.compute_opportunity_score_snapshot() from public,anon,authenticated;