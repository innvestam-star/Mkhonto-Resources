create index if not exists mrcip_ai_release_plans_approved_by_idx on public.mrcip_ai_release_plans(approved_by) where approved_by is not null;
create index if not exists mrcip_ai_release_plans_created_by_idx on public.mrcip_ai_release_plans(created_by);
create index if not exists mrcip_ai_release_plans_org_onboarding_idx on public.mrcip_ai_release_plans(organisation_id,onboarding_id);
create index if not exists mrcip_ai_release_plans_org_prompt_idx on public.mrcip_ai_release_plans(organisation_id,prompt_version_id);
create index if not exists mrcip_ai_release_plans_revoked_by_idx on public.mrcip_ai_release_plans(revoked_by) where revoked_by is not null;
create index if not exists mrcip_ai_runtime_controls_updated_by_idx on public.mrcip_ai_runtime_controls(updated_by) where updated_by is not null;
create index if not exists mrcip_ai_runtime_events_actor_user_idx on public.mrcip_ai_runtime_events(actor_user_id) where actor_user_id is not null;
create index if not exists mrcip_ai_runtime_events_org_execution_idx on public.mrcip_ai_runtime_events(organisation_id,execution_id) where execution_id is not null;
