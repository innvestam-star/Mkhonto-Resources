-- Prevent duplicate memberships for the same user and organisation.
create unique index if not exists organisation_memberships_org_user_uidx
  on public.organisation_memberships (organisation_id, user_id);

-- Return the signed-in user's active memberships and the safest default app route.
create or replace function public.get_my_access()
returns table (
  user_id uuid,
  organisation_id uuid,
  organisation_name text,
  organisation_status text,
  membership_role text,
  membership_status text,
  default_route text,
  can_manage_organisation boolean,
  can_access_finance boolean,
  can_access_freight boolean,
  can_access_driver_portal boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    membership.user_id,
    membership.organisation_id,
    organisation.name,
    organisation.status,
    membership.role,
    membership.status,
    case membership.role
      when 'owner' then '/admin'
      when 'finance' then '/admin/finance'
      when 'accountant' then '/admin/finance'
      when 'dispatcher' then '/admin/freight'
      when 'driver' then '/driver'
      else '/portal'
    end as default_route,
    membership.role = 'owner' as can_manage_organisation,
    membership.role = any (array['owner', 'finance', 'accountant']) as can_access_finance,
    membership.role = any (array['owner', 'finance', 'dispatcher']) as can_access_freight,
    membership.role = 'driver' as can_access_driver_portal
  from public.organisation_memberships membership
  join public.organisations organisation
    on organisation.id = membership.organisation_id
  where membership.user_id = (select auth.uid())
    and membership.status = 'active'
    and organisation.status in ('active', 'trial')
  order by
    case membership.role
      when 'owner' then 1
      when 'finance' then 2
      when 'dispatcher' then 3
      when 'accountant' then 4
      when 'driver' then 5
      else 6
    end,
    membership.created_at;
$$;

revoke all on function public.get_my_access() from public;
grant execute on function public.get_my_access() to authenticated;

-- Server-side helper for route guards. Authentication proves identity;
-- this function resolves organisation and role authorisation.
create or replace function public.can_access_portal(
  p_portal text,
  p_organisation_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organisation_memberships membership
    join public.organisations organisation
      on organisation.id = membership.organisation_id
    where membership.user_id = (select auth.uid())
      and membership.status = 'active'
      and organisation.status in ('active', 'trial')
      and (p_organisation_id is null or membership.organisation_id = p_organisation_id)
      and case lower(trim(p_portal))
        when 'admin' then membership.role = 'owner'
        when 'owner' then membership.role = 'owner'
        when 'finance' then membership.role = any (array['owner', 'finance', 'accountant'])
        when 'freight' then membership.role = any (array['owner', 'finance', 'dispatcher'])
        when 'driver' then membership.role = 'driver'
        when 'portal' then true
        when 'dashboard' then true
        else false
      end
  );
$$;

revoke all on function public.can_access_portal(text, uuid) from public;
grant execute on function public.can_access_portal(text, uuid) to authenticated;

-- Safe self-service tenant onboarding. A user with no active membership can
-- create one organisation and becomes its owner. Existing active members are
-- returned to their current organisation instead of creating duplicates.
create or replace function public.complete_organisation_onboarding(
  p_name text,
  p_trading_name text default '',
  p_industry text default 'Logistics and transport'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_existing_organisation_id uuid;
  v_organisation_id uuid;
  v_email text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if nullif(trim(p_name), '') is null or char_length(trim(p_name)) > 160 then
    raise exception 'Organisation name must contain between 1 and 160 characters'
      using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_user_id::text));

  select membership.organisation_id
    into v_existing_organisation_id
  from public.organisation_memberships membership
  where membership.user_id = v_user_id
    and membership.status = 'active'
  order by membership.created_at
  limit 1;

  if v_existing_organisation_id is not null then
    return v_existing_organisation_id;
  end if;

  select coalesce(users.email, '')
    into v_email
  from auth.users users
  where users.id = v_user_id;

  insert into public.organisations (
    name,
    trading_name,
    industry,
    email,
    plan,
    status,
    created_by
  ) values (
    trim(p_name),
    coalesce(trim(p_trading_name), ''),
    coalesce(nullif(trim(p_industry), ''), 'Logistics and transport'),
    coalesce(v_email, ''),
    'pilot',
    'active',
    v_user_id
  )
  returning id into v_organisation_id;

  insert into public.organisation_memberships (
    organisation_id,
    user_id,
    email,
    display_name,
    role,
    status
  )
  select
    v_organisation_id,
    v_user_id,
    coalesce(users.email, ''),
    coalesce(users.raw_user_meta_data ->> 'full_name', ''),
    'owner',
    'active'
  from auth.users users
  where users.id = v_user_id;

  return v_organisation_id;
end;
$$;

revoke all on function public.complete_organisation_onboarding(text, text, text) from public;
grant execute on function public.complete_organisation_onboarding(text, text, text) to authenticated;

comment on function public.get_my_access() is
  'Returns active organisation memberships, capabilities, and default route for the authenticated user.';
comment on function public.can_access_portal(text, uuid) is
  'Role-aware server-side authorisation helper for admin, owner, finance, freight, driver, and general portal routes.';
comment on function public.complete_organisation_onboarding(text, text, text) is
  'Creates an organisation and owner membership for an authenticated user who has no active membership.';

-- Bootstrap the existing first account as the owner of Mkhonto Resources so
-- the current admin login is no longer authenticated-but-unassigned.
do $$
declare
  v_user_id uuid;
  v_user_email text;
  v_user_name text;
  v_organisation_id uuid;
begin
  select users.id,
         coalesce(users.email, ''),
         coalesce(users.raw_user_meta_data ->> 'full_name', '')
    into v_user_id, v_user_email, v_user_name
  from auth.users users
  order by users.created_at
  limit 1;

  if v_user_id is not null
     and not exists (
       select 1
       from public.organisation_memberships membership
       where membership.user_id = v_user_id
         and membership.status = 'active'
     ) then
    insert into public.organisations (
      name,
      trading_name,
      industry,
      email,
      plan,
      status,
      created_by
    ) values (
      'Mkhonto Resources',
      'Mkhonto Resources',
      'Mining, commodities and logistics',
      v_user_email,
      'pilot',
      'active',
      v_user_id
    )
    returning id into v_organisation_id;

    insert into public.organisation_memberships (
      organisation_id,
      user_id,
      email,
      display_name,
      role,
      status
    ) values (
      v_organisation_id,
      v_user_id,
      v_user_email,
      v_user_name,
      'owner',
      'active'
    );
  end if;
end;
$$;
