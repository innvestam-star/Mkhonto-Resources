create index commodities_created_by_idx on public.commodities (created_by) where created_by is not null;
create index commodity_products_created_by_idx on public.commodity_products (created_by) where created_by is not null;
create index commodity_spec_fields_created_by_idx on public.commodity_spec_fields (created_by) where created_by is not null;

create index counterparties_created_by_idx on public.counterparties (created_by);
create index counterparties_updated_by_idx on public.counterparties (updated_by);
create index counterparties_formal_client_idx on public.counterparties (formal_client_id) where formal_client_id is not null;
create index counterparties_parent_idx on public.counterparties (parent_counterparty_id) where parent_counterparty_id is not null;
create index counterparties_relationship_owner_idx on public.counterparties (relationship_owner) where relationship_owner is not null;

create index counterparty_commodities_commodity_idx on public.counterparty_commodities (commodity_id);
create index counterparty_commodities_product_idx on public.counterparty_commodities (product_id) where product_id is not null;
create index counterparty_commodities_created_by_idx on public.counterparty_commodities (created_by);

create index counterparty_contacts_counterparty_idx on public.counterparty_contacts (counterparty_id);
create index counterparty_contacts_created_by_idx on public.counterparty_contacts (created_by);
create index counterparty_contacts_updated_by_idx on public.counterparty_contacts (updated_by);
create index counterparty_contacts_relationship_owner_idx on public.counterparty_contacts (relationship_owner) where relationship_owner is not null;

create index counterparty_role_assignments_role_idx on public.counterparty_role_assignments (role_key);
create index counterparty_role_assignments_created_by_idx on public.counterparty_role_assignments (created_by);

create index intelligence_sources_captured_by_idx on public.intelligence_sources (captured_by) where captured_by is not null;
create index intelligence_sources_commodity_idx on public.intelligence_sources (commodity_id) where commodity_id is not null;
create index intelligence_sources_product_idx on public.intelligence_sources (product_id) where product_id is not null;
create index intelligence_sources_document_idx on public.intelligence_sources (source_document_id) where source_document_id is not null;

create index mrcip_user_roles_membership_idx on public.mrcip_user_roles (membership_id);
create index mrcip_user_roles_created_by_idx on public.mrcip_user_roles (created_by);

create index verification_records_counterparty_idx on public.verification_records (counterparty_id) where counterparty_id is not null;
create index verification_records_contact_idx on public.verification_records (contact_id) where contact_id is not null;
create index verification_records_source_idx on public.verification_records (source_id) where source_id is not null;
create index verification_records_verified_by_idx on public.verification_records (verified_by) where verified_by is not null;

drop policy if exists commodities_write on public.commodities;
create policy commodities_insert on public.commodities for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));
create policy commodities_update on public.commodities for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));
create policy commodities_delete on public.commodities for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

drop policy if exists commodity_products_write on public.commodity_products;
create policy commodity_products_insert on public.commodity_products for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));
create policy commodity_products_update on public.commodity_products for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));
create policy commodity_products_delete on public.commodity_products for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

drop policy if exists commodity_spec_fields_write on public.commodity_spec_fields;
create policy commodity_spec_fields_insert on public.commodity_spec_fields for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));
create policy commodity_spec_fields_update on public.commodity_spec_fields for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));
create policy commodity_spec_fields_delete on public.commodity_spec_fields for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

drop policy if exists counterparty_commodities_write on public.counterparty_commodities;
create policy counterparty_commodities_insert on public.counterparty_commodities for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst']));
create policy counterparty_commodities_update on public.counterparty_commodities for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst']));
create policy counterparty_commodities_delete on public.counterparty_commodities for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

drop policy if exists intelligence_sources_write on public.intelligence_sources;
create policy intelligence_sources_insert on public.intelligence_sources for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','legal_compliance','research_analyst']));
create policy intelligence_sources_update on public.intelligence_sources for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','legal_compliance','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','legal_compliance','research_analyst']));
create policy intelligence_sources_delete on public.intelligence_sources for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance']));

drop policy if exists verification_records_write on public.verification_records;
create policy verification_records_insert on public.verification_records for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy verification_records_update on public.verification_records for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy verification_records_delete on public.verification_records for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance']));
