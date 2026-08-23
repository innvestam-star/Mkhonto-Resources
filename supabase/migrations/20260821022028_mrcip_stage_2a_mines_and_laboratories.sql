create table public.mines (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  name text not null,
  legal_owner_counterparty_id uuid references public.counterparties(id) on delete set null,
  operator_counterparty_id uuid references public.counterparties(id) on delete set null,
  source_counterparty_id uuid references public.counterparties(id) on delete set null,
  mine_type text not null default '',
  mine_status text not null default 'unknown' check (mine_status in ('operating','care_maintenance','development','exploration','suspended','closed','unknown')),
  country text not null default '',
  province_state text not null default '',
  municipality text not null default '',
  nearest_town text not null default '',
  public_location_reference text not null default '',
  loading_location text not null default '',
  wash_plant boolean not null default false,
  processing_plant boolean not null default false,
  stockyard boolean not null default false,
  estimated_production_capacity_mt_month numeric(16,2) check (estimated_production_capacity_mt_month is null or estimated_production_capacity_mt_month >= 0),
  estimated_available_tonnage_mt numeric(16,2) check (estimated_available_tonnage_mt is null or estimated_available_tonnage_mt >= 0),
  loading_capacity_mt_day numeric(16,2) check (loading_capacity_mt_day is null or loading_capacity_mt_day >= 0),
  operating_hours text not null default '',
  loading_method text not null default '',
  weighbridge boolean,
  rail_access boolean,
  road_access boolean,
  export_capability boolean,
  rbct_access boolean,
  nearest_rail_siding text not null default '',
  nearest_port text not null default '',
  verification_status text not null default 'unverified',
  confidence_score numeric(5,2) not null default 0 check (confidence_score between 0 and 100),
  last_verified_at timestamptz,
  notes text not null default '',
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organisation_id, name)
);

create index mines_org_status_idx on public.mines (organisation_id, mine_status, verification_status);
create index mines_owner_idx on public.mines (legal_owner_counterparty_id) where legal_owner_counterparty_id is not null;
create index mines_operator_idx on public.mines (operator_counterparty_id) where operator_counterparty_id is not null;
create index mines_source_counterparty_idx on public.mines (source_counterparty_id) where source_counterparty_id is not null;
create index mines_created_by_idx on public.mines (created_by);
create index mines_updated_by_idx on public.mines (updated_by);
create index mines_name_trgm_idx on public.mines using gin (name extensions.gin_trgm_ops);

create table public.mine_protected_details (
  mine_id uuid primary key references public.mines(id) on delete cascade,
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  latitude numeric(10,7) check (latitude is null or latitude between -90 and 90),
  longitude numeric(10,7) check (longitude is null or longitude between -180 and 180),
  mine_gate_location text not null default '',
  stockpile_location text not null default '',
  stockpile_coordinates text not null default '',
  protected_source_notes text not null default '',
  sensitive_commercial_notes text not null default '',
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index mine_protected_details_org_idx on public.mine_protected_details (organisation_id);
create index mine_protected_details_created_by_idx on public.mine_protected_details (created_by);
create index mine_protected_details_updated_by_idx on public.mine_protected_details (updated_by);

create table public.mine_products (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  mine_id uuid not null references public.mines(id) on delete cascade,
  commodity_id uuid not null references public.commodities(id) on delete cascade,
  product_id uuid references public.commodity_products(id) on delete set null,
  product_name_override text not null default '',
  specification jsonb not null default '{}'::jsonb,
  monthly_capacity_mt numeric(16,2) check (monthly_capacity_mt is null or monthly_capacity_mt >= 0),
  available_tonnage_mt numeric(16,2) check (available_tonnage_mt is null or available_tonnage_mt >= 0),
  stockpile_tonnage_mt numeric(16,2) check (stockpile_tonnage_mt is null or stockpile_tonnage_mt >= 0),
  status text not null default 'unverified' check (status in ('unverified','verified','available','limited','reserved','allocated','sold','exhausted','suspended','expired')),
  valid_until date,
  notes text not null default '',
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (mine_id, commodity_id, product_id, product_name_override)
);

create index mine_products_org_mine_idx on public.mine_products (organisation_id, mine_id, status);
create index mine_products_commodity_idx on public.mine_products (commodity_id);
create index mine_products_product_idx on public.mine_products (product_id) where product_id is not null;
create index mine_products_created_by_idx on public.mine_products (created_by);
create index mine_products_updated_by_idx on public.mine_products (updated_by);

create table public.laboratories (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  counterparty_id uuid not null references public.counterparties(id) on delete cascade,
  laboratory_name text not null,
  city text not null default '',
  province_state text not null default '',
  country text not null default '',
  physical_address text not null default '',
  accreditation_body text not null default '',
  accreditation_number text not null default '',
  accreditation_expiry date,
  sample_preparation_capability boolean,
  inspection_capability boolean,
  sampling_capability boolean,
  tml_capability boolean,
  marine_cargo_capability boolean,
  typical_turnaround text not null default '',
  pricing_notes text not null default '',
  preferred_status text not null default 'standard' check (preferred_status in ('standard','preferred','restricted','inactive')),
  verification_status text not null default 'unverified',
  last_verified_at timestamptz,
  notes text not null default '',
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organisation_id, counterparty_id, laboratory_name)
);

create index laboratories_org_location_idx on public.laboratories (organisation_id, country, province_state, city);
create index laboratories_counterparty_idx on public.laboratories (counterparty_id);
create index laboratories_created_by_idx on public.laboratories (created_by);
create index laboratories_updated_by_idx on public.laboratories (updated_by);
create index laboratories_name_trgm_idx on public.laboratories using gin (laboratory_name extensions.gin_trgm_ops);

create table public.laboratory_capabilities (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  laboratory_id uuid not null references public.laboratories(id) on delete cascade,
  commodity_id uuid references public.commodities(id) on delete cascade,
  product_id uuid references public.commodity_products(id) on delete set null,
  capability_type text not null check (capability_type in ('analysis','sample_preparation','sampling','inspection','tml','marine_cargo','stockpile_inspection','weighbridge_verification','loading_supervision','vessel_inspection','other')),
  test_method text not null default '',
  capability_notes text not null default '',
  active boolean not null default true,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique nulls not distinct (laboratory_id, commodity_id, product_id, capability_type, test_method)
);

create index laboratory_capabilities_org_lab_idx on public.laboratory_capabilities (organisation_id, laboratory_id, active);
create index laboratory_capabilities_commodity_idx on public.laboratory_capabilities (commodity_id) where commodity_id is not null;
create index laboratory_capabilities_product_idx on public.laboratory_capabilities (product_id) where product_id is not null;
create index laboratory_capabilities_created_by_idx on public.laboratory_capabilities (created_by);

create trigger mines_touch_updated_at before update on public.mines for each row execute function private.touch_updated_at();
create trigger mine_protected_details_touch_updated_at before update on public.mine_protected_details for each row execute function private.touch_updated_at();
create trigger mine_products_touch_updated_at before update on public.mine_products for each row execute function private.touch_updated_at();
create trigger laboratories_touch_updated_at before update on public.laboratories for each row execute function private.touch_updated_at();
