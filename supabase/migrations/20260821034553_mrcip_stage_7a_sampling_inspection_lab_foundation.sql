create unique index if not exists laboratories_org_id_uidx on public.laboratories(organisation_id,id);
create unique index if not exists seller_offer_specs_org_id_uidx on public.seller_offer_specs(organisation_id,id);

create table public.commodity_sampling_requests (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  request_reference text not null,
  request_type text not null default 'sampling' check (request_type in ('sampling','inspection','sampling_and_inspection')),
  opportunity_id uuid null,
  seller_offer_id uuid null,
  mine_id uuid null,
  laboratory_id uuid null,
  commodity_id uuid not null,
  product_id uuid null,
  status text not null default 'draft' check (status in ('draft','requested','scheduled','in_progress','completed','cancelled','rejected')),
  protected_record boolean not null default true,
  requested_scope jsonb not null default '[]'::jsonb,
  sampling_location_reference text not null default '',
  instructions text not null default '',
  requested_at timestamptz null,
  scheduled_at timestamptz null,
  due_at timestamptz null,
  completed_at timestamptz null,
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,request_reference),
  constraint commodity_sampling_requests_opportunity_fk foreign key (organisation_id,opportunity_id) references public.opportunities(organisation_id,id) on delete restrict,
  constraint commodity_sampling_requests_offer_fk foreign key (organisation_id,seller_offer_id) references public.seller_supply_offers(organisation_id,id) on delete restrict,
  constraint commodity_sampling_requests_mine_fk foreign key (organisation_id,mine_id) references public.mines(organisation_id,id) on delete restrict,
  constraint commodity_sampling_requests_lab_fk foreign key (organisation_id,laboratory_id) references public.laboratories(organisation_id,id) on delete restrict,
  constraint commodity_sampling_requests_commodity_fk foreign key (organisation_id,commodity_id) references public.commodities(organisation_id,id) on delete restrict,
  constraint commodity_sampling_requests_product_fk foreign key (organisation_id,product_id) references public.commodity_products(organisation_id,id) on delete restrict,
  constraint commodity_sampling_requests_target_check check (opportunity_id is not null or seller_offer_id is not null or mine_id is not null),
  constraint commodity_sampling_requests_schedule_check check (due_at is null or scheduled_at is null or due_at >= scheduled_at)
);
create index commodity_sampling_requests_status_idx on public.commodity_sampling_requests(organisation_id,status,due_at);
create index commodity_sampling_requests_opportunity_idx on public.commodity_sampling_requests(organisation_id,opportunity_id) where opportunity_id is not null;
create index commodity_sampling_requests_offer_idx on public.commodity_sampling_requests(organisation_id,seller_offer_id) where seller_offer_id is not null;
create index commodity_sampling_requests_mine_idx on public.commodity_sampling_requests(organisation_id,mine_id) where mine_id is not null;
create index commodity_sampling_requests_lab_idx on public.commodity_sampling_requests(organisation_id,laboratory_id) where laboratory_id is not null;
create index commodity_sampling_requests_commodity_idx on public.commodity_sampling_requests(organisation_id,commodity_id,product_id);
create index commodity_sampling_requests_created_by_idx on public.commodity_sampling_requests(created_by);
create index commodity_sampling_requests_updated_by_idx on public.commodity_sampling_requests(updated_by);

create table public.commodity_samples (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  request_id uuid not null,
  parent_sample_id uuid null,
  sample_reference text not null,
  sample_type text not null default 'primary' check (sample_type in ('primary','split','duplicate','reference','retained','composite','other')),
  status text not null default 'collected' check (status in ('collected','sealed','in_transit','received_at_lab','under_test','retained','disposed','rejected')),
  sample_mass_kg numeric(18,6) null check (sample_mass_kg is null or sample_mass_kg > 0),
  package_count integer not null default 1 check (package_count > 0),
  seal_number text not null default '',
  collection_location text not null default '',
  collected_at timestamptz not null,
  collected_by_name text not null default '',
  condition_notes text not null default '',
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,sample_reference),
  constraint commodity_samples_request_fk foreign key (organisation_id,request_id) references public.commodity_sampling_requests(organisation_id,id) on delete restrict,
  constraint commodity_samples_parent_fk foreign key (organisation_id,parent_sample_id) references public.commodity_samples(organisation_id,id) on delete restrict
);
create index commodity_samples_request_idx on public.commodity_samples(organisation_id,request_id,status);
create index commodity_samples_parent_idx on public.commodity_samples(organisation_id,parent_sample_id) where parent_sample_id is not null;
create index commodity_samples_created_by_idx on public.commodity_samples(created_by);
create index commodity_samples_updated_by_idx on public.commodity_samples(updated_by);

create table public.sample_custody_events (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  sample_id uuid not null,
  event_type text not null check (event_type in ('collected','sealed','handover','received','split','repacked','seal_checked','test_started','retained','released','disposed','exception')),
  occurred_at timestamptz not null,
  from_custodian text not null default '',
  to_custodian text not null default '',
  location text not null default '',
  seal_number text not null default '',
  condition_notes text not null default '',
  evidence_document_id uuid null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint sample_custody_events_sample_fk foreign key (organisation_id,sample_id) references public.commodity_samples(organisation_id,id) on delete restrict,
  constraint sample_custody_events_document_fk foreign key (organisation_id,evidence_document_id) references public.documents(organisation_id,id) on delete restrict
);
create index sample_custody_events_sample_idx on public.sample_custody_events(organisation_id,sample_id,occurred_at);
create index sample_custody_events_document_idx on public.sample_custody_events(organisation_id,evidence_document_id) where evidence_document_id is not null;
create index sample_custody_events_created_by_idx on public.sample_custody_events(created_by);

create table public.laboratory_test_orders (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  request_id uuid not null,
  sample_id uuid not null,
  laboratory_id uuid not null,
  order_reference text not null,
  laboratory_reference text not null default '',
  status text not null default 'draft' check (status in ('draft','submitted','received','testing','reported','verified','cancelled','rejected')),
  requested_tests jsonb not null default '[]'::jsonb,
  instructions text not null default '',
  requested_at timestamptz null,
  sample_received_at timestamptz null,
  testing_started_at timestamptz null,
  reported_at timestamptz null,
  verified_at timestamptz null,
  verified_by uuid null references auth.users(id),
  due_at timestamptz null,
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,order_reference),
  constraint laboratory_test_orders_request_fk foreign key (organisation_id,request_id) references public.commodity_sampling_requests(organisation_id,id) on delete restrict,
  constraint laboratory_test_orders_sample_fk foreign key (organisation_id,sample_id) references public.commodity_samples(organisation_id,id) on delete restrict,
  constraint laboratory_test_orders_lab_fk foreign key (organisation_id,laboratory_id) references public.laboratories(organisation_id,id) on delete restrict
);
create index laboratory_test_orders_request_idx on public.laboratory_test_orders(organisation_id,request_id,status);
create index laboratory_test_orders_sample_idx on public.laboratory_test_orders(organisation_id,sample_id,status);
create index laboratory_test_orders_lab_idx on public.laboratory_test_orders(organisation_id,laboratory_id,status);
create index laboratory_test_orders_verified_by_idx on public.laboratory_test_orders(verified_by) where verified_by is not null;
create index laboratory_test_orders_created_by_idx on public.laboratory_test_orders(created_by);
create index laboratory_test_orders_updated_by_idx on public.laboratory_test_orders(updated_by);

create table public.laboratory_test_results (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  order_id uuid not null,
  spec_field_id uuid not null,
  revision_no integer not null default 1 check (revision_no > 0),
  previous_result_id uuid null,
  numeric_value numeric(20,8) null,
  text_value text null,
  unit text not null default '',
  basis text not null default '',
  test_method text not null default '',
  uncertainty numeric(20,8) null check (uncertainty is null or uncertainty >= 0),
  detection_limit numeric(20,8) null check (detection_limit is null or detection_limit >= 0),
  status text not null default 'draft' check (status in ('draft','reported','verified','rejected','superseded')),
  reported_at timestamptz null,
  verified_at timestamptz null,
  verified_by uuid null references auth.users(id),
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,order_id,spec_field_id,revision_no),
  constraint laboratory_test_results_value_check check ((numeric_value is not null) <> (text_value is not null)),
  constraint laboratory_test_results_order_fk foreign key (organisation_id,order_id) references public.laboratory_test_orders(organisation_id,id) on delete restrict,
  constraint laboratory_test_results_field_fk foreign key (organisation_id,spec_field_id) references public.commodity_spec_fields(organisation_id,id) on delete restrict,
  constraint laboratory_test_results_previous_fk foreign key (organisation_id,previous_result_id) references public.laboratory_test_results(organisation_id,id) on delete restrict
);
create index laboratory_test_results_order_idx on public.laboratory_test_results(organisation_id,order_id,status);
create index laboratory_test_results_field_idx on public.laboratory_test_results(organisation_id,spec_field_id,status);
create index laboratory_test_results_previous_idx on public.laboratory_test_results(organisation_id,previous_result_id) where previous_result_id is not null;
create index laboratory_test_results_verified_by_idx on public.laboratory_test_results(verified_by) where verified_by is not null;
create index laboratory_test_results_created_by_idx on public.laboratory_test_results(created_by);
create index laboratory_test_results_updated_by_idx on public.laboratory_test_results(updated_by);

create table public.laboratory_certificates (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  order_id uuid not null,
  laboratory_id uuid not null,
  document_id uuid not null,
  certificate_number text not null,
  certificate_type text not null default 'coa' check (certificate_type in ('coa','analysis_certificate','sampling_certificate','inspection_certificate','tml_certificate','other')),
  status text not null default 'received' check (status in ('received','verified','rejected','superseded')),
  issued_at timestamptz null,
  laboratory_signatory text not null default '',
  checksum_snapshot text not null default '',
  verification_notes text not null default '',
  verified_at timestamptz null,
  verified_by uuid null references auth.users(id),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,document_id),
  unique (organisation_id,laboratory_id,certificate_number),
  constraint laboratory_certificates_order_fk foreign key (organisation_id,order_id) references public.laboratory_test_orders(organisation_id,id) on delete restrict,
  constraint laboratory_certificates_lab_fk foreign key (organisation_id,laboratory_id) references public.laboratories(organisation_id,id) on delete restrict,
  constraint laboratory_certificates_document_fk foreign key (organisation_id,document_id) references public.documents(organisation_id,id) on delete restrict
);
create index laboratory_certificates_order_idx on public.laboratory_certificates(organisation_id,order_id,status);
create index laboratory_certificates_verified_by_idx on public.laboratory_certificates(verified_by) where verified_by is not null;
create index laboratory_certificates_created_by_idx on public.laboratory_certificates(created_by);
create index laboratory_certificates_updated_by_idx on public.laboratory_certificates(updated_by);

create table public.commodity_inspections (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  request_id uuid not null,
  laboratory_id uuid null,
  inspection_reference text not null,
  inspection_type text not null check (inspection_type in ('stockpile','pre_shipment','sampling_supervision','loading','weighbridge','vessel','quality_visual','other')),
  status text not null default 'draft' check (status in ('draft','completed','verified','rejected','superseded')),
  outcome text not null default 'pending' check (outcome in ('pending','pass','conditional','fail','not_applicable')),
  inspected_at timestamptz null,
  location text not null default '',
  inspector_name text not null default '',
  findings jsonb not null default '{}'::jsonb,
  evidence_document_id uuid null,
  verified_at timestamptz null,
  verified_by uuid null references auth.users(id),
  verification_notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,inspection_reference),
  constraint commodity_inspections_request_fk foreign key (organisation_id,request_id) references public.commodity_sampling_requests(organisation_id,id) on delete restrict,
  constraint commodity_inspections_lab_fk foreign key (organisation_id,laboratory_id) references public.laboratories(organisation_id,id) on delete restrict,
  constraint commodity_inspections_document_fk foreign key (organisation_id,evidence_document_id) references public.documents(organisation_id,id) on delete restrict
);
create index commodity_inspections_request_idx on public.commodity_inspections(organisation_id,request_id,status);
create index commodity_inspections_lab_idx on public.commodity_inspections(organisation_id,laboratory_id) where laboratory_id is not null;
create index commodity_inspections_document_idx on public.commodity_inspections(organisation_id,evidence_document_id) where evidence_document_id is not null;
create index commodity_inspections_verified_by_idx on public.commodity_inspections(verified_by) where verified_by is not null;
create index commodity_inspections_created_by_idx on public.commodity_inspections(created_by);
create index commodity_inspections_updated_by_idx on public.commodity_inspections(updated_by);

create table public.lab_result_publications (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  result_id uuid not null,
  certificate_id uuid not null,
  seller_offer_id uuid not null,
  seller_offer_spec_id uuid not null,
  publication_action text not null check (publication_action in ('inserted','replaced','no_change')),
  previous_value jsonb not null default '{}'::jsonb,
  published_value jsonb not null default '{}'::jsonb,
  notes text not null default '',
  published_at timestamptz not null default now(),
  published_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,result_id,seller_offer_id),
  constraint lab_result_publications_result_fk foreign key (organisation_id,result_id) references public.laboratory_test_results(organisation_id,id) on delete restrict,
  constraint lab_result_publications_certificate_fk foreign key (organisation_id,certificate_id) references public.laboratory_certificates(organisation_id,id) on delete restrict,
  constraint lab_result_publications_offer_fk foreign key (organisation_id,seller_offer_id) references public.seller_supply_offers(organisation_id,id) on delete restrict,
  constraint lab_result_publications_offer_spec_fk foreign key (organisation_id,seller_offer_spec_id) references public.seller_offer_specs(organisation_id,id) on delete restrict
);
create index lab_result_publications_offer_idx on public.lab_result_publications(organisation_id,seller_offer_id,published_at desc);
create index lab_result_publications_certificate_idx on public.lab_result_publications(organisation_id,certificate_id);
create index lab_result_publications_offer_spec_idx on public.lab_result_publications(organisation_id,seller_offer_spec_id);
create index lab_result_publications_published_by_idx on public.lab_result_publications(published_by);

alter table public.commodity_sampling_requests enable row level security;
alter table public.commodity_samples enable row level security;
alter table public.sample_custody_events enable row level security;
alter table public.laboratory_test_orders enable row level security;
alter table public.laboratory_test_results enable row level security;
alter table public.laboratory_certificates enable row level security;
alter table public.commodity_inspections enable row level security;
alter table public.lab_result_publications enable row level security;

revoke all on public.commodity_sampling_requests,public.commodity_samples,public.sample_custody_events,public.laboratory_test_orders,public.laboratory_test_results,public.laboratory_certificates,public.commodity_inspections,public.lab_result_publications from anon,authenticated;
