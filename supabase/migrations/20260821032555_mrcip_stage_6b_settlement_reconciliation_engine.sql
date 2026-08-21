create or replace function private.sync_commission_allocation()
returns trigger language plpgsql security definer set search_path=''
as $$
declare s public.commission_schedules%rowtype; m public.facilitator_chain_members%rowtype; reconcile_mode boolean := coalesce(current_setting('mrcip.settlement_reconcile', true),'')='on';
begin
  select * into s from public.commission_schedules where id=new.schedule_id and organisation_id=new.organisation_id;
  if not found then raise exception 'Commission schedule not found'; end if;
  if tg_op='UPDATE' and s.status in ('approved','superseded','payable','partially_paid','paid') and not reconcile_mode then
    raise exception 'Approved/crystallised commission allocations are immutable; use the controlled settlement workflow';
  end if;
  select * into m from public.facilitator_chain_members where id=new.facilitator_member_id and organisation_id=new.organisation_id;
  if not found or m.chain_id <> s.facilitator_chain_id then raise exception 'Commission allocation member must belong to the schedule facilitator chain'; end if;
  if not m.commission_entitled then raise exception 'Facilitator member is not marked commission-entitled'; end if;
  if reconcile_mode and tg_op='UPDATE' then
    if new.schedule_id is distinct from old.schedule_id or new.facilitator_member_id is distinct from old.facilitator_member_id
       or new.pool_share_percent is distinct from old.pool_share_percent or new.payment_trigger_override is distinct from old.payment_trigger_override
       or new.notes is distinct from old.notes then
      raise exception 'Settlement reconciliation may update entitlement status only';
    end if;
  end if;
  new.allocation_basis := s.pool_basis;
  new.allocation_value := round((s.pool_value * new.pool_share_percent / 100.0)::numeric, 6);
  new.updated_at := now();
  return new;
end; $$;
revoke all on function private.sync_commission_allocation() from public,anon,authenticated;

create or replace function private.sync_commission_settlement_batch()
returns trigger language plpgsql security definer set search_path=''
as $$
declare s public.commission_schedules%rowtype; reconcile_mode boolean := coalesce(current_setting('mrcip.settlement_reconcile', true),'')='on';
begin
  select * into s from public.commission_schedules where id=new.schedule_id and organisation_id=new.organisation_id;
  if not found then raise exception 'Commission schedule not found'; end if;
  if tg_op='INSERT' and s.status not in ('payable','partially_paid') then raise exception 'Settlement batch requires a payable or partially-paid commission schedule'; end if;
  if tg_op='UPDATE' and s.status not in ('payable','partially_paid','paid') then raise exception 'Settlement batch is not compatible with the commission schedule status'; end if;

  if tg_op='UPDATE' and old.status in ('approved','partially_settled','settled') then
    if new.schedule_id is distinct from old.schedule_id or new.cycle_no is distinct from old.cycle_no or new.settlement_reference is distinct from old.settlement_reference
       or new.transaction_basis_amount is distinct from old.transaction_basis_amount or new.quantity_basis_mt is distinct from old.quantity_basis_mt
       or new.period_start is distinct from old.period_start or new.period_end is distinct from old.period_end
       or new.source_finance_document_id is distinct from old.source_finance_document_id or new.source_payment_id is distinct from old.source_payment_id
       or new.evidence_document_id is distinct from old.evidence_document_id or new.source_reference is distinct from old.source_reference then
      raise exception 'Approved settlement basis/source fields are immutable';
    end if;
  end if;
  if tg_op='UPDATE' and not reconcile_mode and (new.amount_paid is distinct from old.amount_paid or new.balance_due is distinct from old.balance_due or new.status in ('partially_settled','settled') and new.status is distinct from old.status) then
    raise exception 'Settlement totals/status are derived by reconciliation and cannot be edited directly';
  end if;

  new.pool_basis := s.pool_basis;
  new.pool_rate := s.pool_value;
  new.currency := s.currency;
  if s.pool_basis='fixed_amount' then
    new.transaction_basis_amount := null;
    new.quantity_basis_mt := null;
    new.pool_amount := round(s.pool_value::numeric,6);
  elsif s.pool_basis='per_metric_tonne' then
    if new.quantity_basis_mt is null or new.quantity_basis_mt <= 0 then raise exception 'Per-metric-tonne settlement requires a positive actual quantity basis'; end if;
    new.transaction_basis_amount := null;
    new.pool_amount := round((s.pool_value * new.quantity_basis_mt)::numeric,6);
  elsif s.pool_basis='percent_of_transaction' then
    if new.transaction_basis_amount is null or new.transaction_basis_amount <= 0 then raise exception 'Percentage settlement requires a positive transaction value basis'; end if;
    new.quantity_basis_mt := null;
    new.pool_amount := round((s.pool_value * new.transaction_basis_amount / 100.0)::numeric,6);
  end if;
  if tg_op='INSERT' then
    new.amount_paid := 0;
    new.balance_due := new.pool_amount;
  elsif not reconcile_mode then
    new.balance_due := old.balance_due;
    new.amount_paid := old.amount_paid;
  end if;
  new.updated_at := now();
  return new;
end; $$;
revoke all on function private.sync_commission_settlement_batch() from public,anon,authenticated;
create trigger commission_settlement_batches_sync_biu before insert or update on public.commission_settlement_batches for each row execute function private.sync_commission_settlement_batch();

create or replace function private.seed_commission_settlement_items()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  perform set_config('mrcip.settlement_seed','on',true);
  insert into public.commission_settlement_items(organisation_id,batch_id,schedule_id,allocation_id,facilitator_member_id,pool_share_percent,currency,amount_due,amount_paid,balance_due,status,created_by,updated_by)
  select a.organisation_id,new.id,new.schedule_id,a.id,a.facilitator_member_id,a.pool_share_percent,new.currency,
         round((new.pool_amount*a.pool_share_percent/100.0)::numeric,6),0,round((new.pool_amount*a.pool_share_percent/100.0)::numeric,6),'pending',(select auth.uid()),(select auth.uid())
  from public.commission_allocations a where a.organisation_id=new.organisation_id and a.schedule_id=new.schedule_id;
  return new;
end; $$;
revoke all on function private.seed_commission_settlement_items() from public,anon,authenticated;
create trigger commission_settlement_batches_seed_ai after insert on public.commission_settlement_batches for each row execute function private.seed_commission_settlement_items();

create or replace function private.validate_commission_settlement_item()
returns trigger language plpgsql security definer set search_path=''
as $$
declare b public.commission_settlement_batches%rowtype; a public.commission_allocations%rowtype; seed_mode boolean := coalesce(current_setting('mrcip.settlement_seed',true),'')='on'; reconcile_mode boolean := coalesce(current_setting('mrcip.settlement_reconcile',true),'')='on'; expected_due numeric;
begin
  select * into b from public.commission_settlement_batches where id=new.batch_id and organisation_id=new.organisation_id;
  if not found then raise exception 'Settlement batch not found'; end if;
  select * into a from public.commission_allocations where id=new.allocation_id and organisation_id=new.organisation_id;
  if not found then raise exception 'Commission allocation not found'; end if;
  if a.schedule_id<>b.schedule_id or new.schedule_id<>b.schedule_id or new.facilitator_member_id<>a.facilitator_member_id then raise exception 'Settlement item allocation/schedule/member mismatch'; end if;
  expected_due:=round((b.pool_amount*a.pool_share_percent/100.0)::numeric,6);
  if tg_op='INSERT' and not seed_mode then raise exception 'Settlement items are generated from approved commission allocations'; end if;
  if tg_op='INSERT' then
    new.pool_share_percent:=a.pool_share_percent; new.currency:=b.currency; new.amount_due:=expected_due; new.amount_paid:=0; new.balance_due:=expected_due; new.status:='pending';
  else
    if not reconcile_mode and (new.batch_id is distinct from old.batch_id or new.schedule_id is distinct from old.schedule_id or new.allocation_id is distinct from old.allocation_id
       or new.facilitator_member_id is distinct from old.facilitator_member_id or new.pool_share_percent is distinct from old.pool_share_percent or new.currency is distinct from old.currency
       or new.amount_due is distinct from old.amount_due or new.amount_paid is distinct from old.amount_paid or new.balance_due is distinct from old.balance_due or new.status is distinct from old.status) then
      raise exception 'Settlement item financial/status fields are system-derived';
    end if;
  end if;
  new.updated_at:=now();
  return new;
end; $$;
revoke all on function private.validate_commission_settlement_item() from public,anon,authenticated;
create trigger commission_settlement_items_validate_biu before insert or update on public.commission_settlement_items for each row execute function private.validate_commission_settlement_item();

create or replace function private.guard_commission_settlement_batch()
returns trigger language plpgsql security definer set search_path=''
as $$
declare item_count integer; share_total numeric; due_total numeric; reconcile_mode boolean := coalesce(current_setting('mrcip.settlement_reconcile',true),'')='on';
begin
  if tg_op='DELETE' then
    if old.status in ('approved','partially_settled','settled') then raise exception 'Approved/settled commission settlement batches cannot be deleted'; end if;
    return old;
  end if;
  if new.status='approved' and old.status is distinct from 'approved' then
    if old.status not in ('draft','pending_approval') then raise exception 'Only draft/pending settlement batches may be approved'; end if;
    if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role to approve commission settlement' using errcode='42501'; end if;
    if new.pool_amount<=0 then raise exception 'Settlement pool amount must be positive before approval'; end if;
    if new.source_finance_document_id is null and new.source_payment_id is null and new.evidence_document_id is null and nullif(btrim(new.source_reference),'') is null then
      raise exception 'Settlement approval requires source Finance/Payment/evidence linkage or a source reference';
    end if;
    select count(*),coalesce(sum(pool_share_percent),0),coalesce(sum(amount_due),0) into item_count,share_total,due_total
      from public.commission_settlement_items where organisation_id=new.organisation_id and batch_id=new.id;
    if item_count=0 then raise exception 'Settlement batch has no commission allocation items'; end if;
    if abs(share_total-100.0)>0.000001 then raise exception 'Settlement item shares must total exactly 100%%'; end if;
    if abs(due_total-new.pool_amount)>0.000001 then raise exception 'Settlement item amounts do not reconcile to the pool amount'; end if;
    new.approved_at:=now(); new.approved_by:=(select auth.uid());
  end if;
  if new.status in ('partially_settled','settled') and new.status is distinct from old.status and not reconcile_mode then raise exception 'Settlement completion status is controlled by verified payout reconciliation'; end if;
  if old.status in ('approved','partially_settled','settled') and new.status in ('cancelled','rejected') and new.status is distinct from old.status then
    if exists(select 1 from public.commission_settlement_entries e where e.organisation_id=new.organisation_id and e.batch_id=new.id and e.status='verified') then raise exception 'A settlement batch with verified payouts cannot be cancelled/rejected'; end if;
  end if;
  return new;
end; $$;
revoke all on function private.guard_commission_settlement_batch() from public,anon,authenticated;
create trigger commission_settlement_batches_guard_bud before update or delete on public.commission_settlement_batches for each row execute function private.guard_commission_settlement_batch();

create or replace function private.guard_commission_settlement_entry()
returns trigger language plpgsql security definer set search_path=''
as $$
declare i public.commission_settlement_items%rowtype; b public.commission_settlement_batches%rowtype; prior_verified numeric;
begin
  if tg_op='DELETE' then
    if old.status in ('verified','reversed') then raise exception 'Verified/reversed settlement entries cannot be deleted'; end if;
    return old;
  end if;
  select * into i from public.commission_settlement_items where id=new.item_id and organisation_id=new.organisation_id;
  if not found then raise exception 'Settlement item not found'; end if;
  select * into b from public.commission_settlement_batches where id=new.batch_id and organisation_id=new.organisation_id;
  if not found then raise exception 'Settlement batch not found'; end if;
  if new.batch_id<>i.batch_id or new.schedule_id<>i.schedule_id or new.allocation_id<>i.allocation_id or b.id<>i.batch_id then raise exception 'Settlement entry item/batch/schedule/allocation mismatch'; end if;
  if new.currency<>i.currency then raise exception 'Settlement entry currency must match settlement item currency'; end if;
  if tg_op='INSERT' then
    if b.status not in ('approved','partially_settled') then raise exception 'Payout entries require an approved/partially-settled batch'; end if;
    if new.status<>'pending' then raise exception 'New settlement entries must start pending verification'; end if;
  else
    if new.item_id is distinct from old.item_id or new.batch_id is distinct from old.batch_id or new.schedule_id is distinct from old.schedule_id or new.allocation_id is distinct from old.allocation_id
       or new.amount is distinct from old.amount or new.currency is distinct from old.currency or new.payment_date is distinct from old.payment_date then
      raise exception 'Settlement entry commercial fields are immutable';
    end if;
    if old.status='pending' and new.status='verified' then
      if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role to verify settlement payout' using errcode='42501'; end if;
      if new.evidence_document_id is null and new.finance_document_id is null and new.payment_id is null and nullif(btrim(new.payment_reference),'') is null then raise exception 'Verified payout requires evidence, Finance/Payment linkage, or payment reference'; end if;
      select coalesce(sum(amount),0) into prior_verified from public.commission_settlement_entries where organisation_id=new.organisation_id and item_id=new.item_id and status='verified' and id<>new.id;
      if prior_verified+new.amount > i.amount_due+0.000001 then raise exception 'Verified payout would exceed settlement item amount due'; end if;
      new.verified_at:=now(); new.verified_by:=(select auth.uid());
    elsif old.status='pending' and new.status='rejected' then
      if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role to reject settlement payout' using errcode='42501'; end if;
    elsif old.status='verified' and new.status='reversed' then
      if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role to reverse settlement payout' using errcode='42501'; end if;
      if nullif(btrim(new.reversal_reason),'') is null then raise exception 'Settlement payout reversal requires a reason'; end if;
      new.reversed_at:=now(); new.reversed_by:=(select auth.uid());
    elsif new.status is distinct from old.status then
      raise exception 'Invalid settlement entry status transition';
    end if;
    if old.status in ('verified','reversed','rejected') and new.status=old.status then
      if new.payment_reference is distinct from old.payment_reference or new.payment_method is distinct from old.payment_method or new.evidence_document_id is distinct from old.evidence_document_id
         or new.finance_document_id is distinct from old.finance_document_id or new.payment_id is distinct from old.payment_id then
        raise exception 'Verified/reversed/rejected settlement evidence fields are immutable';
      end if;
    end if;
  end if;
  new.updated_at:=now();
  return new;
end; $$;
revoke all on function private.guard_commission_settlement_entry() from public,anon,authenticated;
create trigger commission_settlement_entries_guard_biud before insert or update or delete on public.commission_settlement_entries for each row execute function private.guard_commission_settlement_entry();

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
      if not exists(select 1 from public.commission_schedule_closeouts c where c.organisation_id=new.organisation_id and c.schedule_id=new.id and c.status='approved') then raise exception 'Recurring commission schedule requires an approved closeout before final paid status'; end if;
      if not exists(select 1 from public.commission_settlement_batches b where b.organisation_id=new.organisation_id and b.schedule_id=new.id and b.status not in ('cancelled','rejected')) then raise exception 'Recurring commission schedule cannot close without settlement cycles'; end if;
      if exists(select 1 from public.commission_settlement_batches b where b.organisation_id=new.organisation_id and b.schedule_id=new.id and b.status not in ('settled','cancelled','rejected')) then raise exception 'Recurring commission schedule cannot close while settlement cycles remain outstanding'; end if;
    end if;
  end if;
  return new;
end; $$;
revoke all on function private.guard_commission_schedule_approval() from public,anon,authenticated;

create or replace function private.reconcile_commission_settlement_batch(p_batch_id uuid)
returns void language plpgsql security definer set search_path=''
as $$
declare b public.commission_settlement_batches%rowtype; s public.commission_schedules%rowtype; paid_total numeric; due_total numeric; new_batch_status text; new_schedule_status text; has_any_verified boolean; has_closeout boolean; has_open_batches boolean;
begin
  select * into b from public.commission_settlement_batches where id=p_batch_id;
  if not found then return; end if;
  select * into s from public.commission_schedules where id=b.schedule_id and organisation_id=b.organisation_id;
  if not found then return; end if;
  perform set_config('mrcip.settlement_reconcile','on',true);

  update public.commission_settlement_items i set
    amount_paid=x.paid,
    balance_due=greatest(round((i.amount_due-x.paid)::numeric,6),0),
    status=case when x.paid>=i.amount_due-0.000001 then 'paid' when x.paid>0 then 'partially_paid' when b.status in ('approved','partially_settled','settled') then 'payable' else 'pending' end,
    updated_at=now(), updated_by=coalesce((select auth.uid()),i.updated_by)
  from (
    select i2.id,coalesce(sum(e.amount) filter(where e.status='verified'),0)::numeric as paid
    from public.commission_settlement_items i2 left join public.commission_settlement_entries e on e.organisation_id=i2.organisation_id and e.item_id=i2.id
    where i2.organisation_id=b.organisation_id and i2.batch_id=b.id group by i2.id
  ) x where i.id=x.id;

  select coalesce(sum(amount_due),0),coalesce(sum(amount_paid),0) into due_total,paid_total from public.commission_settlement_items where organisation_id=b.organisation_id and batch_id=b.id;
  new_batch_status:=case when b.status in ('cancelled','rejected') then b.status when due_total>0 and paid_total>=due_total-0.000001 then 'settled' when paid_total>0 then 'partially_settled' when b.status in ('approved','partially_settled','settled') then 'approved' else b.status end;
  update public.commission_settlement_batches set amount_paid=round(paid_total,6),balance_due=greatest(round((pool_amount-paid_total)::numeric,6),0),status=new_batch_status,updated_at=now(),updated_by=coalesce((select auth.uid()),updated_by) where id=b.id;

  select exists(select 1 from public.commission_settlement_entries e where e.organisation_id=b.organisation_id and e.schedule_id=b.schedule_id and e.status='verified') into has_any_verified;
  if s.pool_basis='fixed_amount' then
    new_schedule_status:=case when new_batch_status='settled' then 'paid' when has_any_verified then 'partially_paid' else 'payable' end;
  else
    select exists(select 1 from public.commission_schedule_closeouts c where c.organisation_id=b.organisation_id and c.schedule_id=b.schedule_id and c.status='approved') into has_closeout;
    select exists(select 1 from public.commission_settlement_batches bx where bx.organisation_id=b.organisation_id and bx.schedule_id=b.schedule_id and bx.status not in ('settled','cancelled','rejected')) into has_open_batches;
    new_schedule_status:=case when has_closeout and not has_open_batches then 'paid' when has_any_verified then 'partially_paid' else 'payable' end;
  end if;
  update public.commission_schedules set status=new_schedule_status,updated_at=now(),updated_by=coalesce((select auth.uid()),updated_by) where id=s.id;

  update public.commission_allocations a set entitlement_status=q.new_status,updated_by=coalesce((select auth.uid()),a.updated_by)
  from (
    select a2.id,case when new_schedule_status='paid' then 'paid' when coalesce(sum(si.amount_paid),0)>0 then 'partially_paid' when coalesce(sum(si.amount_due),0)>0 then 'payable' else 'protected' end as new_status
    from public.commission_allocations a2 left join public.commission_settlement_items si on si.organisation_id=a2.organisation_id and si.allocation_id=a2.id
      left join public.commission_settlement_batches sb on sb.organisation_id=si.organisation_id and sb.id=si.batch_id and sb.status not in ('cancelled','rejected')
    where a2.organisation_id=b.organisation_id and a2.schedule_id=b.schedule_id
    group by a2.id
  ) q where a.id=q.id;
end; $$;
revoke all on function private.reconcile_commission_settlement_batch(uuid) from public,anon,authenticated;

create or replace function private.reconcile_after_settlement_entry()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if tg_op='DELETE' then perform private.reconcile_commission_settlement_batch(old.batch_id); return old; end if;
  if tg_op='INSERT' or new.status is distinct from old.status then perform private.reconcile_commission_settlement_batch(new.batch_id); end if;
  return new;
end; $$;
revoke all on function private.reconcile_after_settlement_entry() from public,anon,authenticated;
create trigger commission_settlement_entries_reconcile_aiud after insert or update or delete on public.commission_settlement_entries for each row execute function private.reconcile_after_settlement_entry();

create or replace function private.reconcile_after_batch_approval()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if new.status='approved' and old.status is distinct from 'approved' then perform private.reconcile_commission_settlement_batch(new.id); end if;
  return new;
end; $$;
revoke all on function private.reconcile_after_batch_approval() from public,anon,authenticated;
create trigger commission_settlement_batches_reconcile_au after update on public.commission_settlement_batches for each row execute function private.reconcile_after_batch_approval();

create or replace function private.finalise_commission_schedule_closeout()
returns trigger language plpgsql security definer set search_path=''
as $$
declare s public.commission_schedules%rowtype;
begin
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role to close commission schedule' using errcode='42501'; end if;
  select * into s from public.commission_schedules where id=new.schedule_id and organisation_id=new.organisation_id;
  if not found then raise exception 'Commission schedule not found'; end if;
  if s.pool_basis='fixed_amount' then raise exception 'Fixed-amount commission schedules close automatically after full settlement'; end if;
  if s.status not in ('payable','partially_paid') then raise exception 'Recurring commission schedule must be payable/partially paid before closeout'; end if;
  if not exists(select 1 from public.commission_settlement_batches b where b.organisation_id=new.organisation_id and b.schedule_id=new.schedule_id and b.status not in ('cancelled','rejected')) then raise exception 'Closeout requires at least one settlement cycle'; end if;
  if exists(select 1 from public.commission_settlement_batches b where b.organisation_id=new.organisation_id and b.schedule_id=new.schedule_id and b.status not in ('settled','cancelled','rejected')) then raise exception 'All settlement cycles must be fully settled before closeout'; end if;
  perform set_config('mrcip.settlement_reconcile','on',true);
  update public.commission_schedules set status='paid',updated_at=now(),updated_by=coalesce((select auth.uid()),updated_by) where id=new.schedule_id;
  update public.commission_allocations set entitlement_status='paid',updated_by=coalesce((select auth.uid()),updated_by) where organisation_id=new.organisation_id and schedule_id=new.schedule_id;
  return new;
end; $$;
revoke all on function private.finalise_commission_schedule_closeout() from public,anon,authenticated;
create trigger commission_schedule_closeouts_finalise_ai after insert on public.commission_schedule_closeouts for each row when (new.status='approved') execute function private.finalise_commission_schedule_closeout();

create or replace function public.create_commission_settlement_batch(
  p_schedule_id uuid,
  p_transaction_basis_amount numeric default null,
  p_quantity_basis_mt numeric default null,
  p_source_finance_document_id uuid default null,
  p_source_payment_id uuid default null,
  p_evidence_document_id uuid default null,
  p_source_reference text default '',
  p_period_start date default null,
  p_period_end date default null,
  p_notes text default ''
) returns uuid language plpgsql set search_path=''
as $$
declare s public.commission_schedules%rowtype; new_id uuid:=gen_random_uuid(); next_cycle integer; ref text;
begin
  select * into s from public.commission_schedules where id=p_schedule_id; if not found then raise exception 'Commission schedule not found'; end if;
  if not private.has_mrcip_role(s.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role' using errcode='42501'; end if;
  if s.status not in ('payable','partially_paid') then raise exception 'Commission schedule is not ready for settlement'; end if;
  select coalesce(max(cycle_no),0)+1 into next_cycle from public.commission_settlement_batches where organisation_id=s.organisation_id and schedule_id=s.id;
  ref:='MR-CSET-'||to_char(current_date,'YYYY')||'-'||upper(substr(replace(new_id::text,'-',''),1,8));
  insert into public.commission_settlement_batches(id,organisation_id,schedule_id,cycle_no,settlement_reference,status,pool_basis,pool_rate,currency,transaction_basis_amount,quantity_basis_mt,pool_amount,amount_paid,balance_due,period_start,period_end,source_finance_document_id,source_payment_id,evidence_document_id,source_reference,notes,created_by,updated_by)
  values(new_id,s.organisation_id,s.id,next_cycle,ref,'draft',s.pool_basis,s.pool_value,s.currency,p_transaction_basis_amount,p_quantity_basis_mt,0,0,0,p_period_start,p_period_end,p_source_finance_document_id,p_source_payment_id,p_evidence_document_id,coalesce(p_source_reference,''),coalesce(p_notes,''),(select auth.uid()),(select auth.uid()));
  return new_id;
end; $$;
revoke all on function public.create_commission_settlement_batch(uuid,numeric,numeric,uuid,uuid,uuid,text,date,date,text) from public,anon;
grant execute on function public.create_commission_settlement_batch(uuid,numeric,numeric,uuid,uuid,uuid,text,date,date,text) to authenticated;

create or replace function public.approve_commission_settlement_batch(p_batch_id uuid)
returns boolean language plpgsql set search_path=''
as $$
declare b public.commission_settlement_batches%rowtype;
begin
  select * into b from public.commission_settlement_batches where id=p_batch_id; if not found then raise exception 'Settlement batch not found'; end if;
  if not private.has_mrcip_role(b.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role' using errcode='42501'; end if;
  update public.commission_settlement_batches set status='approved',updated_by=(select auth.uid()) where id=b.id;
  return true;
end; $$;
revoke all on function public.approve_commission_settlement_batch(uuid) from public,anon;
grant execute on function public.approve_commission_settlement_batch(uuid) to authenticated;

create or replace function public.record_commission_settlement_entry(
  p_item_id uuid,
  p_amount numeric,
  p_payment_date date,
  p_payment_reference text default '',
  p_payment_method text default 'Bank transfer',
  p_evidence_document_id uuid default null,
  p_finance_document_id uuid default null,
  p_payment_id uuid default null,
  p_notes text default ''
) returns uuid language plpgsql set search_path=''
as $$
declare i public.commission_settlement_items%rowtype; b public.commission_settlement_batches%rowtype; new_id uuid:=gen_random_uuid();
begin
  select * into i from public.commission_settlement_items where id=p_item_id; if not found then raise exception 'Settlement item not found'; end if;
  if not private.has_mrcip_role(i.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role' using errcode='42501'; end if;
  select * into b from public.commission_settlement_batches where id=i.batch_id and organisation_id=i.organisation_id;
  if b.status not in ('approved','partially_settled') then raise exception 'Settlement batch is not open for payout recording'; end if;
  insert into public.commission_settlement_entries(id,organisation_id,batch_id,item_id,schedule_id,allocation_id,amount,currency,payment_date,payment_reference,payment_method,status,evidence_document_id,finance_document_id,payment_id,notes,created_by,updated_by)
  values(new_id,i.organisation_id,i.batch_id,i.id,i.schedule_id,i.allocation_id,p_amount,i.currency,p_payment_date,coalesce(p_payment_reference,''),coalesce(p_payment_method,'Bank transfer'),'pending',p_evidence_document_id,p_finance_document_id,p_payment_id,coalesce(p_notes,''),(select auth.uid()),(select auth.uid()));
  return new_id;
end; $$;
revoke all on function public.record_commission_settlement_entry(uuid,numeric,date,text,text,uuid,uuid,uuid,text) from public,anon;
grant execute on function public.record_commission_settlement_entry(uuid,numeric,date,text,text,uuid,uuid,uuid,text) to authenticated;

create or replace function public.verify_commission_settlement_entry(p_entry_id uuid)
returns text language plpgsql set search_path=''
as $$
declare e public.commission_settlement_entries%rowtype; bstatus text;
begin
  select * into e from public.commission_settlement_entries where id=p_entry_id; if not found then raise exception 'Settlement entry not found'; end if;
  if not private.has_mrcip_role(e.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role' using errcode='42501'; end if;
  update public.commission_settlement_entries set status='verified',updated_by=(select auth.uid()) where id=e.id;
  select status into bstatus from public.commission_settlement_batches where id=e.batch_id;
  return bstatus;
end; $$;
revoke all on function public.verify_commission_settlement_entry(uuid) from public,anon;
grant execute on function public.verify_commission_settlement_entry(uuid) to authenticated;

create or replace function public.reverse_commission_settlement_entry(p_entry_id uuid,p_reason text)
returns text language plpgsql set search_path=''
as $$
declare e public.commission_settlement_entries%rowtype; bstatus text;
begin
  select * into e from public.commission_settlement_entries where id=p_entry_id; if not found then raise exception 'Settlement entry not found'; end if;
  if not private.has_mrcip_role(e.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role' using errcode='42501'; end if;
  update public.commission_settlement_entries set status='reversed',reversal_reason=coalesce(p_reason,''),updated_by=(select auth.uid()) where id=e.id;
  select status into bstatus from public.commission_settlement_batches where id=e.batch_id;
  return bstatus;
end; $$;
revoke all on function public.reverse_commission_settlement_entry(uuid,text) from public,anon;
grant execute on function public.reverse_commission_settlement_entry(uuid,text) to authenticated;

create or replace function public.close_commission_schedule(p_schedule_id uuid,p_reason text,p_evidence_document_id uuid default null,p_notes text default '')
returns uuid language plpgsql set search_path=''
as $$
declare s public.commission_schedules%rowtype; new_id uuid:=gen_random_uuid();
begin
  select * into s from public.commission_schedules where id=p_schedule_id; if not found then raise exception 'Commission schedule not found'; end if;
  if not private.has_mrcip_role(s.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role' using errcode='42501'; end if;
  insert into public.commission_schedule_closeouts(id,organisation_id,schedule_id,status,closeout_reason,evidence_document_id,approved_at,approved_by,notes,created_by)
  values(new_id,s.organisation_id,s.id,'approved',coalesce(p_reason,''),p_evidence_document_id,now(),(select auth.uid()),coalesce(p_notes,''),(select auth.uid()));
  return new_id;
end; $$;
revoke all on function public.close_commission_schedule(uuid,text,uuid,text) from public,anon;
grant execute on function public.close_commission_schedule(uuid,text,uuid,text) to authenticated;

revoke delete on public.commission_settlement_items from authenticated;
drop policy if exists commission_settlement_items_delete on public.commission_settlement_items;