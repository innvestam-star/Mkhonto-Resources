create or replace function public.create_opportunity_from_match(p_match_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  m public.commodity_matches%rowtype;
  req public.buyer_requirements%rowtype;
  offer public.seller_supply_offers%rowtype;
  v_id uuid := gen_random_uuid();
  v_number text;
  v_title text;
begin
  select * into m from public.commodity_matches where id=p_match_id;
  if not found then raise exception 'Match not found or not accessible'; end if;
  if not private.has_mrcip_role(m.organisation_id, array['super_admin','managing_director','commodity_manager','trader']) then
    raise exception 'Insufficient MRCIP role to create opportunity' using errcode='42501';
  end if;
  if not m.hard_filter_pass then raise exception 'Disqualified match cannot create an opportunity'; end if;
  if m.status not in ('shortlisted','accepted') then raise exception 'Match must be shortlisted or accepted before opportunity creation'; end if;

  select * into req from public.buyer_requirements where id=m.buyer_requirement_id and organisation_id=m.organisation_id;
  select * into offer from public.seller_supply_offers where id=m.seller_offer_id and organisation_id=m.organisation_id;
  if req.id is null or offer.id is null then raise exception 'Underlying requirement or offer is not accessible'; end if;

  select id into v_id from public.opportunities where match_id=m.id;
  if found then return v_id; end if;

  v_id := gen_random_uuid();
  v_number := 'MR-OPP-' || to_char(current_date,'YYYY') || '-' || upper(substr(replace(v_id::text,'-',''),1,8));
  v_title := coalesce(nullif(req.reference,''), 'Buyer requirement') || ' ↔ ' || coalesce(nullif(offer.reference,''), 'Seller offer');

  insert into public.opportunities (
    id, organisation_id, opportunity_number, title, match_id, buyer_requirement_id, seller_offer_id,
    buyer_counterparty_id, seller_counterparty_id, commodity_id, product_id,
    stage, is_protected, disclosure_locked, created_by, updated_by
  ) values (
    v_id, m.organisation_id, v_number, v_title, m.id, req.id, offer.id,
    req.buyer_counterparty_id, offer.seller_counterparty_id, req.commodity_id, coalesce(req.product_id, offer.product_id),
    'protection', true, true, (select auth.uid()), (select auth.uid())
  );

  insert into public.opportunity_protocol_controls (opportunity_id, organisation_id, protocol_step, updated_by)
  values (v_id, m.organisation_id, 'protect', (select auth.uid()));

  insert into public.opportunity_protection_records (
    organisation_id, opportunity_id, record_type, status, required_for_disclosure, created_by, updated_by
  ) values
    (m.organisation_id, v_id, 'ncnda', 'draft', true, (select auth.uid()), (select auth.uid())),
    (m.organisation_id, v_id, 'transaction_registration', 'draft', true, (select auth.uid()), (select auth.uid())),
    (m.organisation_id, v_id, 'fee_protection', 'draft', false, (select auth.uid()), (select auth.uid()));

  insert into public.opportunity_kyc_cases (
    organisation_id, opportunity_id, counterparty_id, party_role, status, required_for_disclosure, created_by, updated_by
  ) values
    (m.organisation_id, v_id, req.buyer_counterparty_id, 'buyer', 'draft', true, (select auth.uid()), (select auth.uid())),
    (m.organisation_id, v_id, offer.seller_counterparty_id, 'seller', 'draft', false, (select auth.uid()), (select auth.uid()));

  return v_id;
end;
$function$;

revoke all on function public.create_opportunity_from_match(uuid) from public;
revoke all on function public.create_opportunity_from_match(uuid) from anon;
grant execute on function public.create_opportunity_from_match(uuid) to authenticated, service_role;

create or replace function public.refresh_opportunity_protocol(p_opportunity_id uuid)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  o public.opportunities%rowtype;
  req public.buyer_requirements%rowtype;
  offer public.seller_supply_offers%rowtype;
  v_ncnda_ok boolean := false;
  v_registration_ok boolean := false;
  v_required_protection_ok boolean := false;
  v_buyer_kyc_ok boolean := false;
  v_required_kyc_ok boolean := false;
  v_buyer_authority_ok boolean := false;
  v_seller_authority_ok boolean := false;
  v_required_mandates_ok boolean := false;
  v_protection_ok boolean := false;
  v_verification_ok boolean := false;
  v_eligible boolean := false;
  v_blockers jsonb := '[]'::jsonb;
  v_disclosed_count integer := 0;
  v_open_disclosures integer := 0;
  v_disclosure_status text := 'locked';
  v_step text := 'protect';
begin
  select * into o from public.opportunities where id=p_opportunity_id;
  if not found then raise exception 'Opportunity not found or not accessible'; end if;
  if not private.has_mrcip_role(o.organisation_id, array['super_admin','managing_director','commodity_manager','trader','legal_compliance']) then
    raise exception 'Insufficient MRCIP role to evaluate protocol' using errcode='42501';
  end if;

  select * into req from public.buyer_requirements where id=o.buyer_requirement_id and organisation_id=o.organisation_id;
  select * into offer from public.seller_supply_offers where id=o.seller_offer_id and organisation_id=o.organisation_id;

  select exists(
    select 1 from public.opportunity_protection_records p
    where p.opportunity_id=o.id and p.organisation_id=o.organisation_id and p.record_type='ncnda'
      and p.status in ('executed','verified','waived') and (p.expiry_date is null or p.expiry_date >= current_date)
  ) into v_ncnda_ok;

  select exists(
    select 1 from public.opportunity_protection_records p
    where p.opportunity_id=o.id and p.organisation_id=o.organisation_id and p.record_type='transaction_registration'
      and p.status in ('executed','verified','waived') and (p.expiry_date is null or p.expiry_date >= current_date)
  ) into v_registration_ok;

  select not exists(
    select 1 from public.opportunity_protection_records p
    where p.opportunity_id=o.id and p.organisation_id=o.organisation_id and p.required_for_disclosure
      and not (p.status in ('executed','verified','waived') and (p.expiry_date is null or p.expiry_date >= current_date))
  ) into v_required_protection_ok;

  select exists(
    select 1 from public.opportunity_kyc_cases k
    where k.opportunity_id=o.id and k.organisation_id=o.organisation_id and k.party_role='buyer'
      and k.counterparty_id=o.buyer_counterparty_id and k.status='verified'
      and k.risk_rating <> 'prohibited' and (k.valid_until is null or k.valid_until >= current_date)
  ) into v_buyer_kyc_ok;

  select not exists(
    select 1 from public.opportunity_kyc_cases k
    where k.opportunity_id=o.id and k.organisation_id=o.organisation_id and k.required_for_disclosure
      and not (k.status='verified' and k.risk_rating <> 'prohibited' and (k.valid_until is null or k.valid_until >= current_date))
  ) into v_required_kyc_ok;

  select (
    req.authority_status='verified'
    or exists(
      select 1 from public.opportunity_mandates md
      where md.opportunity_id=o.id and md.organisation_id=o.organisation_id and md.counterparty_id=o.buyer_counterparty_id
        and md.mandate_type='buyer' and md.status in ('verified','not_required')
        and (md.expiry_date is null or md.expiry_date >= current_date)
    )
  ) into v_buyer_authority_ok;

  select (
    offer.authority_status='verified'
    or exists(
      select 1 from public.opportunity_mandates md
      where md.opportunity_id=o.id and md.organisation_id=o.organisation_id and md.counterparty_id=o.seller_counterparty_id
        and md.mandate_type='seller' and md.status in ('verified','not_required')
        and (md.expiry_date is null or md.expiry_date >= current_date)
    )
  ) into v_seller_authority_ok;

  select not exists(
    select 1 from public.opportunity_mandates md
    where md.opportunity_id=o.id and md.organisation_id=o.organisation_id and md.required_for_disclosure
      and not (md.status in ('verified','not_required') and (md.expiry_date is null or md.expiry_date >= current_date))
  ) into v_required_mandates_ok;

  v_protection_ok := v_ncnda_ok and v_registration_ok and v_required_protection_ok;
  v_verification_ok := v_buyer_kyc_ok and v_required_kyc_ok and v_buyer_authority_ok and v_seller_authority_ok and v_required_mandates_ok;
  v_eligible := v_protection_ok and v_verification_ok;

  if not v_ncnda_ok then v_blockers := v_blockers || jsonb_build_array('NCNDA not executed/verified or expired'); end if;
  if not v_registration_ok then v_blockers := v_blockers || jsonb_build_array('Transaction registration not completed'); end if;
  if not v_required_protection_ok then v_blockers := v_blockers || jsonb_build_array('Required protection record incomplete'); end if;
  if not v_buyer_kyc_ok then v_blockers := v_blockers || jsonb_build_array('Buyer KYC/KYB not verified'); end if;
  if not v_required_kyc_ok then v_blockers := v_blockers || jsonb_build_array('Required KYC/KYB case incomplete'); end if;
  if not v_buyer_authority_ok then v_blockers := v_blockers || jsonb_build_array('Buyer authority/mandate not verified'); end if;
  if not v_seller_authority_ok then v_blockers := v_blockers || jsonb_build_array('Seller authority/mandate not verified'); end if;
  if not v_required_mandates_ok then v_blockers := v_blockers || jsonb_build_array('Required mandate incomplete'); end if;

  select count(*) filter (where status='disclosed'), count(*) filter (where status in ('requested','approved'))
    into v_disclosed_count, v_open_disclosures
  from public.opportunity_disclosures d
  where d.opportunity_id=o.id and d.organisation_id=o.organisation_id;

  v_step := case when not v_protection_ok then 'protect' when not v_verification_ok then 'verify' when v_disclosed_count=0 then 'disclose' else 'contract' end;
  v_disclosure_status := case
    when not v_eligible then 'locked'
    when v_disclosed_count > 0 and v_open_disclosures = 0 then 'disclosed'
    when v_disclosed_count > 0 then 'partially_disclosed'
    else 'eligible'
  end;

  insert into public.opportunity_protocol_controls (
    opportunity_id, organisation_id, protocol_step, protection_status, verification_status,
    disclosure_status, disclosure_eligible, blocking_reasons, last_evaluated_at, last_evaluated_by, updated_by
  ) values (
    o.id, o.organisation_id, v_step,
    case when v_protection_ok then 'protected' else 'pending' end,
    case when v_verification_ok then 'verified' else 'pending' end,
    v_disclosure_status, v_eligible, v_blockers, now(), (select auth.uid()), (select auth.uid())
  ) on conflict (opportunity_id) do update set
    protocol_step=excluded.protocol_step,
    protection_status=excluded.protection_status,
    verification_status=excluded.verification_status,
    disclosure_status=case when public.opportunity_protocol_controls.disclosure_status='revoked' and not excluded.disclosure_eligible then 'revoked' else excluded.disclosure_status end,
    disclosure_eligible=excluded.disclosure_eligible,
    blocking_reasons=excluded.blocking_reasons,
    last_evaluated_at=excluded.last_evaluated_at,
    last_evaluated_by=excluded.last_evaluated_by,
    updated_by=excluded.updated_by;

  update public.opportunities
  set disclosure_locked=not v_eligible,
      stage=case
        when stage in ('registered','protection','verification','disclosure_ready','disclosed') then
          case when not v_protection_ok then 'protection' when not v_verification_ok then 'verification' when v_disclosed_count=0 then 'disclosure_ready' else 'disclosed' end
        else stage
      end,
      updated_by=(select auth.uid())
  where id=o.id;

  return v_eligible;
end;
$function$;

revoke all on function public.refresh_opportunity_protocol(uuid) from public;
revoke all on function public.refresh_opportunity_protocol(uuid) from anon;
grant execute on function public.refresh_opportunity_protocol(uuid) to authenticated, service_role;

create or replace function private.enforce_opportunity_disclosure_gate()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  ctl public.opportunity_protocol_controls%rowtype;
begin
  if tg_op='INSERT' and new.status <> 'requested' then
    raise exception 'New disclosure records must start as requested';
  end if;

  if tg_op='UPDATE' and new.status in ('approved','disclosed') and new.status is distinct from old.status then
    select * into ctl from public.opportunity_protocol_controls
    where opportunity_id=new.opportunity_id and organisation_id=new.organisation_id;

    if ctl.opportunity_id is null or not ctl.disclosure_eligible or ctl.disclosure_status in ('locked','revoked') then
      raise exception 'Disclosure gate is locked; complete PROTECT and VERIFY prerequisites first' using errcode='42501';
    end if;

    new.prerequisites_snapshot := jsonb_build_object(
      'evaluated_at', ctl.last_evaluated_at,
      'protocol_step', ctl.protocol_step,
      'protection_status', ctl.protection_status,
      'verification_status', ctl.verification_status,
      'disclosure_eligible', ctl.disclosure_eligible,
      'blocking_reasons', ctl.blocking_reasons
    );

    if new.status='approved' then
      if old.status not in ('requested','approved') then raise exception 'Disclosure can only be approved from requested state'; end if;
      new.approved_at := coalesce(new.approved_at, now());
      new.approved_by := coalesce(new.approved_by, (select auth.uid()));
    elsif new.status='disclosed' then
      if old.status <> 'approved' then raise exception 'Disclosure must be approved before it can be recorded as disclosed'; end if;
      new.disclosed_at := coalesce(new.disclosed_at, now());
      new.disclosed_by := coalesce(new.disclosed_by, (select auth.uid()));
    end if;
  end if;

  return new;
end;
$function$;

revoke all on function private.enforce_opportunity_disclosure_gate() from public;
revoke all on function private.enforce_opportunity_disclosure_gate() from anon;
revoke all on function private.enforce_opportunity_disclosure_gate() from authenticated;

drop trigger if exists opportunity_disclosures_gate on public.opportunity_disclosures;
create trigger opportunity_disclosures_gate
before insert or update on public.opportunity_disclosures
for each row execute function private.enforce_opportunity_disclosure_gate();
