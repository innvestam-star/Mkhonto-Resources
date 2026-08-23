create policy commodities_select on public.commodities for select to authenticated using (private.has_mrcip_role(organisation_id, null));
create policy commodities_write on public.commodities for all to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

create policy commodity_products_select on public.commodity_products for select to authenticated using (private.has_mrcip_role(organisation_id, null));
create policy commodity_products_write on public.commodity_products for all to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

create policy commodity_spec_fields_select on public.commodity_spec_fields for select to authenticated using (private.has_mrcip_role(organisation_id, null));
create policy commodity_spec_fields_write on public.commodity_spec_fields for all to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

create policy counterparty_commodities_select on public.counterparty_commodities for select to authenticated using (private.has_mrcip_role(organisation_id, null));
create policy counterparty_commodities_write on public.counterparty_commodities for all to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst']));

create policy intelligence_sources_select on public.intelligence_sources for select to authenticated using (private.has_mrcip_role(organisation_id, null));
create policy intelligence_sources_write on public.intelligence_sources for all to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','legal_compliance','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','legal_compliance','research_analyst']));

create policy verification_records_select on public.verification_records for select to authenticated using (private.has_mrcip_role(organisation_id, null));
create policy verification_records_write on public.verification_records for all to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));

grant select, insert, update, delete on public.mrcip_user_roles to authenticated;
grant select, insert, update, delete on public.counterparties to authenticated;
grant select on public.counterparty_roles to authenticated;
grant select, insert, update, delete on public.counterparty_role_assignments to authenticated;
grant select, insert, update, delete on public.counterparty_contacts to authenticated;
grant select, insert, update, delete on public.commodities to authenticated;
grant select, insert, update, delete on public.commodity_products to authenticated;
grant select, insert, update, delete on public.commodity_spec_fields to authenticated;
grant select, insert, update, delete on public.counterparty_commodities to authenticated;
grant select, insert, update, delete on public.intelligence_sources to authenticated;
grant select, insert, update, delete on public.verification_records to authenticated;

create trigger counterparties_touch_updated_at before update on public.counterparties for each row execute function private.touch_updated_at();
create trigger counterparty_contacts_touch_updated_at before update on public.counterparty_contacts for each row execute function private.touch_updated_at();
create trigger commodities_touch_updated_at before update on public.commodities for each row execute function private.touch_updated_at();
create trigger commodity_products_touch_updated_at before update on public.commodity_products for each row execute function private.touch_updated_at();
create trigger commodity_spec_fields_touch_updated_at before update on public.commodity_spec_fields for each row execute function private.touch_updated_at();
