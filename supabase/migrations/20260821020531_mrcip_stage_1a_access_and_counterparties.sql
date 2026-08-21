create extension if not exists pg_trgm;

create table public.mrcip_user_roles (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  membership_id uuid not null references public.organisation_memberships(id) on delete cascade,
  role_key text not null check (role_key in ('super_admin','managing_director','commodity_manager','business_development','trader','logistics_manager','finance','legal_compliance','research_analyst','read_only')),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique (organisation_id, membership_id, role_key)
);

create index mrcip_user_roles_org_membership_idx on public.mrcip_user_roles (organisation_id, membership_id);

create or replace function private.has_mrcip_role(target_organisation uuid, allowed_roles text[] default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organisation_memberships membership
    where membership.organisation_id = target_organisation
      and membership.user_id = (select auth.uid())
      and membership.status = 'active'
      and (
        membership.role = 'owner'
        or allowed_roles is null
        or exists (
          select 1 from public.mrcip_user_roles mr
          where mr.organisation_id = target_organisation
            and mr.membership_id = membership.id
            and mr.role_key = any(allowed_roles)
        )
      )
  );
$$;

revoke all on function private.has_mrcip_role(uuid, text[]) from public, anon;
grant execute on function private.has_mrcip_role(uuid, text[]) to authenticated;

create table public.counterparties (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  legal_name text not null,
  trading_name text not null default '',
  company_type text not null default 'company',
  registration_number text not null default '',
  vat_number text not null default '',
  tax_number text not null default '',
  country_of_incorporation text not null default '',
  headquarters text not null default '',
  website text not null default '',
  website_domain text not null default '',
  linkedin_url text not null default '',
  main_telephone text not null default '',
  general_email text not null default '',
  physical_address text not null default '',
  postal_address text not null default '',
  parent_counterparty_id uuid references public.counterparties(id) on delete set null,
  formal_client_id uuid references public.clients(id) on delete set null,
  company_status text not null default 'active',
  verification_status text not null default 'unverified',
  confidence_score numeric(5,2) not null default 0 check (confidence_score between 0 and 100),
  last_verified_at timestamptz,
  relationship_owner uuid references auth.users(id) on delete set null,
  notes text not null default '',
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index counterparties_org_status_idx on public.counterparties (organisation_id, company_status, verification_status);
create index counterparties_registration_idx on public.counterparties (organisation_id, registration_number) where registration_number <> '';
create index counterparties_domain_idx on public.counterparties (organisation_id, website_domain) where website_domain <> '';
create index counterparties_legal_name_trgm_idx on public.counterparties using gin (legal_name gin_trgm_ops);
create index counterparties_trading_name_trgm_idx on public.counterparties using gin (trading_name gin_trgm_ops);

create table public.counterparty_roles (
  role_key text primary key,
  label text not null,
  description text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.counterparty_roles (role_key, label) values
('buyer','Buyer'),('seller','Seller'),('producer','Producer'),('mine','Mine'),('product_owner','Product Owner'),('exporter','Exporter'),('importer','Importer'),('trader','Trader'),('offtaker','Offtaker'),('broker','Broker'),('facilitator','Facilitator'),('laboratory','Laboratory'),('inspection_company','Inspection Company'),('logistics_provider','Logistics Provider'),('terminal_operator','Terminal Operator'),('stockyard','Stockyard'),('refinery','Refinery'),('smelter','Smelter'),('steel_mill','Steel Mill'),('power_utility','Power Utility'),('industrial_consumer','Industrial Consumer'),('government_state_buyer','Government / State Buyer'),('financial_institution','Financial Institution'),('insurance_provider','Insurance Provider'),('investor','Investor'),('mining_contractor','Mining Contractor'),('equipment_supplier','Equipment Supplier'),('other','Other');

create table public.counterparty_role_assignments (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  counterparty_id uuid not null references public.counterparties(id) on delete cascade,
  role_key text not null references public.counterparty_roles(role_key),
  role_context text not null default '',
  active boolean not null default true,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique (counterparty_id, role_key, role_context)
);

create index counterparty_role_assignments_org_role_idx on public.counterparty_role_assignments (organisation_id, role_key, active);

create table public.counterparty_contacts (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  counterparty_id uuid not null references public.counterparties(id) on delete cascade,
  full_name text not null,
  job_title text not null default '',
  department text not null default 'Other',
  role text not null default '',
  email text not null default '',
  direct_telephone text not null default '',
  mobile text not null default '',
  whatsapp text not null default '',
  office_telephone text not null default '',
  linkedin_url text not null default '',
  preferred_contact_method text not null default '',
  country text not null default '',
  office_location text not null default '',
  decision_maker_level text not null default '',
  relationship_owner uuid references auth.users(id) on delete set null,
  source_summary text not null default '',
  last_verified_at timestamptz,
  verification_status text not null default 'unverified',
  is_protected boolean not null default false,
  notes text not null default '',
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index counterparty_contacts_org_counterparty_idx on public.counterparty_contacts (organisation_id, counterparty_id);
create index counterparty_contacts_email_idx on public.counterparty_contacts (organisation_id, lower(email)) where email <> '';
create index counterparty_contacts_name_trgm_idx on public.counterparty_contacts using gin (full_name gin_trgm_ops);

insert into public.mrcip_user_roles (organisation_id, membership_id, role_key, created_by)
select organisation_id, id, 'super_admin', user_id from public.organisation_memberships where role = 'owner' and status = 'active';

insert into public.mrcip_user_roles (organisation_id, membership_id, role_key, created_by)
select organisation_id, id, 'managing_director', user_id from public.organisation_memberships where role = 'owner' and status = 'active';
