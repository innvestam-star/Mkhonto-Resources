create table public.mrcip_report_definitions (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  report_key text not null,
  name text not null,
  description text not null default '',
  report_kind text not null check (report_kind in ('counterparty_health','opportunity_pipeline','risk_register','watchlist_signals')),
  visibility text not null default 'private' check (visibility in ('private','shared','executive')),
  owner_user_id uuid not null references auth.users(id),
  watchlist_id uuid null,
  commodity_id uuid null,
  filters jsonb not null default '{}'::jsonb,
  protected_context boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,report_key),
  constraint mrcip_report_definitions_watchlist_fk foreign key (organisation_id,watchlist_id) references public.crm_watchlists(organisation_id,id) on delete restrict,
  constraint mrcip_report_definitions_commodity_fk foreign key (organisation_id,commodity_id) references public.commodities(organisation_id,id) on delete restrict,
  constraint mrcip_report_definitions_watchlist_kind_check check ((report_kind='watchlist_signals' and watchlist_id is not null) or report_kind<>'watchlist_signals')
);
create index mrcip_report_definitions_owner_idx on public.mrcip_report_definitions(organisation_id,owner_user_id,active);
create index mrcip_report_definitions_watchlist_idx on public.mrcip_report_definitions(organisation_id,watchlist_id) where watchlist_id is not null;
create index mrcip_report_definitions_commodity_idx on public.mrcip_report_definitions(organisation_id,commodity_id) where commodity_id is not null;

create table public.mrcip_report_runs (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  definition_id uuid not null,
  report_kind text not null check (report_kind in ('counterparty_health','opportunity_pipeline','risk_register','watchlist_signals')),
  row_count integer not null default 0 check (row_count >= 0),
  result_summary jsonb not null default '{}'::jsonb,
  protected_context boolean not null default false,
  algorithm_version text not null default 'mrcip-report-v1',
  generated_at timestamptz not null default now(),
  generated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint mrcip_report_runs_definition_fk foreign key (organisation_id,definition_id) references public.mrcip_report_definitions(organisation_id,id) on delete restrict
);
create index mrcip_report_runs_definition_latest_idx on public.mrcip_report_runs(organisation_id,definition_id,generated_at desc);
create index mrcip_report_runs_generated_by_idx on public.mrcip_report_runs(generated_by);

create table public.mrcip_watchlist_signal_snapshots (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  watchlist_id uuid not null,
  watchlist_item_id uuid not null,
  entity_type text not null check (entity_type in ('counterparty','mine','laboratory','buyer_requirement','seller_offer','opportunity')),
  signal_count integer not null default 0 check (signal_count >= 0),
  highest_severity text not null default 'none' check (highest_severity in ('none','info','low','medium','high','critical')),
  signals jsonb not null default '[]'::jsonb,
  protected_context boolean not null default false,
  algorithm_version text not null default 'watchlist-signals-v1',
  generated_at timestamptz not null default now(),
  generated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint mrcip_watchlist_signal_snapshots_watchlist_fk foreign key (organisation_id,watchlist_id) references public.crm_watchlists(organisation_id,id) on delete cascade,
  constraint mrcip_watchlist_signal_snapshots_item_fk foreign key (organisation_id,watchlist_item_id) references public.crm_watchlist_items(organisation_id,id) on delete cascade
);
create index mrcip_watchlist_signal_snapshots_latest_idx on public.mrcip_watchlist_signal_snapshots(organisation_id,watchlist_id,watchlist_item_id,generated_at desc);
create index mrcip_watchlist_signal_snapshots_generated_by_idx on public.mrcip_watchlist_signal_snapshots(generated_by);

create table public.mrcip_retrieval_requests (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  query_text text not null check (btrim(query_text)<>''),
  purpose text not null check (btrim(purpose)<>''),
  entity_types text[] not null default array['counterparty','mine','laboratory','buyer_requirement','seller_offer','opportunity']::text[],
  include_protected boolean not null default false,
  max_results integer not null default 20 check (max_results between 1 and 50),
  status text not null default 'requested' check (status in ('requested','completed','failed')),
  result_count integer not null default 0 check (result_count >= 0),
  error_message text not null default '',
  algorithm_version text not null default 'mrcip-retrieval-v1',
  requested_at timestamptz not null default now(),
  requested_by uuid not null default auth.uid() references auth.users(id),
  completed_at timestamptz null,
  unique (organisation_id,id)
);
create index mrcip_retrieval_requests_requester_idx on public.mrcip_retrieval_requests(organisation_id,requested_by,requested_at desc);
create index mrcip_retrieval_requests_status_idx on public.mrcip_retrieval_requests(organisation_id,status,requested_at desc);

alter table public.mrcip_report_definitions enable row level security;
alter table public.mrcip_report_runs enable row level security;
alter table public.mrcip_watchlist_signal_snapshots enable row level security;
alter table public.mrcip_retrieval_requests enable row level security;

revoke all on public.mrcip_report_definitions,public.mrcip_report_runs,public.mrcip_watchlist_signal_snapshots,public.mrcip_retrieval_requests from anon,authenticated;