alter policy documents_select_authorised on public.documents to authenticated using (
  private.is_org_member(organisation_id, array['owner','finance','dispatcher','accountant','viewer'])
  or ((trip_id is not null) and private.can_access_trip(organisation_id, trip_id))
  or private.has_mrcip_role(organisation_id, null::text[])
);
alter policy documents_insert_authorised on public.documents to authenticated with check (
  created_by=(select auth.uid()) and (
    private.is_org_member(organisation_id, array['owner','finance','dispatcher'])
    or ((trip_id is not null) and private.can_access_trip(organisation_id, trip_id))
    or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance'])
  )
);
alter policy documents_update_reviewer on public.documents to authenticated using (
  private.is_org_member(organisation_id, array['owner','finance','dispatcher'])
  or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance'])
) with check (
  private.is_org_member(organisation_id, array['owner','finance','dispatcher'])
  or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance'])
);
alter policy documents_delete_owner on public.documents to authenticated using (
  private.is_org_member(organisation_id, array['owner','finance'])
  or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance'])
);

create policy documents_mrcip_protected_select_guard on public.documents as restrictive
for select to authenticated using (
  category <> 'mrcip_protected'
  or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
);
create policy documents_mrcip_protected_update_guard on public.documents as restrictive
for update to authenticated using (
  category <> 'mrcip_protected'
  or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance'])
) with check (
  category <> 'mrcip_protected'
  or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance'])
);
create policy documents_mrcip_protected_delete_guard on public.documents as restrictive
for delete to authenticated using (
  category <> 'mrcip_protected'
  or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance'])
);

alter policy storage_documents_select_member on storage.objects to authenticated using (
  bucket_id='mkhonto-documents'
  and private.is_org_member(private.storage_organisation_id(name), null::text[])
  and (
    split_part(name,'/',2) <> 'mrcip-protected'
    or private.has_mrcip_role(private.storage_organisation_id(name), array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
  )
);
alter policy storage_documents_insert_member on storage.objects to authenticated with check (
  bucket_id='mkhonto-documents' and (
    (split_part(name,'/',2) <> 'mrcip-protected' and private.is_org_member(private.storage_organisation_id(name), array['owner','finance','dispatcher','driver']))
    or (split_part(name,'/',2) = 'mrcip-protected' and private.has_mrcip_role(private.storage_organisation_id(name), array['super_admin','managing_director','commodity_manager','legal_compliance']))
  )
);
alter policy storage_documents_update_owner on storage.objects to authenticated using (
  bucket_id='mkhonto-documents' and owner_id=((select auth.uid()))::text and (
    (split_part(name,'/',2) <> 'mrcip-protected' and private.is_org_member(private.storage_organisation_id(name), array['owner','finance','dispatcher','driver']))
    or (split_part(name,'/',2) = 'mrcip-protected' and private.has_mrcip_role(private.storage_organisation_id(name), array['super_admin','managing_director','commodity_manager','legal_compliance']))
  )
) with check (
  bucket_id='mkhonto-documents' and owner_id=((select auth.uid()))::text and (
    (split_part(name,'/',2) <> 'mrcip-protected' and private.is_org_member(private.storage_organisation_id(name), array['owner','finance','dispatcher','driver']))
    or (split_part(name,'/',2) = 'mrcip-protected' and private.has_mrcip_role(private.storage_organisation_id(name), array['super_admin','managing_director','commodity_manager','legal_compliance']))
  )
);
alter policy storage_documents_delete_owner on storage.objects to authenticated using (
  bucket_id='mkhonto-documents' and (
    (split_part(name,'/',2) <> 'mrcip-protected' and (private.is_org_member(private.storage_organisation_id(name), array['owner','finance']) or owner_id=((select auth.uid()))::text))
    or (split_part(name,'/',2) = 'mrcip-protected' and private.has_mrcip_role(private.storage_organisation_id(name), array['super_admin','managing_director','legal_compliance']))
  )
);

create or replace function private.enforce_mrcip_protected_document_path()
returns trigger
language plpgsql
security invoker
set search_path=''
as $function$
begin
  if new.category='mrcip_protected' then
    if split_part(new.storage_path,'/',1) <> new.organisation_id::text or split_part(new.storage_path,'/',2) <> 'mrcip-protected' then
      raise exception 'MRCIP protected documents must use organisation/mrcip-protected/... storage paths';
    end if;
  end if;
  return new;
end;
$function$;
revoke all on function private.enforce_mrcip_protected_document_path() from public;
revoke all on function private.enforce_mrcip_protected_document_path() from anon;
revoke all on function private.enforce_mrcip_protected_document_path() from authenticated;
drop trigger if exists documents_mrcip_protected_path_guard on public.documents;
create trigger documents_mrcip_protected_path_guard before insert or update on public.documents for each row execute function private.enforce_mrcip_protected_document_path();

create or replace function private.enforce_deal_room_document_visibility()
returns trigger
language plpgsql
security invoker
set search_path=''
as $function$
declare d public.documents%rowtype;
begin
  select * into d from public.documents where id=new.document_id and organisation_id=new.organisation_id;
  if d.id is null then raise exception 'Document not found or not accessible'; end if;
  if new.visibility in ('protected','external_shared') and d.category <> 'mrcip_protected' then
    raise exception 'Protected/external Deal Room documents must use category mrcip_protected';
  end if;
  return new;
end;
$function$;
revoke all on function private.enforce_deal_room_document_visibility() from public;
revoke all on function private.enforce_deal_room_document_visibility() from anon;
revoke all on function private.enforce_deal_room_document_visibility() from authenticated;
drop trigger if exists opportunity_document_links_visibility_guard on public.opportunity_document_links;
create trigger opportunity_document_links_visibility_guard before insert or update on public.opportunity_document_links for each row execute function private.enforce_deal_room_document_visibility();
