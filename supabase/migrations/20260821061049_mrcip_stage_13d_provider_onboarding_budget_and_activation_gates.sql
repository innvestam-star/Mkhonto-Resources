create or replace function private.guard_mrcip_ai_provider_rate()
returns trigger
language plpgsql
set search_path=''
as $$
declare uid uuid := (select auth.uid()); internal_write boolean := current_setting('app.mrcip_ai_rate_write',true)='on'; next_version integer; cfg public.mrcip_ai_provider_configs%rowtype;
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'AI provider pricing authority required'; end if;
  select * into cfg from public.mrcip_ai_provider_configs where organisation_id=new.organisation_id and id=new.provider_config_id;
  if not found then raise exception 'Provider configuration not found'; end if;
  if tg_op='INSERT' then
    if new.status<>'draft' then raise exception 'New provider rate cards must begin in draft'; end if;
    select coalesce(max(version_no),0)+1 into next_version from public.mrcip_ai_provider_rates where organisation_id=new.organisation_id and provider_config_id=new.provider_config_id;
    new.version_no:=next_version; new.model_name_snapshot:=cfg.model_name; new.created_at:=now(); new.created_by:=uid; new.approved_at:=null; new.approved_by:=null;
  else
    if old.organisation_id<>new.organisation_id or old.provider_config_id<>new.provider_config_id or old.version_no<>new.version_no or old.model_name_snapshot<>new.model_name_snapshot or old.currency<>new.currency or old.input_cost_per_1m<>new.input_cost_per_1m or old.output_cost_per_1m<>new.output_cost_per_1m or old.cached_input_cost_per_1m is distinct from new.cached_input_cost_per_1m or old.pricing_source<>new.pricing_source or old.effective_from<>new.effective_from or old.effective_to is distinct from new.effective_to or old.created_at<>new.created_at or old.created_by<>new.created_by then raise exception 'Provider rate-card commercial terms are immutable; create a new version'; end if;
    if old.status='retired' and new.status<>'retired' then raise exception 'Retired rate cards cannot be reactivated'; end if;
    if old.status='draft' and new.status='active' and not internal_write then raise exception 'Use the controlled rate-card approval RPC'; end if;
    if old.status='active' and new.status not in ('active','retired') then raise exception 'Active rate cards may only remain active or be retired'; end if;
  end if;
  if new.status='active' then new.approved_at:=coalesce(new.approved_at,now()); new.approved_by:=coalesce(new.approved_by,uid); end if;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_provider_rate() from public,anon,authenticated;
create trigger mrcip_ai_provider_rates_guard_biu before insert or update on public.mrcip_ai_provider_rates for each row execute function private.guard_mrcip_ai_provider_rate();

create or replace function private.guard_mrcip_ai_budget_policy()
returns trigger
language plpgsql
set search_path=''
as $$
declare uid uuid := (select auth.uid()); internal_write boolean := current_setting('app.mrcip_ai_budget_write',true)='on'; next_version integer;
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','finance','legal_compliance']) then raise exception 'AI budget-policy authority required'; end if;
  if tg_op='INSERT' then
    if new.status<>'draft' then raise exception 'New AI budget policies must begin in draft'; end if;
    select coalesce(max(version_no),0)+1 into next_version from public.mrcip_ai_budget_policies where organisation_id=new.organisation_id and provider_config_id=new.provider_config_id;
    new.version_no:=next_version; new.created_at:=now(); new.created_by:=uid; new.approved_at:=null; new.approved_by:=null;
  else
    if old.organisation_id<>new.organisation_id or old.provider_config_id<>new.provider_config_id or old.version_no<>new.version_no or old.currency<>new.currency or old.monthly_budget<>new.monthly_budget or old.daily_budget is distinct from new.daily_budget or old.max_cost_per_execution<>new.max_cost_per_execution or old.max_output_tokens_per_execution<>new.max_output_tokens_per_execution or old.max_executions_per_hour<>new.max_executions_per_hour or old.max_executions_per_day<>new.max_executions_per_day or old.max_protected_executions_per_day<>new.max_protected_executions_per_day or old.effective_from<>new.effective_from or old.effective_to is distinct from new.effective_to or old.created_at<>new.created_at or old.created_by<>new.created_by then raise exception 'AI budget-policy terms are immutable; create a new version'; end if;
    if old.status='retired' and new.status<>'retired' then raise exception 'Retired budget policies cannot be reactivated'; end if;
    if old.status='draft' and new.status='active' and not internal_write then raise exception 'Use the controlled budget-policy approval RPC'; end if;
    if old.status='active' and new.status not in ('active','retired') then raise exception 'Active budget policies may only remain active or be retired'; end if;
  end if;
  if new.status='active' then new.approved_at:=coalesce(new.approved_at,now()); new.approved_by:=coalesce(new.approved_by,uid); end if;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_budget_policy() from public,anon,authenticated;
create trigger mrcip_ai_budget_policies_guard_biu before insert or update on public.mrcip_ai_budget_policies for each row execute function private.guard_mrcip_ai_budget_policy();

create or replace function public.approve_mrcip_ai_provider_rate(p_rate_card_id uuid)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare r public.mrcip_ai_provider_rates%rowtype;
begin
  select * into r from public.mrcip_ai_provider_rates where id=p_rate_card_id;
  if not found then raise exception 'Provider rate card not found or not accessible'; end if;
  if not private.has_mrcip_role(r.organisation_id,array['super_admin','managing_director','finance']) then raise exception 'Executive/finance authority required to approve provider pricing'; end if;
  if r.status<>'draft' then raise exception 'Only draft rate cards may be approved'; end if;
  perform set_config('app.mrcip_ai_rate_write','on',true);
  update public.mrcip_ai_provider_rates set status='retired' where organisation_id=r.organisation_id and provider_config_id=r.provider_config_id and status='active';
  update public.mrcip_ai_provider_rates set status='active' where id=r.id;
  return r.id;
end; $$;
revoke all on function public.approve_mrcip_ai_provider_rate(uuid) from public,anon;
grant execute on function public.approve_mrcip_ai_provider_rate(uuid) to authenticated;

create or replace function public.approve_mrcip_ai_budget_policy(p_budget_policy_id uuid)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare b public.mrcip_ai_budget_policies%rowtype;
begin
  select * into b from public.mrcip_ai_budget_policies where id=p_budget_policy_id;
  if not found then raise exception 'AI budget policy not found or not accessible'; end if;
  if not private.has_mrcip_role(b.organisation_id,array['super_admin','managing_director','finance']) then raise exception 'Executive/finance authority required to approve AI budgets'; end if;
  if b.status<>'draft' then raise exception 'Only draft budget policies may be approved'; end if;
  perform set_config('app.mrcip_ai_budget_write','on',true);
  update public.mrcip_ai_budget_policies set status='retired' where organisation_id=b.organisation_id and provider_config_id=b.provider_config_id and status='active';
  update public.mrcip_ai_budget_policies set status='active' where id=b.id;
  return b.id;
end; $$;
revoke all on function public.approve_mrcip_ai_budget_policy(uuid) from public,anon;
grant execute on function public.approve_mrcip_ai_budget_policy(uuid) to authenticated;

create or replace function private.guard_mrcip_ai_provider_onboarding()
returns trigger
language plpgsql
set search_path=''
as $$
declare uid uuid := (select auth.uid()); internal_write boolean := current_setting('app.mrcip_ai_onboarding_write',true)='on'; next_revision integer;
begin
  if uid is null then raise exception 'Authenticated user required'; end if;
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','legal_compliance']) then raise exception 'Executive/legal AI onboarding authority required'; end if;
  if tg_op='INSERT' then
    if new.status not in ('draft','evaluation_required') then raise exception 'New provider onboarding revisions must begin in draft/evaluation_required'; end if;
    select coalesce(max(revision_no),0)+1 into next_revision from public.mrcip_ai_provider_onboarding where organisation_id=new.organisation_id and provider_config_id=new.provider_config_id;
    new.revision_no:=next_revision; new.created_at:=now(); new.created_by:=uid; new.decided_at:=null; new.decided_by:=null;
  else
    if old.organisation_id<>new.organisation_id or old.provider_config_id<>new.provider_config_id or old.revision_no<>new.revision_no or old.created_at<>new.created_at or old.created_by<>new.created_by then raise exception 'Provider onboarding identity/history is immutable'; end if;
    if old.status in ('production_approved','rejected','revoked') and new.status<>old.status then raise exception 'Final onboarding revisions are immutable; create a new revision or use controlled revocation'; end if;
    if new.status in ('evaluation_passed','production_approved','rejected','revoked') and not internal_write then raise exception 'Use the controlled provider-onboarding decision RPCs'; end if;
  end if;
  if new.status in ('production_approved','rejected','revoked') then new.decided_at:=coalesce(new.decided_at,now()); new.decided_by:=coalesce(new.decided_by,uid); end if;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_provider_onboarding() from public,anon,authenticated;
create trigger mrcip_ai_provider_onboarding_guard_biu before insert or update on public.mrcip_ai_provider_onboarding for each row execute function private.guard_mrcip_ai_provider_onboarding();

create or replace function public.prepare_mrcip_ai_provider_onboarding(p_provider_config_id uuid)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare cfg public.mrcip_ai_provider_configs%rowtype; oid uuid;
begin
  select * into cfg from public.mrcip_ai_provider_configs where id=p_provider_config_id;
  if not found then raise exception 'Provider configuration not found or not accessible'; end if;
  if not private.has_mrcip_role(cfg.organisation_id,array['super_admin','managing_director','legal_compliance']) then raise exception 'Executive/legal AI onboarding authority required'; end if;
  insert into public.mrcip_ai_provider_onboarding(organisation_id,provider_config_id,status,created_by) values(cfg.organisation_id,cfg.id,'evaluation_required',(select auth.uid())) returning id into oid;
  return oid;
end; $$;
revoke all on function public.prepare_mrcip_ai_provider_onboarding(uuid) from public,anon;
grant execute on function public.prepare_mrcip_ai_provider_onboarding(uuid) to authenticated;

create or replace function public.approve_mrcip_ai_provider_onboarding(p_onboarding_id uuid,p_evaluation_run_id uuid,p_rate_card_id uuid,p_budget_policy_id uuid,p_protected_data_approved boolean default false,p_legal_data_handling_checked boolean default false,p_security_review_checked boolean default false,p_commercial_review_checked boolean default false,p_decision_notes text default '')
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare o public.mrcip_ai_provider_onboarding%rowtype; cfg public.mrcip_ai_provider_configs%rowtype; er public.mrcip_ai_eval_runs%rowtype; rate public.mrcip_ai_provider_rates%rowtype; bud public.mrcip_ai_budget_policies%rowtype; pv public.mrcip_ai_prompt_versions%rowtype;
begin
  select * into o from public.mrcip_ai_provider_onboarding where id=p_onboarding_id;
  if not found then raise exception 'Provider onboarding revision not found or not accessible'; end if;
  if not private.has_mrcip_role(o.organisation_id,array['super_admin','managing_director','legal_compliance']) then raise exception 'Executive/legal authority required to approve provider onboarding'; end if;
  if o.status not in ('draft','evaluation_required','evaluation_passed') then raise exception 'Provider onboarding revision is not approvable'; end if;
  select * into cfg from public.mrcip_ai_provider_configs where organisation_id=o.organisation_id and id=o.provider_config_id;
  if cfg.status not in ('integration_ready','active') or cfg.connection_status<>'verified' or cfg.credential_status<>'configured_external_secret' then raise exception 'Provider must be gateway-verified and credential-ready'; end if;
  select * into er from public.mrcip_ai_eval_runs where organisation_id=o.organisation_id and id=p_evaluation_run_id;
  if not found or er.provider_config_id<>o.provider_config_id or er.status<>'completed' or er.passed is distinct from true or er.run_mode<>'gateway_evaluation' then raise exception 'Production approval requires a passing completed gateway evaluation for this provider'; end if;
  select * into pv from public.mrcip_ai_prompt_versions where organisation_id=o.organisation_id and id=er.prompt_version_id;
  if not found or pv.status<>'approved' then raise exception 'Evaluated prompt version must remain approved'; end if;
  select * into rate from public.mrcip_ai_provider_rates where organisation_id=o.organisation_id and id=p_rate_card_id and provider_config_id=o.provider_config_id;
  if not found or rate.status<>'active' or rate.effective_from>now() or (rate.effective_to is not null and rate.effective_to<=now()) then raise exception 'Active current provider rate card required'; end if;
  select * into bud from public.mrcip_ai_budget_policies where organisation_id=o.organisation_id and id=p_budget_policy_id and provider_config_id=o.provider_config_id;
  if not found or bud.status<>'active' or bud.effective_from>now() or (bud.effective_to is not null and bud.effective_to<=now()) then raise exception 'Active current AI budget policy required'; end if;
  if bud.currency<>rate.currency then raise exception 'Budget and provider rate-card currencies must match'; end if;
  if pv.max_output_tokens>bud.max_output_tokens_per_execution then raise exception 'Evaluated prompt output cap exceeds the approved budget-policy token cap'; end if;
  if not coalesce(p_legal_data_handling_checked,false) or not coalesce(p_security_review_checked,false) or not coalesce(p_commercial_review_checked,false) then raise exception 'Legal/data-handling, security and commercial reviews must all be checked before production approval'; end if;
  if coalesce(p_protected_data_approved,false) and not pv.protected_data_approved then raise exception 'Protected production approval requires an evaluated prompt approved for protected data'; end if;
  perform set_config('app.mrcip_ai_onboarding_write','on',true);
  update public.mrcip_ai_provider_onboarding set status='production_approved',evaluation_run_id=er.id,prompt_version_id=pv.id,rate_card_id=rate.id,budget_policy_id=bud.id,protected_data_approved=coalesce(p_protected_data_approved,false),legal_data_handling_checked=true,security_review_checked=true,commercial_review_checked=true,decision_notes=left(coalesce(p_decision_notes,''),6000),decided_at=now(),decided_by=(select auth.uid()) where id=o.id;
  return o.id;
end; $$;
revoke all on function public.approve_mrcip_ai_provider_onboarding(uuid,uuid,uuid,uuid,boolean,boolean,boolean,boolean,text) from public,anon;
grant execute on function public.approve_mrcip_ai_provider_onboarding(uuid,uuid,uuid,uuid,boolean,boolean,boolean,boolean,text) to authenticated;

create or replace function public.revoke_mrcip_ai_provider_onboarding(p_onboarding_id uuid,p_reason text)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare o public.mrcip_ai_provider_onboarding%rowtype;
begin
  select * into o from public.mrcip_ai_provider_onboarding where id=p_onboarding_id;
  if not found then raise exception 'Provider onboarding revision not found or not accessible'; end if;
  if not private.has_mrcip_role(o.organisation_id,array['super_admin','managing_director']) then raise exception 'Executive authority required to revoke provider onboarding'; end if;
  if o.status<>'production_approved' then raise exception 'Only production-approved onboarding may be revoked'; end if;
  if btrim(coalesce(p_reason,''))='' then raise exception 'Revocation reason is required'; end if;
  perform set_config('app.mrcip_ai_onboarding_write','on',true);
  update public.mrcip_ai_provider_onboarding set status='revoked',decision_notes=left(p_reason,6000),decided_at=now(),decided_by=(select auth.uid()) where id=o.id;
  update public.mrcip_ai_provider_configs set status='disabled',protected_data_allowed=false where organisation_id=o.organisation_id and id=o.provider_config_id and status='active';
  return o.id;
end; $$;
revoke all on function public.revoke_mrcip_ai_provider_onboarding(uuid,text) from public,anon;
grant execute on function public.revoke_mrcip_ai_provider_onboarding(uuid,text) to authenticated;

create or replace function private.enforce_mrcip_ai_stage13_provider_activation()
returns trigger
language plpgsql
set search_path=''
as $$
declare o public.mrcip_ai_provider_onboarding%rowtype; rate_status text; budget_status text;
begin
  if new.status='active' then
    select * into o from public.mrcip_ai_provider_onboarding where organisation_id=new.organisation_id and provider_config_id=new.id and status='production_approved' order by revision_no desc limit 1;
    if not found then raise exception 'Stage 13 production-approved provider onboarding is required before activation'; end if;
    select status into rate_status from public.mrcip_ai_provider_rates where organisation_id=new.organisation_id and id=o.rate_card_id and provider_config_id=new.id and effective_from<=now() and (effective_to is null or effective_to>now());
    select status into budget_status from public.mrcip_ai_budget_policies where organisation_id=new.organisation_id and id=o.budget_policy_id and provider_config_id=new.id and effective_from<=now() and (effective_to is null or effective_to>now());
    if rate_status<>'active' or budget_status<>'active' then raise exception 'Production activation requires the onboarding-linked active current rate card and budget policy'; end if;
    if new.protected_data_allowed and not o.protected_data_approved then raise exception 'Protected-data provider activation exceeds Stage 13 onboarding approval'; end if;
  end if;
  return new;
end; $$;
revoke all on function private.enforce_mrcip_ai_stage13_provider_activation() from public,anon,authenticated;
create trigger z_mrcip_ai_provider_configs_stage13_activation_gate_biu before insert or update on public.mrcip_ai_provider_configs for each row execute function private.enforce_mrcip_ai_stage13_provider_activation();

create or replace function private.enforce_mrcip_ai_stage13_execution_gate()
returns trigger
language plpgsql
set search_path=''
as $$
declare o public.mrcip_ai_provider_onboarding%rowtype; bud public.mrcip_ai_budget_policies%rowtype; rate public.mrcip_ai_provider_rates%rowtype; pv public.mrcip_ai_prompt_versions%rowtype; hourly_count integer; daily_count integer; protected_count integer; month_spend numeric; day_spend numeric; over_exec integer;
begin
  select * into o from public.mrcip_ai_provider_onboarding where organisation_id=new.organisation_id and provider_config_id=new.provider_config_id and status='production_approved' order by revision_no desc limit 1;
  if not found then raise exception 'Stage 13 production onboarding approval required for provider execution'; end if;
  if o.prompt_version_id<>new.prompt_version_id then raise exception 'Execution prompt version is not the Stage 13 evaluated/approved production prompt'; end if;
  select * into bud from public.mrcip_ai_budget_policies where organisation_id=new.organisation_id and id=o.budget_policy_id and status='active' and effective_from<=now() and (effective_to is null or effective_to>now());
  if not found then raise exception 'Stage 13 active budget policy is unavailable'; end if;
  select * into rate from public.mrcip_ai_provider_rates where organisation_id=new.organisation_id and id=o.rate_card_id and status='active' and effective_from<=now() and (effective_to is null or effective_to>now());
  if not found then raise exception 'Stage 13 active provider rate card is unavailable'; end if;
  if rate.currency<>bud.currency then raise exception 'Provider rate and budget currency mismatch'; end if;
  select * into pv from public.mrcip_ai_prompt_versions where organisation_id=new.organisation_id and id=new.prompt_version_id;
  if pv.max_output_tokens>bud.max_output_tokens_per_execution then raise exception 'Prompt output token cap exceeds Stage 13 budget policy'; end if;
  select count(*)::integer into hourly_count from public.mrcip_ai_executions e where e.organisation_id=new.organisation_id and e.provider_config_id=new.provider_config_id and e.prepared_at>=now()-interval '1 hour' and e.status in ('prepared','running','completed');
  select count(*)::integer into daily_count from public.mrcip_ai_executions e where e.organisation_id=new.organisation_id and e.provider_config_id=new.provider_config_id and e.prepared_at>=date_trunc('day',now()) and e.status in ('prepared','running','completed');
  select count(*)::integer into protected_count from public.mrcip_ai_executions e where e.organisation_id=new.organisation_id and e.provider_config_id=new.provider_config_id and e.prepared_at>=date_trunc('day',now()) and e.protected_context and e.status in ('prepared','running','completed');
  if hourly_count>=bud.max_executions_per_hour then raise exception 'Stage 13 hourly provider execution limit reached'; end if;
  if daily_count>=bud.max_executions_per_day then raise exception 'Stage 13 daily provider execution limit reached'; end if;
  if new.protected_context and protected_count>=bud.max_protected_executions_per_day then raise exception 'Stage 13 protected-context daily execution limit reached'; end if;
  select coalesce(sum(e.cost_amount),0) into month_spend from public.mrcip_ai_executions e where e.organisation_id=new.organisation_id and e.provider_config_id=new.provider_config_id and e.status='completed' and e.cost_currency=bud.currency and e.finished_at>=date_trunc('month',now());
  if month_spend>=bud.monthly_budget then raise exception 'Stage 13 monthly AI budget reached'; end if;
  if bud.daily_budget is not null then select coalesce(sum(e.cost_amount),0) into day_spend from public.mrcip_ai_executions e where e.organisation_id=new.organisation_id and e.provider_config_id=new.provider_config_id and e.status='completed' and e.cost_currency=bud.currency and e.finished_at>=date_trunc('day',now()); if day_spend>=bud.daily_budget then raise exception 'Stage 13 daily AI budget reached'; end if; end if;
  select count(*)::integer into over_exec from public.mrcip_ai_executions e where e.organisation_id=new.organisation_id and e.provider_config_id=new.provider_config_id and e.status='completed' and e.finished_at>=date_trunc('month',now()) and e.cost_currency=bud.currency and e.cost_amount>bud.max_cost_per_execution;
  if over_exec>0 then raise exception 'Stage 13 execution-cost breach requires budget/onboarding review before further provider use'; end if;
  return new;
end; $$;
revoke all on function private.enforce_mrcip_ai_stage13_execution_gate() from public,anon,authenticated;
create trigger z_mrcip_ai_executions_stage13_production_gate_bi before insert on public.mrcip_ai_executions for each row execute function private.enforce_mrcip_ai_stage13_execution_gate();

create or replace function private.apply_mrcip_ai_stage13_execution_cost()
returns trigger
language plpgsql
set search_path=''
as $$
declare o public.mrcip_ai_provider_onboarding%rowtype; bud public.mrcip_ai_budget_policies%rowtype; rate public.mrcip_ai_provider_rates%rowtype; calc numeric(18,8); projected_month numeric; projected_day numeric;
begin
  if new.status='completed' and old.status='running' then
    select * into o from public.mrcip_ai_provider_onboarding where organisation_id=new.organisation_id and provider_config_id=new.provider_config_id and status='production_approved' order by revision_no desc limit 1;
    if not found then raise exception 'Stage 13 production onboarding disappeared before execution completion'; end if;
    select * into rate from public.mrcip_ai_provider_rates where organisation_id=new.organisation_id and id=o.rate_card_id and status='active';
    select * into bud from public.mrcip_ai_budget_policies where organisation_id=new.organisation_id and id=o.budget_policy_id and status='active';
    if rate.id is null or bud.id is null or rate.currency<>bud.currency then raise exception 'Stage 13 rate/budget controls unavailable at execution completion'; end if;
    if new.input_tokens is null or new.output_tokens is null then raise exception 'Token usage is required to derive Stage 13 execution cost'; end if;
    calc:=round(((new.input_tokens::numeric*rate.input_cost_per_1m)+(new.output_tokens::numeric*rate.output_cost_per_1m))/1000000,8);
    new.cost_amount:=calc; new.cost_currency:=rate.currency; new.cost_source:='configured_rate';
    select coalesce(sum(e.cost_amount),0)+calc into projected_month from public.mrcip_ai_executions e where e.organisation_id=new.organisation_id and e.provider_config_id=new.provider_config_id and e.status='completed' and e.cost_currency=bud.currency and e.finished_at>=date_trunc('month',now()) and e.id<>new.id;
    select coalesce(sum(e.cost_amount),0)+calc into projected_day from public.mrcip_ai_executions e where e.organisation_id=new.organisation_id and e.provider_config_id=new.provider_config_id and e.status='completed' and e.cost_currency=bud.currency and e.finished_at>=date_trunc('day',now()) and e.id<>new.id;
    if calc>bud.max_cost_per_execution or projected_month>bud.monthly_budget or (bud.daily_budget is not null and projected_day>bud.daily_budget) then
      new.provider_telemetry:=coalesce(new.provider_telemetry,'{}'::jsonb)||jsonb_build_object('stage13_budget_breach',true,'configured_cost',calc,'budget_currency',bud.currency,'projected_month_spend',projected_month,'projected_day_spend',projected_day);
    end if;
  end if;
  return new;
end; $$;
revoke all on function private.apply_mrcip_ai_stage13_execution_cost() from public,anon,authenticated;
create trigger mrcip_ai_executions_stage13_cost_bu before update on public.mrcip_ai_executions for each row execute function private.apply_mrcip_ai_stage13_execution_cost();