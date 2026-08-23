create or replace function private.guard_facilitator_chain_approval()
returns trigger language plpgsql security definer set search_path=''
as $$
declare bad_count integer; member_count integer;
begin
  new.updated_at := now();
  if new.status='approved' and old.status is distinct from 'approved' then
    if not private.has_mrcip_role(new.organisation_id, array['super_admin','managing_director','legal_compliance']) then raise exception 'Only executive/legal roles may approve a facilitator chain' using errcode='42501'; end if;
    select count(*), count(*) filter (where authority_status not in ('verified','not_required') or protected_status not in ('protected','waived')) into member_count,bad_count
    from public.facilitator_chain_members m where m.chain_id=new.id and m.organisation_id=new.organisation_id;
    if member_count=0 then raise exception 'Facilitator chain cannot be approved without participants'; end if;
    if bad_count>0 then raise exception 'Every facilitator-chain participant must have verified/not-required authority and protected/waived protection status before approval'; end if;
    update public.facilitator_chains c set status='superseded',updated_at=now(),updated_by=(select auth.uid())
      where c.organisation_id=new.organisation_id and c.opportunity_id=new.opportunity_id and c.id<>new.id and c.status='approved';
    new.approved_at:=now(); new.approved_by:=(select auth.uid());
  end if;
  if old.status in ('approved','superseded') then
    if new.opportunity_id is distinct from old.opportunity_id or new.revision_no is distinct from old.revision_no or new.previous_chain_id is distinct from old.previous_chain_id or new.amendment_reason is distinct from old.amendment_reason then
      raise exception 'Approved/superseded facilitator chains are immutable; create a revision';
    end if;
  end if;
  return new;
end; $$;

create or replace function public.create_facilitator_chain_revision(p_chain_id uuid,p_reason text default '')
returns uuid language plpgsql set search_path=''
as $$
declare oldc public.facilitator_chains%rowtype; new_id uuid:=gen_random_uuid(); next_rev integer; r record; new_member_id uuid; id_map jsonb:='{}'::jsonb;
begin
  select * into oldc from public.facilitator_chains where id=p_chain_id; if not found then raise exception 'Facilitator chain not found'; end if;
  if not private.has_mrcip_role(oldc.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']) then raise exception 'Insufficient role' using errcode='42501'; end if;
  if oldc.status not in ('approved','superseded') then raise exception 'Only an approved/superseded chain may be revised'; end if;
  select coalesce(max(revision_no),0)+1 into next_rev from public.facilitator_chains where organisation_id=oldc.organisation_id and opportunity_id=oldc.opportunity_id;
  insert into public.facilitator_chains(id,organisation_id,opportunity_id,revision_no,previous_chain_id,status,amendment_reason,created_by,updated_by)
  values(new_id,oldc.organisation_id,oldc.opportunity_id,next_rev,oldc.id,'draft',coalesce(p_reason,''),(select auth.uid()),(select auth.uid()));
  for r in select * from public.facilitator_chain_members where organisation_id=oldc.organisation_id and chain_id=oldc.id order by created_at,id loop
    new_member_id:=gen_random_uuid(); id_map:=id_map||jsonb_build_object(r.id::text,new_member_id::text);
    insert into public.facilitator_chain_members(id,organisation_id,chain_id,participant_counterparty_id,participant_contact_id,display_name,company_name,role,represents,represents_counterparty_id,authority_status,protected_status,commission_entitled,notes,created_by,updated_by)
    values(new_member_id,r.organisation_id,new_id,r.participant_counterparty_id,r.participant_contact_id,r.display_name,r.company_name,r.role,r.represents,r.represents_counterparty_id,r.authority_status,r.protected_status,r.commission_entitled,r.notes,(select auth.uid()),(select auth.uid()));
  end loop;
  for r in select id,introduced_by_member_id from public.facilitator_chain_members where organisation_id=oldc.organisation_id and chain_id=oldc.id and introduced_by_member_id is not null loop
    update public.facilitator_chain_members set introduced_by_member_id=(id_map->>r.introduced_by_member_id::text)::uuid,updated_by=(select auth.uid())
      where organisation_id=oldc.organisation_id and chain_id=new_id and id=(id_map->>r.id::text)::uuid;
  end loop;
  return new_id;
end; $$;

create or replace function private.guard_commission_schedule_approval()
returns trigger language plpgsql security definer set search_path=''
as $$
declare share_total numeric; allocation_count integer; bad_allocations integer; c public.facilitator_chains%rowtype; p public.opportunity_protection_records%rowtype; trigger_ok boolean;
begin
  new.updated_at:=now();
  if new.status='approved' and old.status is distinct from 'approved' then
    if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role to approve commission schedule' using errcode='42501'; end if;
    select * into c from public.facilitator_chains where id=new.facilitator_chain_id and organisation_id=new.organisation_id;
    if not found or c.opportunity_id<>new.opportunity_id or c.status<>'approved' then raise exception 'Commission schedule requires an approved facilitator chain for the same opportunity'; end if;
    if new.fee_protection_record_id is null then raise exception 'Approved commission schedule requires a fee-protection record'; end if;
    select * into p from public.opportunity_protection_records where id=new.fee_protection_record_id and organisation_id=new.organisation_id;
    if not found or p.opportunity_id<>new.opportunity_id or p.record_type<>'fee_protection' or p.status not in ('executed','verified') or (p.expiry_date is not null and p.expiry_date<current_date) then raise exception 'Fee-protection record must belong to the opportunity and be executed/verified and current'; end if;
    if exists(select 1 from public.commission_schedules s where s.organisation_id=new.organisation_id and s.opportunity_id=new.opportunity_id and s.id<>new.id and s.status in ('payable','partially_paid','paid')) then raise exception 'A crystallised/paid commission schedule cannot be superseded'; end if;
    select count(*),coalesce(sum(pool_share_percent),0),count(*) filter(where allocation_basis<>new.pool_basis or abs(allocation_value-round((new.pool_value*pool_share_percent/100.0)::numeric,6))>0.000001)
      into allocation_count,share_total,bad_allocations from public.commission_allocations a where a.schedule_id=new.id and a.organisation_id=new.organisation_id;
    if allocation_count=0 then raise exception 'Commission schedule requires at least one allocation'; end if;
    if abs(share_total-100.0)>0.000001 then raise exception 'Commission allocation shares must total exactly 100%%; current total is %',share_total; end if;
    if bad_allocations>0 then raise exception 'Commission allocation values are inconsistent with the approved pool'; end if;
    if exists(select 1 from public.commission_allocations a join public.facilitator_chain_members m on m.organisation_id=a.organisation_id and m.id=a.facilitator_member_id
              where a.schedule_id=new.id and a.organisation_id=new.organisation_id and (m.chain_id<>new.facilitator_chain_id or not m.commission_entitled or m.authority_status not in ('verified','not_required') or m.protected_status not in ('protected','waived'))) then
      raise exception 'Every allocated facilitator must belong to the approved chain, be commission-entitled, authorised and protected';
    end if;
    update public.commission_schedules s set status='superseded',updated_at=now(),updated_by=(select auth.uid()) where s.organisation_id=new.organisation_id and s.opportunity_id=new.opportunity_id and s.id<>new.id and s.status='approved';
    new.approved_at:=now(); new.approved_by:=(select auth.uid()); new.effective_date:=coalesce(new.effective_date,current_date);
  end if;
  if new.status='payable' and old.status is distinct from 'payable' then
    if old.status<>'approved' then raise exception 'Commission schedule can become payable only from approved status'; end if;
    select exists(select 1 from public.commission_trigger_events e where e.organisation_id=new.organisation_id and e.schedule_id=new.id and e.event_type=new.payment_trigger and e.status='verified') into trigger_ok;
    if not trigger_ok then raise exception 'Commission schedule cannot become payable until its payment trigger is verified'; end if;
  end if;
  if new.status in ('partially_paid','paid') and old.status is distinct from new.status then raise exception 'Commission settlement status requires the dedicated settlement workflow'; end if;
  return new;
end; $$;

create or replace function public.approve_commission_schedule(p_schedule_id uuid)
returns boolean language plpgsql set search_path=''
as $$
declare s public.commission_schedules%rowtype;
begin
  select * into s from public.commission_schedules where id=p_schedule_id; if not found then raise exception 'Commission schedule not found'; end if;
  if not private.has_mrcip_role(s.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role' using errcode='42501'; end if;
  update public.commission_allocations set entitlement_status='protected',updated_by=(select auth.uid()) where schedule_id=s.id and organisation_id=s.organisation_id;
  update public.commission_schedules set status='approved',updated_by=(select auth.uid()) where id=s.id;
  return true;
end; $$;

create or replace function private.guard_commission_trigger_event()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  new.updated_at:=now();
  if new.status='verified' and old.status is distinct from 'verified' then
    if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role to verify commission trigger' using errcode='42501'; end if;
    if new.occurred_at is null then raise exception 'Trigger event occurrence time is required before verification'; end if;
    if new.evidence_document_id is null and new.finance_document_id is null and new.payment_id is null and nullif(btrim(new.event_reference),'') is null then raise exception 'Trigger verification requires evidence, finance/payment linkage, or a reference'; end if;
    new.verified_at:=now(); new.verified_by:=(select auth.uid());
  end if;
  return new;
end; $$;
revoke all on function private.guard_commission_trigger_event() from public,anon,authenticated;
create trigger commission_trigger_events_verification_guard before update on public.commission_trigger_events for each row execute function private.guard_commission_trigger_event();

create or replace function private.validate_commission_finance_link()
returns trigger language plpgsql security definer set search_path=''
as $$
declare alloc_schedule uuid;
begin
  if new.allocation_id is not null then
    select schedule_id into alloc_schedule from public.commission_allocations where id=new.allocation_id and organisation_id=new.organisation_id;
    if alloc_schedule is distinct from new.schedule_id then raise exception 'Commission allocation must belong to the linked schedule'; end if;
  end if;
  return new;
end; $$;
revoke all on function private.validate_commission_finance_link() from public,anon,authenticated;
create trigger commission_finance_links_validate_bi before insert on public.commission_finance_links for each row execute function private.validate_commission_finance_link();