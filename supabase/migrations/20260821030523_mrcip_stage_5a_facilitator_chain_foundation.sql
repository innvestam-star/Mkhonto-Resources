create table public.facilitator_chains (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  opportunity_id uuid not null,
  revision_no integer not null default 1 check (revision_no > 0),
  previous_chain_id uuid null,
  status text not null default 'draft' check (status in ('draft','pending_approval','approved','superseded','rejected')),
  amendment_reason text not null default '',
  approved_at timestamptz null,
  approved_by uuid null references auth.users(id),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id, id),
  unique (organisation_id, opportunity_id, revision_no),
  constraint facilitator_chains_opportunity_fk foreign key (organisation_id, opportunity_id)
    references public.opportunities(organisation_id, id) on delete cascade,
  constraint facilitator_chains_previous_fk foreign key (organisation_id, previous_chain_id)
    references public.facilitator_chains(organisation_id, id) on delete restrict
);

create unique index facilitator_chains_one_approved_idx
  on public.facilitator_chains(organisation_id, opportunity_id)
  where status='approved';
create index facilitator_chains_org_opportunity_idx
  on public.facilitator_chains(organisation_id, opportunity_id, status, revision_no desc);
create index facilitator_chains_previous_idx
  on public.facilitator_chains(organisation_id, previous_chain_id)
  where previous_chain_id is not null;
create index facilitator_chains_approved_by_idx on public.facilitator_chains(approved_by) where approved_by is not null;
create index facilitator_chains_created_by_idx on public.facilitator_chains(created_by);
create index facilitator_chains_updated_by_idx on public.facilitator_chains(updated_by);

create table public.facilitator_chain_members (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  chain_id uuid not null,
  participant_counterparty_id uuid null,
  participant_contact_id uuid null,
  display_name text not null default '',
  company_name text not null default '',
  role text not null default 'facilitator' check (role in ('lead_facilitator','facilitator','broker','introducer','buyer_mandate','seller_mandate','agent','consultant','other')),
  represents text not null default 'other' check (represents in ('buyer','seller','mkhonto','self','other')),
  represents_counterparty_id uuid null,
  introduced_by_member_id uuid null,
  authority_status text not null default 'unverified' check (authority_status in ('unverified','pending','verified','not_required','expired')),
  protected_status text not null default 'pending' check (protected_status in ('unprotected','pending','protected','waived')),
  commission_entitled boolean not null default false,
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id, id),
  constraint facilitator_chain_members_chain_fk foreign key (organisation_id, chain_id)
    references public.facilitator_chains(organisation_id, id) on delete cascade,
  constraint facilitator_chain_members_party_fk foreign key (organisation_id, participant_counterparty_id)
    references public.counterparties(organisation_id, id) on delete restrict,
  constraint facilitator_chain_members_contact_fk foreign key (organisation_id, participant_contact_id)
    references public.counterparty_contacts(organisation_id, id) on delete restrict,
  constraint facilitator_chain_members_represents_fk foreign key (organisation_id, represents_counterparty_id)
    references public.counterparties(organisation_id, id) on delete restrict,
  constraint facilitator_chain_members_introduced_by_fk foreign key (organisation_id, introduced_by_member_id)
    references public.facilitator_chain_members(organisation_id, id) on delete restrict,
  constraint facilitator_chain_members_identity_check check (
    participant_counterparty_id is not null or nullif(btrim(display_name),'') is not null
  )
);

create index facilitator_chain_members_org_chain_idx on public.facilitator_chain_members(organisation_id, chain_id);
create index facilitator_chain_members_party_idx on public.facilitator_chain_members(organisation_id, participant_counterparty_id) where participant_counterparty_id is not null;
create index facilitator_chain_members_contact_idx on public.facilitator_chain_members(organisation_id, participant_contact_id) where participant_contact_id is not null;
create index facilitator_chain_members_represents_idx on public.facilitator_chain_members(organisation_id, represents_counterparty_id) where represents_counterparty_id is not null;
create index facilitator_chain_members_introduced_by_idx on public.facilitator_chain_members(organisation_id, introduced_by_member_id) where introduced_by_member_id is not null;
create index facilitator_chain_members_created_by_idx on public.facilitator_chain_members(created_by);
create index facilitator_chain_members_updated_by_idx on public.facilitator_chain_members(updated_by);

create or replace function private.validate_facilitator_chain_member()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  parent_chain public.facilitator_chains%rowtype;
  introducer_chain uuid;
begin
  select * into parent_chain from public.facilitator_chains
   where id=new.chain_id and organisation_id=new.organisation_id;
  if not found then raise exception 'Facilitator chain not found'; end if;
  if parent_chain.status in ('approved','superseded') then
    raise exception 'Approved/superseded facilitator chains are immutable; create a revision';
  end if;
  if new.introduced_by_member_id is not null then
    select chain_id into introducer_chain from public.facilitator_chain_members
      where id=new.introduced_by_member_id and organisation_id=new.organisation_id;
    if introducer_chain is distinct from new.chain_id then
      raise exception 'Introducer must belong to the same facilitator chain';
    end if;
  end if;
  if new.participant_contact_id is not null and new.participant_counterparty_id is not null then
    if not exists (
      select 1 from public.counterparty_contacts c
      where c.id=new.participant_contact_id and c.organisation_id=new.organisation_id
        and c.counterparty_id=new.participant_counterparty_id
    ) then raise exception 'Participant contact must belong to the participant counterparty'; end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function private.validate_facilitator_chain_member() from public, anon, authenticated;

create trigger facilitator_chain_members_validate_biu
before insert or update on public.facilitator_chain_members
for each row execute function private.validate_facilitator_chain_member();

create or replace function private.prevent_locked_facilitator_chain_delete()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if old.status in ('approved','superseded') then
    raise exception 'Approved/superseded facilitator chains cannot be deleted';
  end if;
  return old;
end;
$$;
revoke all on function private.prevent_locked_facilitator_chain_delete() from public, anon, authenticated;

create trigger facilitator_chains_prevent_locked_delete
before delete on public.facilitator_chains
for each row execute function private.prevent_locked_facilitator_chain_delete();

alter table public.facilitator_chains enable row level security;
alter table public.facilitator_chain_members enable row level security;

create policy facilitator_chains_select on public.facilitator_chains for select to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','business_development','legal_compliance','finance']));
create policy facilitator_chains_insert on public.facilitator_chains for insert to authenticated
with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy facilitator_chains_update on public.facilitator_chains for update to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance']))
with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance']) and updated_by=(select auth.uid()));
create policy facilitator_chains_delete on public.facilitator_chains for delete to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance']));

create policy facilitator_chain_members_select on public.facilitator_chain_members for select to authenticated
using (exists(select 1 from public.facilitator_chains c where c.id=chain_id and c.organisation_id=organisation_id));
create policy facilitator_chain_members_insert on public.facilitator_chain_members for insert to authenticated
with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy facilitator_chain_members_update on public.facilitator_chain_members for update to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance']))
with check (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','legal_compliance']) and updated_by=(select auth.uid()));
create policy facilitator_chain_members_delete on public.facilitator_chain_members for delete to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','legal_compliance']));

revoke all on public.facilitator_chains, public.facilitator_chain_members from anon;
revoke all on public.facilitator_chains, public.facilitator_chain_members from authenticated;
grant select,insert,update,delete on public.facilitator_chains, public.facilitator_chain_members to authenticated;