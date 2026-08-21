create table public.commission_schedules (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  opportunity_id uuid not null,
  facilitator_chain_id uuid not null,
  previous_schedule_id uuid null,
  revision_no integer not null default 1 check (revision_no > 0),
  status text not null default 'draft' check (status in ('draft','pending_approval','approved','superseded','payable','partially_paid','paid','cancelled','rejected')),
  pool_basis text not null check (pool_basis in ('percent_of_transaction','per_metric_tonne','fixed_amount')),
  pool_value numeric(20,6) not null check (pool_value >= 0),
  currency text not null default 'ZAR' check (char_length(currency)=3),
  quantity_basis_mt numeric(20,4) null check (quantity_basis_mt is null or quantity_basis_mt >= 0),
  payment_trigger text not null default 'buyer_payment_received' check (payment_trigger in ('buyer_payment_received','seller_payment_received','invoice_paid','delivery_completed','custom')),
  trigger_terms text not null default '',
  fee_protection_record_id uuid null,
  amendment_reason text not null default '',
  effective_date date null,
  approved_at timestamptz null,
  approved_by uuid null references auth.users(id),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id, id),
  unique (organisation_id, opportunity_id, revision_no),
  constraint commission_schedules_opportunity_fk foreign key (organisation_id, opportunity_id) references public.opportunities(organisation_id, id) on delete cascade,
  constraint commission_schedules_chain_fk foreign key (organisation_id, facilitator_chain_id) references public.facilitator_chains(organisation_id, id) on delete restrict,
  constraint commission_schedules_previous_fk foreign key (organisation_id, previous_schedule_id) references public.commission_schedules(organisation_id, id) on delete restrict,
  constraint commission_schedules_fee_protection_fk foreign key (organisation_id, fee_protection_record_id) references public.opportunity_protection_records(organisation_id, id) on delete restrict
);
create unique index commission_schedules_one_approved_idx on public.commission_schedules(organisation_id, opportunity_id) where status in ('approved','payable','partially_paid');
create index commission_schedules_org_opportunity_idx on public.commission_schedules(organisation_id, opportunity_id, revision_no desc);
create index commission_schedules_chain_idx on public.commission_schedules(organisation_id, facilitator_chain_id);
create index commission_schedules_previous_idx on public.commission_schedules(organisation_id, previous_schedule_id) where previous_schedule_id is not null;
create index commission_schedules_fee_protection_idx on public.commission_schedules(organisation_id, fee_protection_record_id) where fee_protection_record_id is not null;
create index commission_schedules_approved_by_idx on public.commission_schedules(approved_by) where approved_by is not null;
create index commission_schedules_created_by_idx on public.commission_schedules(created_by);
create index commission_schedules_updated_by_idx on public.commission_schedules(updated_by);

create table public.commission_allocations (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  schedule_id uuid not null,
  facilitator_member_id uuid not null,
  pool_share_percent numeric(9,6) not null check (pool_share_percent > 0 and pool_share_percent <= 100),
  allocation_basis text not null,
  allocation_value numeric(20,6) not null default 0 check (allocation_value >= 0),
  payment_trigger_override text null check (payment_trigger_override is null or payment_trigger_override in ('buyer_payment_received','seller_payment_received','invoice_paid','delivery_completed','custom')),
  entitlement_status text not null default 'pending' check (entitlement_status in ('pending','protected','payable','partially_paid','paid','withheld','cancelled')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id, id),
  unique (organisation_id, schedule_id, facilitator_member_id),
  constraint commission_allocations_schedule_fk foreign key (organisation_id, schedule_id) references public.commission_schedules(organisation_id, id) on delete cascade,
  constraint commission_allocations_member_fk foreign key (organisation_id, facilitator_member_id) references public.facilitator_chain_members(organisation_id, id) on delete restrict,
  constraint commission_allocations_basis_check check (allocation_basis in ('percent_of_transaction','per_metric_tonne','fixed_amount'))
);
create index commission_allocations_org_schedule_idx on public.commission_allocations(organisation_id, schedule_id);
create index commission_allocations_member_idx on public.commission_allocations(organisation_id, facilitator_member_id);
create index commission_allocations_created_by_idx on public.commission_allocations(created_by);
create index commission_allocations_updated_by_idx on public.commission_allocations(updated_by);

create table public.commission_trigger_events (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  schedule_id uuid not null,
  event_type text not null check (event_type in ('buyer_payment_received','seller_payment_received','invoice_paid','delivery_completed','custom')),
  status text not null default 'pending' check (status in ('pending','verified','rejected','revoked')),
  event_reference text not null default '',
  evidence_document_id uuid null,
  finance_document_id uuid null,
  payment_id uuid null,
  occurred_at timestamptz null,
  verified_at timestamptz null,
  verified_by uuid null references auth.users(id),
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id, id),
  constraint commission_trigger_events_schedule_fk foreign key (organisation_id, schedule_id) references public.commission_schedules(organisation_id, id) on delete cascade,
  constraint commission_trigger_events_document_fk foreign key (organisation_id, evidence_document_id) references public.documents(organisation_id, id) on delete restrict,
  constraint commission_trigger_events_finance_document_fk foreign key (organisation_id, finance_document_id) references public.finance_documents(organisation_id, id) on delete restrict,
  constraint commission_trigger_events_payment_fk foreign key (organisation_id, payment_id) references public.payments(organisation_id, id) on delete restrict
);
create index commission_trigger_events_org_schedule_idx on public.commission_trigger_events(organisation_id, schedule_id, status);
create index commission_trigger_events_document_idx on public.commission_trigger_events(organisation_id, evidence_document_id) where evidence_document_id is not null;
create index commission_trigger_events_finance_document_idx on public.commission_trigger_events(organisation_id, finance_document_id) where finance_document_id is not null;
create index commission_trigger_events_payment_idx on public.commission_trigger_events(organisation_id, payment_id) where payment_id is not null;
create index commission_trigger_events_verified_by_idx on public.commission_trigger_events(verified_by) where verified_by is not null;
create index commission_trigger_events_created_by_idx on public.commission_trigger_events(created_by);
create index commission_trigger_events_updated_by_idx on public.commission_trigger_events(updated_by);

create table public.commission_finance_links (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  schedule_id uuid not null,
  allocation_id uuid null,
  finance_document_id uuid not null,
  link_role text not null default 'commission_invoice' check (link_role in ('commission_invoice','source_invoice','supporting_invoice','credit_note','other')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id, id),
  unique (organisation_id, schedule_id, finance_document_id, allocation_id),
  constraint commission_finance_links_schedule_fk foreign key (organisation_id, schedule_id) references public.commission_schedules(organisation_id, id) on delete cascade,
  constraint commission_finance_links_allocation_fk foreign key (organisation_id, allocation_id) references public.commission_allocations(organisation_id, id) on delete cascade,
  constraint commission_finance_links_document_fk foreign key (organisation_id, finance_document_id) references public.finance_documents(organisation_id, id) on delete restrict
);
create index commission_finance_links_org_schedule_idx on public.commission_finance_links(organisation_id, schedule_id);
create index commission_finance_links_allocation_idx on public.commission_finance_links(organisation_id, allocation_id) where allocation_id is not null;
create index commission_finance_links_document_idx on public.commission_finance_links(organisation_id, finance_document_id);
create index commission_finance_links_created_by_idx on public.commission_finance_links(created_by);

create or replace function private.sync_commission_allocation()
returns trigger language plpgsql security definer set search_path=''
as $$
declare s public.commission_schedules%rowtype; m public.facilitator_chain_members%rowtype;
begin
  select * into s from public.commission_schedules where id=new.schedule_id and organisation_id=new.organisation_id;
  if not found then raise exception 'Commission schedule not found'; end if;
  if s.status in ('approved','superseded','payable','partially_paid','paid') then raise exception 'Approved/superseded commission schedules are immutable; create a revision'; end if;
  select * into m from public.facilitator_chain_members where id=new.facilitator_member_id and organisation_id=new.organisation_id;
  if not found or m.chain_id <> s.facilitator_chain_id then raise exception 'Commission allocation member must belong to the schedule facilitator chain'; end if;
  if not m.commission_entitled then raise exception 'Facilitator member is not marked commission-entitled'; end if;
  new.allocation_basis := s.pool_basis;
  new.allocation_value := round((s.pool_value * new.pool_share_percent / 100.0)::numeric, 6);
  new.updated_at := now();
  return new;
end; $$;
revoke all on function private.sync_commission_allocation() from public, anon, authenticated;
create trigger commission_allocations_sync_biu before insert or update on public.commission_allocations for each row execute function private.sync_commission_allocation();

create or replace function private.prevent_locked_commission_schedule_mutation()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if tg_op='DELETE' and old.status in ('approved','superseded','payable','partially_paid','paid') then raise exception 'Approved/superseded commission schedules cannot be deleted'; end if;
  if tg_op='UPDATE' and old.status in ('approved','superseded','payable','partially_paid','paid') then
    if new.pool_basis is distinct from old.pool_basis or new.pool_value is distinct from old.pool_value or new.currency is distinct from old.currency
       or new.facilitator_chain_id is distinct from old.facilitator_chain_id or new.fee_protection_record_id is distinct from old.fee_protection_record_id
       or new.payment_trigger is distinct from old.payment_trigger or new.trigger_terms is distinct from old.trigger_terms
       or new.quantity_basis_mt is distinct from old.quantity_basis_mt or new.opportunity_id is distinct from old.opportunity_id then
      raise exception 'Commercial terms of approved commission schedules are immutable; create a revision';
    end if;
  end if;
  if tg_op='DELETE' then return old; end if;
  new.updated_at := now(); return new;
end; $$;
revoke all on function private.prevent_locked_commission_schedule_mutation() from public, anon, authenticated;
create trigger commission_schedules_lock_bud before update or delete on public.commission_schedules for each row execute function private.prevent_locked_commission_schedule_mutation();

alter table public.commission_schedules enable row level security;
alter table public.commission_allocations enable row level security;
alter table public.commission_trigger_events enable row level security;
alter table public.commission_finance_links enable row level security;

create policy commission_schedules_select on public.commission_schedules for select to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance']));
create policy commission_schedules_insert on public.commission_schedules for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy commission_schedules_update on public.commission_schedules for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance']) and updated_by=(select auth.uid()));
create policy commission_schedules_delete on public.commission_schedules for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance']));
create policy commission_allocations_select on public.commission_allocations for select to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance']));
create policy commission_allocations_insert on public.commission_allocations for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy commission_allocations_update on public.commission_allocations for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance']) and updated_by=(select auth.uid()));
create policy commission_allocations_delete on public.commission_allocations for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance']));
create policy commission_trigger_events_select on public.commission_trigger_events for select to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance']));
create policy commission_trigger_events_insert on public.commission_trigger_events for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy commission_trigger_events_update on public.commission_trigger_events for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance']) and updated_by=(select auth.uid()));
create policy commission_trigger_events_delete on public.commission_trigger_events for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance']));
create policy commission_finance_links_select on public.commission_finance_links for select to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance']));
create policy commission_finance_links_insert on public.commission_finance_links for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance']) and created_by=(select auth.uid()));
create policy commission_finance_links_delete on public.commission_finance_links for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','finance','legal_compliance']));

revoke all on public.commission_schedules, public.commission_allocations, public.commission_trigger_events, public.commission_finance_links from anon;
revoke all on public.commission_schedules, public.commission_allocations, public.commission_trigger_events, public.commission_finance_links from authenticated;
grant select,insert,update,delete on public.commission_schedules, public.commission_allocations, public.commission_trigger_events to authenticated;
grant select,insert,delete on public.commission_finance_links to authenticated;