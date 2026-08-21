create table public.mrcip_data_quality_issues (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  issue_key text not null,
  entity_type text not null check (entity_type in ('counterparty','mine','laboratory','buyer_requirement','seller_offer','opportunity')),
  counterparty_id uuid null,
  mine_id uuid null,
  laboratory_id uuid null,
  buyer_requirement_id uuid null,
  seller_offer_id uuid null,
  opportunity_id uuid null,
  dimension text not null check (dimension in ('identity','contact','provenance','verification','commercial','specification','logistics','compliance','workflow','other')),
  severity text not null default 'medium' check (severity in ('info','low','medium','high','critical')),
  status text not null default 'open' check (status in ('open','resolved','waived')),
  message text not null,
  remediation text not null default '',
  auto_generated boolean not null default true,
  algorithm_version text not null default 'counterparty-quality-v1',
  protected_context boolean not null default false,
  source_id uuid null,
  evidence_document_id uuid null,
  detected_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  resolved_at timestamptz null,
  resolved_by uuid null references auth.users(id),
  waiver_reason text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,issue_key),
  constraint mrcip_data_quality_issues_counterparty_fk foreign key (organisation_id,counterparty_id) references public.counterparties(organisation_id,id) on delete cascade,
  constraint mrcip_data_quality_issues_mine_fk foreign key (organisation_id,mine_id) references public.mines(organisation_id,id) on delete cascade,
  constraint mrcip_data_quality_issues_laboratory_fk foreign key (organisation_id,laboratory_id) references public.laboratories(organisation_id,id) on delete cascade,
  constraint mrcip_data_quality_issues_requirement_fk foreign key (organisation_id,buyer_requirement_id) references public.buyer_requirements(organisation_id,id) on delete cascade,
  constraint mrcip_data_quality_issues_offer_fk foreign key (organisation_id,seller_offer_id) references public.seller_supply_offers(organisation_id,id) on delete cascade,
  constraint mrcip_data_quality_issues_opportunity_fk foreign key (organisation_id,opportunity_id) references public.opportunities(organisation_id,id) on delete cascade,
  constraint mrcip_data_quality_issues_source_fk foreign key (organisation_id,source_id) references public.intelligence_sources(organisation_id,id) on delete restrict,
  constraint mrcip_data_quality_issues_document_fk foreign key (organisation_id,evidence_document_id) references public.documents(organisation_id,id) on delete restrict,
  constraint mrcip_data_quality_issues_entity_check check (
    (entity_type='counterparty' and counterparty_id is not null and mine_id is null and laboratory_id is null and buyer_requirement_id is null and seller_offer_id is null and opportunity_id is null)
    or (entity_type='mine' and counterparty_id is null and mine_id is not null and laboratory_id is null and buyer_requirement_id is null and seller_offer_id is null and opportunity_id is null)
    or (entity_type='laboratory' and counterparty_id is null and mine_id is null and laboratory_id is not null and buyer_requirement_id is null and seller_offer_id is null and opportunity_id is null)
    or (entity_type='buyer_requirement' and counterparty_id is null and mine_id is null and laboratory_id is null and buyer_requirement_id is not null and seller_offer_id is null and opportunity_id is null)
    or (entity_type='seller_offer' and counterparty_id is null and mine_id is null and laboratory_id is null and buyer_requirement_id is null and seller_offer_id is not null and opportunity_id is null)
    or (entity_type='opportunity' and counterparty_id is null and mine_id is null and laboratory_id is null and buyer_requirement_id is null and seller_offer_id is null and opportunity_id is not null)
  )
);
create index mrcip_data_quality_issues_status_idx on public.mrcip_data_quality_issues(organisation_id,status,severity,entity_type);
create index mrcip_data_quality_issues_counterparty_idx on public.mrcip_data_quality_issues(organisation_id,counterparty_id) where counterparty_id is not null;
create index mrcip_data_quality_issues_mine_idx on public.mrcip_data_quality_issues(organisation_id,mine_id) where mine_id is not null;
create index mrcip_data_quality_issues_laboratory_idx on public.mrcip_data_quality_issues(organisation_id,laboratory_id) where laboratory_id is not null;
create index mrcip_data_quality_issues_requirement_idx on public.mrcip_data_quality_issues(organisation_id,buyer_requirement_id) where buyer_requirement_id is not null;
create index mrcip_data_quality_issues_offer_idx on public.mrcip_data_quality_issues(organisation_id,seller_offer_id) where seller_offer_id is not null;
create index mrcip_data_quality_issues_opportunity_idx on public.mrcip_data_quality_issues(organisation_id,opportunity_id) where opportunity_id is not null;
create index mrcip_data_quality_issues_source_idx on public.mrcip_data_quality_issues(organisation_id,source_id) where source_id is not null;
create index mrcip_data_quality_issues_document_idx on public.mrcip_data_quality_issues(organisation_id,evidence_document_id) where evidence_document_id is not null;
create index mrcip_data_quality_issues_resolved_by_idx on public.mrcip_data_quality_issues(resolved_by) where resolved_by is not null;
create index mrcip_data_quality_issues_created_by_idx on public.mrcip_data_quality_issues(created_by);
create index mrcip_data_quality_issues_updated_by_idx on public.mrcip_data_quality_issues(updated_by);

create table public.counterparty_risk_flags (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  counterparty_id uuid not null,
  category text not null check (category in ('identity','verification','authority','compliance','commercial','delivery','reputation','legal','other')),
  severity text not null default 'medium' check (severity in ('low','medium','high','critical')),
  status text not null default 'open' check (status in ('open','mitigated','resolved','false_positive')),
  title text not null,
  description text not null default '',
  mitigation text not null default '',
  source_id uuid null,
  evidence_document_id uuid null,
  protected_context boolean not null default true,
  flagged_at timestamptz not null default now(),
  flagged_by uuid not null default auth.uid() references auth.users(id),
  resolved_at timestamptz null,
  resolved_by uuid null references auth.users(id),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint counterparty_risk_flags_counterparty_fk foreign key (organisation_id,counterparty_id) references public.counterparties(organisation_id,id) on delete cascade,
  constraint counterparty_risk_flags_source_fk foreign key (organisation_id,source_id) references public.intelligence_sources(organisation_id,id) on delete restrict,
  constraint counterparty_risk_flags_document_fk foreign key (organisation_id,evidence_document_id) references public.documents(organisation_id,id) on delete restrict
);
create index counterparty_risk_flags_counterparty_idx on public.counterparty_risk_flags(organisation_id,counterparty_id,status,severity);
create index counterparty_risk_flags_source_idx on public.counterparty_risk_flags(organisation_id,source_id) where source_id is not null;
create index counterparty_risk_flags_document_idx on public.counterparty_risk_flags(organisation_id,evidence_document_id) where evidence_document_id is not null;
create index counterparty_risk_flags_flagged_by_idx on public.counterparty_risk_flags(flagged_by);
create index counterparty_risk_flags_resolved_by_idx on public.counterparty_risk_flags(resolved_by) where resolved_by is not null;
create index counterparty_risk_flags_created_by_idx on public.counterparty_risk_flags(created_by);
create index counterparty_risk_flags_updated_by_idx on public.counterparty_risk_flags(updated_by);

create table public.counterparty_quality_snapshots (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  counterparty_id uuid not null,
  score numeric(5,2) not null default 0 check (score between 0 and 100),
  grade text not null default 'E' check (grade in ('A','B','C','D','E')),
  components jsonb not null default '{}'::jsonb,
  open_issue_count integer not null default 0 check (open_issue_count >= 0),
  algorithm_version text not null default 'counterparty-quality-v1',
  generated_at timestamptz not null default now(),
  generated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint counterparty_quality_snapshots_counterparty_fk foreign key (organisation_id,counterparty_id) references public.counterparties(organisation_id,id) on delete cascade
);
create index counterparty_quality_snapshots_latest_idx on public.counterparty_quality_snapshots(organisation_id,counterparty_id,generated_at desc);
create index counterparty_quality_snapshots_generated_by_idx on public.counterparty_quality_snapshots(generated_by);

create table public.counterparty_risk_snapshots (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  counterparty_id uuid not null,
  risk_score numeric(5,2) not null default 0 check (risk_score between 0 and 100),
  risk_band text not null default 'low' check (risk_band in ('low','moderate','high','critical')),
  baseline_components jsonb not null default '{}'::jsonb,
  flag_components jsonb not null default '[]'::jsonb,
  open_flag_count integer not null default 0 check (open_flag_count >= 0),
  protected_context boolean not null default true,
  algorithm_version text not null default 'counterparty-risk-v1',
  generated_at timestamptz not null default now(),
  generated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint counterparty_risk_snapshots_counterparty_fk foreign key (organisation_id,counterparty_id) references public.counterparties(organisation_id,id) on delete cascade
);
create index counterparty_risk_snapshots_latest_idx on public.counterparty_risk_snapshots(organisation_id,counterparty_id,generated_at desc);
create index counterparty_risk_snapshots_generated_by_idx on public.counterparty_risk_snapshots(generated_by);

create table public.opportunity_score_snapshots (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  opportunity_id uuid not null,
  total_score numeric(5,2) not null default 0 check (total_score between 0 and 100),
  readiness_band text not null default 'early' check (readiness_band in ('early','developing','strong','high')),
  match_score numeric(5,2) not null default 0 check (match_score between 0 and 30),
  buyer_readiness_score numeric(5,2) not null default 0 check (buyer_readiness_score between 0 and 15),
  seller_readiness_score numeric(5,2) not null default 0 check (seller_readiness_score between 0 and 15),
  protocol_score numeric(5,2) not null default 0 check (protocol_score between 0 and 15),
  evidence_score numeric(5,2) not null default 0 check (evidence_score between 0 and 10),
  logistics_score numeric(5,2) not null default 0 check (logistics_score between 0 and 5),
  commercial_score numeric(5,2) not null default 0 check (commercial_score between 0 and 10),
  risk_penalty numeric(5,2) not null default 0 check (risk_penalty between 0 and 15),
  buyer_quality_snapshot_id uuid null,
  seller_quality_snapshot_id uuid null,
  buyer_risk_snapshot_id uuid null,
  seller_risk_snapshot_id uuid null,
  explanation jsonb not null default '{}'::jsonb,
  protected_context boolean not null default true,
  algorithm_version text not null default 'opportunity-readiness-v1',
  generated_at timestamptz not null default now(),
  generated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint opportunity_score_snapshots_opportunity_fk foreign key (organisation_id,opportunity_id) references public.opportunities(organisation_id,id) on delete cascade,
  constraint opportunity_score_snapshots_buyer_quality_fk foreign key (organisation_id,buyer_quality_snapshot_id) references public.counterparty_quality_snapshots(organisation_id,id) on delete restrict,
  constraint opportunity_score_snapshots_seller_quality_fk foreign key (organisation_id,seller_quality_snapshot_id) references public.counterparty_quality_snapshots(organisation_id,id) on delete restrict,
  constraint opportunity_score_snapshots_buyer_risk_fk foreign key (organisation_id,buyer_risk_snapshot_id) references public.counterparty_risk_snapshots(organisation_id,id) on delete restrict,
  constraint opportunity_score_snapshots_seller_risk_fk foreign key (organisation_id,seller_risk_snapshot_id) references public.counterparty_risk_snapshots(organisation_id,id) on delete restrict
);
create index opportunity_score_snapshots_latest_idx on public.opportunity_score_snapshots(organisation_id,opportunity_id,generated_at desc);
create index opportunity_score_snapshots_buyer_quality_idx on public.opportunity_score_snapshots(organisation_id,buyer_quality_snapshot_id) where buyer_quality_snapshot_id is not null;
create index opportunity_score_snapshots_seller_quality_idx on public.opportunity_score_snapshots(organisation_id,seller_quality_snapshot_id) where seller_quality_snapshot_id is not null;
create index opportunity_score_snapshots_buyer_risk_idx on public.opportunity_score_snapshots(organisation_id,buyer_risk_snapshot_id) where buyer_risk_snapshot_id is not null;
create index opportunity_score_snapshots_seller_risk_idx on public.opportunity_score_snapshots(organisation_id,seller_risk_snapshot_id) where seller_risk_snapshot_id is not null;
create index opportunity_score_snapshots_generated_by_idx on public.opportunity_score_snapshots(generated_by);

alter table public.mrcip_data_quality_issues enable row level security;
alter table public.counterparty_risk_flags enable row level security;
alter table public.counterparty_quality_snapshots enable row level security;
alter table public.counterparty_risk_snapshots enable row level security;
alter table public.opportunity_score_snapshots enable row level security;

revoke all on public.mrcip_data_quality_issues,public.counterparty_risk_flags,public.counterparty_quality_snapshots,public.counterparty_risk_snapshots,public.opportunity_score_snapshots from anon,authenticated;