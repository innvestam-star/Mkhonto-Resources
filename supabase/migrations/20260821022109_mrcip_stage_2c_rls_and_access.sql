alter table public.mines enable row level security;
alter table public.mine_protected_details enable row level security;
alter table public.mine_products enable row level security;
alter table public.laboratories enable row level security;
alter table public.laboratory_capabilities enable row level security;
alter table public.intelligence_import_batches enable row level security;
alter table public.intelligence_import_rows enable row level security;
alter table public.intelligence_duplicate_candidates enable row level security;

create policy mines_select on public.mines for select to authenticated using (private.has_mrcip_role(organisation_id, null));
create policy mines_insert on public.mines for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst']) and created_by = (select auth.uid()));
create policy mines_update on public.mines for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst']));
create policy mines_delete on public.mines for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

create policy mine_protected_details_select on public.mine_protected_details for select to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance']));
create policy mine_protected_details_insert on public.mine_protected_details for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance']) and created_by = (select auth.uid()));
create policy mine_protected_details_update on public.mine_protected_details for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance']));
create policy mine_protected_details_delete on public.mine_protected_details for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance']));

create policy mine_products_select on public.mine_products for select to authenticated using (private.has_mrcip_role(organisation_id, null));
create policy mine_products_insert on public.mine_products for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','research_analyst']) and created_by = (select auth.uid()));
create policy mine_products_update on public.mine_products for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','research_analyst']));
create policy mine_products_delete on public.mine_products for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

create policy laboratories_select on public.laboratories for select to authenticated using (private.has_mrcip_role(organisation_id, null));
create policy laboratories_insert on public.laboratories for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and created_by = (select auth.uid()));
create policy laboratories_update on public.laboratories for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy laboratories_delete on public.laboratories for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

create policy laboratory_capabilities_select on public.laboratory_capabilities for select to authenticated using (private.has_mrcip_role(organisation_id, null));
create policy laboratory_capabilities_insert on public.laboratory_capabilities for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']) and created_by = (select auth.uid()));
create policy laboratory_capabilities_update on public.laboratory_capabilities for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy laboratory_capabilities_delete on public.laboratory_capabilities for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

create policy intelligence_import_batches_select on public.intelligence_import_batches for select to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy intelligence_import_batches_insert on public.intelligence_import_batches for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','research_analyst']) and created_by = (select auth.uid()));
create policy intelligence_import_batches_update on public.intelligence_import_batches for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','research_analyst']));
create policy intelligence_import_batches_delete on public.intelligence_import_batches for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director']));

create policy intelligence_import_rows_select on public.intelligence_import_rows for select to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy intelligence_import_rows_insert on public.intelligence_import_rows for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','research_analyst']));
create policy intelligence_import_rows_update on public.intelligence_import_rows for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','research_analyst']));
create policy intelligence_import_rows_delete on public.intelligence_import_rows for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director']));

create policy intelligence_duplicate_candidates_select on public.intelligence_duplicate_candidates for select to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance','research_analyst']));
create policy intelligence_duplicate_candidates_insert on public.intelligence_duplicate_candidates for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','research_analyst']));
create policy intelligence_duplicate_candidates_update on public.intelligence_duplicate_candidates for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','research_analyst']));
create policy intelligence_duplicate_candidates_delete on public.intelligence_duplicate_candidates for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director']));

grant select, insert, update, delete on public.mines to authenticated;
grant select, insert, update, delete on public.mine_protected_details to authenticated;
grant select, insert, update, delete on public.mine_products to authenticated;
grant select, insert, update, delete on public.laboratories to authenticated;
grant select, insert, update, delete on public.laboratory_capabilities to authenticated;
grant select, insert, update, delete on public.intelligence_import_batches to authenticated;
grant select, insert, update, delete on public.intelligence_import_rows to authenticated;
grant select, insert, update, delete on public.intelligence_duplicate_candidates to authenticated;
