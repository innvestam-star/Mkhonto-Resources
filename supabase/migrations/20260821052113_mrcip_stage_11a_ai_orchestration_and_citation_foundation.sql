create table public.mrcip_ai_provider_configs (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  provider_key text not null check (btrim(provider_key) <> '' and length(provider_key) <= 100),
  model_name text not null check (btrim(model_name) <> '' and length(model_name) <= 200),
  status text not null default 'disabled' check (status in ('disabled','integration_ready','active','revoked')),
  credential_status text not null default 'not_configured' check (credential_status in ('not_configured','configured_external_secret','revoked')),
  protected_data_allowed boolean not null default false,
  external_processing_location text not null default '',
  data_handling_notes text not null default '',
  approved_at timestamptz null,
  approved_by uuid null references auth.users(id),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,provider_key,model_name)
);
create index mrcip_ai_provider_configs_status_idx on public.mrcip_ai_provider_configs(organisation_id,status,provider_key,model_name);
create index mrcip_ai_provider_configs_approved_by_idx on public.mrcip_ai_provider_configs(approved_by) where approved_by is not null;
create index mrcip_ai_provider_configs_created_by_idx on public.mrcip_ai_provider_configs(created_by);
create index mrcip_ai_provider_configs_updated_by_idx on public.mrcip_ai_provider_configs(updated_by);

create table public.mrcip_ai_requests (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  retrieval_request_id uuid not null,
  request_text text not null check (btrim(request_text) <> '' and length(request_text) <= 4000),
  purpose text not null check (btrim(purpose) <> '' and length(purpose) <= 500),
  output_type text not null default 'answer' check (output_type in ('answer','brief','comparison','counterparty_summary','opportunity_summary','risk_summary','watchlist_summary')),
  entity_types text[] not null default array['counterparty','mine','laboratory','buyer_requirement','seller_offer','opportunity']::text[],
  include_protected boolean not null default false,
  max_context_items integer not null default 12 check (max_context_items between 1 and 25),
  context_count integer not null default 0 check (context_count >= 0 and context_count <= 25),
  protected_context boolean not null default false,
  status text not null default 'context_ready' check (status in ('context_ready','response_submitted','review_required','approved','changes_requested','rejected','cancelled','failed')),
  policy_version text not null default 'mrcip-ai-policy-v1',
  policy_snapshot jsonb not null default '{}'::jsonb,
  requested_at timestamptz not null default now(),
  requested_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint mrcip_ai_requests_retrieval_fk foreign key (organisation_id,retrieval_request_id) references public.mrcip_retrieval_requests(organisation_id,id) on delete restrict
);
create index mrcip_ai_requests_requester_idx on public.mrcip_ai_requests(organisation_id,requested_by,requested_at desc);
create index mrcip_ai_requests_retrieval_idx on public.mrcip_ai_requests(organisation_id,retrieval_request_id);

create table public.mrcip_ai_context_items (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  request_id uuid not null,
  retrieval_request_id uuid not null,
  result_rank integer not null check (result_rank between 1 and 50),
  entity_type text not null check (entity_type in ('counterparty','mine','laboratory','buyer_requirement','seller_offer','opportunity')),
  entity_id uuid not null,
  title text not null,
  subtitle text not null default '',
  relevance_score numeric(5,4) not null default 0 check (relevance_score between 0 and 1),
  protected_context boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  context_fingerprint text not null,
  captured_at timestamptz not null default now(),
  captured_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,request_id,result_rank),
  constraint mrcip_ai_context_items_request_fk foreign key (organisation_id,request_id) references public.mrcip_ai_requests(organisation_id,id) on delete cascade,
  constraint mrcip_ai_context_items_retrieval_fk foreign key (organisation_id,retrieval_request_id) references public.mrcip_retrieval_requests(organisation_id,id) on delete restrict
);
create index mrcip_ai_context_items_request_idx on public.mrcip_ai_context_items(organisation_id,request_id,result_rank);
create index mrcip_ai_context_items_entity_idx on public.mrcip_ai_context_items(organisation_id,entity_type,entity_id);
create index mrcip_ai_context_items_captured_by_idx on public.mrcip_ai_context_items(captured_by);

create table public.mrcip_ai_responses (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  request_id uuid not null,
  response_version integer not null default 1 check (response_version > 0),
  response_origin text not null default 'human_draft' check (response_origin in ('human_draft','deterministic_system','external_model')),
  provider_config_id uuid null,
  provider_key text not null default '',
  model_name text not null default '',
  provider_request_id text not null default '',
  answer_text text not null check (btrim(answer_text) <> '' and length(answer_text) <= 20000),
  evidence_state text not null default 'supported' check (evidence_state in ('supported','insufficient','conflicted')),
  protected_context boolean not null default false,
  status text not null default 'review_required' check (status in ('review_required','approved','changes_requested','rejected','superseded')),
  policy_version text not null default 'mrcip-ai-policy-v1',
  answer_fingerprint text not null,
  generated_at timestamptz not null default now(),
  generated_by uuid not null default auth.uid() references auth.users(id),
  reviewed_at timestamptz null,
  reviewed_by uuid null references auth.users(id),
  review_summary text not null default '',
  unique (organisation_id,id),
  unique (organisation_id,request_id,response_version),
  constraint mrcip_ai_responses_request_fk foreign key (organisation_id,request_id) references public.mrcip_ai_requests(organisation_id,id) on delete cascade,
  constraint mrcip_ai_responses_provider_fk foreign key (organisation_id,provider_config_id) references public.mrcip_ai_provider_configs(organisation_id,id) on delete restrict
);
create index mrcip_ai_responses_request_latest_idx on public.mrcip_ai_responses(organisation_id,request_id,response_version desc);
create index mrcip_ai_responses_provider_idx on public.mrcip_ai_responses(organisation_id,provider_config_id) where provider_config_id is not null;
create index mrcip_ai_responses_generated_by_idx on public.mrcip_ai_responses(generated_by);
create index mrcip_ai_responses_reviewed_by_idx on public.mrcip_ai_responses(reviewed_by) where reviewed_by is not null;

create table public.mrcip_ai_citations (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  response_id uuid not null,
  context_item_id uuid not null,
  citation_order integer not null check (citation_order > 0 and citation_order <= 100),
  citation_kind text not null default 'support' check (citation_kind in ('support','context','contradiction')),
  claim_anchor text not null default '' check (length(claim_anchor) <= 1000),
  protected_context boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,response_id,citation_order),
  unique (organisation_id,response_id,context_item_id),
  constraint mrcip_ai_citations_response_fk foreign key (organisation_id,response_id) references public.mrcip_ai_responses(organisation_id,id) on delete cascade,
  constraint mrcip_ai_citations_context_fk foreign key (organisation_id,context_item_id) references public.mrcip_ai_context_items(organisation_id,id) on delete restrict
);
create index mrcip_ai_citations_response_idx on public.mrcip_ai_citations(organisation_id,response_id,citation_order);
create index mrcip_ai_citations_context_idx on public.mrcip_ai_citations(organisation_id,context_item_id);
create index mrcip_ai_citations_created_by_idx on public.mrcip_ai_citations(created_by);

create table public.mrcip_ai_reviews (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  response_id uuid not null,
  decision text not null check (decision in ('approve','changes_requested','reject')),
  citation_check_passed boolean not null default false,
  factuality_check_passed boolean not null default false,
  protection_check_passed boolean not null default false,
  notes text not null default '' check (length(notes) <= 4000),
  reviewer_id uuid not null default auth.uid() references auth.users(id),
  reviewed_at timestamptz not null default now(),
  unique (organisation_id,id),
  constraint mrcip_ai_reviews_response_fk foreign key (organisation_id,response_id) references public.mrcip_ai_responses(organisation_id,id) on delete cascade
);
create index mrcip_ai_reviews_response_idx on public.mrcip_ai_reviews(organisation_id,response_id,reviewed_at desc);
create index mrcip_ai_reviews_reviewer_idx on public.mrcip_ai_reviews(organisation_id,reviewer_id,reviewed_at desc);

alter table public.mrcip_ai_provider_configs enable row level security;
alter table public.mrcip_ai_requests enable row level security;
alter table public.mrcip_ai_context_items enable row level security;
alter table public.mrcip_ai_responses enable row level security;
alter table public.mrcip_ai_citations enable row level security;
alter table public.mrcip_ai_reviews enable row level security;

revoke all on public.mrcip_ai_provider_configs,public.mrcip_ai_requests,public.mrcip_ai_context_items,public.mrcip_ai_responses,public.mrcip_ai_citations,public.mrcip_ai_reviews from anon,authenticated;