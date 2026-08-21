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
        or exists (
          select 1
          from public.mrcip_user_roles mr
          where mr.organisation_id = target_organisation
            and mr.membership_id = membership.id
            and (allowed_roles is null or mr.role_key = any(allowed_roles))
        )
      )
  );
$$;

revoke all on function private.has_mrcip_role(uuid, text[]) from public, anon;
grant execute on function private.has_mrcip_role(uuid, text[]) to authenticated;

drop policy if exists counterparty_contacts_select on public.counterparty_contacts;
create policy counterparty_contacts_select on public.counterparty_contacts for select to authenticated
using (
  (not is_protected and private.has_mrcip_role(organisation_id, null))
  or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])
);

drop policy if exists intelligence_sources_select on public.intelligence_sources;
create policy intelligence_sources_select on public.intelligence_sources for select to authenticated
using (
  (source_type in ('public','document','import') and private.has_mrcip_role(organisation_id, null))
  or private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance','research_analyst'])
);
