create unique index if not exists counterparties_org_id_uidx on public.counterparties (organisation_id, id);
create unique index if not exists counterparty_contacts_org_id_uidx on public.counterparty_contacts (organisation_id, id);
create unique index if not exists commodities_org_id_uidx on public.commodities (organisation_id, id);
create unique index if not exists commodity_products_org_id_uidx on public.commodity_products (organisation_id, id);
create unique index if not exists commodity_spec_fields_org_id_uidx on public.commodity_spec_fields (organisation_id, id);
create unique index if not exists mines_org_id_uidx on public.mines (organisation_id, id);
create unique index if not exists intelligence_sources_org_id_uidx on public.intelligence_sources (organisation_id, id);

create table public.buyer_requirements (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  buyer_counterparty_id uuid not null,
  buyer_contact_id uuid,
  commodity_id uuid not null,
  product_id uuid,
  source_id uuid,
  reference text,
  status text not null default 'draft' check (status in ('draft','active','on_hold','matched','fulfilled','expired','cancelled')),
  priority smallint not null default 3 check (priority between 1 and 5),
  quantity_total_mt numeric(18,3) check (quantity_total_mt is null or quantity_total_mt >= 0),
  quantity_monthly_mt numeric(18,3) check (quantity_monthly_mt is null or quantity_monthly_mt >= 0),
  minimum_lot_mt numeric(18,3) check (minimum_lot_mt is null or minimum_lot_mt >= 0),
  contract_term_months integer check (contract_term_months is null or contract_term_months >= 0),
  delivery_start_date date,
  delivery_end_date date,
  destination_country text not null default '',
  destination_province_state text not null default '',
  destination_location text not null default '',
  preferred_origin_countries text[] not null default '{}',
  incoterm text not null default '',
  pricing_basis text not null default '',
  target_price numeric(18,4) check (target_price is null or target_price >= 0),
  currency text not null default 'USD',
  payment_terms text not null default '',
  payment_instrument text not null default '',
  inspection_required boolean not null default true,
  inspection_standard text not null default '',
  logistics_responsibility text not null default 'tbd' check (logistics_responsibility in ('buyer','seller','mkhonto','shared','tbd')),
  mkhonto_transport_requested boolean not null default false,
  transport_mode text not null default '',
  authority_status text not null default 'unverified' check (authority_status in ('unverified','requested','verified','expired','rejected')),
  mandate_status text not null default 'not_required' check (mandate_status in ('not_required','requested','received','verified','expired','rejected')),
  protection_status text not null default 'unprotected' check (protection_status in ('unprotected','pending','protected','expired')),
  valid_until date,
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid(),
  constraint buyer_requirements_dates_check check (delivery_end_date is null or delivery_start_date is null or delivery_end_date >= delivery_start_date),
  constraint buyer_requirements_buyer_fk foreign key (organisation_id, buyer_counterparty_id) references public.counterparties(organisation_id, id),
  constraint buyer_requirements_contact_fk foreign key (organisation_id, buyer_contact_id) references public.counterparty_contacts(organisation_id, id),
  constraint buyer_requirements_commodity_fk foreign key (organisation_id, commodity_id) references public.commodities(organisation_id, id),
  constraint buyer_requirements_product_fk foreign key (organisation_id, product_id) references public.commodity_products(organisation_id, id),
  constraint buyer_requirements_source_fk foreign key (organisation_id, source_id) references public.intelligence_sources(organisation_id, id)
);

create unique index buyer_requirements_org_id_uidx on public.buyer_requirements (organisation_id, id);
create unique index buyer_requirements_reference_uidx on public.buyer_requirements (organisation_id, lower(reference)) where reference is not null and btrim(reference) <> '';
create index buyer_requirements_org_status_idx on public.buyer_requirements (organisation_id, status, priority, valid_until);
create index buyer_requirements_buyer_idx on public.buyer_requirements (organisation_id, buyer_counterparty_id);
create index buyer_requirements_contact_idx on public.buyer_requirements (organisation_id, buyer_contact_id) where buyer_contact_id is not null;
create index buyer_requirements_commodity_product_idx on public.buyer_requirements (organisation_id, commodity_id, product_id);
create index buyer_requirements_source_idx on public.buyer_requirements (organisation_id, source_id) where source_id is not null;
create index buyer_requirements_created_by_idx on public.buyer_requirements (created_by);
create index buyer_requirements_updated_by_idx on public.buyer_requirements (updated_by);

create trigger buyer_requirements_touch_updated_at
before update on public.buyer_requirements
for each row execute function private.touch_updated_at();

create table public.seller_supply_offers (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  seller_counterparty_id uuid not null,
  seller_contact_id uuid,
  mine_id uuid,
  commodity_id uuid not null,
  product_id uuid,
  source_id uuid,
  reference text,
  status text not null default 'draft' check (status in ('draft','active','on_hold','reserved','sold','expired','cancelled')),
  is_protected boolean not null default false,
  quantity_available_mt numeric(18,3) check (quantity_available_mt is null or quantity_available_mt >= 0),
  quantity_monthly_mt numeric(18,3) check (quantity_monthly_mt is null or quantity_monthly_mt >= 0),
  minimum_lot_mt numeric(18,3) check (minimum_lot_mt is null or minimum_lot_mt >= 0),
  origin_country text not null default '',
  origin_province_state text not null default '',
  public_origin_reference text not null default '',
  loading_location text not null default '',
  loading_method text not null default '',
  price numeric(18,4) check (price is null or price >= 0),
  currency text not null default 'USD',
  price_basis text not null default '',
  incoterm text not null default '',
  payment_terms text not null default '',
  payment_instrument text not null default '',
  inspection_terms text not null default '',
  logistics_responsibility text not null default 'tbd' check (logistics_responsibility in ('buyer','seller','mkhonto','shared','tbd')),
  mkhonto_transport_available boolean not null default false,
  transport_mode text not null default '',
  authority_status text not null default 'unverified' check (authority_status in ('unverified','requested','verified','expired','rejected')),
  mandate_status text not null default 'not_required' check (mandate_status in ('not_required','requested','received','verified','expired','rejected')),
  protection_status text not null default 'unprotected' check (protection_status in ('unprotected','pending','protected','expired')),
  available_from date,
  valid_until date,
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid(),
  constraint seller_supply_offers_dates_check check (valid_until is null or available_from is null or valid_until >= available_from),
  constraint seller_supply_offers_seller_fk foreign key (organisation_id, seller_counterparty_id) references public.counterparties(organisation_id, id),
  constraint seller_supply_offers_contact_fk foreign key (organisation_id, seller_contact_id) references public.counterparty_contacts(organisation_id, id),
  constraint seller_supply_offers_mine_fk foreign key (organisation_id, mine_id) references public.mines(organisation_id, id),
  constraint seller_supply_offers_commodity_fk foreign key (organisation_id, commodity_id) references public.commodities(organisation_id, id),
  constraint seller_supply_offers_product_fk foreign key (organisation_id, product_id) references public.commodity_products(organisation_id, id),
  constraint seller_supply_offers_source_fk foreign key (organisation_id, source_id) references public.intelligence_sources(organisation_id, id)
);

create unique index seller_supply_offers_org_id_uidx on public.seller_supply_offers (organisation_id, id);
create unique index seller_supply_offers_reference_uidx on public.seller_supply_offers (organisation_id, lower(reference)) where reference is not null and btrim(reference) <> '';
create index seller_supply_offers_org_status_idx on public.seller_supply_offers (organisation_id, status, valid_until);
create index seller_supply_offers_seller_idx on public.seller_supply_offers (organisation_id, seller_counterparty_id);
create index seller_supply_offers_contact_idx on public.seller_supply_offers (organisation_id, seller_contact_id) where seller_contact_id is not null;
create index seller_supply_offers_mine_idx on public.seller_supply_offers (organisation_id, mine_id) where mine_id is not null;
create index seller_supply_offers_commodity_product_idx on public.seller_supply_offers (organisation_id, commodity_id, product_id);
create index seller_supply_offers_source_idx on public.seller_supply_offers (organisation_id, source_id) where source_id is not null;
create index seller_supply_offers_created_by_idx on public.seller_supply_offers (created_by);
create index seller_supply_offers_updated_by_idx on public.seller_supply_offers (updated_by);

create trigger seller_supply_offers_touch_updated_at
before update on public.seller_supply_offers
for each row execute function private.touch_updated_at();

create table public.buyer_requirement_specs (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  requirement_id uuid not null,
  spec_field_id uuid not null,
  mandatory boolean not null default true,
  weight numeric(6,3) not null default 1 check (weight > 0 and weight <= 100),
  minimum_numeric numeric(20,6),
  maximum_numeric numeric(20,6),
  target_numeric numeric(20,6),
  expected_text text,
  unit text not null default '',
  basis text not null default '',
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid(),
  constraint buyer_requirement_specs_range_check check (maximum_numeric is null or minimum_numeric is null or maximum_numeric >= minimum_numeric),
  constraint buyer_requirement_specs_requirement_fk foreign key (organisation_id, requirement_id) references public.buyer_requirements(organisation_id, id) on delete cascade,
  constraint buyer_requirement_specs_field_fk foreign key (organisation_id, spec_field_id) references public.commodity_spec_fields(organisation_id, id),
  unique (requirement_id, spec_field_id)
);
create index buyer_requirement_specs_org_req_idx on public.buyer_requirement_specs (organisation_id, requirement_id);
create index buyer_requirement_specs_org_field_idx on public.buyer_requirement_specs (organisation_id, spec_field_id);
create index buyer_requirement_specs_created_by_idx on public.buyer_requirement_specs (created_by);
create index buyer_requirement_specs_updated_by_idx on public.buyer_requirement_specs (updated_by);
create trigger buyer_requirement_specs_touch_updated_at before update on public.buyer_requirement_specs for each row execute function private.touch_updated_at();

create table public.seller_offer_specs (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  offer_id uuid not null,
  spec_field_id uuid not null,
  numeric_value numeric(20,6),
  text_value text,
  unit text not null default '',
  basis text not null default '',
  test_method text not null default '',
  certificate_document_id uuid references public.documents(id),
  tested_at timestamptz,
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid(),
  constraint seller_offer_specs_value_check check (numeric_value is not null or text_value is not null),
  constraint seller_offer_specs_offer_fk foreign key (organisation_id, offer_id) references public.seller_supply_offers(organisation_id, id) on delete cascade,
  constraint seller_offer_specs_field_fk foreign key (organisation_id, spec_field_id) references public.commodity_spec_fields(organisation_id, id),
  unique (offer_id, spec_field_id)
);
create index seller_offer_specs_org_offer_idx on public.seller_offer_specs (organisation_id, offer_id);
create index seller_offer_specs_org_field_idx on public.seller_offer_specs (organisation_id, spec_field_id);
create index seller_offer_specs_certificate_idx on public.seller_offer_specs (certificate_document_id) where certificate_document_id is not null;
create index seller_offer_specs_created_by_idx on public.seller_offer_specs (created_by);
create index seller_offer_specs_updated_by_idx on public.seller_offer_specs (updated_by);
create trigger seller_offer_specs_touch_updated_at before update on public.seller_offer_specs for each row execute function private.touch_updated_at();