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
    if req.opportunity_id is not null and not exists(select 1 from public.opportunity_document_links l where l.organisation_id=c.organisation_id and l.opportunity_id=req.opportunity_id and l.document_id=c.document_id and l.document_role='assay') then
      insert into public.opportunity_document_links(organisation_id,opportunity_id,document_id,document_role,visibility,party_scope,sharing_status,notes,created_by,updated_by)
      values(c.organisation_id,req.opportunity_id,c.document_id,'assay','protected','internal','draft','Verified Stage 7 laboratory certificate',(select auth.uid()),(select auth.uid()));
    end if;
    insert into public.audit_events(organisation_id,entity_type,entity_id,action,summary,metadata,actor_id)
    values(c.organisation_id,'laboratory_certificate',c.id,'verified','Laboratory certificate verified',jsonb_build_object('order_id',c.order_id,'document_id',c.document_id),(select auth.uid()));
    perform set_config('mrcip.lab_verify',coalesce(old_flag,''),true);
  exception when others then perform set_config('mrcip.lab_verify',coalesce(old_flag,''),true); raise; end;
  return 'verified';
end; $$;
revoke all on function public.verify_laboratory_certificate(uuid,text) from public,anon;
grant execute on function public.verify_laboratory_certificate(uuid,text) to authenticated;

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
    if req.opportunity_id is not null and i.evidence_document_id is not null and not exists(select 1 from public.opportunity_document_links l where l.organisation_id=i.organisation_id and l.opportunity_id=req.opportunity_id and l.document_id=i.evidence_document_id and l.document_role='inspection') then
      insert into public.opportunity_document_links(organisation_id,opportunity_id,document_id,document_role,visibility,party_scope,sharing_status,notes,created_by,updated_by)
      values(i.organisation_id,req.opportunity_id,i.evidence_document_id,'inspection','protected','internal','draft','Verified Stage 7 inspection report',(select auth.uid()),(select auth.uid()));
    end if;
    insert into public.audit_events(organisation_id,entity_type,entity_id,action,summary,metadata,actor_id)
    values(i.organisation_id,'commodity_inspection',i.id,'verified','Commodity inspection verified',jsonb_build_object('request_id',i.request_id,'outcome',i.outcome,'evidence_document_id',i.evidence_document_id),(select auth.uid()));
    perform set_config('mrcip.lab_verify',coalesce(old_flag,''),true);
  exception when others then perform set_config('mrcip.lab_verify',coalesce(old_flag,''),true); raise; end;
  return 'verified';
end; $$;
revoke all on function public.verify_commodity_inspection(uuid,text) from public,anon;
grant execute on function public.verify_commodity_inspection(uuid,text) to authenticated;
