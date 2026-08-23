create table public.mrcip_ai_release_plans (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  provider_config_id uuid not null,
  onboarding_id uuid not null,
  prompt_version_id uuid not null,
  predecessor_release_plan_id uuid,
  revision_no integer not null check (revision_no > 0),
  release_scope text not null check (release_scope in ('pilot','production')),
  status text not null default 'draft' check (status in ('draft','approved','retired','revoked')),
  protected_data_allowed boolean not null default false,
  allowed_role_keys text[] not null default array['super_admin','managing_director','commodity_manager','research_analyst','legal_compliance']::text[],
  pilot_execution_limit integer not null default 25 check (pilot_execution_limit between 1 and 10000),
  pilot_protected_execution_limit integer not null default 0 check (pilot_protected_execution_limit between 0 and 10000),
  min_pilot_completed_executions integer not null default 10 check (min_pilot_completed_executions between 1 and 10000),
  max_pilot_failure_rate numeric(7,6) not null default 0.100000 check (max_pilot_failure_rate between 0 and 1),
  require_human_review boolean not null default true check (require_human_review),
  decision_notes text not null default '' check (length(decision_notes) <= 6000),
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  approved_at timestamptz,
  approved_by uuid references auth.users(id),
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,provider_config_id,revision_no),
  foreign key (organisation_id,provider_config_id) references public.mrcip_ai_provider_configs(organisation_id,id) on delete restrict,
  foreign key (organisation_id,onboarding_id) references public.mrcip_ai_provider_onboarding(organisation_id,id) on delete restrict,
  foreign key (organisation_id,prompt_version_id) references public.mrcip_ai_prompt_versions(organisation_id,id) on delete restrict,
  foreign key (organisation_id,predecessor_release_plan_id) references public.mrcip_ai_release_plans(organisation_id,id) on delete restrict,
  check (pilot_protected_execution_limit <= pilot_execution_limit),
  check (cardinality(allowed_role_keys) > 0 and allowed_role_keys <@ array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance']::text[]),
  check ((release_scope='pilot' and predecessor_release_plan_id is null) or (release_scope='production' and predecessor_release_plan_id is not null))
);

create table public.mrcip_ai_runtime_controls (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  provider_config_id uuid not null,
  active_release_plan_id uuid,
  runtime_state text not null default 'disabled' check (runtime_state in ('disabled','pilot','production','paused','stopped')),
  emergency_stop boolean not null default true,
  transition_reason text not null default '' check (length(transition_reason) <= 4000),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id),
  unique (organisation_id,id),
  unique (organisation_id,provider_config_id),
  foreign key (organisation_id,provider_config_id) references public.mrcip_ai_provider_configs(organisation_id,id) on delete restrict,
  foreign key (organisation_id,active_release_plan_id) references public.mrcip_ai_release_plans(organisation_id,id) on delete restrict,
  check ((runtime_state in ('pilot','production') and active_release_plan_id is not null and emergency_stop=false) or (runtime_state in ('disabled','paused','stopped') and emergency_stop=true))
);

create table public.mrcip_ai_execution_release_links (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  execution_id uuid not null,
  release_plan_id uuid not null,
  runtime_state_snapshot text not null check (runtime_state_snapshot in ('pilot','production')),
  linked_at timestamptz not null default now(),
  unique (organisation_id,id),
  unique (organisation_id,execution_id),
  foreign key (organisation_id,execution_id) references public.mrcip_ai_executions(organisation_id,id) on delete restrict,
  foreign key (organisation_id,release_plan_id) references public.mrcip_ai_release_plans(organisation_id,id) on delete restrict
);

create table public.mrcip_ai_runtime_events (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  provider_config_id uuid not null,
  release_plan_id uuid,
  execution_id uuid,
  event_type text not null check (event_type in ('release_prepared','release_approved','release_retired','release_revoked','pilot_activated','production_activated','paused','resumed','stopped','auto_paused_budget','auto_paused_failure_rate','auto_paused_protection')),
  actor_kind text not null check (actor_kind in ('user','system','gateway')),
  actor_user_id uuid references auth.users(id),
  reason text not null default '' check (length(reason) <= 4000),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (organisation_id,id),
  foreign key (organisation_id,provider_config_id) references public.mrcip_ai_provider_configs(organisation_id,id) on delete restrict,
  foreign key (organisation_id,release_plan_id) references public.mrcip_ai_release_plans(organisation_id,id) on delete restrict,
  foreign key (organisation_id,execution_id) references public.mrcip_ai_executions(organisation_id,id) on delete restrict
);

create index mrcip_ai_release_plans_org_provider_scope_status_idx on public.mrcip_ai_release_plans(organisation_id,provider_config_id,release_scope,status);
create index mrcip_ai_release_plans_org_predecessor_idx on public.mrcip_ai_release_plans(organisation_id,predecessor_release_plan_id) where predecessor_release_plan_id is not null;
create index mrcip_ai_runtime_controls_org_release_idx on public.mrcip_ai_runtime_controls(organisation_id,active_release_plan_id) where active_release_plan_id is not null;
create index mrcip_ai_execution_release_links_org_release_idx on public.mrcip_ai_execution_release_links(organisation_id,release_plan_id,linked_at desc);
create index mrcip_ai_runtime_events_org_provider_created_idx on public.mrcip_ai_runtime_events(organisation_id,provider_config_id,created_at desc);
create index mrcip_ai_runtime_events_org_release_idx on public.mrcip_ai_runtime_events(organisation_id,release_plan_id,created_at desc) where release_plan_id is not null;

alter table public.mrcip_ai_release_plans enable row level security;
alter table public.mrcip_ai_runtime_controls enable row level security;
alter table public.mrcip_ai_execution_release_links enable row level security;
alter table public.mrcip_ai_runtime_events enable row level security;

revoke all on public.mrcip_ai_release_plans from anon,authenticated;
revoke all on public.mrcip_ai_runtime_controls from anon,authenticated;
revoke all on public.mrcip_ai_execution_release_links from anon,authenticated;
revoke all on public.mrcip_ai_runtime_events from anon,authenticated;