drop policy if exists mrcip_ai_eval_suites_select on public.mrcip_ai_eval_suites;
drop policy if exists mrcip_ai_eval_suites_insert on public.mrcip_ai_eval_suites;
drop policy if exists mrcip_ai_eval_suites_update on public.mrcip_ai_eval_suites;
drop policy if exists mrcip_ai_eval_cases_select on public.mrcip_ai_eval_cases;
drop policy if exists mrcip_ai_eval_cases_insert on public.mrcip_ai_eval_cases;
drop policy if exists mrcip_ai_eval_cases_update on public.mrcip_ai_eval_cases;
drop policy if exists mrcip_ai_eval_runs_select on public.mrcip_ai_eval_runs;
drop policy if exists mrcip_ai_eval_runs_insert on public.mrcip_ai_eval_runs;
drop policy if exists mrcip_ai_eval_runs_update on public.mrcip_ai_eval_runs;
drop policy if exists mrcip_ai_eval_attempts_select on public.mrcip_ai_eval_attempts;
drop policy if exists mrcip_ai_eval_attempts_insert on public.mrcip_ai_eval_attempts;
drop policy if exists mrcip_ai_eval_results_select on public.mrcip_ai_eval_results;
drop policy if exists mrcip_ai_eval_results_insert on public.mrcip_ai_eval_results;
drop policy if exists mrcip_ai_provider_rates_select on public.mrcip_ai_provider_rates;
drop policy if exists mrcip_ai_provider_rates_insert on public.mrcip_ai_provider_rates;
drop policy if exists mrcip_ai_provider_rates_update on public.mrcip_ai_provider_rates;
drop policy if exists mrcip_ai_budget_policies_select on public.mrcip_ai_budget_policies;
drop policy if exists mrcip_ai_budget_policies_insert on public.mrcip_ai_budget_policies;
drop policy if exists mrcip_ai_budget_policies_update on public.mrcip_ai_budget_policies;
drop policy if exists mrcip_ai_provider_onboarding_select on public.mrcip_ai_provider_onboarding;
drop policy if exists mrcip_ai_provider_onboarding_insert on public.mrcip_ai_provider_onboarding;
drop policy if exists mrcip_ai_provider_onboarding_update on public.mrcip_ai_provider_onboarding;

create policy mrcip_ai_eval_suites_select on public.mrcip_ai_eval_suites for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','research_analyst','legal_compliance']));
create policy mrcip_ai_eval_suites_insert on public.mrcip_ai_eval_suites for insert to authenticated with check (created_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','research_analyst','legal_compliance']));
create policy mrcip_ai_eval_suites_update on public.mrcip_ai_eval_suites for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','research_analyst','legal_compliance'])) with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','research_analyst','legal_compliance']));

create policy mrcip_ai_eval_cases_select on public.mrcip_ai_eval_cases for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','research_analyst','legal_compliance']));
create policy mrcip_ai_eval_cases_insert on public.mrcip_ai_eval_cases for insert to authenticated with check (created_by=(select auth.uid()) and updated_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','research_analyst','legal_compliance']));
create policy mrcip_ai_eval_cases_update on public.mrcip_ai_eval_cases for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','research_analyst','legal_compliance'])) with check (updated_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','research_analyst','legal_compliance']));

create policy mrcip_ai_eval_runs_select on public.mrcip_ai_eval_runs for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','research_analyst','legal_compliance']) and (requested_by=(select auth.uid()) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance'])));
create policy mrcip_ai_eval_runs_insert on public.mrcip_ai_eval_runs for insert to authenticated with check (requested_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','research_analyst','legal_compliance']));
create policy mrcip_ai_eval_runs_update on public.mrcip_ai_eval_runs for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','research_analyst','legal_compliance'])) with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','research_analyst','legal_compliance']));

create policy mrcip_ai_eval_attempts_select on public.mrcip_ai_eval_attempts for select to authenticated using (exists(select 1 from public.mrcip_ai_eval_runs r where r.organisation_id=mrcip_ai_eval_attempts.organisation_id and r.id=mrcip_ai_eval_attempts.run_id));
create policy mrcip_ai_eval_attempts_insert on public.mrcip_ai_eval_attempts for insert to authenticated with check (requested_by=(select auth.uid()) and exists(select 1 from public.mrcip_ai_eval_runs r where r.organisation_id=mrcip_ai_eval_attempts.organisation_id and r.id=mrcip_ai_eval_attempts.run_id));

create policy mrcip_ai_eval_results_select on public.mrcip_ai_eval_results for select to authenticated using (exists(select 1 from public.mrcip_ai_eval_runs r where r.organisation_id=mrcip_ai_eval_results.organisation_id and r.id=mrcip_ai_eval_results.run_id));
create policy mrcip_ai_eval_results_insert on public.mrcip_ai_eval_results for insert to authenticated with check (reviewed_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','research_analyst','legal_compliance']));

create policy mrcip_ai_provider_rates_select on public.mrcip_ai_provider_rates for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']));
create policy mrcip_ai_provider_rates_insert on public.mrcip_ai_provider_rates for insert to authenticated with check (created_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']));
create policy mrcip_ai_provider_rates_update on public.mrcip_ai_provider_rates for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance'])) with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']));

create policy mrcip_ai_budget_policies_select on public.mrcip_ai_budget_policies for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']));
create policy mrcip_ai_budget_policies_insert on public.mrcip_ai_budget_policies for insert to authenticated with check (created_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']));
create policy mrcip_ai_budget_policies_update on public.mrcip_ai_budget_policies for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance'])) with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','finance','legal_compliance']));

create policy mrcip_ai_provider_onboarding_select on public.mrcip_ai_provider_onboarding for select to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance']));
create policy mrcip_ai_provider_onboarding_insert on public.mrcip_ai_provider_onboarding for insert to authenticated with check (created_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance']));
create policy mrcip_ai_provider_onboarding_update on public.mrcip_ai_provider_onboarding for update to authenticated using (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance'])) with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance']));

revoke all on public.mrcip_ai_eval_suites,public.mrcip_ai_eval_cases,public.mrcip_ai_eval_runs,public.mrcip_ai_eval_attempts,public.mrcip_ai_eval_results,public.mrcip_ai_provider_rates,public.mrcip_ai_budget_policies,public.mrcip_ai_provider_onboarding from anon,authenticated;
grant select,insert,update on public.mrcip_ai_eval_suites,public.mrcip_ai_eval_cases,public.mrcip_ai_eval_runs to authenticated;
grant select,insert on public.mrcip_ai_eval_attempts,public.mrcip_ai_eval_results to authenticated;
grant select,insert,update on public.mrcip_ai_provider_rates,public.mrcip_ai_budget_policies,public.mrcip_ai_provider_onboarding to authenticated;

grant select on public.mrcip_ai_eval_suites,public.mrcip_ai_eval_cases,public.mrcip_ai_eval_runs,public.mrcip_ai_eval_attempts,public.mrcip_ai_eval_results,public.mrcip_ai_provider_rates,public.mrcip_ai_budget_policies,public.mrcip_ai_provider_onboarding to service_role;
grant insert,update on public.mrcip_ai_eval_runs,public.mrcip_ai_eval_attempts to service_role;

create or replace view public.mrcip_ai_eval_suite_summary with (security_invoker=true) as
select s.organisation_id,s.id as suite_id,s.suite_key,s.name,s.version_no,s.status,s.min_case_count,s.min_overall_score,s.min_groundedness_score,s.min_citation_score,s.min_policy_score,s.max_protection_leaks,s.max_critical_failures,s.max_unsupported_claim_rate,s.max_over_refusal_rate,s.min_high_risk_pass_rate,s.approved_at,s.approved_by,
 count(c.id) filter(where c.status='active')::integer as active_case_count,
 count(c.id) filter(where c.status='active' and c.severity in ('high','critical'))::integer as high_risk_case_count,
 count(distinct c.category) filter(where c.status='active')::integer as category_count
from public.mrcip_ai_eval_suites s left join public.mrcip_ai_eval_cases c on c.organisation_id=s.organisation_id and c.suite_id=s.id
group by s.organisation_id,s.id,s.suite_key,s.name,s.version_no,s.status,s.min_case_count,s.min_overall_score,s.min_groundedness_score,s.min_citation_score,s.min_policy_score,s.max_protection_leaks,s.max_critical_failures,s.max_unsupported_claim_rate,s.max_over_refusal_rate,s.min_high_risk_pass_rate,s.approved_at,s.approved_by;

create or replace view public.mrcip_ai_eval_run_summary with (security_invoker=true) as
select r.organisation_id,r.id as run_id,r.suite_id,s.suite_key,s.version_no as suite_version,r.provider_config_id,cfg.provider_key,cfg.model_name,r.prompt_version_id,pv.version_no as prompt_version_no,r.run_no,r.run_mode,r.status,r.case_count,r.reviewed_case_count,r.avg_overall_score,r.avg_groundedness_score,r.avg_citation_score,r.avg_policy_score,r.protection_leak_count,r.critical_failure_count,r.unsupported_claim_rate,r.over_refusal_rate,r.high_risk_pass_rate,r.passed,r.failure_reasons,r.prepared_at,r.started_at,r.finished_at,r.requested_by,r.finalised_by,
 (select count(*)::integer from public.mrcip_ai_eval_attempts a where a.organisation_id=r.organisation_id and a.run_id=r.id and a.status='completed') as completed_attempt_count,
 (select coalesce(sum(a.cost_amount),0) from public.mrcip_ai_eval_attempts a where a.organisation_id=r.organisation_id and a.run_id=r.id and a.status='completed') as recorded_eval_cost
from public.mrcip_ai_eval_runs r join public.mrcip_ai_eval_suites s on s.organisation_id=r.organisation_id and s.id=r.suite_id join public.mrcip_ai_provider_configs cfg on cfg.organisation_id=r.organisation_id and cfg.id=r.provider_config_id join public.mrcip_ai_prompt_versions pv on pv.organisation_id=r.organisation_id and pv.id=r.prompt_version_id;

create or replace view public.mrcip_ai_budget_usage_summary with (security_invoker=true) as
select bp.organisation_id,bp.id as budget_policy_id,bp.provider_config_id,bp.currency,bp.monthly_budget,bp.daily_budget,bp.max_cost_per_execution,bp.max_output_tokens_per_execution,bp.max_executions_per_hour,bp.max_executions_per_day,bp.max_protected_executions_per_day,bp.status,
 coalesce((select sum(e.cost_amount) from public.mrcip_ai_executions e where e.organisation_id=bp.organisation_id and e.provider_config_id=bp.provider_config_id and e.status='completed' and e.cost_currency=bp.currency and e.finished_at>=date_trunc('month',now())),0) as month_spend,
 coalesce((select sum(e.cost_amount) from public.mrcip_ai_executions e where e.organisation_id=bp.organisation_id and e.provider_config_id=bp.provider_config_id and e.status='completed' and e.cost_currency=bp.currency and e.finished_at>=date_trunc('day',now())),0) as day_spend,
 (select count(*)::integer from public.mrcip_ai_executions e where e.organisation_id=bp.organisation_id and e.provider_config_id=bp.provider_config_id and e.prepared_at>=now()-interval '1 hour' and e.status in ('prepared','running','completed')) as executions_last_hour,
 (select count(*)::integer from public.mrcip_ai_executions e where e.organisation_id=bp.organisation_id and e.provider_config_id=bp.provider_config_id and e.prepared_at>=date_trunc('day',now()) and e.status in ('prepared','running','completed')) as executions_today,
 (select count(*)::integer from public.mrcip_ai_executions e where e.organisation_id=bp.organisation_id and e.provider_config_id=bp.provider_config_id and e.prepared_at>=date_trunc('day',now()) and e.protected_context and e.status in ('prepared','running','completed')) as protected_executions_today
from public.mrcip_ai_budget_policies bp;

revoke all on public.mrcip_ai_eval_suite_summary,public.mrcip_ai_eval_run_summary,public.mrcip_ai_budget_usage_summary from public,anon,authenticated;
grant select on public.mrcip_ai_eval_suite_summary,public.mrcip_ai_eval_run_summary,public.mrcip_ai_budget_usage_summary to authenticated;