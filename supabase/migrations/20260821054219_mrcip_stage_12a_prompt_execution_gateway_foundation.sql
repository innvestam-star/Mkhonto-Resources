alter table public.mrcip_ai_provider_configs
  add column adapter_key text not null default 'unconfigured' check (adapter_key in ('unconfigured','openai_responses_v1')),
  add column credential_secret_ref text not null default '' check (credential_secret_ref = '' or credential_secret_ref ~ '^MRCIP_AI_[A-Z0-9_]{1,64}$'),
  add column connection_status text not null default 'not_tested' check (connection_status in ('not_tested','verified','failed','revoked')),
  add column connection_verified_at timestamptz null,
  add column connection_verification_ref text not null default '',
  add column last_connection_error text not null default '';

create table public.mrcip_ai_prompt_templates (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  prompt_key text not null check (btrim(prompt_key) <> '' and prompt_key ~ '^[a-z0-9][a-z0-9_-]{2,79}$'),
  name text not null check (btrim(name) <> '' and length(name) <= 200),
  purpose text not null check (btrim(purpose) <> '' and length(purpose) <= 500),
  output_type text not null default 'answer' check (output_type in ('answer','brief','comparison','counterparty_summary','opportunity_summary','risk_summary','watchlist_summary')),
  status text not null default 'active' check (status in ('active','retired')),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,prompt_key)
);
create index mrcip_ai_prompt_templates_status_idx on public.mrcip_ai_prompt_templates(organisation_id,status,output_type,prompt_key);
create index mrcip_ai_prompt_templates_created_by_idx on public.mrcip_ai_prompt_templates(created_by);
create index mrcip_ai_prompt_templates_updated_by_idx on public.mrcip_ai_prompt_templates(updated_by);

create table public.mrcip_ai_prompt_versions (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  template_id uuid not null,
  version_no integer not null default 1 check (version_no > 0),
  system_instructions text not null check (btrim(system_instructions) <> '' and length(system_instructions) <= 12000),
  response_instructions text not null check (btrim(response_instructions) <> '' and length(response_instructions) <= 8000),
  max_output_tokens integer not null default 1600 check (max_output_tokens between 128 and 8000),
  status text not null default 'draft' check (status in ('draft','approved','retired')),
  protected_data_approved boolean not null default false,
  content_fingerprint text not null,
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  approved_at timestamptz null,
  approved_by uuid null references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,template_id,version_no),
  constraint mrcip_ai_prompt_versions_template_fk foreign key (organisation_id,template_id) references public.mrcip_ai_prompt_templates(organisation_id,id) on delete restrict
);
create index mrcip_ai_prompt_versions_status_idx on public.mrcip_ai_prompt_versions(organisation_id,template_id,status,version_no desc);
create index mrcip_ai_prompt_versions_created_by_idx on public.mrcip_ai_prompt_versions(created_by);
create index mrcip_ai_prompt_versions_approved_by_idx on public.mrcip_ai_prompt_versions(approved_by) where approved_by is not null;

create table public.mrcip_ai_executions (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  request_id uuid not null,
  provider_config_id uuid not null,
  prompt_version_id uuid not null,
  execution_no integer not null default 1 check (execution_no > 0),
  status text not null default 'prepared' check (status in ('prepared','running','completed','failed','blocked','cancelled')),
  protected_context boolean not null default false,
  policy_version text not null default 'mrcip-ai-policy-v1',
  provider_key_snapshot text not null,
  model_name_snapshot text not null,
  adapter_key_snapshot text not null,
  prompt_version_no integer not null check (prompt_version_no > 0),
  prompt_fingerprint text not null,
  context_fingerprint text not null,
  input_fingerprint text not null,
  provider_request_id text not null default '',
  response_id uuid null,
  response_fingerprint text not null default '',
  input_tokens integer null check (input_tokens is null or input_tokens >= 0),
  output_tokens integer null check (output_tokens is null or output_tokens >= 0),
  total_tokens integer null check (total_tokens is null or total_tokens >= 0),
  latency_ms integer null check (latency_ms is null or latency_ms >= 0),
  cost_amount numeric(18,8) null check (cost_amount is null or cost_amount >= 0),
  cost_currency text not null default '' check (cost_currency = '' or cost_currency ~ '^[A-Z]{3}$'),
  cost_source text not null default 'unknown' check (cost_source in ('unknown','provider_reported','configured_rate')),
  provider_telemetry jsonb not null default '{}'::jsonb,
  failure_code text not null default '',
  failure_message text not null default '',
  prepared_at timestamptz not null default now(),
  started_at timestamptz null,
  finished_at timestamptz null,
  requested_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,request_id,execution_no),
  constraint mrcip_ai_executions_request_fk foreign key (organisation_id,request_id) references public.mrcip_ai_requests(organisation_id,id) on delete restrict,
  constraint mrcip_ai_executions_provider_fk foreign key (organisation_id,provider_config_id) references public.mrcip_ai_provider_configs(organisation_id,id) on delete restrict,
  constraint mrcip_ai_executions_prompt_version_fk foreign key (organisation_id,prompt_version_id) references public.mrcip_ai_prompt_versions(organisation_id,id) on delete restrict
);
create index mrcip_ai_executions_request_idx on public.mrcip_ai_executions(organisation_id,request_id,execution_no desc);
create index mrcip_ai_executions_status_idx on public.mrcip_ai_executions(organisation_id,status,prepared_at desc);
create index mrcip_ai_executions_provider_idx on public.mrcip_ai_executions(organisation_id,provider_config_id,prepared_at desc);
create index mrcip_ai_executions_prompt_idx on public.mrcip_ai_executions(organisation_id,prompt_version_id,prepared_at desc);
create index mrcip_ai_executions_requested_by_idx on public.mrcip_ai_executions(requested_by);

create table public.mrcip_ai_execution_events (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  execution_id uuid not null,
  event_type text not null check (event_type in ('prepared','started','provider_request','provider_response','completed','failed','blocked','cancelled')),
  event_status text not null default 'recorded' check (event_status in ('recorded','success','failure')),
  actor_kind text not null default 'gateway' check (actor_kind in ('user','gateway','system')),
  actor_user_id uuid null references auth.users(id),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (organisation_id,id),
  constraint mrcip_ai_execution_events_execution_fk foreign key (organisation_id,execution_id) references public.mrcip_ai_executions(organisation_id,id) on delete cascade
);
create index mrcip_ai_execution_events_execution_idx on public.mrcip_ai_execution_events(organisation_id,execution_id,created_at,id);
create index mrcip_ai_execution_events_actor_user_idx on public.mrcip_ai_execution_events(actor_user_id) where actor_user_id is not null;

alter table public.mrcip_ai_responses add column execution_id uuid null;
alter table public.mrcip_ai_responses
  add constraint mrcip_ai_responses_execution_fk foreign key (organisation_id,execution_id) references public.mrcip_ai_executions(organisation_id,id) on delete restrict;
create unique index mrcip_ai_responses_execution_uidx on public.mrcip_ai_responses(organisation_id,execution_id) where execution_id is not null;

alter table public.mrcip_ai_executions
  add constraint mrcip_ai_executions_response_fk foreign key (organisation_id,response_id) references public.mrcip_ai_responses(organisation_id,id) on delete restrict;

alter table public.mrcip_ai_prompt_templates enable row level security;
alter table public.mrcip_ai_prompt_versions enable row level security;
alter table public.mrcip_ai_executions enable row level security;
alter table public.mrcip_ai_execution_events enable row level security;

revoke all on public.mrcip_ai_prompt_templates,public.mrcip_ai_prompt_versions,public.mrcip_ai_executions,public.mrcip_ai_execution_events from anon,authenticated;