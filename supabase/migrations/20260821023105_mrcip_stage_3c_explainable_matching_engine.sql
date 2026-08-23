create table public.commodity_matches (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  buyer_requirement_id uuid not null,
  seller_offer_id uuid not null,
  status text not null default 'candidate' check (status in ('candidate','disqualified','shortlisted','accepted','rejected','stale')),
  hard_filter_pass boolean not null default false,
  commodity_score numeric(6,2) not null default 0 check (commodity_score between 0 and 20),
  product_score numeric(6,2) not null default 0 check (product_score between 0 and 10),
  specification_score numeric(6,2) not null default 0 check (specification_score between 0 and 30),
  quantity_score numeric(6,2) not null default 0 check (quantity_score between 0 and 10),
  origin_score numeric(6,2) not null default 0 check (origin_score between 0 and 5),
  incoterm_score numeric(6,2) not null default 0 check (incoterm_score between 0 and 5),
  logistics_score numeric(6,2) not null default 0 check (logistics_score between 0 and 5),
  commercial_score numeric(6,2) not null default 0 check (commercial_score between 0 and 5),
  verification_score numeric(6,2) not null default 0 check (verification_score between 0 and 10),
  total_score numeric(6,2) not null default 0 check (total_score between 0 and 100),
  failed_mandatory_specs integer not null default 0 check (failed_mandatory_specs >= 0),
  explanation jsonb not null default '{}'::jsonb,
  algorithm_version text not null default '1.0',
  generated_at timestamptz not null default now(),
  generated_by uuid not null default auth.uid(),
  reviewed_at timestamptz,
  reviewed_by uuid,
  review_notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid(),
  constraint commodity_matches_requirement_fk foreign key (organisation_id, buyer_requirement_id) references public.buyer_requirements(organisation_id, id) on delete cascade,
  constraint commodity_matches_offer_fk foreign key (organisation_id, seller_offer_id) references public.seller_supply_offers(organisation_id, id) on delete cascade,
  unique (buyer_requirement_id, seller_offer_id)
);

create unique index commodity_matches_org_id_uidx on public.commodity_matches (organisation_id, id);
create index commodity_matches_org_requirement_score_idx on public.commodity_matches (organisation_id, buyer_requirement_id, hard_filter_pass, total_score desc);
create index commodity_matches_org_offer_idx on public.commodity_matches (organisation_id, seller_offer_id);
create index commodity_matches_generated_by_idx on public.commodity_matches (generated_by);
create index commodity_matches_reviewed_by_idx on public.commodity_matches (reviewed_by) where reviewed_by is not null;
create index commodity_matches_updated_by_idx on public.commodity_matches (updated_by);
create trigger commodity_matches_touch_updated_at before update on public.commodity_matches for each row execute function private.touch_updated_at();

alter table public.commodity_matches enable row level security;
grant select, insert, update, delete on public.commodity_matches to authenticated;
grant all on public.commodity_matches to service_role;
revoke all on public.commodity_matches from anon;

create policy commodity_matches_select on public.commodity_matches
for select to authenticated
using (
  private.has_mrcip_role(organisation_id, null::text[])
  and exists (
    select 1 from public.seller_supply_offers offer
    where offer.id = commodity_matches.seller_offer_id
      and offer.organisation_id = commodity_matches.organisation_id
  )
);

create policy commodity_matches_insert on public.commodity_matches
for insert to authenticated
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader'])
  and generated_by = (select auth.uid())
  and updated_by = (select auth.uid())
  and exists (
    select 1 from public.seller_supply_offers offer
    where offer.id = commodity_matches.seller_offer_id
      and offer.organisation_id = commodity_matches.organisation_id
  )
);

create policy commodity_matches_update on public.commodity_matches
for update to authenticated
using (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader'])
  and exists (
    select 1 from public.seller_supply_offers offer
    where offer.id = commodity_matches.seller_offer_id
      and offer.organisation_id = commodity_matches.organisation_id
  )
)
with check (
  private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager','trader'])
  and updated_by = (select auth.uid())
  and exists (
    select 1 from public.seller_supply_offers offer
    where offer.id = commodity_matches.seller_offer_id
      and offer.organisation_id = commodity_matches.organisation_id
  )
);

create policy commodity_matches_delete on public.commodity_matches
for delete to authenticated
using (private.has_mrcip_role(organisation_id, array['super_admin','managing_director','commodity_manager']));

create or replace function public.refresh_buyer_requirement_matches(p_requirement_id uuid)
returns integer
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  req public.buyer_requirements%rowtype;
  offer public.seller_supply_offers%rowtype;
  v_total_weight numeric := 0;
  v_matched_weight numeric := 0;
  v_failed_mandatory integer := 0;
  v_failed_specs jsonb := '[]'::jsonb;
  v_product_compatible boolean := false;
  v_spec_score numeric := 0;
  v_quantity_score numeric := 0;
  v_origin_score numeric := 0;
  v_incoterm_score numeric := 0;
  v_logistics_score numeric := 0;
  v_commercial_score numeric := 0;
  v_verification_score numeric := 0;
  v_total_score numeric := 0;
  v_verification_status text := '';
  v_confidence numeric := 0;
  v_hard_filter_pass boolean := false;
  v_evaluated integer := 0;
begin
  select * into req
  from public.buyer_requirements
  where id = p_requirement_id;

  if not found then
    raise exception 'Buyer requirement not found or not accessible';
  end if;

  if req.status <> 'active' then
    raise exception 'Buyer requirement must be active before matching';
  end if;

  if req.valid_until is not null and req.valid_until < current_date then
    raise exception 'Buyer requirement has expired';
  end if;

  if not private.has_mrcip_role(req.organisation_id, array['super_admin','managing_director','commodity_manager','trader']) then
    raise exception 'Insufficient MRCIP role to refresh matches' using errcode = '42501';
  end if;

  update public.commodity_matches
  set status = 'stale', updated_by = (select auth.uid())
  where organisation_id = req.organisation_id
    and buyer_requirement_id = req.id
    and status in ('candidate','disqualified');

  for offer in
    select *
    from public.seller_supply_offers s
    where s.organisation_id = req.organisation_id
      and s.commodity_id = req.commodity_id
      and s.status = 'active'
      and (s.valid_until is null or s.valid_until >= current_date)
      and (s.available_from is null or s.available_from <= coalesce(req.delivery_end_date, current_date + interval '365 days'))
  loop
    v_product_compatible := (req.product_id is null or offer.product_id is null or req.product_id = offer.product_id);

    select
      coalesce(sum(b.weight), 0),
      coalesce(sum(case when
        s.id is not null
        and (
          (b.minimum_numeric is null and b.maximum_numeric is null and b.target_numeric is null)
          or (
            s.numeric_value is not null
            and (b.unit = '' or s.unit = '' or lower(b.unit) = lower(s.unit))
            and (b.basis = '' or s.basis = '' or lower(b.basis) = lower(s.basis))
            and (b.minimum_numeric is null or s.numeric_value >= b.minimum_numeric)
            and (b.maximum_numeric is null or s.numeric_value <= b.maximum_numeric)
          )
        )
        and (b.expected_text is null or btrim(b.expected_text) = '' or lower(coalesce(s.text_value,'')) = lower(btrim(b.expected_text)))
      then b.weight else 0 end), 0),
      coalesce(sum(case when b.mandatory and not (
        s.id is not null
        and (
          (b.minimum_numeric is null and b.maximum_numeric is null and b.target_numeric is null)
          or (
            s.numeric_value is not null
            and (b.unit = '' or s.unit = '' or lower(b.unit) = lower(s.unit))
            and (b.basis = '' or s.basis = '' or lower(b.basis) = lower(s.basis))
            and (b.minimum_numeric is null or s.numeric_value >= b.minimum_numeric)
            and (b.maximum_numeric is null or s.numeric_value <= b.maximum_numeric)
          )
        )
        and (b.expected_text is null or btrim(b.expected_text) = '' or lower(coalesce(s.text_value,'')) = lower(btrim(b.expected_text)))
      ) then 1 else 0 end), 0)::integer,
      coalesce(jsonb_agg(
        jsonb_build_object(
          'field', f.label,
          'field_key', f.field_key,
          'mandatory', b.mandatory,
          'required_min', b.minimum_numeric,
          'required_max', b.maximum_numeric,
          'required_target', b.target_numeric,
          'required_text', b.expected_text,
          'required_unit', b.unit,
          'required_basis', b.basis,
          'offered_numeric', s.numeric_value,
          'offered_text', s.text_value,
          'offered_unit', s.unit,
          'offered_basis', s.basis
        )
      ) filter (where b.mandatory and not (
        s.id is not null
        and (
          (b.minimum_numeric is null and b.maximum_numeric is null and b.target_numeric is null)
          or (
            s.numeric_value is not null
            and (b.unit = '' or s.unit = '' or lower(b.unit) = lower(s.unit))
            and (b.basis = '' or s.basis = '' or lower(b.basis) = lower(s.basis))
            and (b.minimum_numeric is null or s.numeric_value >= b.minimum_numeric)
            and (b.maximum_numeric is null or s.numeric_value <= b.maximum_numeric)
          )
        )
        and (b.expected_text is null or btrim(b.expected_text) = '' or lower(coalesce(s.text_value,'')) = lower(btrim(b.expected_text)))
      )), '[]'::jsonb)
    into v_total_weight, v_matched_weight, v_failed_mandatory, v_failed_specs
    from public.buyer_requirement_specs b
    join public.commodity_spec_fields f on f.id = b.spec_field_id and f.organisation_id = b.organisation_id
    left join public.seller_offer_specs s
      on s.offer_id = offer.id
     and s.spec_field_id = b.spec_field_id
     and s.organisation_id = b.organisation_id
    where b.requirement_id = req.id
      and b.organisation_id = req.organisation_id;

    v_spec_score := case when v_total_weight > 0 then round(30 * v_matched_weight / v_total_weight, 2) else 15 end;

    if coalesce(req.quantity_monthly_mt,0) > 0 then
      v_quantity_score := case
        when offer.quantity_monthly_mt is null then 5
        when offer.quantity_monthly_mt >= req.quantity_monthly_mt then 10
        else round(greatest(0, 10 * offer.quantity_monthly_mt / req.quantity_monthly_mt), 2)
      end;
    elsif coalesce(req.quantity_total_mt,0) > 0 then
      v_quantity_score := case
        when offer.quantity_available_mt is null then 5
        when offer.quantity_available_mt >= req.quantity_total_mt then 10
        else round(greatest(0, 10 * offer.quantity_available_mt / req.quantity_total_mt), 2)
      end;
    else
      v_quantity_score := 7;
    end if;

    if cardinality(req.preferred_origin_countries) = 0 then
      v_origin_score := 3;
    elsif exists (select 1 from unnest(req.preferred_origin_countries) c where lower(c) = lower(offer.origin_country)) then
      v_origin_score := 5;
    else
      v_origin_score := 0;
    end if;

    v_incoterm_score := case
      when btrim(req.incoterm) = '' then 3
      when btrim(offer.incoterm) = '' then 1
      when lower(req.incoterm) = lower(offer.incoterm) then 5
      else 0
    end;

    v_logistics_score := case
      when req.mkhonto_transport_requested and offer.mkhonto_transport_available then 5
      when req.mkhonto_transport_requested and not offer.mkhonto_transport_available then 1
      when req.logistics_responsibility = 'tbd' or offer.logistics_responsibility = 'tbd' then 3
      when req.logistics_responsibility = offer.logistics_responsibility then 5
      when req.logistics_responsibility in ('shared','mkhonto') or offer.logistics_responsibility in ('shared','mkhonto') then 4
      else 1
    end;

    v_commercial_score := case
      when req.target_price is null or req.target_price <= 0 then 3
      when offer.price is null or offer.price <= 0 then 2
      when offer.currency <> req.currency then 1
      when offer.price <= req.target_price then 5
      else round(greatest(0, 5 * req.target_price / offer.price), 2)
    end;

    select c.verification_status, c.confidence_score
      into v_verification_status, v_confidence
    from public.counterparties c
    where c.id = offer.seller_counterparty_id
      and c.organisation_id = offer.organisation_id;

    v_verification_score := case coalesce(v_verification_status,'')
      when 'verified' then least(10, 8 + coalesce(v_confidence,0) * 0.02)
      when 'pending' then least(7, 4 + coalesce(v_confidence,0) * 0.02)
      when 'rejected' then 0
      else least(4, 1 + coalesce(v_confidence,0) * 0.02)
    end;

    v_hard_filter_pass := v_product_compatible and v_failed_mandatory = 0;

    v_total_score := round(
      20
      + (case when req.product_id is not null and offer.product_id = req.product_id then 10 when v_product_compatible then 6 else 0 end)
      + v_spec_score
      + v_quantity_score
      + v_origin_score
      + v_incoterm_score
      + v_logistics_score
      + v_commercial_score
      + v_verification_score,
      2
    );

    insert into public.commodity_matches (
      organisation_id, buyer_requirement_id, seller_offer_id, status, hard_filter_pass,
      commodity_score, product_score, specification_score, quantity_score, origin_score,
      incoterm_score, logistics_score, commercial_score, verification_score, total_score,
      failed_mandatory_specs, explanation, algorithm_version, generated_at, generated_by,
      updated_by
    ) values (
      req.organisation_id, req.id, offer.id,
      case when v_hard_filter_pass then 'candidate' else 'disqualified' end,
      v_hard_filter_pass,
      20,
      case when req.product_id is not null and offer.product_id = req.product_id then 10 when v_product_compatible then 6 else 0 end,
      v_spec_score, v_quantity_score, v_origin_score, v_incoterm_score, v_logistics_score,
      v_commercial_score, round(v_verification_score,2), v_total_score,
      v_failed_mandatory,
      jsonb_build_object(
        'algorithm_version','1.0',
        'hard_filters', jsonb_build_object(
          'commodity_match', true,
          'product_compatible', v_product_compatible,
          'failed_mandatory_specs', v_failed_mandatory
        ),
        'components', jsonb_build_object(
          'commodity', 20,
          'product', case when req.product_id is not null and offer.product_id = req.product_id then 10 when v_product_compatible then 6 else 0 end,
          'specification', v_spec_score,
          'quantity', v_quantity_score,
          'origin', v_origin_score,
          'incoterm', v_incoterm_score,
          'logistics', v_logistics_score,
          'commercial', v_commercial_score,
          'verification', round(v_verification_score,2)
        ),
        'failed_specifications', v_failed_specs,
        'buyer_requirement_reference', req.reference,
        'seller_offer_reference', offer.reference
      ),
      '1.0', now(), (select auth.uid()), (select auth.uid())
    )
    on conflict (buyer_requirement_id, seller_offer_id) do update
    set hard_filter_pass = excluded.hard_filter_pass,
        commodity_score = excluded.commodity_score,
        product_score = excluded.product_score,
        specification_score = excluded.specification_score,
        quantity_score = excluded.quantity_score,
        origin_score = excluded.origin_score,
        incoterm_score = excluded.incoterm_score,
        logistics_score = excluded.logistics_score,
        commercial_score = excluded.commercial_score,
        verification_score = excluded.verification_score,
        total_score = excluded.total_score,
        failed_mandatory_specs = excluded.failed_mandatory_specs,
        explanation = excluded.explanation,
        algorithm_version = excluded.algorithm_version,
        generated_at = excluded.generated_at,
        generated_by = excluded.generated_by,
        updated_by = excluded.updated_by,
        status = case
          when public.commodity_matches.status in ('shortlisted','accepted','rejected') then public.commodity_matches.status
          else excluded.status
        end;

    v_evaluated := v_evaluated + 1;
  end loop;

  return v_evaluated;
end;
$function$;

revoke all on function public.refresh_buyer_requirement_matches(uuid) from public;
revoke all on function public.refresh_buyer_requirement_matches(uuid) from anon;
grant execute on function public.refresh_buyer_requirement_matches(uuid) to authenticated;
grant execute on function public.refresh_buyer_requirement_matches(uuid) to service_role;