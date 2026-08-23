create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  opportunity_number text not null,
  title text not null default '',
  match_id uuid not null,
  buyer_requirement_id uuid not null,
  seller_offer_id uuid not null,
  buyer_counterparty_id uuid not null,
  seller_counterparty_id uuid not null,
  commodity_id uuid not null,
  product_id uuid,
  status text not null default 'active' check (status in ('active','on_hold','closed','cancelled')),
  stage text not null default 'registered' check (stage in ('registered','protection','verification','disclosure_ready','disclosed','negotiation','contracting','contracted','closed_won','closed_lost','cancelled')),
  priority smallint not null default 3 check (priority between 1 and 5),
  is_protected boolean not null default true,
  disclosure_locked boolean not null default true,
  relationship_owner uuid,
  next_action text not null default '',
  next_action_due_at timestamptz,
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid(),
  constraint opportunities_match_fk foreign key (organisation_id, match_id) references public.commodity_matches(organisation_id, id),
  constraint opportunities_requirement_fk foreign key (organisation_id, buyer_requirement_id) references public.buyer_requirements(organisation_id, id),
  constraint opportunities_offer_fk foreign key (organisation_id, seller_offer_id) references public.seller_supply_offers(organisation_id, id),
  constraint opportunities_buyer_fk foreign key (organisation_id, buyer_counterparty_id) references public.counterparties(organisation_id, id),
  constraint opportunities_seller_fk foreign key (organisation_id, seller_counterparty_id) references public.counterparties(organisation_id, id),
  constraint opportunities_commodity_fk foreign key (organisation_id, commodity_id) references public.commodities(organisation_id, id),
  constraint opportunities_product_fk foreign key (organisation_id, product_id) references public.commodity_products(organisation_id, id),
  unique (organisation_id, opportunity_number),
  unique (match_id)
);
create unique index opportunities_org_id_uidx on public.opportunities (organisation_id, id);
create index opportunities_org_stage_idx on public.opportunities (organisation_id, status, stage, priority);
create index opportunities_buyer_idx on public.opportunities (organisation_id, buyer_counterparty_id);
create index opportunities_seller_idx on public.opportunities (organisation_id, seller_counterparty_id);
create index opportunities_org_product_idx on public.opportunities (organisation_id, product_id) where product_id is not null;
create index opportunities_relationship_owner_idx on public.opportunities (relationship_owner) where relationship_owner is not null;
create index opportunities_created_by_idx on public.opportunities (created_by);
create index opportunities_updated_by_idx on public.opportunities (updated_by);
create trigger opportunities_touch_updated_at before update on public.opportunities for each row execute function private.touch_updated_at();

create table public.opportunity_protocol_controls (
  opportunity_id uuid primary key,
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  protocol_step text not null default 'protect' check (protocol_step in ('protect','verify','disclose','contract','complete')),
  protection_status text not null default 'pending' check (protection_status in ('pending','protected','failed','expired','waived')),
  verification_status text not null default 'pending' check (verification_status in ('pending','verified','failed','expired')),
  disclosure_status text not null default 'locked' check (disclosure_status in ('locked','eligible','approved','partially_disclosed','disclosed','revoked')),
  contract_status text not null default 'not_started' check (contract_status in ('not_started','drafting','negotiating','executed','expired','terminated')),
  disclosure_eligible boolean not null default false,
  blocking_reasons jsonb not null default '[]'::jsonb,
  last_evaluated_at timestamptz,
  last_evaluated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid(),
  constraint opportunity_protocol_controls_opportunity_fk foreign key (organisation_id, opportunity_id) references public.opportunities(organisation_id, id) on delete cascade
);
create index opportunity_protocol_controls_org_step_idx on public.opportunity_protocol_controls (organisation_id, protocol_step, disclosure_eligible);
create index opportunity_protocol_controls_evaluated_by_idx on public.opportunity_protocol_controls (last_evaluated_by) where last_evaluated_by is not null;
create index opportunity_protocol_controls_updated_by_idx on public.opportunity_protocol_controls (updated_by);
create trigger opportunity_protocol_controls_touch_updated_at before update on public.opportunity_protocol_controls for each row execute function private.touch_updated_at();

create table public.opportunity_protection_records (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  opportunity_id uuid not null,
  record_type text not null check (record_type in ('ncnda','fee_protection','transaction_registration','commission_schedule','confidentiality_undertaking','other')),
  status text not null default 'draft' check (status in ('draft','requested','executed','verified','rejected','expired','revoked','waived')),
  required_for_disclosure boolean not null default false,
  document_id uuid,
  effective_date date,
  expiry_date date,
  protection_term_end date,
  includes_renewals boolean not null default true,
  affiliates_covered boolean not null default true,
  reference text not null default '',
  notes text not null default '',
  verified_at timestamptz,
  verified_by uuid,
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid(),
  constraint opportunity_protection_records_dates_check check (expiry_date is null or effective_date is null or expiry_date >= effective_date),
  constraint opportunity_protection_records_opportunity_fk foreign key (organisation_id, opportunity_id) references public.opportunities(organisation_id, id) on delete cascade,
  constraint opportunity_protection_records_document_fk foreign key (organisation_id, document_id) references public.documents(organisation_id, id)
);
create index opportunity_protection_records_org_opp_idx on public.opportunity_protection_records (organisation_id, opportunity_id, record_type, status);
create index opportunity_protection_records_document_idx on public.opportunity_protection_records (organisation_id, document_id) where document_id is not null;
create index opportunity_protection_records_verified_by_idx on public.opportunity_protection_records (verified_by) where verified_by is not null;
create index opportunity_protection_records_created_by_idx on public.opportunity_protection_records (created_by);
create index opportunity_protection_records_updated_by_idx on public.opportunity_protection_records (updated_by);
create trigger opportunity_protection_records_touch_updated_at before update on public.opportunity_protection_records for each row execute function private.touch_updated_at();

create table public.opportunity_kyc_cases (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  opportunity_id uuid not null,
  counterparty_id uuid not null,
  party_role text not null check (party_role in ('buyer','seller','facilitator','transporter','other')),
  status text not null default 'draft' check (status in ('draft','requested','in_review','verified','rejected','expired','escalated')),
  required_for_disclosure boolean not null default false,
  risk_rating text not null default 'unrated' check (risk_rating in ('unrated','low','medium','high','prohibited')),
  registration_verified boolean not null default false,
  ownership_verified boolean not null default false,
  authority_verified boolean not null default false,
  address_verified boolean not null default false,
  tax_verified boolean not null default false,
  sanctions_screening_status text not null default 'not_started' check (sanctions_screening_status in ('not_started','pending','clear','potential_match','escalated')),
  pep_screening_status text not null default 'not_started' check (pep_screening_status in ('not_started','pending','clear','potential_match','escalated')),
  capability_evidence_status text not null default 'not_requested' check (capability_evidence_status in ('not_requested','requested','received','verified','rejected')),
  valid_until date,
  reviewer_notes text not null default '',
  reviewed_at timestamptz,
  reviewed_by uuid,
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid(),
  constraint opportunity_kyc_cases_opportunity_fk foreign key (organisation_id, opportunity_id) references public.opportunities(organisation_id, id) on delete cascade,
  constraint opportunity_kyc_cases_counterparty_fk foreign key (organisation_id, counterparty_id) references public.counterparties(organisation_id, id),
  unique (opportunity_id, counterparty_id, party_role)
);
create index opportunity_kyc_cases_org_opp_idx on public.opportunity_kyc_cases (organisation_id, opportunity_id, status);
create index opportunity_kyc_cases_counterparty_idx on public.opportunity_kyc_cases (organisation_id, counterparty_id);
create index opportunity_kyc_cases_reviewed_by_idx on public.opportunity_kyc_cases (reviewed_by) where reviewed_by is not null;
create index opportunity_kyc_cases_created_by_idx on public.opportunity_kyc_cases (created_by);
create index opportunity_kyc_cases_updated_by_idx on public.opportunity_kyc_cases (updated_by);
create trigger opportunity_kyc_cases_touch_updated_at before update on public.opportunity_kyc_cases for each row execute function private.touch_updated_at();

create table public.opportunity_mandates (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  opportunity_id uuid not null,
  counterparty_id uuid not null,
  mandate_type text not null check (mandate_type in ('buyer','seller','facilitator','transporter','other')),
  status text not null default 'requested' check (status in ('requested','received','verified','rejected','expired','revoked','not_required')),
  required_for_disclosure boolean not null default false,
  authority_scope text not null default '',
  effective_date date,
  expiry_date date,
  document_id uuid,
  includes_affiliates boolean not null default false,
  includes_renewals boolean not null default false,
  notes text not null default '',
  verified_at timestamptz,
  verified_by uuid,
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid(),
  constraint opportunity_mandates_dates_check check (expiry_date is null or effective_date is null or expiry_date >= effective_date),
  constraint opportunity_mandates_opportunity_fk foreign key (organisation_id, opportunity_id) references public.opportunities(organisation_id, id) on delete cascade,
  constraint opportunity_mandates_counterparty_fk foreign key (organisation_id, counterparty_id) references public.counterparties(organisation_id, id),
  constraint opportunity_mandates_document_fk foreign key (organisation_id, document_id) references public.documents(organisation_id, id)
);
create index opportunity_mandates_org_opp_idx on public.opportunity_mandates (organisation_id, opportunity_id, mandate_type, status);
create index opportunity_mandates_counterparty_idx on public.opportunity_mandates (organisation_id, counterparty_id);
create index opportunity_mandates_document_idx on public.opportunity_mandates (organisation_id, document_id) where document_id is not null;
create index opportunity_mandates_verified_by_idx on public.opportunity_mandates (verified_by) where verified_by is not null;
create index opportunity_mandates_created_by_idx on public.opportunity_mandates (created_by);
create index opportunity_mandates_updated_by_idx on public.opportunity_mandates (updated_by);
create trigger opportunity_mandates_touch_updated_at before update on public.opportunity_mandates for each row execute function private.touch_updated_at();

create table public.opportunity_disclosures (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  opportunity_id uuid not null,
  recipient_counterparty_id uuid not null,
  disclosure_type text not null check (disclosure_type in ('seller_identity','mine_identity','seller_contact','mine_location','stockpile_location','pricing','assay_certificate','commercial_document','other')),
  status text not null default 'requested' check (status in ('requested','approved','disclosed','denied','revoked')),
  disclosure_summary text not null default '',
  prerequisites_snapshot jsonb not null default '{}'::jsonb,
  requested_at timestamptz not null default now(),
  requested_by uuid not null default auth.uid(),
  approved_at timestamptz,
  approved_by uuid,
  disclosed_at timestamptz,
  disclosed_by uuid,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid(),
  constraint opportunity_disclosures_opportunity_fk foreign key (organisation_id, opportunity_id) references public.opportunities(organisation_id, id) on delete cascade,
  constraint opportunity_disclosures_recipient_fk foreign key (organisation_id, recipient_counterparty_id) references public.counterparties(organisation_id, id)
);
create index opportunity_disclosures_org_opp_idx on public.opportunity_disclosures (organisation_id, opportunity_id, status, disclosure_type);
create index opportunity_disclosures_recipient_idx on public.opportunity_disclosures (organisation_id, recipient_counterparty_id);
create index opportunity_disclosures_requested_by_idx on public.opportunity_disclosures (requested_by);
create index opportunity_disclosures_approved_by_idx on public.opportunity_disclosures (approved_by) where approved_by is not null;
create index opportunity_disclosures_disclosed_by_idx on public.opportunity_disclosures (disclosed_by) where disclosed_by is not null;
create index opportunity_disclosures_updated_by_idx on public.opportunity_disclosures (updated_by);
create trigger opportunity_disclosures_touch_updated_at before update on public.opportunity_disclosures for each row execute function private.touch_updated_at();
