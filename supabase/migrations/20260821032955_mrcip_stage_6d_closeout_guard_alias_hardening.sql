create or replace function private.guard_commission_schedule_approval()
returns trigger language plpgsql security definer set search_path=''
as $$
declare share_total numeric; allocation_count integer; bad_allocations integer; chain_row public.facilitator_chains%rowtype; protection_row public.opportunity_protection_records%rowtype; trigger_ok boolean;
begin
  new.updated_at:=now();
  if new.status='approved' and old.status is distinct from 'approved' then
    if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role to approve commission schedule' using errcode='42501'; end if;
    select * into chain_row from public.facilitator_chains where id=new.facilitator_chain_id and organisation_id=new.organisation_id;
    if not found or chain_row.opportunity_id<>new.opportunity_id or chain_row.status<>'approved' then raise exception 'Commission schedule requires an approved facilitator chain for the same opportunity'; end if;
    if new.fee_protection_record_id is null then raise exception 'Approved commission schedule requires a fee-protection record'; end if;
    select * into protection_row from public.opportunity_protection_records where id=new.fee_protection_record_id and organisation_id=new.organisation_id;
    if not found or protection_row.opportunity_id<>new.opportunity_id or protection_row.record_type<>'fee_protection' or protection_row.status not in ('executed','verified') or (protection_row.expiry_date is not null and protection_row.expiry_date<current_date) then raise exception 'Fee-protection record must belong to the opportunity and be executed/verified and current'; end if;
    if exists(select 1 from public.commission_schedules s where s.organisation_id=new.organisation_id and s.opportunity_id=new.opportunity_id and s.id<>new.id and s.status in ('payable','partially_paid','paid')) then raise exception 'A crystallised/paid commission schedule cannot be superseded'; end if;
    select count(*),coalesce(sum(pool_share_percent),0),count(*) filter(where allocation_basis<>new.pool_basis or abs(allocation_value-round((new.pool_value*pool_share_percent/100.0)::numeric,6))>0.000001)
      into allocation_count,share_total,bad_allocations from public.commission_allocations a where a.schedule_id=new.id and a.organisation_id=new.organisation_id;
    if allocation_count=0 then raise exception 'Commission schedule requires at least one allocation'; end if;
    if abs(share_total-100.0)>0.000001 then raise exception 'Commission allocation shares must total exactly 100%%; current total is %',share_total; end if;
    if bad_allocations>0 then raise exception 'Commission allocation values are inconsistent with the approved pool'; end if;
    if exists(select 1 from public.commission_allocations a join public.facilitator_chain_members m on m.organisation_id=a.organisation_id and m.id=a.facilitator_member_id where a.schedule_id=new.id and a.organisation_id=new.organisation_id and (m.chain_id<>new.facilitator_chain_id or not m.commission_entitled or m.authority_status not in ('verified','not_required') or m.protected_status not in ('protected','waived'))) then raise exception 'Every allocated facilitator must belong to the approved chain, be commission-entitled, authorised and protected'; end if;
    update public.commission_schedules s set status='superseded',updated_at=now(),updated_by=(select auth.uid()) where s.organisation_id=new.organisation_id and s.opportunity_id=new.opportunity_id and s.id<>new.id and s.status='approved';
    new.approved_at:=now(); new.approved_by:=(select auth.uid()); new.effective_date:=coalesce(new.effective_date,current_date);
  end if;
  if new.status='payable' and old.status is distinct from 'payable' then
    if old.status not in ('approved','partially_paid','paid') then raise exception 'Commission schedule can become payable only from approved/settlement states'; end if;
    select exists(select 1 from public.commission_trigger_events e where e.organisation_id=new.organisation_id and e.schedule_id=new.id and e.event_type=new.payment_trigger and e.status='verified') into trigger_ok;
    if not trigger_ok then raise exception 'Commission schedule cannot become payable until its payment trigger is verified'; end if;
  end if;
  if new.status='partially_paid' and old.status is distinct from 'partially_paid' then
    if not exists(select 1 from public.commission_settlement_entries e where e.organisation_id=new.organisation_id and e.schedule_id=new.id and e.status='verified') then raise exception 'Commission schedule cannot become partially paid without a verified settlement payout'; end if;
  end if;
  if new.status='paid' and old.status is distinct from 'paid' then
    if new.pool_basis='fixed_amount' then
      if not exists(select 1 from public.commission_settlement_batches b where b.organisation_id=new.organisation_id and b.schedule_id=new.id and b.pool_basis='fixed_amount' and b.status='settled') then raise exception 'Fixed commission schedule cannot be paid until its settlement batch is fully settled'; end if;
    else
      if not exists(select 1 from public.commission_schedule_closeouts co where co.organisation_id=new.organisation_id and co.schedule_id=new.id and co.status='approved') then raise exception 'Recurring commission schedule requires an approved closeout before final paid status'; end if;
      if not exists(select 1 from public.commission_settlement_batches b where b.organisation_id=new.organisation_id and b.schedule_id=new.id and b.status not in ('cancelled','rejected')) then raise exception 'Recurring commission schedule cannot close without settlement cycles'; end if;
      if exists(select 1 from public.commission_settlement_batches b where b.organisation_id=new.organisation_id and b.schedule_id=new.id and b.status not in ('settled','cancelled','rejected')) then raise exception 'Recurring commission schedule cannot close while settlement cycles remain outstanding'; end if;
    end if;
  end if;
  return new;
end; $$;
revoke all on function private.guard_commission_schedule_approval() from public,anon,authenticated;