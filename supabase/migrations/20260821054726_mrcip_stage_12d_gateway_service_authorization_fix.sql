create or replace function public.mrcip_ai_gateway_get_provider_config(p_provider_config_id uuid,p_requester_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path=''
as $$
declare cfg public.mrcip_ai_provider_configs%rowtype;
begin
  if current_user<>'service_role' then raise exception 'Gateway service role required'; end if;
  select * into cfg from public.mrcip_ai_provider_configs where id=p_provider_config_id;
  if not found then raise exception 'Provider configuration not found'; end if;
  if not exists (
    select 1 from public.organisation_memberships om
    left join public.mrcip_user_roles mur on mur.organisation_id=om.organisation_id and mur.membership_id=om.id
    where om.organisation_id=cfg.organisation_id and om.user_id=p_requester_id and (om.role='owner' or mur.role_key in ('super_admin','managing_director'))
  ) then raise exception 'Requester is not authorised to verify provider connections'; end if;
  if cfg.status not in ('integration_ready','active') then raise exception 'Provider is not ready for verification'; end if;
  return jsonb_build_object('provider_config_id',cfg.id,'organisation_id',cfg.organisation_id,'provider_key',cfg.provider_key,'model_name',cfg.model_name,'adapter_key',cfg.adapter_key,'credential_secret_ref',cfg.credential_secret_ref,'connection_status',cfg.connection_status);
end; $$;
revoke all on function public.mrcip_ai_gateway_get_provider_config(uuid,uuid) from public,anon,authenticated;
grant execute on function public.mrcip_ai_gateway_get_provider_config(uuid,uuid) to service_role;

create or replace function public.mrcip_ai_gateway_record_provider_check(p_provider_config_id uuid,p_requester_id uuid,p_success boolean,p_verification_ref text default '',p_error_code text default '',p_error_message text default '')
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare cfg public.mrcip_ai_provider_configs%rowtype; err text;
begin
  if current_user<>'service_role' then raise exception 'Gateway service role required'; end if;
  select * into cfg from public.mrcip_ai_provider_configs where id=p_provider_config_id;
  if not found then raise exception 'Provider configuration not found'; end if;
  if not exists (
    select 1 from public.organisation_memberships om
    left join public.mrcip_user_roles mur on mur.organisation_id=om.organisation_id and mur.membership_id=om.id
    where om.organisation_id=cfg.organisation_id and om.user_id=p_requester_id and (om.role='owner' or mur.role_key in ('super_admin','managing_director'))
  ) then raise exception 'Requester is not authorised to verify provider connections'; end if;
  err:=case when coalesce(p_error_code,'')='' then left(coalesce(p_error_message,''),1800) else left(p_error_code||':'||coalesce(p_error_message,''),1800) end;
  perform set_config('app.mrcip_ai_provider_verification','on',true);
  update public.mrcip_ai_provider_configs
  set connection_status=case when p_success then 'verified' else 'failed' end,
      connection_verified_at=case when p_success then now() else null end,
      connection_verification_ref=left(coalesce(p_verification_ref,''),500),
      last_connection_error=case when p_success then '' else err end
  where id=cfg.id;
  return cfg.id;
end; $$;
revoke all on function public.mrcip_ai_gateway_record_provider_check(uuid,uuid,boolean,text,text,text) from public,anon,authenticated;
grant execute on function public.mrcip_ai_gateway_record_provider_check(uuid,uuid,boolean,text,text,text) to service_role;