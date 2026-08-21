create or replace function private.seed_commission_settlement_items()
returns trigger language plpgsql security definer set search_path=''
as $$
declare old_seed text:=current_setting('mrcip.settlement_seed',true);
begin
  perform set_config('mrcip.settlement_seed','on',true);
  begin
    insert into public.commission_settlement_items(organisation_id,batch_id,schedule_id,allocation_id,facilitator_member_id,pool_share_percent,currency,amount_due,amount_paid,balance_due,status,created_by,updated_by)
    select a.organisation_id,new.id,new.schedule_id,a.id,a.facilitator_member_id,a.pool_share_percent,new.currency,
           round((new.pool_amount*a.pool_share_percent/100.0)::numeric,6),0,round((new.pool_amount*a.pool_share_percent/100.0)::numeric,6),'pending',(select auth.uid()),(select auth.uid())
    from public.commission_allocations a where a.organisation_id=new.organisation_id and a.schedule_id=new.schedule_id;
    perform set_config('mrcip.settlement_seed',coalesce(old_seed,''),true);
  exception when others then
    perform set_config('mrcip.settlement_seed',coalesce(old_seed,''),true);
    raise;
  end;
  return new;
end; $$;
revoke all on function private.seed_commission_settlement_items() from public,anon,authenticated;

create or replace function private.reconcile_commission_settlement_batch(p_batch_id uuid)
returns void language plpgsql security definer set search_path=''
as $$
declare b public.commission_settlement_batches%rowtype; s public.commission_schedules%rowtype; paid_total numeric; due_total numeric; new_batch_status text; new_schedule_status text; has_any_verified boolean; has_closeout boolean; has_open_batches boolean; old_reconcile text:=current_setting('mrcip.settlement_reconcile',true);
begin
  select * into b from public.commission_settlement_batches where id=p_batch_id;
  if not found then return; end if;
  select * into s from public.commission_schedules where id=b.schedule_id and organisation_id=b.organisation_id;
  if not found then return; end if;
  perform set_config('mrcip.settlement_reconcile','on',true);
  begin
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
    perform set_config('mrcip.settlement_reconcile',coalesce(old_reconcile,''),true);
  exception when others then
    perform set_config('mrcip.settlement_reconcile',coalesce(old_reconcile,''),true);
    raise;
  end;
end; $$;
revoke all on function private.reconcile_commission_settlement_batch(uuid) from public,anon,authenticated;

create or replace function private.finalise_commission_schedule_closeout()
returns trigger language plpgsql security definer set search_path=''
as $$
declare s public.commission_schedules%rowtype; old_reconcile text:=current_setting('mrcip.settlement_reconcile',true);
begin
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'Insufficient role to close commission schedule' using errcode='42501'; end if;
  select * into s from public.commission_schedules where id=new.schedule_id and organisation_id=new.organisation_id;
  if not found then raise exception 'Commission schedule not found'; end if;
  if s.pool_basis='fixed_amount' then raise exception 'Fixed-amount commission schedules close automatically after full settlement'; end if;
  if s.status not in ('payable','partially_paid') then raise exception 'Recurring commission schedule must be payable/partially paid before closeout'; end if;
  if not exists(select 1 from public.commission_settlement_batches b where b.organisation_id=new.organisation_id and b.schedule_id=new.schedule_id and b.status not in ('cancelled','rejected')) then raise exception 'Closeout requires at least one settlement cycle'; end if;
  if exists(select 1 from public.commission_settlement_batches b where b.organisation_id=new.organisation_id and b.schedule_id=new.schedule_id and b.status not in ('settled','cancelled','rejected')) then raise exception 'All settlement cycles must be fully settled before closeout'; end if;
  perform set_config('mrcip.settlement_reconcile','on',true);
  begin
    update public.commission_schedules set status='paid',updated_at=now(),updated_by=coalesce((select auth.uid()),updated_by) where id=new.schedule_id;
    update public.commission_allocations set entitlement_status='paid',updated_by=coalesce((select auth.uid()),updated_by) where organisation_id=new.organisation_id and schedule_id=new.schedule_id;
    perform set_config('mrcip.settlement_reconcile',coalesce(old_reconcile,''),true);
  exception when others then
    perform set_config('mrcip.settlement_reconcile',coalesce(old_reconcile,''),true);
    raise;
  end;
  return new;
end; $$;
revoke all on function private.finalise_commission_schedule_closeout() from public,anon,authenticated;