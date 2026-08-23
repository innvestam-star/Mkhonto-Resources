create or replace function public.mrcip_ai_gateway_record_provider_request(p_execution_id uuid,p_requester_id uuid)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare e public.mrcip_ai_executions%rowtype;
begin
  if current_user<>'service_role' then raise exception 'Gateway service role required'; end if;
  select * into e from public.mrcip_ai_executions where id=p_execution_id;
  if not found then raise exception 'AI execution not found'; end if;
  if e.requested_by<>p_requester_id then raise exception 'Execution requester mismatch'; end if;
  if e.status<>'running' then raise exception 'Provider request event requires a running execution'; end if;
  insert into public.mrcip_ai_execution_events(organisation_id,execution_id,event_type,event_status,actor_kind,actor_user_id,details)
  values(e.organisation_id,e.id,'provider_request','recorded','gateway',p_requester_id,jsonb_build_object('provider_key',e.provider_key_snapshot,'model_name',e.model_name_snapshot,'adapter_key',e.adapter_key_snapshot,'input_fingerprint',e.input_fingerprint));
  return e.id;
end; $$;
revoke all on function public.mrcip_ai_gateway_record_provider_request(uuid,uuid) from public,anon,authenticated;
grant execute on function public.mrcip_ai_gateway_record_provider_request(uuid,uuid) to service_role;