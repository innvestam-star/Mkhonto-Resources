create policy mrcip_ai_prompt_templates_select on public.mrcip_ai_prompt_templates for select to authenticated using (
  private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','research_analyst','legal_compliance'])
);
create policy mrcip_ai_prompt_templates_insert on public.mrcip_ai_prompt_templates for insert to authenticated with check (
  created_by=(select auth.uid()) and updated_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','research_analyst','legal_compliance'])
);
create policy mrcip_ai_prompt_templates_update on public.mrcip_ai_prompt_templates for update to authenticated using (
  private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','research_analyst','legal_compliance'])
) with check (
  updated_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','research_analyst','legal_compliance'])
);

create policy mrcip_ai_prompt_versions_select on public.mrcip_ai_prompt_versions for select to authenticated using (
  private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','research_analyst','legal_compliance'])
);
create policy mrcip_ai_prompt_versions_insert on public.mrcip_ai_prompt_versions for insert to authenticated with check (
  created_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','research_analyst','legal_compliance'])
);
create policy mrcip_ai_prompt_versions_update on public.mrcip_ai_prompt_versions for update to authenticated using (
  private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance'])
) with check (
  private.has_mrcip_role(organisation_id,array['super_admin','managing_director','legal_compliance'])
);

create policy mrcip_ai_executions_select on public.mrcip_ai_executions for select to authenticated using (
  private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])
  and (requested_by=(select auth.uid()) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']))
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);
create policy mrcip_ai_executions_insert on public.mrcip_ai_executions for insert to authenticated with check (
  requested_by=(select auth.uid())
  and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);

create policy mrcip_ai_execution_events_select on public.mrcip_ai_execution_events for select to authenticated using (
  exists (
    select 1 from public.mrcip_ai_executions e
    where e.organisation_id=mrcip_ai_execution_events.organisation_id and e.id=mrcip_ai_execution_events.execution_id
  )
);

revoke all on public.mrcip_ai_prompt_templates,public.mrcip_ai_prompt_versions,public.mrcip_ai_executions,public.mrcip_ai_execution_events from anon,authenticated;
grant select,insert,update on public.mrcip_ai_prompt_templates to authenticated;
grant select,insert,update on public.mrcip_ai_prompt_versions to authenticated;
grant select,insert on public.mrcip_ai_executions to authenticated;
grant select on public.mrcip_ai_execution_events to authenticated;

grant select,insert,update on public.mrcip_ai_provider_configs to service_role;
grant select on public.mrcip_ai_requests,public.mrcip_ai_context_items,public.mrcip_ai_prompt_templates,public.mrcip_ai_prompt_versions to service_role;
grant select,insert,update on public.mrcip_ai_executions to service_role;
grant select,insert on public.mrcip_ai_execution_events to service_role;
grant select,insert,update on public.mrcip_ai_responses to service_role;
grant select,insert on public.mrcip_ai_citations to service_role;

create or replace view public.mrcip_ai_prompt_catalog_summary with (security_invoker=true) as
select t.organisation_id,t.id as template_id,t.prompt_key,t.name,t.purpose,t.output_type,t.status as template_status,t.updated_at,t.updated_by,
  v.id as latest_approved_version_id,v.version_no as latest_approved_version_no,v.max_output_tokens,v.protected_data_approved,v.content_fingerprint,v.approved_at,v.approved_by
from public.mrcip_ai_prompt_templates t
left join lateral (
  select pv.id,pv.version_no,pv.max_output_tokens,pv.protected_data_approved,pv.content_fingerprint,pv.approved_at,pv.approved_by
  from public.mrcip_ai_prompt_versions pv
  where pv.organisation_id=t.organisation_id and pv.template_id=t.id and pv.status='approved'
  order by pv.version_no desc limit 1
) v on true;
revoke all on public.mrcip_ai_prompt_catalog_summary from public,anon,authenticated;
grant select on public.mrcip_ai_prompt_catalog_summary to authenticated;

create or replace view public.mrcip_ai_execution_summary with (security_invoker=true) as
select e.organisation_id,e.id as execution_id,e.request_id,e.execution_no,e.status as execution_status,e.protected_context,e.policy_version,e.gateway_policy_version,
  e.provider_config_id,e.provider_key_snapshot,e.model_name_snapshot,e.adapter_key_snapshot,e.prompt_version_id,e.prompt_version_no,e.prompt_fingerprint,e.context_fingerprint,e.input_fingerprint,
  e.provider_request_id,e.response_id,e.response_fingerprint,e.input_tokens,e.output_tokens,e.total_tokens,e.latency_ms,e.cost_amount,e.cost_currency,e.cost_source,e.failure_code,e.failure_message,e.prepared_at,e.started_at,e.finished_at,e.requested_by,
  r.request_text,r.purpose,r.output_type,r.status as request_status,
  resp.status as response_status,resp.evidence_state,resp.generated_at,resp.reviewed_at,resp.reviewed_by,
  (select count(*)::integer from public.mrcip_ai_execution_events ev where ev.organisation_id=e.organisation_id and ev.execution_id=e.id) as event_count
from public.mrcip_ai_executions e
join public.mrcip_ai_requests r on r.organisation_id=e.organisation_id and r.id=e.request_id
left join public.mrcip_ai_responses resp on resp.organisation_id=e.organisation_id and resp.id=e.response_id;
revoke all on public.mrcip_ai_execution_summary from public,anon,authenticated;
grant select on public.mrcip_ai_execution_summary to authenticated;

create or replace view public.mrcip_ai_execution_event_trace with (security_invoker=true) as
select e.organisation_id,e.id as execution_id,e.request_id,e.execution_no,e.status as execution_status,e.provider_key_snapshot,e.model_name_snapshot,e.adapter_key_snapshot,
  ev.id as event_id,ev.event_type,ev.event_status,ev.actor_kind,ev.actor_user_id,ev.details,ev.created_at
from public.mrcip_ai_executions e
join public.mrcip_ai_execution_events ev on ev.organisation_id=e.organisation_id and ev.execution_id=e.id;
revoke all on public.mrcip_ai_execution_event_trace from public,anon,authenticated;
grant select on public.mrcip_ai_execution_event_trace to authenticated;