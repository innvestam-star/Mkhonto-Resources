begin;

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null default '',
  telephone text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index profiles_email_uidx on public.profiles (lower(email));

create table public.organisations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  trading_name text not null default '',
  registration_number text not null default '',
  vat_number text not null default '',
  industry text not null default 'Logistics and transport',
  email text not null default '',
  telephone text not null default '',
  physical_address text not null default '',
  plan text not null default 'pilot',
  status text not null default 'active' check (status in ('active', 'trial', 'suspended', 'closed')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organisation_memberships (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  email text not null,
  display_name text not null default '',
  role text not null default 'viewer' check (role in ('owner', 'finance', 'dispatcher', 'driver', 'accountant', 'viewer')),
  status text not null default 'active' check (status in ('invited', 'active', 'suspended', 'revoked')),
  invited_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organisation_id, user_id),
  unique (organisation_id, email)
);

create index organisation_memberships_user_idx on public.organisation_memberships (user_id, status);
create index organisation_memberships_email_idx on public.organisation_memberships (lower(email), status);

create or replace function private.is_org_member(target_organisation uuid, allowed_roles text[] default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organisation_memberships membership
    where membership.organisation_id = target_organisation
      and membership.user_id = (select auth.uid())
      and membership.status = 'active'
      and (allowed_roles is null or membership.role = any(allowed_roles))
  );
$$;

revoke all on function private.is_org_member(uuid, text[]) from public, anon;
grant execute on function private.is_org_member(uuid, text[]) to authenticated;

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  name text not null,
  contact_person text not null default '',
  registration_number text not null default '',
  vat_number text not null default '',
  billing_address text not null default '',
  physical_address text not null default '',
  email text not null default '',
  telephone text not null default '',
  payment_terms text not null default '',
  status text not null default 'active',
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index clients_org_name_idx on public.clients (organisation_id, name);

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  registration_number text not null,
  description text not null default '',
  truck_type text not null default '34-ton side tipper',
  capacity_tonnes numeric(8,2) not null default 34 check (capacity_tonnes >= 0),
  status text not null default 'active',
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organisation_id, registration_number)
);

create table public.drivers (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  membership_id uuid references public.organisation_memberships(id) on delete set null,
  name text not null,
  email text not null default '',
  telephone text not null default '',
  employee_number text not null default '',
  licence_number text not null default '',
  licence_expiry date,
  status text not null default 'active',
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index drivers_org_idx on public.drivers (organisation_id, status);
create index drivers_membership_idx on public.drivers (membership_id);

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  trip_number text not null,
  trip_date date not null,
  vehicle_id uuid not null references public.vehicles(id),
  driver_id uuid references public.drivers(id),
  client_id uuid references public.clients(id) on delete set null,
  client_name text not null default '',
  contract_reference text not null default '',
  commodity text not null default 'Coal',
  loading_location text not null,
  delivery_location text not null,
  loaded_km numeric(10,2) not null default 0 check (loaded_km >= 0),
  empty_km numeric(10,2) not null default 0 check (empty_km >= 0),
  tonnes numeric(10,2) not null default 0 check (tonnes >= 0),
  rate_per_tonne numeric(14,2) not null default 0 check (rate_per_tonne >= 0),
  revenue numeric(16,2) not null default 0 check (revenue >= 0),
  weighbridge_number text not null default '',
  loading_arrival_at timestamptz,
  loading_service_started_at timestamptz,
  loading_departure_at timestamptz,
  delivery_arrival_at timestamptz,
  delivery_service_started_at timestamptz,
  delivery_departure_at timestamptz,
  standing_grace_minutes integer not null default 1440 check (standing_grace_minutes >= 0),
  standing_cycle_minutes integer not null default 1440 check (standing_cycle_minutes > 0),
  standing_fee_per_cycle numeric(14,2) not null default 6000 check (standing_fee_per_cycle >= 0),
  standing_billable_minutes integer not null default 0 check (standing_billable_minutes >= 0),
  standing_charge numeric(16,2) not null default 0 check (standing_charge >= 0),
  standing_status text not null default 'not-recorded',
  status text not null default 'draft' check (status in ('draft', 'submitted', 'approved', 'invoice-ready', 'invoiced', 'paid', 'cancelled')),
  notes text not null default '',
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organisation_id, trip_number)
);

create index trips_org_date_idx on public.trips (organisation_id, trip_date desc);
create index trips_driver_idx on public.trips (driver_id, trip_date desc);
create index trips_vehicle_idx on public.trips (vehicle_id, trip_date desc);

create or replace function private.can_access_trip(target_organisation uuid, target_trip uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organisation_memberships membership
    where membership.organisation_id = target_organisation
      and membership.user_id = (select auth.uid())
      and membership.status = 'active'
      and (
        membership.role = any(array['owner', 'finance', 'dispatcher', 'accountant', 'viewer'])
        or (
          membership.role = 'driver'
          and exists (
            select 1
            from public.drivers driver
            join public.trips trip on trip.driver_id = driver.id
            where driver.membership_id = membership.id
              and trip.id = target_trip
              and trip.organisation_id = target_organisation
          )
        )
      )
  );
$$;

revoke all on function private.can_access_trip(uuid, uuid) from public, anon;
grant execute on function private.can_access_trip(uuid, uuid) to authenticated;

create table public.trip_events (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  trip_id uuid not null references public.trips(id) on delete cascade,
  event_type text not null check (event_type in ('assigned', 'departed', 'loading-arrival', 'loading-started', 'loading-departed', 'delivery-arrival', 'delivery-started', 'delivered', 'exception', 'standing-time')),
  occurred_at timestamptz not null,
  latitude numeric(10,7),
  longitude numeric(10,7),
  notes text not null default '',
  evidence_document_id uuid,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now()
);

create index trip_events_trip_time_idx on public.trip_events (trip_id, occurred_at desc);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  trip_id uuid references public.trips(id) on delete set null,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  expense_date date not null,
  category text not null,
  supplier text not null default '',
  reference text not null default '',
  amount numeric(16,2) not null check (amount >= 0),
  vat_amount numeric(16,2) not null default 0 check (vat_amount >= 0),
  payment_status text not null default 'incurred',
  notes text not null default '',
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index expenses_org_date_idx on public.expenses (organisation_id, expense_date desc);
create index expenses_trip_idx on public.expenses (trip_id);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  trip_id uuid references public.trips(id) on delete cascade,
  expense_id uuid references public.expenses(id) on delete cascade,
  category text not null,
  original_name text not null,
  storage_path text not null,
  content_type text not null,
  size_bytes bigint not null check (size_bytes >= 0 and size_bytes <= 15728640),
  checksum text not null,
  status text not null default 'uploaded' check (status in ('uploaded', 'needs-review', 'approved', 'rejected')),
  extraction jsonb not null default '{}'::jsonb,
  created_by uuid not null default auth.uid() references auth.users(id),
  reviewed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  unique (organisation_id, checksum),
  unique (storage_path)
);

create index documents_org_created_idx on public.documents (organisation_id, created_at desc);
create index documents_trip_idx on public.documents (trip_id);

alter table public.trip_events
  add constraint trip_events_evidence_document_fk
  foreign key (evidence_document_id) references public.documents(id) on delete set null;

create table public.finance_documents (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  document_number text not null,
  document_type text not null check (document_type in ('quotation', 'invoice', 'credit-note')),
  status text not null default 'draft',
  client_id uuid references public.clients(id) on delete set null,
  source_quotation_id uuid references public.finance_documents(id) on delete set null,
  issue_date date not null,
  supply_date date,
  due_date date,
  expiry_date date,
  project text not null default '',
  commodity text not null default '',
  loading_location text not null default '',
  delivery_location text not null default '',
  purchase_order_number text not null default '',
  client_reference text not null default '',
  currency text not null default 'ZAR',
  pricing_mode text not null default 'exclusive',
  amount_paid numeric(16,2) not null default 0,
  raw_subtotal numeric(16,2) not null default 0,
  discount_total numeric(16,2) not null default 0,
  subtotal_ex_vat numeric(16,2) not null default 0,
  vat_total numeric(16,2) not null default 0,
  grand_total numeric(16,2) not null default 0,
  balance_due numeric(16,2) not null default 0,
  notes text not null default '',
  terms text not null default '',
  issued_at timestamptz,
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organisation_id, document_number)
);

create index finance_documents_org_updated_idx on public.finance_documents (organisation_id, updated_at desc);
create index finance_documents_client_idx on public.finance_documents (client_id);

create table public.finance_line_items (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  document_id uuid not null references public.finance_documents(id) on delete cascade,
  position integer not null,
  category text not null default 'service',
  description text not null,
  quantity numeric(14,4) not null default 1,
  unit text not null default 'Each',
  rate numeric(16,4) not null default 0,
  discount_type text not null default 'percentage',
  discount_value numeric(16,4) not null default 0,
  vat_treatment text not null default 'standard',
  vat_rate numeric(8,4) not null default 15,
  price_includes_vat boolean not null default false,
  raw_amount numeric(16,2) not null default 0,
  discount_amount numeric(16,2) not null default 0,
  net_amount numeric(16,2) not null default 0,
  vat_amount numeric(16,2) not null default 0,
  total_amount numeric(16,2) not null default 0,
  unique (document_id, position)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  document_id uuid not null references public.finance_documents(id) on delete cascade,
  amount numeric(16,2) not null check (amount > 0),
  payment_date date not null,
  reference text not null default '',
  method text not null default 'Bank transfer',
  notes text not null default '',
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now()
);

create index payments_document_idx on public.payments (document_id, payment_date desc);

create table public.freight_analyses (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  title text not null default 'Freight profitability analysis',
  client_name text not null default '',
  commodity text not null default '',
  loading_location text not null default '',
  delivery_location text not null default '',
  source_document_id uuid references public.documents(id) on delete set null,
  inputs jsonb not null default '{}'::jsonb,
  results jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft', 'review', 'approved', 'archived')),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index freight_analyses_org_updated_idx on public.freight_analyses (organisation_id, updated_at desc);

create table public.negotiations (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  analysis_id uuid references public.freight_analyses(id) on delete set null,
  client_name text not null default '',
  route text not null default '',
  commodity text not null default '',
  status text not null default 'draft',
  current_rate numeric(16,2) not null default 0,
  proposed_rate numeric(16,2) not null default 0,
  floor_rate numeric(16,2) not null default 0,
  target_rate numeric(16,2) not null default 0,
  snapshot jsonb not null default '{}'::jsonb,
  advice jsonb not null default '{}'::jsonb,
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index negotiations_org_updated_idx on public.negotiations (organisation_id, updated_at desc);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  entity_type text not null,
  entity_id uuid,
  action text not null,
  summary text not null,
  metadata jsonb not null default '{}'::jsonb,
  actor_id uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now()
);

create index audit_events_org_created_idx on public.audit_events (organisation_id, created_at desc);

create or replace function private.touch_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at before update on public.profiles for each row execute function private.touch_updated_at();
create trigger organisations_touch_updated_at before update on public.organisations for each row execute function private.touch_updated_at();
create trigger memberships_touch_updated_at before update on public.organisation_memberships for each row execute function private.touch_updated_at();
create trigger clients_touch_updated_at before update on public.clients for each row execute function private.touch_updated_at();
create trigger vehicles_touch_updated_at before update on public.vehicles for each row execute function private.touch_updated_at();
create trigger drivers_touch_updated_at before update on public.drivers for each row execute function private.touch_updated_at();
create trigger trips_touch_updated_at before update on public.trips for each row execute function private.touch_updated_at();
create trigger expenses_touch_updated_at before update on public.expenses for each row execute function private.touch_updated_at();
create trigger finance_documents_touch_updated_at before update on public.finance_documents for each row execute function private.touch_updated_at();
create trigger freight_analyses_touch_updated_at before update on public.freight_analyses for each row execute function private.touch_updated_at();
create trigger negotiations_touch_updated_at before update on public.negotiations for each row execute function private.touch_updated_at();

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, coalesce(new.email, ''), coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end;
$$;

revoke all on function private.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

alter table public.profiles enable row level security;
alter table public.organisations enable row level security;
alter table public.organisation_memberships enable row level security;
alter table public.clients enable row level security;
alter table public.vehicles enable row level security;
alter table public.drivers enable row level security;
alter table public.trips enable row level security;
alter table public.trip_events enable row level security;
alter table public.expenses enable row level security;
alter table public.documents enable row level security;
alter table public.finance_documents enable row level security;
alter table public.finance_line_items enable row level security;
alter table public.payments enable row level security;
alter table public.freight_analyses enable row level security;
alter table public.negotiations enable row level security;
alter table public.audit_events enable row level security;

create policy profiles_select_own on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy profiles_insert_own on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy profiles_update_own on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy organisations_select_member on public.organisations for select to authenticated
using (created_by = (select auth.uid()) or private.is_org_member(id, null));
create policy organisations_insert_owner on public.organisations for insert to authenticated
with check (created_by = (select auth.uid()));
create policy organisations_update_owner on public.organisations for update to authenticated
using (private.is_org_member(id, array['owner'])) with check (private.is_org_member(id, array['owner']));
create policy organisations_delete_owner on public.organisations for delete to authenticated
using (private.is_org_member(id, array['owner']));

create policy memberships_select_member on public.organisation_memberships for select to authenticated
using (user_id = (select auth.uid()) or private.is_org_member(organisation_id, null));
create policy memberships_insert_owner on public.organisation_memberships for insert to authenticated
with check (
  private.is_org_member(organisation_id, array['owner'])
  or (
    user_id = (select auth.uid()) and role = 'owner' and status = 'active'
    and exists (
      select 1 from public.organisations organisation
      where organisation.id = organisation_memberships.organisation_id
        and organisation.created_by = (select auth.uid())
    )
  )
);
create policy memberships_update_owner on public.organisation_memberships for update to authenticated
using (private.is_org_member(organisation_id, array['owner']))
with check (private.is_org_member(organisation_id, array['owner']));
create policy memberships_delete_owner on public.organisation_memberships for delete to authenticated
using (private.is_org_member(organisation_id, array['owner']));

create policy clients_select_finance on public.clients for select to authenticated
using (private.is_org_member(organisation_id, array['owner','finance','accountant']));
create policy clients_insert_finance on public.clients for insert to authenticated
with check (private.is_org_member(organisation_id, array['owner','finance','accountant']) and created_by = (select auth.uid()));
create policy clients_update_finance on public.clients for update to authenticated
using (private.is_org_member(organisation_id, array['owner','finance','accountant']))
with check (private.is_org_member(organisation_id, array['owner','finance','accountant']));
create policy clients_delete_owner on public.clients for delete to authenticated
using (private.is_org_member(organisation_id, array['owner','finance']));

create policy vehicles_select_member on public.vehicles for select to authenticated using (private.is_org_member(organisation_id, null));
create policy vehicles_insert_manager on public.vehicles for insert to authenticated
with check (private.is_org_member(organisation_id, array['owner','dispatcher']) and created_by = (select auth.uid()));
create policy vehicles_update_manager on public.vehicles for update to authenticated
using (private.is_org_member(organisation_id, array['owner','dispatcher']))
with check (private.is_org_member(organisation_id, array['owner','dispatcher']));
create policy vehicles_delete_owner on public.vehicles for delete to authenticated using (private.is_org_member(organisation_id, array['owner']));

create policy drivers_select_member on public.drivers for select to authenticated using (private.is_org_member(organisation_id, null));
create policy drivers_insert_manager on public.drivers for insert to authenticated
with check (private.is_org_member(organisation_id, array['owner','dispatcher']) and created_by = (select auth.uid()));
create policy drivers_update_manager on public.drivers for update to authenticated
using (private.is_org_member(organisation_id, array['owner','dispatcher']))
with check (private.is_org_member(organisation_id, array['owner','dispatcher']));
create policy drivers_delete_owner on public.drivers for delete to authenticated using (private.is_org_member(organisation_id, array['owner']));

create policy trips_select_assigned on public.trips for select to authenticated using (private.can_access_trip(organisation_id, id));
create policy trips_insert_assigned on public.trips for insert to authenticated
with check (
  created_by = (select auth.uid()) and (
    private.is_org_member(organisation_id, array['owner','dispatcher'])
    or (
      private.is_org_member(organisation_id, array['driver'])
      and exists (
        select 1 from public.drivers driver
        join public.organisation_memberships membership on membership.id = driver.membership_id
        where driver.id = driver_id and membership.user_id = (select auth.uid())
      )
    )
  )
);
create policy trips_update_assigned on public.trips for update to authenticated
using (private.can_access_trip(organisation_id, id))
with check (private.can_access_trip(organisation_id, id));
create policy trips_delete_manager on public.trips for delete to authenticated
using (private.is_org_member(organisation_id, array['owner','dispatcher']));

create policy trip_events_select_assigned on public.trip_events for select to authenticated using (private.can_access_trip(organisation_id, trip_id));
create policy trip_events_insert_assigned on public.trip_events for insert to authenticated
with check (private.can_access_trip(organisation_id, trip_id) and created_by = (select auth.uid()));
create policy trip_events_update_manager on public.trip_events for update to authenticated
using (private.is_org_member(organisation_id, array['owner','dispatcher']))
with check (private.is_org_member(organisation_id, array['owner','dispatcher']));
create policy trip_events_delete_manager on public.trip_events for delete to authenticated
using (private.is_org_member(organisation_id, array['owner','dispatcher']));

create policy expenses_select_authorised on public.expenses for select to authenticated
using (
  private.is_org_member(organisation_id, array['owner','finance','dispatcher','accountant'])
  or (trip_id is not null and private.can_access_trip(organisation_id, trip_id))
);
create policy expenses_insert_authorised on public.expenses for insert to authenticated
with check (
  created_by = (select auth.uid()) and (
    private.is_org_member(organisation_id, array['owner','finance','dispatcher','accountant'])
    or (trip_id is not null and private.can_access_trip(organisation_id, trip_id))
  )
);
create policy expenses_update_authorised on public.expenses for update to authenticated
using (private.is_org_member(organisation_id, array['owner','finance']) or created_by = (select auth.uid()))
with check (private.is_org_member(organisation_id, array['owner','finance']) or created_by = (select auth.uid()));
create policy expenses_delete_finance on public.expenses for delete to authenticated
using (private.is_org_member(organisation_id, array['owner','finance']));

create policy documents_select_authorised on public.documents for select to authenticated
using (
  private.is_org_member(organisation_id, array['owner','finance','dispatcher','accountant','viewer'])
  or (trip_id is not null and private.can_access_trip(organisation_id, trip_id))
);
create policy documents_insert_authorised on public.documents for insert to authenticated
with check (
  created_by = (select auth.uid()) and (
    private.is_org_member(organisation_id, array['owner','finance','dispatcher'])
    or (trip_id is not null and private.can_access_trip(organisation_id, trip_id))
  )
);
create policy documents_update_reviewer on public.documents for update to authenticated
using (private.is_org_member(organisation_id, array['owner','finance','dispatcher']))
with check (private.is_org_member(organisation_id, array['owner','finance','dispatcher']));
create policy documents_delete_owner on public.documents for delete to authenticated
using (private.is_org_member(organisation_id, array['owner','finance']));

create policy finance_documents_select_finance on public.finance_documents for select to authenticated
using (private.is_org_member(organisation_id, array['owner','finance','accountant']));
create policy finance_documents_insert_finance on public.finance_documents for insert to authenticated
with check (private.is_org_member(organisation_id, array['owner','finance','accountant']) and created_by = (select auth.uid()));
create policy finance_documents_update_finance on public.finance_documents for update to authenticated
using (private.is_org_member(organisation_id, array['owner','finance','accountant']))
with check (private.is_org_member(organisation_id, array['owner','finance','accountant']));
create policy finance_documents_delete_owner on public.finance_documents for delete to authenticated
using (private.is_org_member(organisation_id, array['owner','finance']));

create policy finance_line_items_select_finance on public.finance_line_items for select to authenticated
using (private.is_org_member(organisation_id, array['owner','finance','accountant']));
create policy finance_line_items_insert_finance on public.finance_line_items for insert to authenticated
with check (private.is_org_member(organisation_id, array['owner','finance','accountant']));
create policy finance_line_items_update_finance on public.finance_line_items for update to authenticated
using (private.is_org_member(organisation_id, array['owner','finance','accountant']))
with check (private.is_org_member(organisation_id, array['owner','finance','accountant']));
create policy finance_line_items_delete_finance on public.finance_line_items for delete to authenticated
using (private.is_org_member(organisation_id, array['owner','finance','accountant']));

create policy payments_select_finance on public.payments for select to authenticated
using (private.is_org_member(organisation_id, array['owner','finance','accountant']));
create policy payments_insert_finance on public.payments for insert to authenticated
with check (private.is_org_member(organisation_id, array['owner','finance','accountant']) and created_by = (select auth.uid()));
create policy payments_update_finance on public.payments for update to authenticated
using (private.is_org_member(organisation_id, array['owner','finance']))
with check (private.is_org_member(organisation_id, array['owner','finance']));
create policy payments_delete_owner on public.payments for delete to authenticated
using (private.is_org_member(organisation_id, array['owner','finance']));

create policy freight_analyses_select_commercial on public.freight_analyses for select to authenticated
using (private.is_org_member(organisation_id, array['owner','finance','dispatcher']));
create policy freight_analyses_insert_commercial on public.freight_analyses for insert to authenticated
with check (private.is_org_member(organisation_id, array['owner','finance','dispatcher']) and created_by = (select auth.uid()));
create policy freight_analyses_update_commercial on public.freight_analyses for update to authenticated
using (private.is_org_member(organisation_id, array['owner','finance','dispatcher']))
with check (private.is_org_member(organisation_id, array['owner','finance','dispatcher']));
create policy freight_analyses_delete_owner on public.freight_analyses for delete to authenticated using (private.is_org_member(organisation_id, array['owner']));

create policy negotiations_select_commercial on public.negotiations for select to authenticated
using (private.is_org_member(organisation_id, array['owner','finance','dispatcher']));
create policy negotiations_insert_commercial on public.negotiations for insert to authenticated
with check (private.is_org_member(organisation_id, array['owner','finance','dispatcher']) and created_by = (select auth.uid()));
create policy negotiations_update_commercial on public.negotiations for update to authenticated
using (private.is_org_member(organisation_id, array['owner','finance','dispatcher']))
with check (private.is_org_member(organisation_id, array['owner','finance','dispatcher']));
create policy negotiations_delete_owner on public.negotiations for delete to authenticated using (private.is_org_member(organisation_id, array['owner']));

create policy audit_events_select_management on public.audit_events for select to authenticated
using (private.is_org_member(organisation_id, array['owner','finance','dispatcher','accountant']));
create policy audit_events_insert_member on public.audit_events for insert to authenticated
with check (private.is_org_member(organisation_id, null) and actor_id = (select auth.uid()));

create view public.organisation_hub_summary
with (security_invoker = true)
as
select
  organisation.id as organisation_id,
  organisation.name,
  organisation.plan,
  organisation.status,
  (select count(*) from public.vehicles vehicle where vehicle.organisation_id = organisation.id and vehicle.status = 'active') as active_vehicles,
  (select count(*) from public.drivers driver where driver.organisation_id = organisation.id and driver.status = 'active') as active_drivers,
  (select count(*) from public.trips trip where trip.organisation_id = organisation.id and trip.trip_date >= date_trunc('month', current_date)::date) as trips_this_month,
  (select coalesce(sum(trip.tonnes), 0) from public.trips trip where trip.organisation_id = organisation.id and trip.trip_date >= date_trunc('month', current_date)::date) as tonnes_this_month,
  (select coalesce(sum(document.grand_total), 0) from public.finance_documents document where document.organisation_id = organisation.id and document.document_type = 'invoice' and document.status not in ('void', 'cancelled')) as invoiced_value,
  (select count(*) from public.documents document where document.organisation_id = organisation.id and document.status = 'needs-review') as documents_to_review,
  (select count(*) from public.freight_analyses analysis where analysis.organisation_id = organisation.id and analysis.status in ('draft', 'review')) as active_analyses
from public.organisations organisation;

grant select, insert, update, delete on table
  public.profiles,
  public.organisations,
  public.organisation_memberships,
  public.clients,
  public.vehicles,
  public.drivers,
  public.trips,
  public.trip_events,
  public.expenses,
  public.documents,
  public.finance_documents,
  public.finance_line_items,
  public.payments,
  public.freight_analyses,
  public.negotiations,
  public.audit_events
to authenticated;

grant select on public.organisation_hub_summary to authenticated;
grant usage, select on all sequences in schema public to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'mkhonto-documents',
  'mkhonto-documents',
  false,
  15728640,
  array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function private.storage_organisation_id(object_name text)
returns uuid
language plpgsql
immutable
security invoker
set search_path = ''
as $$
begin
  return nullif(split_part(object_name, '/', 1), '')::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;

revoke all on function private.storage_organisation_id(text) from public, anon;
grant execute on function private.storage_organisation_id(text) to authenticated;

create policy storage_documents_select_member on storage.objects for select to authenticated
using (
  bucket_id = 'mkhonto-documents'
  and private.is_org_member(private.storage_organisation_id(name), null)
);

create policy storage_documents_insert_member on storage.objects for insert to authenticated
with check (
  bucket_id = 'mkhonto-documents'
  and private.is_org_member(private.storage_organisation_id(name), array['owner','finance','dispatcher','driver'])
);

create policy storage_documents_update_owner on storage.objects for update to authenticated
using (
  bucket_id = 'mkhonto-documents'
  and private.is_org_member(private.storage_organisation_id(name), array['owner','finance','dispatcher','driver'])
  and owner_id = (select auth.uid())::text
)
with check (
  bucket_id = 'mkhonto-documents'
  and private.is_org_member(private.storage_organisation_id(name), array['owner','finance','dispatcher','driver'])
  and owner_id = (select auth.uid())::text
);

create policy storage_documents_delete_owner on storage.objects for delete to authenticated
using (
  bucket_id = 'mkhonto-documents'
  and (
    private.is_org_member(private.storage_organisation_id(name), array['owner','finance'])
    or owner_id = (select auth.uid())::text
  )
);

commit;
