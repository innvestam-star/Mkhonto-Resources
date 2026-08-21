revoke all on public.audit_events from anon,authenticated;
grant select,insert on public.audit_events to authenticated;
drop policy if exists audit_events_select_mrcip on public.audit_events;
create policy audit_events_select_mrcip on public.audit_events for select to authenticated
using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']));

create or replace function private.sync_commodity_sampling_request()
returns trigger language plpgsql security definer set search_path=''
as $$
declare opp public.opportunities%rowtype; offer public.seller_supply_offers%rowtype; lab public.laboratories%rowtype;
begin
  if new.opportunity_id is not null then
    select * into opp from public.opportunities where organisation_id=new.organisation_id and id=new.opportunity_id;
    if not found then raise exception 'Opportunity not found for sampling request'; end if;
    if new.seller_offer_id is null then new.seller_offer_id:=opp.seller_offer_id; end if;
    if new.seller_offer_id<>opp.seller_offer_id then raise exception 'Sampling request seller offer must match the linked opportunity'; end if;
    new.commodity_id:=opp.commodity_id;
    if new.product_id is null then new.product_id:=opp.product_id; end if;
  end if;
  if new.seller_offer_id is not null then
    select * into offer from public.seller_supply_offers where organisation_id=new.organisation_id and id=new.seller_offer_id;
    if not found then raise exception 'Seller offer not found for sampling request'; end if;
    if new.commodity_id is distinct from offer.commodity_id then raise exception 'Sampling request commodity must match seller offer'; end if;
    if new.product_id is null then new.product_id:=offer.product_id;
    elsif offer.product_id is not null and new.product_id<>offer.product_id then raise exception 'Sampling request product must match seller offer'; end if;
    if new.mine_id is null then new.mine_id:=offer.mine_id;
    elsif offer.mine_id is not null and new.mine_id<>offer.mine_id then raise exception 'Sampling request mine must match seller offer'; end if;
    if offer.is_protected then new.protected_record:=true; end if;
  end if;
  if new.laboratory_id is not null then
    select * into lab from public.laboratories where organisation_id=new.organisation_id and id=new.laboratory_id;
    if not found then raise exception 'Laboratory not found for sampling request'; end if;
  end if;
  if new.status in ('requested','scheduled','in_progress') and new.requested_at is null then new.requested_at:=now(); end if;
  if new.status='completed' and new.completed_at is null then new.completed_at:=now(); end if;
  if tg_op='UPDATE' and old.status in ('completed','cancelled','rejected') and new.status is distinct from old.status then
    raise exception 'Closed sampling requests cannot be reopened by direct update';
  end if;
  new.updated_at:=now();
  return new;
end; $$;
revoke all on function private.sync_commodity_sampling_request() from public,anon,authenticated;
create trigger commodity_sampling_requests_sync_biu before insert or update on public.commodity_sampling_requests for each row execute function private.sync_commodity_sampling_request();

create or replace function private.guard_commodity_sample()
returns trigger language plpgsql security definer set search_path=''
as $$
declare req public.commodity_sampling_requests%rowtype; parent_row public.commodity_samples%rowtype;
begin
  select * into req from public.commodity_sampling_requests where organisation_id=new.organisation_id and id=new.request_id;
  if not found then raise exception 'Sampling request not found for sample'; end if;
  if req.status in ('cancelled','rejected') then raise exception 'Cannot create/update a sample for a cancelled/rejected request'; end if;
  if new.parent_sample_id is not null then
    select * into parent_row from public.commodity_samples where organisation_id=new.organisation_id and id=new.parent_sample_id;
    if not found or parent_row.request_id<>new.request_id then raise exception 'Parent sample must belong to the same sampling request'; end if;
  end if;
  if tg_op='UPDATE' and exists(select 1 from public.sample_custody_events e where e.organisation_id=new.organisation_id and e.sample_id=new.id) then
    if new.request_id is distinct from old.request_id or new.parent_sample_id is distinct from old.parent_sample_id or new.sample_reference is distinct from old.sample_reference
       or new.sample_type is distinct from old.sample_type or new.collected_at is distinct from old.collected_at or new.collection_location is distinct from old.collection_location
       or new.collected_by_name is distinct from old.collected_by_name then
      raise exception 'Core sample identity/collection fields are immutable after chain-of-custody begins';
    end if;
  end if;
  new.updated_at:=now();
  return new;
end; $$;
revoke all on function private.guard_commodity_sample() from public,anon,authenticated;
create trigger commodity_samples_guard_biu before insert or update on public.commodity_samples for each row execute function private.guard_commodity_sample();

create or replace function private.guard_sample_custody_event()
returns trigger language plpgsql security definer set search_path=''
as $$
declare s public.commodity_samples%rowtype; req public.commodity_sampling_requests%rowtype; d public.documents%rowtype;
begin
  if tg_op<>'INSERT' then raise exception 'Chain-of-custody events are append-only'; end if;
  select * into s from public.commodity_samples where organisation_id=new.organisation_id and id=new.sample_id;
  if not found then raise exception 'Sample not found for custody event'; end if;
  select * into req from public.commodity_sampling_requests where organisation_id=new.organisation_id and id=s.request_id;
  if new.occurred_at<s.collected_at then raise exception 'Custody event cannot predate sample collection'; end if;
  if new.evidence_document_id is not null then
    select * into d from public.documents where organisation_id=new.organisation_id and id=new.evidence_document_id;
    if not found then raise exception 'Custody evidence document not found'; end if;
    if req.protected_record and d.category<>'mrcip_protected' then raise exception 'Protected sampling evidence must use an mrcip_protected document'; end if;
  end if;
  return new;
end; $$;
revoke all on function private.guard_sample_custody_event() from public,anon,authenticated;
create trigger sample_custody_events_guard_biud before insert or update or delete on public.sample_custody_events for each row execute function private.guard_sample_custody_event();

create or replace function private.apply_sample_custody_status()
returns trigger language plpgsql security definer set search_path=''
as $$
declare next_status text;
begin
  next_status:=case new.event_type when 'sealed' then 'sealed' when 'handover' then 'in_transit' when 'received' then 'received_at_lab' when 'test_started' then 'under_test' when 'retained' then 'retained' when 'disposed' then 'disposed' else null end;
  if next_status is not null then
    update public.commodity_samples set status=next_status,updated_at=now(),updated_by=coalesce((select auth.uid()),updated_by) where organisation_id=new.organisation_id and id=new.sample_id;
  end if;
  return new;
end; $$;
revoke all on function private.apply_sample_custody_status() from public,anon,authenticated;
create trigger sample_custody_events_apply_ai after insert on public.sample_custody_events for each row execute function private.apply_sample_custody_status();

create or replace function private.guard_laboratory_test_order()
returns trigger language plpgsql security definer set search_path=''
as $$
declare s public.commodity_samples%rowtype; req public.commodity_sampling_requests%rowtype; internal_verify boolean:=coalesce(current_setting('mrcip.lab_verify',true),'')='on';
begin
  select * into s from public.commodity_samples where organisation_id=new.organisation_id and id=new.sample_id;
  if not found or s.request_id<>new.request_id then raise exception 'Test order sample must belong to the sampling request'; end if;
  select * into req from public.commodity_sampling_requests where organisation_id=new.organisation_id and id=new.request_id;
  if req.laboratory_id is not null and req.laboratory_id<>new.laboratory_id then raise exception 'Test order laboratory must match the laboratory assigned to the sampling request'; end if;
  if tg_op='INSERT' and new.status<>'draft' then raise exception 'New laboratory test orders must start as draft'; end if;
  if tg_op='UPDATE' then
    if old.status in ('verified','cancelled','rejected') and new.status is distinct from old.status then raise exception 'Closed laboratory test orders cannot be reopened by direct update'; end if;
    if new.status='received' and old.status is distinct from 'received' then
      if not exists(select 1 from public.sample_custody_events e where e.organisation_id=new.organisation_id and e.sample_id=new.sample_id and e.event_type='received') then raise exception 'Laboratory receipt requires a received chain-of-custody event'; end if;
      new.sample_received_at:=coalesce(new.sample_received_at,now());
    end if;
    if new.status='testing' and old.status is distinct from 'testing' then new.testing_started_at:=coalesce(new.testing_started_at,now()); end if;
    if new.status='reported' and old.status is distinct from 'reported' then
      if not exists(select 1 from public.laboratory_test_results r where r.organisation_id=new.organisation_id and r.order_id=new.id and r.status in ('reported','verified')) then raise exception 'A reported laboratory order requires at least one reported result'; end if;
      new.reported_at:=coalesce(new.reported_at,now());
    end if;
    if new.status='verified' and old.status is distinct from 'verified' and not internal_verify then raise exception 'Laboratory order verification is controlled by verified certificate/result workflow'; end if;
  end if;
  new.updated_at:=now();
  return new;
end; $$;
revoke all on function private.guard_laboratory_test_order() from public,anon,authenticated;
create trigger laboratory_test_orders_guard_biu before insert or update on public.laboratory_test_orders for each row execute function private.guard_laboratory_test_order();

create or replace function private.guard_laboratory_test_result()
returns trigger language plpgsql security definer set search_path=''
as $$
declare ord public.laboratory_test_orders%rowtype; req public.commodity_sampling_requests%rowtype; sf public.commodity_spec_fields%rowtype; prev public.laboratory_test_results%rowtype; internal_verify boolean:=coalesce(current_setting('mrcip.lab_verify',true),'')='on'; internal_revision boolean:=coalesce(current_setting('mrcip.lab_revision',true),'')='on';
begin
  select * into ord from public.laboratory_test_orders where organisation_id=new.organisation_id and id=new.order_id;
  if not found then raise exception 'Laboratory test order not found'; end if;
  select * into req from public.commodity_sampling_requests where organisation_id=new.organisation_id and id=ord.request_id;
  select * into sf from public.commodity_spec_fields where organisation_id=new.organisation_id and id=new.spec_field_id;
  if not found or sf.commodity_id<>req.commodity_id then raise exception 'Laboratory result specification field must belong to the request commodity'; end if;
  if sf.data_type='numeric' and new.numeric_value is null then raise exception 'Numeric specification field requires a numeric result'; end if;
  if sf.data_type<>'numeric' and new.text_value is null then raise exception 'Non-numeric specification field requires a text result'; end if;
  if tg_op='INSERT' then
    if new.status<>'draft' then raise exception 'New laboratory results must start as draft'; end if;
    if new.revision_no=1 then
      if new.previous_result_id is not null then raise exception 'Initial laboratory result cannot reference a previous revision'; end if;
    else
      if not internal_revision then raise exception 'Laboratory result revisions must use the controlled revision workflow'; end if;
      select * into prev from public.laboratory_test_results where organisation_id=new.organisation_id and id=new.previous_result_id;
      if not found or prev.order_id<>new.order_id or prev.spec_field_id<>new.spec_field_id or new.revision_no<>prev.revision_no+1 then raise exception 'Laboratory result revision lineage is invalid'; end if;
    end if;
  else
    if old.status in ('verified','rejected','superseded') and not internal_verify then raise exception 'Verified/rejected/superseded laboratory results are immutable'; end if;
    if old.status='reported' and not internal_verify then
      if new.numeric_value is distinct from old.numeric_value or new.text_value is distinct from old.text_value or new.unit is distinct from old.unit or new.basis is distinct from old.basis or new.test_method is distinct from old.test_method then
        raise exception 'Reported laboratory result values are immutable; create a controlled revision';
      end if;
    end if;
    if new.status='reported' and old.status is distinct from 'reported' then new.reported_at:=coalesce(new.reported_at,now()); end if;
    if new.status in ('verified','rejected','superseded') and new.status is distinct from old.status and not internal_verify then raise exception 'Laboratory result verification/rejection/supersession is controlled'; end if;
  end if;
  new.updated_at:=now();
  return new;
end; $$;
revoke all on function private.guard_laboratory_test_result() from public,anon,authenticated;
create trigger laboratory_test_results_guard_biu before insert or update on public.laboratory_test_results for each row execute function private.guard_laboratory_test_result();

create or replace function private.guard_laboratory_certificate()
returns trigger language plpgsql security definer set search_path=''
as $$
declare ord public.laboratory_test_orders%rowtype; d public.documents%rowtype; internal_verify boolean:=coalesce(current_setting('mrcip.lab_verify',true),'')='on';
begin
  select * into ord from public.laboratory_test_orders where organisation_id=new.organisation_id and id=new.order_id;
  if not found or ord.laboratory_id<>new.laboratory_id then raise exception 'Certificate laboratory must match the laboratory test order'; end if;
  select * into d from public.documents where organisation_id=new.organisation_id and id=new.document_id;
  if not found then raise exception 'Certificate document not found'; end if;
  if d.category<>'mrcip_protected' then raise exception 'Laboratory certificates must use an mrcip_protected document'; end if;
  new.checksum_snapshot:=d.checksum;
  if tg_op='INSERT' and new.status<>'received' then raise exception 'New laboratory certificates must start received'; end if;
  if tg_op='UPDATE' then
    if old.status in ('verified','rejected','superseded') and not internal_verify then raise exception 'Verified/rejected/superseded certificates are immutable'; end if;
    if new.status in ('verified','rejected','superseded') and new.status is distinct from old.status and not internal_verify then raise exception 'Certificate verification/rejection/supersession is controlled'; end if;
  end if;
  new.updated_at:=now();
  return new;
end; $$;
revoke all on function private.guard_laboratory_certificate() from public,anon,authenticated;
create trigger laboratory_certificates_guard_biu before insert or update on public.laboratory_certificates for each row execute function private.guard_laboratory_certificate();

create or replace function private.guard_commodity_inspection()
returns trigger language plpgsql security definer set search_path=''
as $$
declare req public.commodity_sampling_requests%rowtype; d public.documents%rowtype; internal_verify boolean:=coalesce(current_setting('mrcip.lab_verify',true),'')='on';
begin
  select * into req from public.commodity_sampling_requests where organisation_id=new.organisation_id and id=new.request_id;
  if not found then raise exception 'Sampling/inspection request not found'; end if;
  if req.request_type not in ('inspection','sampling_and_inspection') then raise exception 'Inspection record requires an inspection-capable request'; end if;
  if new.evidence_document_id is not null then
    select * into d from public.documents where organisation_id=new.organisation_id and id=new.evidence_document_id;
    if not found then raise exception 'Inspection evidence document not found'; end if;
    if req.protected_record and d.category<>'mrcip_protected' then raise exception 'Protected inspection evidence must use an mrcip_protected document'; end if;
  end if;
  if tg_op='UPDATE' and old.status in ('verified','rejected','superseded') and not internal_verify then raise exception 'Verified/rejected/superseded inspection records are immutable'; end if;
  if new.status='completed' and old.status is distinct from 'completed' then
    if new.inspected_at is null or new.outcome='pending' then raise exception 'Completed inspection requires inspection time and outcome'; end if;
  end if;
  if new.status in ('verified','rejected','superseded') and (tg_op='INSERT' or new.status is distinct from old.status) and not internal_verify then raise exception 'Inspection verification/rejection/supersession is controlled'; end if;
  new.updated_at:=now();
  return new;
end; $$;
revoke all on function private.guard_commodity_inspection() from public,anon,authenticated;
create trigger commodity_inspections_guard_biu before insert or update on public.commodity_inspections for each row execute function private.guard_commodity_inspection();

create or replace function private.guard_lab_result_publication()
returns trigger language plpgsql security definer set search_path=''
as $$
declare r public.laboratory_test_results%rowtype; c public.laboratory_certificates%rowtype; spec public.seller_offer_specs%rowtype;
begin
  if tg_op<>'INSERT' then raise exception 'Laboratory result publication ledger is append-only'; end if;
  select * into r from public.laboratory_test_results where organisation_id=new.organisation_id and id=new.result_id;
  select * into c from public.laboratory_certificates where organisation_id=new.organisation_id and id=new.certificate_id;
  select * into spec from public.seller_offer_specs where organisation_id=new.organisation_id and id=new.seller_offer_spec_id;
  if not found then raise exception 'Published seller offer specification not found'; end if;
  if r.status<>'verified' or c.status<>'verified' or c.order_id<>r.order_id then raise exception 'Publication requires a verified result and verified certificate for the same order'; end if;
  if spec.offer_id<>new.seller_offer_id or spec.spec_field_id<>r.spec_field_id or spec.certificate_document_id<>c.document_id then raise exception 'Publication ledger must reference the published verified assay/spec record'; end if;
  if new.published_by<>(select auth.uid()) then raise exception 'Publication actor must be the authenticated user'; end if;
  new.published_value:=jsonb_build_object('numeric_value',spec.numeric_value,'text_value',spec.text_value,'unit',spec.unit,'basis',spec.basis,'test_method',spec.test_method,'certificate_document_id',spec.certificate_document_id,'tested_at',spec.tested_at);
  return new;
end; $$;
revoke all on function private.guard_lab_result_publication() from public,anon,authenticated;
create trigger lab_result_publications_guard_biud before insert or update or delete on public.lab_result_publications for each row execute function private.guard_lab_result_publication();

create or replace function public.record_sample_custody_event(p_sample_id uuid,p_event_type text,p_occurred_at timestamptz,p_from_custodian text default '',p_to_custodian text default '',p_location text default '',p_seal_number text default '',p_condition_notes text default '',p_evidence_document_id uuid default null,p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql set search_path=''
as $$
declare s public.commodity_samples%rowtype; eid uuid:=gen_random_uuid();
begin
  select * into s from public.commodity_samples where id=p_sample_id;
  if not found then raise exception 'Sample not found'; end if;
  if not private.has_mrcip_role(s.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) then raise exception 'Insufficient role' using errcode='42501'; end if;
  insert into public.sample_custody_events(id,organisation_id,sample_id,event_type,occurred_at,from_custodian,to_custodian,location,seal_number,condition_notes,evidence_document_id,metadata,created_by)
  values(eid,s.organisation_id,s.id,p_event_type,p_occurred_at,coalesce(p_from_custodian,''),coalesce(p_to_custodian,''),coalesce(p_location,''),coalesce(p_seal_number,''),coalesce(p_condition_notes,''),p_evidence_document_id,coalesce(p_metadata,'{}'::jsonb),(select auth.uid()));
  return eid;
end; $$;
revoke all on function public.record_sample_custody_event(uuid,text,timestamptz,text,text,text,text,text,uuid,jsonb) from public,anon;
grant execute on function public.record_sample_custody_event(uuid,text,timestamptz,text,text,text,text,text,uuid,jsonb) to authenticated;

create or replace function public.verify_laboratory_certificate(p_certificate_id uuid,p_notes text default '')
returns text language plpgsql set search_path=''
as $$
declare c public.laboratory_certificates%rowtype; ord public.laboratory_test_orders%rowtype; req public.commodity_sampling_requests%rowtype; old_flag text:=current_setting('mrcip.lab_verify',true);
begin
  select * into c from public.laboratory_certificates where id=p_certificate_id;
  if not found then raise exception 'Laboratory certificate not found'; end if;
  if not private.has_mrcip_role(c.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']) then raise exception 'Insufficient role' using errcode='42501'; end if;
  if c.status<>'received' then raise exception 'Only received certificates may be verified'; end if;
  select * into ord from public.laboratory_test_orders where organisation_id=c.organisation_id and id=c.order_id;
  if not exists(select 1 from public.laboratory_test_results r where r.organisation_id=c.organisation_id and r.order_id=c.order_id and r.status='reported') then raise exception 'Certificate verification requires at least one reported laboratory result'; end if;
  perform set_config('mrcip.lab_verify','on',true);
  begin
    update public.laboratory_certificates set status='verified',verified_at=now(),verified_by=(select auth.uid()),verification_notes=coalesce(p_notes,''),updated_by=(select auth.uid()) where id=c.id;
    select * into req from public.commodity_sampling_requests where organisation_id=c.organisation_id and id=ord.request_id;
    if req.opportunity_id is not null and not exists(select 1 from public.opportunity_document_links l where l.organisation_id=c.organisation_id and l.opportunity_id=req.opportunity_id and l.document_id=c.document_id and l.document_role='laboratory_certificate') then
      insert into public.opportunity_document_links(organisation_id,opportunity_id,document_id,document_role,visibility,party_scope,sharing_status,notes,created_by,updated_by)
      values(c.organisation_id,req.opportunity_id,c.document_id,'laboratory_certificate','protected','internal','draft','Verified Stage 7 laboratory certificate',(select auth.uid()),(select auth.uid()));
    end if;
    insert into public.audit_events(organisation_id,entity_type,entity_id,action,summary,metadata,actor_id)
    values(c.organisation_id,'laboratory_certificate',c.id,'verified','Laboratory certificate verified',jsonb_build_object('order_id',c.order_id,'document_id',c.document_id),(select auth.uid()));
    perform set_config('mrcip.lab_verify',coalesce(old_flag,''),true);
  exception when others then perform set_config('mrcip.lab_verify',coalesce(old_flag,''),true); raise; end;
  return 'verified';
end; $$;
revoke all on function public.verify_laboratory_certificate(uuid,text) from public,anon;
grant execute on function public.verify_laboratory_certificate(uuid,text) to authenticated;

create or replace function public.verify_laboratory_test_result(p_result_id uuid,p_certificate_id uuid,p_notes text default '')
returns text language plpgsql set search_path=''
as $$
declare r public.laboratory_test_results%rowtype; c public.laboratory_certificates%rowtype; old_flag text:=current_setting('mrcip.lab_verify',true); prev_id uuid;
begin
  select * into r from public.laboratory_test_results where id=p_result_id;
  if not found then raise exception 'Laboratory result not found'; end if;
  if not private.has_mrcip_role(r.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']) then raise exception 'Insufficient role' using errcode='42501'; end if;
  if r.status<>'reported' then raise exception 'Only reported laboratory results may be verified'; end if;
  select * into c from public.laboratory_certificates where organisation_id=r.organisation_id and id=p_certificate_id;
  if not found or c.status<>'verified' or c.order_id<>r.order_id then raise exception 'Result verification requires a verified certificate for the same laboratory order'; end if;
  prev_id:=r.previous_result_id;
  perform set_config('mrcip.lab_verify','on',true);
  begin
    update public.laboratory_test_results set status='verified',verified_at=now(),verified_by=(select auth.uid()),notes=case when nullif(coalesce(p_notes,''),'') is null then notes else concat_ws(E'\n',notes,p_notes) end,updated_by=(select auth.uid()) where id=r.id;
    if prev_id is not null then update public.laboratory_test_results set status='superseded',updated_by=(select auth.uid()) where organisation_id=r.organisation_id and id=prev_id and status='verified'; end if;
    if not exists(select 1 from public.laboratory_test_results x where x.organisation_id=r.organisation_id and x.order_id=r.order_id and x.status in ('draft','reported')) and exists(select 1 from public.laboratory_test_results x where x.organisation_id=r.organisation_id and x.order_id=r.order_id and x.status='verified') then
      update public.laboratory_test_orders set status='verified',verified_at=now(),verified_by=(select auth.uid()),updated_by=(select auth.uid()) where organisation_id=r.organisation_id and id=r.order_id;
    end if;
    insert into public.audit_events(organisation_id,entity_type,entity_id,action,summary,metadata,actor_id)
    values(r.organisation_id,'laboratory_test_result',r.id,'verified','Laboratory test result verified',jsonb_build_object('order_id',r.order_id,'certificate_id',c.id,'spec_field_id',r.spec_field_id,'revision_no',r.revision_no),(select auth.uid()));
    perform set_config('mrcip.lab_verify',coalesce(old_flag,''),true);
  exception when others then perform set_config('mrcip.lab_verify',coalesce(old_flag,''),true); raise; end;
  return 'verified';
end; $$;
revoke all on function public.verify_laboratory_test_result(uuid,uuid,text) from public,anon;
grant execute on function public.verify_laboratory_test_result(uuid,uuid,text) to authenticated;

create or replace function public.create_laboratory_result_revision(p_result_id uuid,p_numeric_value numeric default null,p_text_value text default null,p_unit text default '',p_basis text default '',p_test_method text default '',p_notes text default '')
returns uuid language plpgsql set search_path=''
as $$
declare r public.laboratory_test_results%rowtype; rid uuid:=gen_random_uuid(); old_flag text:=current_setting('mrcip.lab_revision',true);
begin
  select * into r from public.laboratory_test_results where id=p_result_id;
  if not found then raise exception 'Laboratory result not found'; end if;
  if not private.has_mrcip_role(r.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) then raise exception 'Insufficient role' using errcode='42501'; end if;
  if r.status not in ('reported','verified','rejected') then raise exception 'Only reported/verified/rejected laboratory results may be revised'; end if;
  if exists(select 1 from public.laboratory_test_results x where x.organisation_id=r.organisation_id and x.previous_result_id=r.id and x.status in ('draft','reported','verified')) then raise exception 'An active revision already exists for this laboratory result'; end if;
  perform set_config('mrcip.lab_revision','on',true);
  begin
    insert into public.laboratory_test_results(id,organisation_id,order_id,spec_field_id,revision_no,previous_result_id,numeric_value,text_value,unit,basis,test_method,status,notes,created_by,updated_by)
    values(rid,r.organisation_id,r.order_id,r.spec_field_id,r.revision_no+1,r.id,p_numeric_value,p_text_value,coalesce(p_unit,''),coalesce(p_basis,''),coalesce(p_test_method,''),'draft',coalesce(p_notes,''),(select auth.uid()),(select auth.uid()));
    perform set_config('mrcip.lab_revision',coalesce(old_flag,''),true);
  exception when others then perform set_config('mrcip.lab_revision',coalesce(old_flag,''),true); raise; end;
  return rid;
end; $$;
revoke all on function public.create_laboratory_result_revision(uuid,numeric,text,text,text,text,text) from public,anon;
grant execute on function public.create_laboratory_result_revision(uuid,numeric,text,text,text,text,text) to authenticated;

create or replace function public.verify_commodity_inspection(p_inspection_id uuid,p_notes text default '')
returns text language plpgsql set search_path=''
as $$
declare i public.commodity_inspections%rowtype; req public.commodity_sampling_requests%rowtype; old_flag text:=current_setting('mrcip.lab_verify',true);
begin
  select * into i from public.commodity_inspections where id=p_inspection_id;
  if not found then raise exception 'Inspection record not found'; end if;
  if not private.has_mrcip_role(i.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']) then raise exception 'Insufficient role' using errcode='42501'; end if;
  if i.status<>'completed' then raise exception 'Only completed inspections may be verified'; end if;
  if i.evidence_document_id is null and i.findings='{}'::jsonb then raise exception 'Inspection verification requires findings or evidence document'; end if;
  perform set_config('mrcip.lab_verify','on',true);
  begin
    update public.commodity_inspections set status='verified',verified_at=now(),verified_by=(select auth.uid()),verification_notes=coalesce(p_notes,''),updated_by=(select auth.uid()) where id=i.id;
    select * into req from public.commodity_sampling_requests where organisation_id=i.organisation_id and id=i.request_id;
    if req.opportunity_id is not null and i.evidence_document_id is not null and not exists(select 1 from public.opportunity_document_links l where l.organisation_id=i.organisation_id and l.opportunity_id=req.opportunity_id and l.document_id=i.evidence_document_id and l.document_role='inspection_report') then
      insert into public.opportunity_document_links(organisation_id,opportunity_id,document_id,document_role,visibility,party_scope,sharing_status,notes,created_by,updated_by)
      values(i.organisation_id,req.opportunity_id,i.evidence_document_id,'inspection_report','protected','internal','draft','Verified Stage 7 inspection report',(select auth.uid()),(select auth.uid()));
    end if;
    insert into public.audit_events(organisation_id,entity_type,entity_id,action,summary,metadata,actor_id)
    values(i.organisation_id,'commodity_inspection',i.id,'verified','Commodity inspection verified',jsonb_build_object('request_id',i.request_id,'outcome',i.outcome,'evidence_document_id',i.evidence_document_id),(select auth.uid()));
    perform set_config('mrcip.lab_verify',coalesce(old_flag,''),true);
  exception when others then perform set_config('mrcip.lab_verify',coalesce(old_flag,''),true); raise; end;
  return 'verified';
end; $$;
revoke all on function public.verify_commodity_inspection(uuid,text) from public,anon;
grant execute on function public.verify_commodity_inspection(uuid,text) to authenticated;

create or replace function public.publish_verified_laboratory_result(p_result_id uuid,p_certificate_id uuid,p_seller_offer_id uuid,p_replace_existing boolean default false,p_notes text default '')
returns uuid language plpgsql set search_path=''
as $$
declare r public.laboratory_test_results%rowtype; c public.laboratory_certificates%rowtype; ord public.laboratory_test_orders%rowtype; req public.commodity_sampling_requests%rowtype; offer public.seller_supply_offers%rowtype; existing public.seller_offer_specs%rowtype; spec_id uuid; action text; prev jsonb:='{}'::jsonb;
begin
  select * into r from public.laboratory_test_results where id=p_result_id;
  if not found or r.status<>'verified' then raise exception 'Only verified laboratory results may be published'; end if;
  if not private.has_mrcip_role(r.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']) then raise exception 'Insufficient role' using errcode='42501'; end if;
  select * into c from public.laboratory_certificates where organisation_id=r.organisation_id and id=p_certificate_id;
  if not found or c.status<>'verified' or c.order_id<>r.order_id then raise exception 'Publication requires a verified certificate for the same order'; end if;
  select * into ord from public.laboratory_test_orders where organisation_id=r.organisation_id and id=r.order_id;
  select * into req from public.commodity_sampling_requests where organisation_id=r.organisation_id and id=ord.request_id;
  select * into offer from public.seller_supply_offers where organisation_id=r.organisation_id and id=p_seller_offer_id;
  if not found then raise exception 'Seller offer not found'; end if;
  if req.seller_offer_id is not null and req.seller_offer_id<>offer.id then raise exception 'Laboratory result may only publish to the seller offer linked to its sampling request'; end if;
  if req.opportunity_id is not null and not exists(select 1 from public.opportunities o where o.organisation_id=r.organisation_id and o.id=req.opportunity_id and o.seller_offer_id=offer.id) then raise exception 'Laboratory result seller offer does not match the linked opportunity'; end if;
  if offer.commodity_id<>req.commodity_id then raise exception 'Seller offer commodity does not match laboratory request commodity'; end if;
  select * into existing from public.seller_offer_specs where organisation_id=r.organisation_id and offer_id=offer.id and spec_field_id=r.spec_field_id;
  if not found then
    spec_id:=gen_random_uuid(); action:='inserted';
    insert into public.seller_offer_specs(id,organisation_id,offer_id,spec_field_id,numeric_value,text_value,unit,basis,test_method,certificate_document_id,tested_at,notes,created_by,updated_by)
    values(spec_id,r.organisation_id,offer.id,r.spec_field_id,r.numeric_value,r.text_value,r.unit,r.basis,r.test_method,c.document_id,coalesce(c.issued_at,r.reported_at,now()),coalesce(p_notes,''),(select auth.uid()),(select auth.uid()));
  else
    spec_id:=existing.id;
    if existing.numeric_value is not distinct from r.numeric_value and existing.text_value is not distinct from r.text_value and existing.unit=r.unit and existing.basis=r.basis and existing.test_method=r.test_method and existing.certificate_document_id=c.document_id then
      action:='no_change';
    else
      if not p_replace_existing then raise exception 'A seller offer specification already exists with different values; explicit replacement approval is required'; end if;
      prev:=jsonb_build_object('numeric_value',existing.numeric_value,'text_value',existing.text_value,'unit',existing.unit,'basis',existing.basis,'test_method',existing.test_method,'certificate_document_id',existing.certificate_document_id,'tested_at',existing.tested_at);
      update public.seller_offer_specs set numeric_value=r.numeric_value,text_value=r.text_value,unit=r.unit,basis=r.basis,test_method=r.test_method,certificate_document_id=c.document_id,tested_at=coalesce(c.issued_at,r.reported_at,now()),notes=case when nullif(coalesce(p_notes,''),'') is null then notes else concat_ws(E'\n',notes,p_notes) end,updated_by=(select auth.uid()),updated_at=now() where id=existing.id;
      action:='replaced';
    end if;
  end if;
  insert into public.lab_result_publications(organisation_id,result_id,certificate_id,seller_offer_id,seller_offer_spec_id,publication_action,previous_value,notes,published_by)
  values(r.organisation_id,r.id,c.id,offer.id,spec_id,action,prev,coalesce(p_notes,''),(select auth.uid()));
  insert into public.audit_events(organisation_id,entity_type,entity_id,action,summary,metadata,actor_id)
  values(r.organisation_id,'seller_offer_spec',spec_id,'laboratory_result_published','Verified laboratory result published to seller offer specification',jsonb_build_object('result_id',r.id,'certificate_id',c.id,'seller_offer_id',offer.id,'publication_action',action),(select auth.uid()));
  return spec_id;
end; $$;
revoke all on function public.publish_verified_laboratory_result(uuid,uuid,uuid,boolean,text) from public,anon;
grant execute on function public.publish_verified_laboratory_result(uuid,uuid,uuid,boolean,text) to authenticated;

create policy commodity_sampling_requests_select on public.commodity_sampling_requests for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy commodity_sampling_requests_insert on public.commodity_sampling_requests for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy commodity_sampling_requests_update on public.commodity_sampling_requests for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst'])) with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and updated_by=(select auth.uid()));
create policy commodity_sampling_requests_delete on public.commodity_sampling_requests for delete to authenticated using (status='draft' and private.has_mrcip_role(organisation_id,array['super_admin','managing_director']));

create policy commodity_samples_select on public.commodity_samples for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy commodity_samples_insert on public.commodity_samples for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy commodity_samples_update on public.commodity_samples for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst'])) with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and updated_by=(select auth.uid()));

create policy sample_custody_events_select on public.sample_custody_events for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy sample_custody_events_insert on public.sample_custody_events for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and created_by=(select auth.uid()));

create policy laboratory_test_orders_select on public.laboratory_test_orders for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy laboratory_test_orders_insert on public.laboratory_test_orders for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy laboratory_test_orders_update on public.laboratory_test_orders for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst'])) with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and updated_by=(select auth.uid()));
create policy laboratory_test_orders_delete on public.laboratory_test_orders for delete to authenticated using (status='draft' and private.has_mrcip_role(organisation_id,array['super_admin','managing_director']));

create policy laboratory_test_results_select on public.laboratory_test_results for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy laboratory_test_results_insert on public.laboratory_test_results for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy laboratory_test_results_update on public.laboratory_test_results for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst'])) with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and updated_by=(select auth.uid()));

create policy laboratory_certificates_select on public.laboratory_certificates for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy laboratory_certificates_insert on public.laboratory_certificates for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy laboratory_certificates_update on public.laboratory_certificates for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst'])) with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and updated_by=(select auth.uid()));

create policy commodity_inspections_select on public.commodity_inspections for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy commodity_inspections_insert on public.commodity_inspections for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy commodity_inspections_update on public.commodity_inspections for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst'])) with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and updated_by=(select auth.uid()));

create policy lab_result_publications_select on public.lab_result_publications for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy lab_result_publications_insert on public.lab_result_publications for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']) and published_by=(select auth.uid()));

revoke all on public.commodity_sampling_requests,public.commodity_samples,public.sample_custody_events,public.laboratory_test_orders,public.laboratory_test_results,public.laboratory_certificates,public.commodity_inspections,public.lab_result_publications from anon,authenticated;
grant select,insert,update,delete on public.commodity_sampling_requests to authenticated;
grant select,insert,update on public.commodity_samples to authenticated;
grant select,insert on public.sample_custody_events to authenticated;
grant select,insert,update,delete on public.laboratory_test_orders to authenticated;
grant select,insert,update on public.laboratory_test_results to authenticated;
grant select,insert,update on public.laboratory_certificates to authenticated;
grant select,insert,update on public.commodity_inspections to authenticated;
grant select,insert on public.lab_result_publications to authenticated;
