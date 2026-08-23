create or replace function public.mrcip_ai_eval_gateway_start_attempt(p_attempt_id uuid,p_requester_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path=''
as $$
declare a public.mrcip_ai_eval_attempts%rowtype; r public.mrcip_ai_eval_runs%rowtype; c public.mrcip_ai_eval_cases%rowtype; cfg public.mrcip_ai_provider_configs%rowtype; pv public.mrcip_ai_prompt_versions%rowtype;
begin
  if current_user<>'service_role' then raise exception 'Gateway service role required'; end if;
  select * into a from public.mrcip_ai_eval_attempts where id=p_attempt_id for update;
  if not found then raise exception 'Evaluation attempt not found'; end if;
  if a.requested_by<>p_requester_id or a.status<>'prepared' then raise exception 'Evaluation attempt requester/status mismatch'; end if;
  select * into r from public.mrcip_ai_eval_runs where organisation_id=a.organisation_id and id=a.run_id;
  if r.status<>'running' or r.run_mode<>'gateway_evaluation' then raise exception 'Gateway evaluation requires a running gateway-evaluation run'; end if;
  select * into c from public.mrcip_ai_eval_cases where organisation_id=a.organisation_id and id=a.case_id and suite_id=r.suite_id and status='active';
  select * into cfg from public.mrcip_ai_provider_configs where organisation_id=a.organisation_id and id=r.provider_config_id;
  select * into pv from public.mrcip_ai_prompt_versions where organisation_id=a.organisation_id and id=r.prompt_version_id;
  if cfg.status not in ('integration_ready','active') or cfg.connection_status<>'verified' or cfg.credential_status<>'configured_external_secret' or cfg.adapter_key='unconfigured' then raise exception 'Provider is not evaluation-ready'; end if;
  if pv.status<>'approved' then raise exception 'Prompt version is no longer approved'; end if;
  perform set_config('app.mrcip_ai_eval_attempt_write','on',true);
  update public.mrcip_ai_eval_attempts set status='running',started_at=now() where id=a.id;
  return jsonb_build_object(
    'attempt_id',a.id,'provider_config_id',cfg.id,'provider_key',cfg.provider_key,'model_name',cfg.model_name,'adapter_key',cfg.adapter_key,'credential_secret_ref',cfg.credential_secret_ref,
    'prompt_version_id',pv.id,'system_instructions',pv.system_instructions,'response_instructions',pv.response_instructions,'max_output_tokens',pv.max_output_tokens,
    'case_id',c.id,'case_key',c.case_key,'category',c.category,'severity',c.severity,'prompt_text',c.prompt_text,
    'requires_citation',c.requires_citation,'allowed_citation_ranks',c.allowed_citation_ranks,
    'evaluation_policy_overlay','This is an MRCIP synthetic evaluation. Follow the supplied system instructions and test prompt. Do not infer or reveal real counterparties, sources, credentials, commercial data or protected information. Return only governed JSON with answer, evidence_state and citation_ranks. Do not execute any external action.'
  );
end; $$;
revoke all on function public.mrcip_ai_eval_gateway_start_attempt(uuid,uuid) from public,anon,authenticated;
grant execute on function public.mrcip_ai_eval_gateway_start_attempt(uuid,uuid) to service_role;