create table public.commission_settlement_batches (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  schedule_id uuid not null,
  cycle_no integer not null check (cycle_no > 0),
  settlement_reference text not null,
  status text not null default 'draft' check (status in ('draft','pending_approval','approved','partially_settled','settled','cancelled','rejected')),
  pool_basis text not null check (pool_basis in ('percent_of_transaction','per_metric_tonne','fixed_amount')),
  pool_rate numeric(20,6) not null check (pool_rate >= 0),
  currency text not null default 'ZAR' check (char_length(currency)=3),
  transaction_basis_amount numeric(20,6) null check (transaction_basis_amount is null or transaction_basis_amount >= 0),
  quantity_basis_mt numeric(20,4) null check (quantity_basis_mt is null or quantity_basis_mt >= 0),
  pool_amount numeric(20,6) not null check (pool_amount >= 0),
  amount_paid numeric(20,6) not null default 0 check (amount_paid >= 0),
  balance_due numeric(20,6) not null check (balance_due >= 0),
  period_start date null,
  period_end date null,
  source_finance_document_id uuid null,
  source_payment_id uuid null,
  evidence_document_id uuid null,
  source_reference text not null default '',
  notes text not null default '',
  approved_at timestamptz null,
  approved_by uuid null references auth.users(id),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id, id),
  unique (organisation_id, schedule_id, cycle_no),
  unique (organisation_id, settlement_reference),
  constraint commission_settlement_batches_schedule_fk foreign key (organisation_id, schedule_id)
    references public.commission_schedules(organisation_id, id) on delete restrict,
  constraint commission_settlement_batches_finance_document_fk foreign key (organisation_id, source_finance_document_id)
    references public.finance_documents(organisation_id, id) on delete restrict,
  constraint commission_settlement_batches_payment_fk foreign key (organisation_id, source_payment_id)
    references public.payments(organisation_id, id) on delete restrict,
  constraint commission_settlement_batches_evidence_fk foreign key (organisation_id, evidence_document_id)
    references public.documents(organisation_id, id) on delete restrict,
  constraint commission_settlement_batches_period_check check (period_end is null or period_start is null or period_end >= period_start)
);

create unique index commission_settlement_batches_one_fixed_active_idx
  on public.commission_settlement_batches(organisation_id, schedule_id)
  where pool_basis='fixed_amount' and status not in ('cancelled','rejected');
create unique index commission_settlement_batches_source_payment_idx
  on public.commission_settlement_batches(organisation_id, schedule_id, source_payment_id)
  where source_payment_id is not null and status not in ('cancelled','rejected');
create index commission_settlement_batches_org_schedule_idx on public.commission_settlement_batches(organisation_id, schedule_id, cycle_no desc);
create index commission_settlement_batches_status_idx on public.commission_settlement_batches(organisation_id, status, updated_at desc);
create index commission_settlement_batches_source_finance_idx on public.commission_settlement_batches(organisation_id, source_finance_document_id) where source_finance_document_id is not null;
create index commission_settlement_batches_evidence_idx on public.commission_settlement_batches(organisation_id, evidence_document_id) where evidence_document_id is not null;
create index commission_settlement_batches_approved_by_idx on public.commission_settlement_batches(approved_by) where approved_by is not null;
create index commission_settlement_batches_created_by_idx on public.commission_settlement_batches(created_by);
create index commission_settlement_batches_updated_by_idx on public.commission_settlement_batches(updated_by);

create table public.commission_settlement_items (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  batch_id uuid not null,
  schedule_id uuid not null,
  allocation_id uuid not null,
  facilitator_member_id uuid not null,
  pool_share_percent numeric(9,6) not null check (pool_share_percent > 0 and pool_share_percent <= 100),
  currency text not null check (char_length(currency)=3),
  amount_due numeric(20,6) not null check (amount_due >= 0),
  amount_paid numeric(20,6) not null default 0 check (amount_paid >= 0),
  balance_due numeric(20,6) not null check (balance_due >= 0),
  status text not null default 'pending' check (status in ('pending','payable','partially_paid','paid','withheld','cancelled')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id, id),
  unique (organisation_id, batch_id, allocation_id),
  constraint commission_settlement_items_batch_fk foreign key (organisation_id, batch_id)
    references public.commission_settlement_batches(organisation_id, id) on delete cascade,
  constraint commission_settlement_items_schedule_fk foreign key (organisation_id, schedule_id)
    references public.commission_schedules(organisation_id, id) on delete restrict,
  constraint commission_settlement_items_allocation_fk foreign key (organisation_id, allocation_id)
    references public.commission_allocations(organisation_id, id) on delete restrict,
  constraint commission_settlement_items_member_fk foreign key (organisation_id, facilitator_member_id)
    references public.facilitator_chain_members(organisation_id, id) on delete restrict
);
create index commission_settlement_items_org_batch_idx on public.commission_settlement_items(organisation_id, batch_id);
create index commission_settlement_items_schedule_idx on public.commission_settlement_items(organisation_id, schedule_id);
create index commission_settlement_items_allocation_idx on public.commission_settlement_items(organisation_id, allocation_id);
create index commission_settlement_items_member_idx on public.commission_settlement_items(organisation_id, facilitator_member_id);
create index commission_settlement_items_status_idx on public.commission_settlement_items(organisation_id, status);
create index commission_settlement_items_created_by_idx on public.commission_settlement_items(created_by);
create index commission_settlement_items_updated_by_idx on public.commission_settlement_items(updated_by);

create table public.commission_settlement_entries (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  batch_id uuid not null,
  item_id uuid not null,
  schedule_id uuid not null,
  allocation_id uuid not null,
  amount numeric(20,6) not null check (amount > 0),
  currency text not null check (char_length(currency)=3),
  payment_date date not null,
  payment_reference text not null default '',
  payment_method text not null default 'Bank transfer',
  status text not null default 'pending' check (status in ('pending','verified','rejected','reversed')),
  evidence_document_id uuid null,
  finance_document_id uuid null,
  payment_id uuid null,
  notes text not null default '',
  verified_at timestamptz null,
  verified_by uuid null references auth.users(id),
  reversed_at timestamptz null,
  reversed_by uuid null references auth.users(id),
  reversal_reason text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id, id),
  constraint commission_settlement_entries_batch_fk foreign key (organisation_id, batch_id)
    references public.commission_settlement_batches(organisation_id, id) on delete restrict,
  constraint commission_settlement_entries_item_fk foreign key (organisation_id, item_id)
    references public.commission_settlement_items(organisation_id, id) on delete restrict,
  constraint commission_settlement_entries_schedule_fk foreign key (organisation_id, schedule_id)
    references public.commission_schedules(organisation_id, id) on delete restrict,
  constraint commission_settlement_entries_allocation_fk foreign key (organisation_id, allocation_id)
    references public.commission_allocations(organisation_id, id) on delete restrict,
  constraint commission_settlement_entries_evidence_fk foreign key (organisation_id, evidence_document_id)
    references public.documents(organisation_id, id) on delete restrict,
  constraint commission_settlement_entries_finance_document_fk foreign key (organisation_id, finance_document_id)
    references public.finance_documents(organisation_id, id) on delete restrict,
  constraint commission_settlement_entries_payment_fk foreign key (organisation_id, payment_id)
    references public.payments(organisation_id, id) on delete restrict
);
create index commission_settlement_entries_org_batch_idx on public.commission_settlement_entries(organisation_id, batch_id, status);
create index commission_settlement_entries_item_idx on public.commission_settlement_entries(organisation_id, item_id, status);
create index commission_settlement_entries_schedule_idx on public.commission_settlement_entries(organisation_id, schedule_id, status);
create index commission_settlement_entries_allocation_idx on public.commission_settlement_entries(organisation_id, allocation_id, status);
create index commission_settlement_entries_evidence_idx on public.commission_settlement_entries(organisation_id, evidence_document_id) where evidence_document_id is not null;
create index commission_settlement_entries_finance_idx on public.commission_settlement_entries(organisation_id, finance_document_id) where finance_document_id is not null;
create index commission_settlement_entries_payment_idx on public.commission_settlement_entries(organisation_id, payment_id) where payment_id is not null;
create index commission_settlement_entries_verified_by_idx on public.commission_settlement_entries(verified_by) where verified_by is not null;
create index commission_settlement_entries_reversed_by_idx on public.commission_settlement_entries(reversed_by) where reversed_by is not null;
create index commission_settlement_entries_created_by_idx on public.commission_settlement_entries(created_by);
create index commission_settlement_entries_updated_by_idx on public.commission_settlement_entries(updated_by);

create table public.commission_schedule_closeouts (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  schedule_id uuid not null,
  status text not null default 'approved' check (status in ('approved','rejected','revoked')),
  closeout_reason text not null,
  evidence_document_id uuid null,
  approved_at timestamptz not null default now(),
  approved_by uuid not null default auth.uid() references auth.users(id),
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id, id),
  unique (organisation_id, schedule_id),
  constraint commission_schedule_closeouts_schedule_fk foreign key (organisation_id, schedule_id)
    references public.commission_schedules(organisation_id, id) on delete restrict,
  constraint commission_schedule_closeouts_evidence_fk foreign key (organisation_id, evidence_document_id)
    references public.documents(organisation_id, id) on delete restrict,
  constraint commission_schedule_closeouts_reason_check check (nullif(btrim(closeout_reason),'') is not null)
);
create index commission_schedule_closeouts_org_schedule_idx on public.commission_schedule_closeouts(organisation_id, schedule_id, status);
create index commission_schedule_closeouts_evidence_idx on public.commission_schedule_closeouts(organisation_id, evidence_document_id) where evidence_document_id is not null;
create index commission_schedule_closeouts_approved_by_idx on public.commission_schedule_closeouts(approved_by);
create index commission_schedule_closeouts_created_by_idx on public.commission_schedule_closeouts(created_by);

alter table public.commission_settlement_batches enable row level security;
alter table public.commission_settlement_items enable row level security;
alter table public.commission_settlement_entries enable row level security;
alter table public.commission_schedule_closeouts enable row level security;

create policy commission_settlement_batches_select on public.commission_settlement_batches for select to authenticated
using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']));
create policy commission_settlement_batches_insert on public.commission_settlement_batches for insert to authenticated
with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy commission_settlement_batches_update on public.commission_settlement_batches for update to authenticated
using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']))
with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']) and updated_by=(select auth.uid()));
create policy commission_settlement_batches_delete on public.commission_settlement_batches for delete to authenticated
using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance']));

create policy commission_settlement_items_select on public.commission_settlement_items for select to authenticated
using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']));
create policy commission_settlement_items_insert on public.commission_settlement_items for insert to authenticated
with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy commission_settlement_items_update on public.commission_settlement_items for update to authenticated
using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']))
with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']) and updated_by=(select auth.uid()));
create policy commission_settlement_items_delete on public.commission_settlement_items for delete to authenticated
using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance']));

create policy commission_settlement_entries_select on public.commission_settlement_entries for select to authenticated
using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']));
create policy commission_settlement_entries_insert on public.commission_settlement_entries for insert to authenticated
with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy commission_settlement_entries_update on public.commission_settlement_entries for update to authenticated
using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']))
with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']) and updated_by=(select auth.uid()));
create policy commission_settlement_entries_delete on public.commission_settlement_entries for delete to authenticated
using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance']));

create policy commission_schedule_closeouts_select on public.commission_schedule_closeouts for select to authenticated
using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']));
create policy commission_schedule_closeouts_insert on public.commission_schedule_closeouts for insert to authenticated
with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']) and created_by=(select auth.uid()) and approved_by=(select auth.uid()));

revoke all on public.commission_settlement_batches, public.commission_settlement_items, public.commission_settlement_entries, public.commission_schedule_closeouts from anon;
revoke all on public.commission_settlement_batches, public.commission_settlement_items, public.commission_settlement_entries, public.commission_schedule_closeouts from authenticated;
grant select,insert,update,delete on public.commission_settlement_batches, public.commission_settlement_items, public.commission_settlement_entries to authenticated;
grant select,insert on public.commission_schedule_closeouts to authenticated;