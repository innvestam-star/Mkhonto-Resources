create or replace function private.guard_mrcip_ai_provider_config()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  uid uuid := (select auth.uid());
  internal_verify boolean := (current_user='service_role' and current_setting('app.mrcip_ai_provider_verification',true)='on');
  runtime_changed boolean:=false;
  secret_missing boolean:=false;
begin
  if internal_verify then
    if tg_op<>'UPDATE' then raise exception 'Gateway verification may only update an existing provider configuration'; end if;
    new.organisation_id:=old.organisation_id;
    new.provider_key:=old.provider_key;
    new.model_name:=old.model_name;
    new.adapter_key:=old.adapter_key;
    new.credential_secret_ref:=old.credential_secret_ref;
    new.external_processing_location:=old.external_processing_location;
    new.data_handling_notes:=old.data_handling_notes;
    new.created_at:=old.created_at;
    new.created_by:=old.created_by;
    new.approved_at:=old.approved_at;
    new.approved_by:=old.approved_by;
    secret_missing := new.last_connection_error like 'SECRET_MISSING:%';
    if new.connection_status='failed' then
      if secret_missing then
        new.status:='disabled';
        new.credential_status:='not_configured';
      else
        if old.status='active' then new.status:='integration_ready'; else new.status:=old.status; end if;
        new.credential_status:=old.credential_status;
      end if;
      new.protected_data_allowed:=false;
    elsif new.connection_status='verified' then
      new.status:=old.status;
      new.protected_data_allowed:=old.protected_data_allowed;
      new.credential_status:=old.credential_status;
      new.connection_verified_at:=coalesce(new.connection_verified_at,now());
    elsif new.connection_status='revoked' then
      new.status:='revoked';
      new.credential_status:='revoked';
      new.protected_data_allowed:=false;
    else
      raise exception 'Gateway verification may record only verified, failed or revoked state';
    end if;
    new.updated_at:=now();
    new.updated_by:=old.updated_by;
    return new;
  end if;

  if uid is null then raise exception 'Authenticated user required'; end if;
  if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director']) then
    raise exception 'Executive MRCIP authority required to configure AI providers';
  end if;
  if tg_op='UPDATE' then
    if old.organisation_id<>new.organisation_id or old.provider_key<>new.provider_key or old.model_name<>new.model_name or old.created_at<>new.created_at or old.created_by<>new.created_by then
      raise exception 'Provider identity and creation history are immutable; create a new provider configuration instead';
    end if;
    runtime_changed := old.adapter_key is distinct from new.adapter_key or old.credential_secret_ref is distinct from new.credential_secret_ref;
    if runtime_changed then
      if old.status in ('active','revoked') then raise exception 'Deactivate or replace an active/revoked provider before changing runtime configuration'; end if;
      new.connection_status:='not_tested';
      new.connection_verified_at:=null;
      new.connection_verification_ref:='';
      new.last_connection_error:='';
    end if;
  end if;
  if new.status in ('integration_ready','active') then
    if new.credential_status<>'configured_external_secret' then raise exception 'Provider cannot be integration-ready or active without an externally configured credential'; end if;
    if new.adapter_key='unconfigured' or btrim(new.credential_secret_ref)='' then raise exception 'Provider cannot be integration-ready or active without an approved runtime adapter and MRCIP AI secret reference'; end if;
  end if;
  if new.status='active' and new.connection_status<>'verified' then raise exception 'Provider cannot be active until the Stage 12 gateway verifies the configured connection'; end if;
  if new.status='active' then
    new.approved_at:=coalesce(new.approved_at,now());
    new.approved_by:=coalesce(new.approved_by,uid);
  end if;
  if new.protected_data_allowed and new.status<>'active' then raise exception 'Protected-data processing may be enabled only for an active approved provider'; end if;
  if new.status='revoked' then
    new.credential_status:='revoked';
    new.connection_status:='revoked';
    new.protected_data_allowed:=false;
  end if;
  if new.credential_status='revoked' and new.status<>'revoked' then raise exception 'A revoked credential requires provider status revoked'; end if;
  new.updated_at:=now();
  new.updated_by:=uid;
  if tg_op='INSERT' then
    new.created_by:=uid;
    new.created_at:=now();
    if new.status='active' then raise exception 'New provider configurations must be verified before activation'; end if;
  end if;
  return new;
end; $$;
revoke all on function private.guard_mrcip_ai_provider_config() from public,anon,authenticated;