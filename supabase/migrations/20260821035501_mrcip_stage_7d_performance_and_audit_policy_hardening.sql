create index commodity_sampling_requests_product_idx
  on public.commodity_sampling_requests(organisation_id, product_id)
  where product_id is not null;

drop policy if exists audit_events_select_management on public.audit_events;
drop policy if exists audit_events_select_mrcip on public.audit_events;
create policy audit_events_select_authorised on public.audit_events
for select to authenticated
using (
  private.is_org_member(organisation_id,array['owner','finance','dispatcher','accountant'])
  or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance'])
);
