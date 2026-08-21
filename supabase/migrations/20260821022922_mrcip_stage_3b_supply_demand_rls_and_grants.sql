alter table public.buyer_requirements enable row level security;
alter table public.seller_supply_offers enable row level security;
alter table public.buyer_requirement_specs enable row level security;
alter table public.seller_offer_specs enable row level security;

grant select, insert, update, delete on public.buyer_requirements to authenticated;
grant select, insert, update, delete on public.seller_supply_offers to authenticated;
grant select, insert, update, delete on public.buyer_requirement_specs to authenticated;
grant select, insert, update, delete on public.seller_offer_specs to authenticated;
grant all on public.buyer_requirements to service_role;
grant all on public.seller_supply_offers to service_role;
grant all on public.buyer_requirement_specs to service_role;
grant all on public.seller_offer_specs to service_role;
revoke all on public.buyer_requirements from anon;
revoke all on public.seller_supply_offers from anon;
revoke all on public.buyer_requirement_specs from anon;
revoke all on public.seller_offer_specs from anon;

create policy buyer_requirements_select on public.buyer_requirements
for select to authenticated
using (private.has_mrcip_role(organisation_id, null::text[]));

create policy buyer_requirements_insert on public.buyer_requirements
for insert to authenticated
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])
  and created_by = (select auth.uid())
  and updated_by = (select auth.uid())
);

create policy buyer_requirements_update on public.buyer_requirements
for update to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst']))
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])
  and updated_by = (select auth.uid())
);

create policy buyer_requirements_delete on public.buyer_requirements
for delete to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

create policy seller_supply_offers_select on public.seller_supply_offers
for select to authenticated
using (
  ((not is_protected) and private.has_mrcip_role(organisation_id, null::text[]))
  or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
);

create policy seller_supply_offers_insert on public.seller_supply_offers
for insert to authenticated
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])
  and created_by = (select auth.uid())
  and updated_by = (select auth.uid())
  and ((not is_protected) or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);

create policy seller_supply_offers_update on public.seller_supply_offers
for update to authenticated
using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])
  and ((not is_protected) or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
)
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])
  and updated_by = (select auth.uid())
  and ((not is_protected) or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);

create policy seller_supply_offers_delete on public.seller_supply_offers
for delete to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

create policy buyer_requirement_specs_select on public.buyer_requirement_specs
for select to authenticated
using (private.has_mrcip_role(organisation_id, null::text[]));

create policy buyer_requirement_specs_insert on public.buyer_requirement_specs
for insert to authenticated
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])
  and created_by = (select auth.uid())
  and updated_by = (select auth.uid())
);

create policy buyer_requirement_specs_update on public.buyer_requirement_specs
for update to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst']))
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])
  and updated_by = (select auth.uid())
);

create policy buyer_requirement_specs_delete on public.buyer_requirement_specs
for delete to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader']));

create policy seller_offer_specs_select on public.seller_offer_specs
for select to authenticated
using (
  exists (
    select 1 from public.seller_supply_offers offer
    where offer.id = seller_offer_specs.offer_id
      and offer.organisation_id = seller_offer_specs.organisation_id
  )
);

create policy seller_offer_specs_insert on public.seller_offer_specs
for insert to authenticated
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])
  and created_by = (select auth.uid())
  and updated_by = (select auth.uid())
  and exists (
    select 1 from public.seller_supply_offers offer
    where offer.id = seller_offer_specs.offer_id
      and offer.organisation_id = seller_offer_specs.organisation_id
  )
);

create policy seller_offer_specs_update on public.seller_offer_specs
for update to authenticated
using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])
  and exists (
    select 1 from public.seller_supply_offers offer
    where offer.id = seller_offer_specs.offer_id
      and offer.organisation_id = seller_offer_specs.organisation_id
  )
)
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])
  and updated_by = (select auth.uid())
  and exists (
    select 1 from public.seller_supply_offers offer
    where offer.id = seller_offer_specs.offer_id
      and offer.organisation_id = seller_offer_specs.organisation_id
  )
);

create policy seller_offer_specs_delete on public.seller_offer_specs
for delete to authenticated
using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader'])
  and exists (
    select 1 from public.seller_supply_offers offer
    where offer.id = seller_offer_specs.offer_id
      and offer.organisation_id = seller_offer_specs.organisation_id
  )
);