alter table public.opportunities enable row level security;
alter table public.opportunity_protocol_controls enable row level security;
alter table public.opportunity_protection_records enable row level security;
alter table public.opportunity_kyc_cases enable row level security;
alter table public.opportunity_mandates enable row level security;
alter table public.opportunity_disclosures enable row level security;

do $$
declare t text;
begin
  foreach t in array array['opportunities','opportunity_protocol_controls','opportunity_protection_records','opportunity_kyc_cases','opportunity_mandates','opportunity_disclosures'] loop
    execute format('revoke all on public.%I from anon', t);
    execute format('revoke all on public.%I from authenticated', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('grant all on public.%I to service_role', t);
  end loop;
end $$;

create policy opportunities_select on public.opportunities
for select to authenticated
using (
  private.has_mrcip_role(organisation_id, null::text[])
  and exists (
    select 1 from public.seller_supply_offers offer
    where offer.id = opportunities.seller_offer_id
      and offer.organisation_id = opportunities.organisation_id
  )
);
create policy opportunities_insert on public.opportunities
for insert to authenticated
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader'])
  and created_by = (select auth.uid()) and updated_by = (select auth.uid())
  and exists (select 1 from public.seller_supply_offers offer where offer.id=opportunities.seller_offer_id and offer.organisation_id=opportunities.organisation_id)
);
create policy opportunities_update on public.opportunities
for update to authenticated
using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','legal_compliance'])
  and exists (select 1 from public.seller_supply_offers offer where offer.id=opportunities.seller_offer_id and offer.organisation_id=opportunities.organisation_id)
)
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','legal_compliance'])
  and updated_by = (select auth.uid())
  and exists (select 1 from public.seller_supply_offers offer where offer.id=opportunities.seller_offer_id and offer.organisation_id=opportunities.organisation_id)
);
create policy opportunities_delete on public.opportunities
for delete to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director']));

create policy opportunity_protocol_controls_select on public.opportunity_protocol_controls
for select to authenticated
using (
  private.has_mrcip_role(organisation_id, null::text[])
  and exists (select 1 from public.opportunities o where o.id=opportunity_protocol_controls.opportunity_id and o.organisation_id=opportunity_protocol_controls.organisation_id)
);
create policy opportunity_protocol_controls_insert on public.opportunity_protocol_controls
for insert to authenticated
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
  and updated_by=(select auth.uid())
  and exists (select 1 from public.opportunities o where o.id=opportunity_protocol_controls.opportunity_id and o.organisation_id=opportunity_protocol_controls.organisation_id)
);
create policy opportunity_protocol_controls_update on public.opportunity_protocol_controls
for update to authenticated
using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
  and exists (select 1 from public.opportunities o where o.id=opportunity_protocol_controls.opportunity_id and o.organisation_id=opportunity_protocol_controls.organisation_id)
)
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
  and updated_by=(select auth.uid())
  and exists (select 1 from public.opportunities o where o.id=opportunity_protocol_controls.opportunity_id and o.organisation_id=opportunity_protocol_controls.organisation_id)
);
create policy opportunity_protocol_controls_delete on public.opportunity_protocol_controls
for delete to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director']));

create policy opportunity_protection_records_select on public.opportunity_protection_records
for select to authenticated
using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
  and exists (select 1 from public.opportunities o where o.id=opportunity_protection_records.opportunity_id and o.organisation_id=opportunity_protection_records.organisation_id)
);
create policy opportunity_protection_records_insert on public.opportunity_protection_records
for insert to authenticated
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance'])
  and created_by=(select auth.uid()) and updated_by=(select auth.uid())
  and exists (select 1 from public.opportunities o where o.id=opportunity_protection_records.opportunity_id and o.organisation_id=opportunity_protection_records.organisation_id)
);
create policy opportunity_protection_records_update on public.opportunity_protection_records
for update to authenticated
using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance'])
  and exists (select 1 from public.opportunities o where o.id=opportunity_protection_records.opportunity_id and o.organisation_id=opportunity_protection_records.organisation_id)
)
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance'])
  and updated_by=(select auth.uid())
  and exists (select 1 from public.opportunities o where o.id=opportunity_protection_records.opportunity_id and o.organisation_id=opportunity_protection_records.organisation_id)
);
create policy opportunity_protection_records_delete on public.opportunity_protection_records
for delete to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance']));

create policy opportunity_kyc_cases_select on public.opportunity_kyc_cases
for select to authenticated
using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance'])
  and exists (select 1 from public.opportunities o where o.id=opportunity_kyc_cases.opportunity_id and o.organisation_id=opportunity_kyc_cases.organisation_id)
);
create policy opportunity_kyc_cases_insert on public.opportunity_kyc_cases
for insert to authenticated
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance'])
  and created_by=(select auth.uid()) and updated_by=(select auth.uid())
  and exists (select 1 from public.opportunities o where o.id=opportunity_kyc_cases.opportunity_id and o.organisation_id=opportunity_kyc_cases.organisation_id)
);
create policy opportunity_kyc_cases_update on public.opportunity_kyc_cases
for update to authenticated
using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance'])
  and exists (select 1 from public.opportunities o where o.id=opportunity_kyc_cases.opportunity_id and o.organisation_id=opportunity_kyc_cases.organisation_id)
)
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance'])
  and updated_by=(select auth.uid())
  and exists (select 1 from public.opportunities o where o.id=opportunity_kyc_cases.opportunity_id and o.organisation_id=opportunity_kyc_cases.organisation_id)
);
create policy opportunity_kyc_cases_delete on public.opportunity_kyc_cases
for delete to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance']));

create policy opportunity_mandates_select on public.opportunity_mandates
for select to authenticated
using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
  and exists (select 1 from public.opportunities o where o.id=opportunity_mandates.opportunity_id and o.organisation_id=opportunity_mandates.organisation_id)
);
create policy opportunity_mandates_insert on public.opportunity_mandates
for insert to authenticated
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance'])
  and created_by=(select auth.uid()) and updated_by=(select auth.uid())
  and exists (select 1 from public.opportunities o where o.id=opportunity_mandates.opportunity_id and o.organisation_id=opportunity_mandates.organisation_id)
);
create policy opportunity_mandates_update on public.opportunity_mandates
for update to authenticated
using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance'])
  and exists (select 1 from public.opportunities o where o.id=opportunity_mandates.opportunity_id and o.organisation_id=opportunity_mandates.organisation_id)
)
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance'])
  and updated_by=(select auth.uid())
  and exists (select 1 from public.opportunities o where o.id=opportunity_mandates.opportunity_id and o.organisation_id=opportunity_mandates.organisation_id)
);
create policy opportunity_mandates_delete on public.opportunity_mandates
for delete to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance']));

create policy opportunity_disclosures_select on public.opportunity_disclosures
for select to authenticated
using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
  and exists (select 1 from public.opportunities o where o.id=opportunity_disclosures.opportunity_id and o.organisation_id=opportunity_disclosures.organisation_id)
);
create policy opportunity_disclosures_insert on public.opportunity_disclosures
for insert to authenticated
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
  and requested_by=(select auth.uid()) and updated_by=(select auth.uid())
  and exists (select 1 from public.opportunities o where o.id=opportunity_disclosures.opportunity_id and o.organisation_id=opportunity_disclosures.organisation_id)
);
create policy opportunity_disclosures_update on public.opportunity_disclosures
for update to authenticated
using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
  and exists (select 1 from public.opportunities o where o.id=opportunity_disclosures.opportunity_id and o.organisation_id=opportunity_disclosures.organisation_id)
)
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
  and updated_by=(select auth.uid())
  and exists (select 1 from public.opportunities o where o.id=opportunity_disclosures.opportunity_id and o.organisation_id=opportunity_disclosures.organisation_id)
);
create policy opportunity_disclosures_delete on public.opportunity_disclosures
for delete to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance']));
