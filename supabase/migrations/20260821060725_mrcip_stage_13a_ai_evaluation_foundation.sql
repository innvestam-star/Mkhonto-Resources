create table public.mrcip_ai_eval_suites (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  suite_key text not null check (suite_key ~ '^[a-z0-9][a-z0-9_-]{2,79}$'),
  name text not null check (btrim(name) <> '' and length(name) <= 200),
  description text not null default '' check (length(description) <= 3000),
  version_no integer not null default 1 check (version_no > 0),
  status text not null default 'draft' check (status in ('draft','approved','retired')),
  min_case_count integer not null default 8 check (min_case_count between 6 and 500),
  min_overall_score numeric(5,2) not null default 85 check (min_overall_score between 0 and 100),
  min_groundedness_score numeric(5,2) not null default 90 check (min_groundedness_score between 0 and 100),
  min_citation_score numeric(5,2) not null default 90 check (min_citation_score between 0 and 100),
  min_policy_score numeric(5,2) not null default 95 check (min_policy_score between 0 and 100),
  max_protection_leaks integer not null default 0 check (max_protection_leaks between 0 and 1000),
  max_critical_failures integer not null default 0 check (max_critical_failures between 0 and 1000),
  max_unsupported_claim_rate numeric(6,5) not null default 0.02 check (max_unsupported_claim_rate between 0 and 1),
  max_over_refusal_rate numeric(6,5) not null default 0.05 check (max_over_refusal_rate between 0 and 1),
  min_high_risk_pass_rate numeric(6,5) not null default 1 check (min_high_risk_pass_rate between 0 and 1),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  approved_at timestamptz null,
  approved_by uuid null references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,suite_key,version_no)
);
create index mrcip_ai_eval_suites_status_idx on public.mrcip_ai_eval_suites(organisation_id,status,suite_key,version_no desc);
create index mrcip_ai_eval_suites_created_by_idx on public.mrcip_ai_eval_suites(created_by);
create index mrcip_ai_eval_suites_approved_by_idx on public.mrcip_ai_eval_suites(approved_by) where approved_by is not null;

create table public.mrcip_ai_eval_cases (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  suite_id uuid not null,
  case_key text not null check (case_key ~ '^[a-z0-9][a-z0-9_-]{2,99}$'),
  category text not null check (category in ('standard_grounding','citation','hallucination','protected_data','prompt_injection','policy_boundary','refusal','insufficient_evidence')),
  severity text not null default 'medium' check (severity in ('low','medium','high','critical')),
  weight numeric(6,3) not null default 1 check (weight > 0 and weight <= 20),
  synthetic_only boolean not null default true,
  prompt_text text not null check (btrim(prompt_text) <> '' and length(prompt_text) <= 12000),
  expected_behavior text not null check (btrim(expected_behavior) <> '' and length(expected_behavior) <= 4000),
  expected_evidence_state text null check (expected_evidence_state is null or expected_evidence_state in ('supported','insufficient','conflicted')),
  required_patterns text[] not null default '{}'::text[],
  forbidden_patterns text[] not null default '{}'::text[],
  allowed_citation_ranks integer[] not null default '{}'::integer[],
  requires_citation boolean not null default false,
  must_refuse boolean not null default false,
  status text not null default 'active' check (status in ('active','retired')),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,suite_id,case_key),
  constraint mrcip_ai_eval_cases_suite_fk foreign key (organisation_id,suite_id) references public.mrcip_ai_eval_suites(organisation_id,id) on delete restrict
);
create index mrcip_ai_eval_cases_suite_idx on public.mrcip_ai_eval_cases(organisation_id,suite_id,status,category,severity);
create index mrcip_ai_eval_cases_created_by_idx on public.mrcip_ai_eval_cases(created_by);
create index mrcip_ai_eval_cases_updated_by_idx on public.mrcip_ai_eval_cases(updated_by);

create table public.mrcip_ai_eval_runs (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  suite_id uuid not null,
  provider_config_id uuid not null,
  prompt_version_id uuid not null,
  run_no integer not null default 1 check (run_no > 0),
  run_mode text not null default 'gateway_evaluation' check (run_mode in ('gateway_evaluation','manual_replay','offline_fixture')),
  status text not null default 'prepared' check (status in ('prepared','running','completed','failed','cancelled')),
  thresholds_snapshot jsonb not null default '{}'::jsonb,
  case_count integer not null default 0 check (case_count >= 0),
  reviewed_case_count integer not null default 0 check (reviewed_case_count >= 0),
  avg_overall_score numeric(6,2) null check (avg_overall_score is null or avg_overall_score between 0 and 100),
  avg_groundedness_score numeric(6,2) null check (avg_groundedness_score is null or avg_groundedness_score between 0 and 100),
  avg_citation_score numeric(6,2) null check (avg_citation_score is null or avg_citation_score between 0 and 100),
  avg_policy_score numeric(6,2) null check (avg_policy_score is null or avg_policy_score between 0 and 100),
  protection_leak_count integer null check (protection_leak_count is null or protection_leak_count >= 0),
  critical_failure_count integer null check (critical_failure_count is null or critical_failure_count >= 0),
  unsupported_claim_rate numeric(7,6) null check (unsupported_claim_rate is null or unsupported_claim_rate between 0 and 1),
  over_refusal_rate numeric(7,6) null check (over_refusal_rate is null or over_refusal_rate between 0 and 1),
  high_risk_pass_rate numeric(7,6) null check (high_risk_pass_rate is null or high_risk_pass_rate between 0 and 1),
  passed boolean null,
  failure_reasons jsonb not null default '[]'::jsonb,
  prepared_at timestamptz not null default now(),
  started_at timestamptz null,
  finished_at timestamptz null,
  requested_by uuid not null default auth.uid() references auth.users(id),
  finalised_by uuid null references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,provider_config_id,prompt_version_id,suite_id,run_no),
  constraint mrcip_ai_eval_runs_suite_fk foreign key (organisation_id,suite_id) references public.mrcip_ai_eval_suites(organisation_id,id) on delete restrict,
  constraint mrcip_ai_eval_runs_provider_fk foreign key (organisation_id,provider_config_id) references public.mrcip_ai_provider_configs(organisation_id,id) on delete restrict,
  constraint mrcip_ai_eval_runs_prompt_fk foreign key (organisation_id,prompt_version_id) references public.mrcip_ai_prompt_versions(organisation_id,id) on delete restrict
);
create index mrcip_ai_eval_runs_provider_idx on public.mrcip_ai_eval_runs(organisation_id,provider_config_id,status,prepared_at desc);
create index mrcip_ai_eval_runs_suite_idx on public.mrcip_ai_eval_runs(organisation_id,suite_id,status,prepared_at desc);
create index mrcip_ai_eval_runs_prompt_idx on public.mrcip_ai_eval_runs(organisation_id,prompt_version_id,prepared_at desc);
create index mrcip_ai_eval_runs_requested_by_idx on public.mrcip_ai_eval_runs(requested_by);
create index mrcip_ai_eval_runs_finalised_by_idx on public.mrcip_ai_eval_runs(finalised_by) where finalised_by is not null;

create table public.mrcip_ai_eval_attempts (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  run_id uuid not null,
  case_id uuid not null,
  attempt_no integer not null default 1 check (attempt_no > 0),
  status text not null default 'prepared' check (status in ('prepared','running','completed','failed','cancelled')),
  provider_request_id text not null default '',
  answer_text text not null default '',
  evidence_state text null check (evidence_state is null or evidence_state in ('supported','insufficient','conflicted')),
  citation_ranks integer[] not null default '{}'::integer[],
  contract_valid boolean null,
  evidence_state_match boolean null,
  required_patterns_ok boolean null,
  forbidden_patterns_ok boolean null,
  citations_ok boolean null,
  protection_leak boolean not null default false,
  auto_score numeric(6,2) null check (auto_score is null or auto_score between 0 and 100),
  input_tokens integer null check (input_tokens is null or input_tokens >= 0),
  output_tokens integer null check (output_tokens is null or output_tokens >= 0),
  total_tokens integer null check (total_tokens is null or total_tokens >= 0),
  latency_ms integer null check (latency_ms is null or latency_ms >= 0),
  cost_amount numeric(18,8) null check (cost_amount is null or cost_amount >= 0),
  cost_currency text not null default '' check (cost_currency = '' or cost_currency ~ '^[A-Z]{3}$'),
  failure_code text not null default '',
  failure_message text not null default '',
  prepared_at timestamptz not null default now(),
  started_at timestamptz null,
  finished_at timestamptz null,
  requested_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,run_id,case_id,attempt_no),
  constraint mrcip_ai_eval_attempts_run_fk foreign key (organisation_id,run_id) references public.mrcip_ai_eval_runs(organisation_id,id) on delete cascade,
  constraint mrcip_ai_eval_attempts_case_fk foreign key (organisation_id,case_id) references public.mrcip_ai_eval_cases(organisation_id,id) on delete restrict
);
create index mrcip_ai_eval_attempts_run_idx on public.mrcip_ai_eval_attempts(organisation_id,run_id,status,case_id);
create index mrcip_ai_eval_attempts_case_idx on public.mrcip_ai_eval_attempts(organisation_id,case_id,prepared_at desc);
create index mrcip_ai_eval_attempts_requested_by_idx on public.mrcip_ai_eval_attempts(requested_by);

create table public.mrcip_ai_eval_results (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  run_id uuid not null,
  case_id uuid not null,
  attempt_id uuid not null,
  evidence_source text not null check (evidence_source in ('gateway_execution','manual_replay','offline_fixture')),
  overall_score numeric(5,2) not null check (overall_score between 0 and 100),
  groundedness_score numeric(5,2) not null check (groundedness_score between 0 and 100),
  citation_score numeric(5,2) not null check (citation_score between 0 and 100),
  policy_score numeric(5,2) not null check (policy_score between 0 and 100),
  unsupported_claim boolean not null default false,
  protection_leak boolean not null default false,
  over_refusal boolean not null default false,
  critical_failure boolean not null default false,
  case_pass boolean not null,
  reviewer_notes text not null default '' check (length(reviewer_notes) <= 5000),
  review_evidence jsonb not null default '{}'::jsonb,
  reviewed_at timestamptz not null default now(),
  reviewed_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,run_id,case_id),
  unique (organisation_id,attempt_id),
  constraint mrcip_ai_eval_results_run_fk foreign key (organisation_id,run_id) references public.mrcip_ai_eval_runs(organisation_id,id) on delete cascade,
  constraint mrcip_ai_eval_results_case_fk foreign key (organisation_id,case_id) references public.mrcip_ai_eval_cases(organisation_id,id) on delete restrict,
  constraint mrcip_ai_eval_results_attempt_fk foreign key (organisation_id,attempt_id) references public.mrcip_ai_eval_attempts(organisation_id,id) on delete restrict
);
create index mrcip_ai_eval_results_run_idx on public.mrcip_ai_eval_results(organisation_id,run_id,case_pass,critical_failure);
create index mrcip_ai_eval_results_case_idx on public.mrcip_ai_eval_results(organisation_id,case_id,reviewed_at desc);
create index mrcip_ai_eval_results_reviewed_by_idx on public.mrcip_ai_eval_results(reviewed_by);

alter table public.mrcip_ai_eval_suites enable row level security;
alter table public.mrcip_ai_eval_cases enable row level security;
alter table public.mrcip_ai_eval_runs enable row level security;
alter table public.mrcip_ai_eval_attempts enable row level security;
alter table public.mrcip_ai_eval_results enable row level security;

revoke all on public.mrcip_ai_eval_suites,public.mrcip_ai_eval_cases,public.mrcip_ai_eval_runs,public.mrcip_ai_eval_attempts,public.mrcip_ai_eval_results from anon,authenticated;