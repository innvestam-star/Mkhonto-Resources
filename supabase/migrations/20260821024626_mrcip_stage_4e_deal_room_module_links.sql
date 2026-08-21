create unique index if not exists finance_documents_org_id_uidx on public.finance_documents (organisation_id, id);
create unique index if not exists freight_analyses_org_id_uidx on public.freight_analyses (organisation_id, id);
create unique index if not exists negotiations_org_id_uidx on public.negotiations (organisation_id, id);

create table public.opportunity_document_links (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  opportunity_id uuid not null,
  document_id uuid not null,
  document_role text not null check (document_role in ('ncnda','fee_protection','transaction_registration','commission_schedule','kyc','kyb','mandate','loi','icpo','assay','inspection','spa','quotation','invoice','proof_of_payment','correspondence','other')),
  visibility text not null default 'protected' check (visibility in ('internal','protected','external_shared')),
  party_scope text not null default 'internal' check (party_scope in ('internal','buyer','seller','both','facilitator')),
  sharing_status text not null default 'draft' check (sharing_status in ('draft','approved','shared','revoked')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid(),
  constraint opportunity_document_links_opportunity_fk foreign key (organisation_id, opportunity_id) references public.opportunities(organisation_id, id) on delete cascade,
  constraint opportunity_document_links_document_fk foreign key (organisation_id, document_id) references public.documents(organisation_id, id),
  unique (opportunity_id, document_id)
);
create index opportunity_document_links_org_opp_idx on public.opportunity_document_links (organisation_id, opportunity_id, visibility, sharing_status);
create index opportunity_document_links_document_idx on public.opportunity_document_links (organisation_id, document_id);
create index opportunity_document_links_created_by_idx on public.opportunity_document_links (created_by);
create index opportunity_document_links_updated_by_idx on public.opportunity_document_links (updated_by);
create trigger opportunity_document_links_touch_updated_at before update on public.opportunity_document_links for each row execute function private.touch_updated_at();

create table public.opportunity_freight_links (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  opportunity_id uuid not null,
  freight_analysis_id uuid not null,
  link_role text not null default 'commercial_analysis' check (link_role in ('commercial_analysis','route_option','approved_route','historical_reference')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  constraint opportunity_freight_links_opportunity_fk foreign key (organisation_id, opportunity_id) references public.opportunities(organisation_id, id) on delete cascade,
  constraint opportunity_freight_links_analysis_fk foreign key (organisation_id, freight_analysis_id) references public.freight_analyses(organisation_id, id),
  unique (opportunity_id, freight_analysis_id, link_role)
);
create index opportunity_freight_links_org_opp_idx on public.opportunity_freight_links (organisation_id, opportunity_id);
create index opportunity_freight_links_analysis_idx on public.opportunity_freight_links (organisation_id, freight_analysis_id);
create index opportunity_freight_links_created_by_idx on public.opportunity_freight_links (created_by);

create table public.opportunity_finance_links (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  opportunity_id uuid not null,
  finance_document_id uuid not null,
  link_role text not null check (link_role in ('quotation','invoice','credit_note','commercial_reference','other')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  constraint opportunity_finance_links_opportunity_fk foreign key (organisation_id, opportunity_id) references public.opportunities(organisation_id, id) on delete cascade,
  constraint opportunity_finance_links_document_fk foreign key (organisation_id, finance_document_id) references public.finance_documents(organisation_id, id),
  unique (opportunity_id, finance_document_id)
);
create index opportunity_finance_links_org_opp_idx on public.opportunity_finance_links (organisation_id, opportunity_id);
create index opportunity_finance_links_document_idx on public.opportunity_finance_links (organisation_id, finance_document_id);
create index opportunity_finance_links_created_by_idx on public.opportunity_finance_links (created_by);

create table public.opportunity_negotiation_links (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  opportunity_id uuid not null,
  negotiation_id uuid not null,
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  constraint opportunity_negotiation_links_opportunity_fk foreign key (organisation_id, opportunity_id) references public.opportunities(organisation_id, id) on delete cascade,
  constraint opportunity_negotiation_links_negotiation_fk foreign key (organisation_id, negotiation_id) references public.negotiations(organisation_id, id),
  unique (opportunity_id, negotiation_id)
);
create index opportunity_negotiation_links_org_opp_idx on public.opportunity_negotiation_links (organisation_id, opportunity_id);
create index opportunity_negotiation_links_negotiation_idx on public.opportunity_negotiation_links (organisation_id, negotiation_id);
create index opportunity_negotiation_links_created_by_idx on public.opportunity_negotiation_links (created_by);

alter table public.opportunity_document_links enable row level security;
alter table public.opportunity_freight_links enable row level security;
alter table public.opportunity_finance_links enable row level security;
alter table public.opportunity_negotiation_links enable row level security;

do $$
declare t text;
begin
  foreach t in array array['opportunity_document_links','opportunity_freight_links','opportunity_finance_links','opportunity_negotiation_links'] loop
    execute format('revoke all on public.%I from anon', t);
    execute format('revoke all on public.%I from authenticated', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('grant all on public.%I to service_role', t);
  end loop;
end $$;

create policy opportunity_document_links_select on public.opportunity_document_links
for select to authenticated using (
  exists (select 1 from public.opportunities o where o.id=opportunity_document_links.opportunity_id and o.organisation_id=opportunity_document_links.organisation_id)
  and (visibility='internal' or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);
create policy opportunity_document_links_insert on public.opportunity_document_links
for insert to authenticated with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
  and created_by=(select auth.uid()) and updated_by=(select auth.uid())
  and exists (select 1 from public.opportunities o where o.id=opportunity_document_links.opportunity_id and o.organisation_id=opportunity_document_links.organisation_id)
);
create policy opportunity_document_links_update on public.opportunity_document_links
for update to authenticated using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
  and exists (select 1 from public.opportunities o where o.id=opportunity_document_links.opportunity_id and o.organisation_id=opportunity_document_links.organisation_id)
) with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
  and updated_by=(select auth.uid())
  and exists (select 1 from public.opportunities o where o.id=opportunity_document_links.opportunity_id and o.organisation_id=opportunity_document_links.organisation_id)
);
create policy opportunity_document_links_delete on public.opportunity_document_links
for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance']));

create policy opportunity_freight_links_select on public.opportunity_freight_links
for select to authenticated using (exists (select 1 from public.opportunities o where o.id=opportunity_freight_links.opportunity_id and o.organisation_id=opportunity_freight_links.organisation_id));
create policy opportunity_freight_links_insert on public.opportunity_freight_links
for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader']) and created_by=(select auth.uid()) and exists (select 1 from public.opportunities o where o.id=opportunity_freight_links.opportunity_id and o.organisation_id=opportunity_freight_links.organisation_id));
create policy opportunity_freight_links_delete on public.opportunity_freight_links
for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

create policy opportunity_finance_links_select on public.opportunity_finance_links
for select to authenticated using (exists (select 1 from public.opportunities o where o.id=opportunity_finance_links.opportunity_id and o.organisation_id=opportunity_finance_links.organisation_id));
create policy opportunity_finance_links_insert on public.opportunity_finance_links
for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader']) and created_by=(select auth.uid()) and exists (select 1 from public.opportunities o where o.id=opportunity_finance_links.opportunity_id and o.organisation_id=opportunity_finance_links.organisation_id));
create policy opportunity_finance_links_delete on public.opportunity_finance_links
for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

create policy opportunity_negotiation_links_select on public.opportunity_negotiation_links
for select to authenticated using (exists (select 1 from public.opportunities o where o.id=opportunity_negotiation_links.opportunity_id and o.organisation_id=opportunity_negotiation_links.organisation_id));
create policy opportunity_negotiation_links_insert on public.opportunity_negotiation_links
for insert to authenticated with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader']) and created_by=(select auth.uid()) and exists (select 1 from public.opportunities o where o.id=opportunity_negotiation_links.opportunity_id and o.organisation_id=opportunity_negotiation_links.organisation_id));
create policy opportunity_negotiation_links_delete on public.opportunity_negotiation_links
for delete to authenticated using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));
