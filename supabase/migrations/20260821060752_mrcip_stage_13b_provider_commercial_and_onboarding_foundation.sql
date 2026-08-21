create table public.mrcip_ai_provider_rates (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  provider_config_id uuid not null,
  version_no integer not null default 1 check (version_no > 0),
  model_name_snapshot text not null check (btrim(model_name_snapshot) <> '' and length(model_name_snapshot) <= 300),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  input_cost_per_1m numeric(18,8) not null check (input_cost_per_1m >= 0),
  output_cost_per_1m numeric(18,8) not null check (output_cost_per_1m >= 0),
  cached_input_cost_per_1m numeric(18,8) null check (cached_input_cost_per_1m is null or cached_input_cost_per_1m >= 0),
  pricing_source text not null check (btrim(pricing_source) <> '' and length(pricing_source) <= 1000),
  status text not null default 'draft' check (status in ('draft','active','retired')),
  effective_from timestamptz not null default now(),
  effective_to timestamptz null check (effective_to is null or effective_to > effective_from),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  approved_at timestamptz null,
  approved_by uuid null references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,provider_config_id,version_no),
  constraint mrcip_ai_provider_rates_provider_fk foreign key (organisation_id,provider_config_id) references public.mrcip_ai_provider_configs(organisation_id,id) on delete restrict
);
create unique index mrcip_ai_provider_rates_one_active_idx on public.mrcip_ai_provider_rates(organisation_id,provider_config_id) where status='active';
create index mrcip_ai_provider_rates_effective_idx on public.mrcip_ai_provider_rates(organisation_id,provider_config_id,effective_from,effective_to);
create index mrcip_ai_provider_rates_created_by_idx on public.mrcip_ai_provider_rates(created_by);
create index mrcip_ai_provider_rates_approved_by_idx on public.mrcip_ai_provider_rates(approved_by) where approved_by is not null;

create table public.mrcip_ai_budget_policies (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  provider_config_id uuid not null,
  version_no integer not null default 1 check (version_no > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  monthly_budget numeric(18,4) not null check (monthly_budget > 0),
  daily_budget numeric(18,4) null check (daily_budget is null or daily_budget > 0),
  max_cost_per_execution numeric(18,4) not null check (max_cost_per_execution > 0),
  max_output_tokens_per_execution integer not null default 4000 check (max_output_tokens_per_execution between 128 and 32000),
  max_executions_per_hour integer not null default 60 check (max_executions_per_hour between 1 and 10000),
  max_executions_per_day integer not null default 500 check (max_executions_per_day between 1 and 100000),
  max_protected_executions_per_day integer not null default 50 check (max_protected_executions_per_day between 0 and 100000),
  status text not null default 'draft' check (status in ('draft','active','retired')),
  effective_from timestamptz not null default now(),
  effective_to timestamptz null check (effective_to is null or effective_to > effective_from),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  approved_at timestamptz null,
  approved_by uuid null references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,provider_config_id,version_no),
  constraint mrcip_ai_budget_policies_provider_fk foreign key (organisation_id,provider_config_id) references public.mrcip_ai_provider_configs(organisation_id,id) on delete restrict
);
create unique index mrcip_ai_budget_policies_one_active_idx on public.mrcip_ai_budget_policies(organisation_id,provider_config_id) where status='active';
create index mrcip_ai_budget_policies_effective_idx on public.mrcip_ai_budget_policies(organisation_id,provider_config_id,effective_from,effective_to);
create index mrcip_ai_budget_policies_created_by_idx on public.mrcip_ai_budget_policies(created_by);
create index mrcip_ai_budget_policies_approved_by_idx on public.mrcip_ai_budget_policies(approved_by) where approved_by is not null;

create table public.mrcip_ai_provider_onboarding (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  provider_config_id uuid not null,
  revision_no integer not null default 1 check (revision_no > 0),
  status text not null default 'draft' check (status in ('draft','evaluation_required','evaluation_passed','production_approved','rejected','revoked')),
  evaluation_run_id uuid null,
  prompt_version_id uuid null,
  rate_card_id uuid null,
  budget_policy_id uuid null,
  protected_data_approved boolean not null default false,
  legal_data_handling_checked boolean not null default false,
  security_review_checked boolean not null default false,
  commercial_review_checked boolean not null default false,
  decision_notes text not null default '' check (length(decision_notes) <= 6000),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  decided_at timestamptz null,
  decided_by uuid null references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,provider_config_id,revision_no),
  constraint mrcip_ai_provider_onboarding_provider_fk foreign key (organisation_id,provider_config_id) references public.mrcip_ai_provider_configs(organisation_id,id) on delete restrict,
  constraint mrcip_ai_provider_onboarding_eval_fk foreign key (organisation_id,evaluation_run_id) references public.mrcip_ai_eval_runs(organisation_id,id) on delete restrict,
  constraint mrcip_ai_provider_onboarding_prompt_fk foreign key (organisation_id,prompt_version_id) references public.mrcip_ai_prompt_versions(organisation_id,id) on delete restrict,
  constraint mrcip_ai_provider_onboarding_rate_fk foreign key (organisation_id,rate_card_id) references public.mrcip_ai_provider_rates(organisation_id,id) on delete restrict,
  constraint mrcip_ai_provider_onboarding_budget_fk foreign key (organisation_id,budget_policy_id) references public.mrcip_ai_budget_policies(organisation_id,id) on delete restrict
);
create index mrcip_ai_provider_onboarding_provider_idx on public.mrcip_ai_provider_onboarding(organisation_id,provider_config_id,revision_no desc,status);
create index mrcip_ai_provider_onboarding_eval_idx on public.mrcip_ai_provider_onboarding(organisation_id,evaluation_run_id) where evaluation_run_id is not null;
create index mrcip_ai_provider_onboarding_prompt_idx on public.mrcip_ai_provider_onboarding(organisation_id,prompt_version_id) where prompt_version_id is not null;
create index mrcip_ai_provider_onboarding_rate_idx on public.mrcip_ai_provider_onboarding(organisation_id,rate_card_id) where rate_card_id is not null;
create index mrcip_ai_provider_onboarding_budget_idx on public.mrcip_ai_provider_onboarding(organisation_id,budget_policy_id) where budget_policy_id is not null;
create index mrcip_ai_provider_onboarding_created_by_idx on public.mrcip_ai_provider_onboarding(created_by);
create index mrcip_ai_provider_onboarding_decided_by_idx on public.mrcip_ai_provider_onboarding(decided_by) where decided_by is not null;

alter table public.mrcip_ai_provider_rates enable row level security;
alter table public.mrcip_ai_budget_policies enable row level security;
alter table public.mrcip_ai_provider_onboarding enable row level security;

revoke all on public.mrcip_ai_provider_rates,public.mrcip_ai_budget_policies,public.mrcip_ai_provider_onboarding from anon,authenticated;