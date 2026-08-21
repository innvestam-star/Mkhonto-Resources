alter table public.mrcip_user_roles enable row level security;
alter table public.counterparties enable row level security;
alter table public.counterparty_roles enable row level security;
alter table public.counterparty_role_assignments enable row level security;
alter table public.counterparty_contacts enable row level security;
alter table public.commodities enable row level security;
alter table public.commodity_products enable row level security;
alter table public.commodity_spec_fields enable row level security;
alter table public.counterparty_commodities enable row level security;
alter table public.intelligence_sources enable row level security;
alter table public.verification_records enable row level security;

create policy mrcip_user_roles_select on public.mrcip_user_roles for select to authenticated using (private.has_mrcip_role(organisation_id, null));
create policy mrcip_user_roles_insert on public.mrcip_user_roles for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director']));
create policy mrcip_user_roles_update on public.mrcip_user_roles for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director']));
create policy mrcip_user_roles_delete on public.mrcip_user_roles for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director']));

create policy counterparties_select on public.counterparties for select to authenticated using (private.has_mrcip_role(organisation_id, null));
create policy counterparties_insert on public.counterparties for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst']) and created_by = (select auth.uid()));
create policy counterparties_update on public.counterparties for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst']));
create policy counterparties_delete on public.counterparties for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director']));

create policy counterparty_roles_select on public.counterparty_roles for select to authenticated using (true);

create policy counterparty_role_assignments_select on public.counterparty_role_assignments for select to authenticated using (private.has_mrcip_role(organisation_id, null));
create policy counterparty_role_assignments_insert on public.counterparty_role_assignments for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst']));
create policy counterparty_role_assignments_update on public.counterparty_role_assignments for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst']));
create policy counterparty_role_assignments_delete on public.counterparty_role_assignments for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

create policy counterparty_contacts_select on public.counterparty_contacts for select to authenticated using (private.has_mrcip_role(organisation_id, null));
create policy counterparty_contacts_insert on public.counterparty_contacts for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst']) and created_by = (select auth.uid()));
create policy counterparty_contacts_update on public.counterparty_contacts for update to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst'])) with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst']));
create policy counterparty_contacts_delete on public.counterparty_contacts for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));
