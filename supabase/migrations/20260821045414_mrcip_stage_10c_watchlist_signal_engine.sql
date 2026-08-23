create or replace function private.compute_mrcip_watchlist_signal_snapshot()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  item public.crm_watchlist_items%rowtype;
  wl public.crm_watchlists%rowtype;
  cp public.counterparties%rowtype;
  mn public.mines%rowtype;
  lab public.laboratories%rowtype;
  req public.buyer_requirements%rowtype;
  offe public.seller_supply_offers%rowtype;
  opp public.opportunities%rowtype;
  qgrade text; qscore numeric;
  rband text; rscore numeric;
  readiness text; readiness_score numeric; risk_pen numeric;
  protocol_step text;
  sigs jsonb:='[]'::jsonb;
  max_rank integer:=0;
  privileged boolean:=false;
begin
  select * into item from public.crm_watchlist_items
  where organisation_id=new.organisation_id and id=new.watchlist_item_id;
  if not found then raise exception 'Watchlist item not found or not accessible'; end if;
  select * into wl from public.crm_watchlists
  where organisation_id=item.organisation_id and id=item.watchlist_id;
  if not found then raise exception 'Watchlist not found or not accessible'; end if;
  if new.watchlist_id<>item.watchlist_id then raise exception 'Watchlist snapshot item does not belong to supplied watchlist'; end if;

  privileged:=private.has_mrcip_role(item.organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']);
  new.organisation_id:=item.organisation_id;
  new.watchlist_id:=item.watchlist_id;
  new.entity_type:=item.entity_type;
  new.protected_context:=coalesce(item.protected_context,false) or coalesce(wl.is_protected,false);

  if item.entity_type='counterparty' then
    select * into cp from public.counterparties where organisation_id=item.organisation_id and id=item.counterparty_id;
    if not found then raise exception 'Counterparty watchlist entity is not accessible'; end if;
    if cp.last_verified_at is null or cp.last_verified_at<now()-interval '180 days' then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','verification_stale','severity','medium','title','Counterparty verification requires refresh','message','Verification is missing or older than 180 days.','evidence',jsonb_build_object('last_verified_at',cp.last_verified_at,'verification_status',cp.verification_status)));
      max_rank:=greatest(max_rank,3);
    end if;
    select s.grade,s.score into qgrade,qscore from public.counterparty_quality_snapshots s where s.organisation_id=item.organisation_id and s.counterparty_id=cp.id order by s.generated_at desc limit 1;
    if qgrade='E' then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','quality_grade_low','severity','high','title','Counterparty data quality is weak','message','Latest deterministic quality grade is E.','evidence',jsonb_build_object('quality_grade',qgrade,'quality_score',qscore)));
      max_rank:=greatest(max_rank,4);
    elsif qgrade='D' then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','quality_grade_low','severity','medium','title','Counterparty data quality needs attention','message','Latest deterministic quality grade is D.','evidence',jsonb_build_object('quality_grade',qgrade,'quality_score',qscore)));
      max_rank:=greatest(max_rank,3);
    end if;
    if privileged then
      select s.risk_band,s.risk_score into rband,rscore from public.counterparty_risk_snapshots s where s.organisation_id=item.organisation_id and s.counterparty_id=cp.id order by s.generated_at desc limit 1;
      if rband='critical' then
        sigs:=sigs||jsonb_build_array(jsonb_build_object('type','counterparty_risk','severity','critical','title','Critical counterparty risk state','message','Latest internal risk snapshot is critical.','evidence',jsonb_build_object('risk_band',rband,'risk_score',rscore)));
        max_rank:=greatest(max_rank,5);
      elsif rband='high' then
        sigs:=sigs||jsonb_build_array(jsonb_build_object('type','counterparty_risk','severity','high','title','High counterparty risk state','message','Latest internal risk snapshot is high.','evidence',jsonb_build_object('risk_band',rband,'risk_score',rscore)));
        max_rank:=greatest(max_rank,4);
      end if;
    end if;

  elsif item.entity_type='mine' then
    select * into mn from public.mines where organisation_id=item.organisation_id and id=item.mine_id;
    if not found then raise exception 'Mine watchlist entity is not accessible'; end if;
    if mn.last_verified_at is null or mn.last_verified_at<now()-interval '180 days' then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','verification_stale','severity','medium','title','Mine verification requires refresh','message','Mine verification is missing or older than 180 days.','evidence',jsonb_build_object('last_verified_at',mn.last_verified_at,'verification_status',mn.verification_status)));
      max_rank:=greatest(max_rank,3);
    end if;
    if lower(mn.mine_status)='care_maintenance' then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','mine_status','severity','medium','title','Mine is in care and maintenance','message','Current mine status may affect near-term supply availability.','evidence',jsonb_build_object('mine_status',mn.mine_status)));
      max_rank:=greatest(max_rank,3);
    elsif lower(mn.mine_status) in ('suspended','closed') then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','mine_status','severity','high','title','Mine operating status requires attention','message','Current mine status is suspended or closed.','evidence',jsonb_build_object('mine_status',mn.mine_status)));
      max_rank:=greatest(max_rank,4);
    end if;

  elsif item.entity_type='laboratory' then
    select * into lab from public.laboratories where organisation_id=item.organisation_id and id=item.laboratory_id;
    if not found then raise exception 'Laboratory watchlist entity is not accessible'; end if;
    if lab.last_verified_at is null or lab.last_verified_at<now()-interval '180 days' then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','verification_stale','severity','medium','title','Laboratory verification requires refresh','message','Laboratory verification is missing or older than 180 days.','evidence',jsonb_build_object('last_verified_at',lab.last_verified_at,'verification_status',lab.verification_status)));
      max_rank:=greatest(max_rank,3);
    end if;
    if lab.accreditation_expiry is not null and lab.accreditation_expiry<current_date then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','accreditation_expiry','severity','high','title','Laboratory accreditation appears expired','message','Recorded accreditation expiry date is in the past.','evidence',jsonb_build_object('accreditation_expiry',lab.accreditation_expiry,'accreditation_body',lab.accreditation_body)));
      max_rank:=greatest(max_rank,4);
    elsif lab.accreditation_expiry is not null and lab.accreditation_expiry<=current_date+30 then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','accreditation_expiry','severity','medium','title','Laboratory accreditation expires soon','message','Recorded accreditation expires within 30 days.','evidence',jsonb_build_object('accreditation_expiry',lab.accreditation_expiry,'accreditation_body',lab.accreditation_body)));
      max_rank:=greatest(max_rank,3);
    end if;

  elsif item.entity_type='buyer_requirement' then
    select * into req from public.buyer_requirements where organisation_id=item.organisation_id and id=item.buyer_requirement_id;
    if not found then raise exception 'Buyer requirement watchlist entity is not accessible'; end if;
    if req.valid_until is not null and req.valid_until<current_date then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','requirement_validity','severity','high','title','Buyer requirement has expired','message','Requirement validity date is in the past.','evidence',jsonb_build_object('valid_until',req.valid_until,'status',req.status)));
      max_rank:=greatest(max_rank,4);
    elsif req.valid_until is not null and req.valid_until<=current_date+7 then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','requirement_validity','severity','medium','title','Buyer requirement expires soon','message','Requirement validity expires within 7 days.','evidence',jsonb_build_object('valid_until',req.valid_until,'status',req.status)));
      max_rank:=greatest(max_rank,3);
    end if;

  elsif item.entity_type='seller_offer' then
    select * into offe from public.seller_supply_offers where organisation_id=item.organisation_id and id=item.seller_offer_id;
    if not found then raise exception 'Seller offer watchlist entity is not accessible'; end if;
    new.protected_context:=new.protected_context or offe.is_protected;
    if offe.valid_until is not null and offe.valid_until<current_date then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','offer_validity','severity','high','title','Seller offer has expired','message','Offer validity date is in the past.','evidence',jsonb_build_object('valid_until',offe.valid_until,'status',offe.status)));
      max_rank:=greatest(max_rank,4);
    elsif offe.valid_until is not null and offe.valid_until<=current_date+7 then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','offer_validity','severity','medium','title','Seller offer expires soon','message','Offer validity expires within 7 days.','evidence',jsonb_build_object('valid_until',offe.valid_until,'status',offe.status)));
      max_rank:=greatest(max_rank,3);
    end if;
    if lower(offe.status)='active' and (lower(offe.authority_status)<>'verified' or lower(offe.mandate_status)<>'verified') then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','seller_authority','severity','medium','title','Seller authority or mandate is incomplete','message','Active supply is missing verified authority and/or mandate status.','evidence',jsonb_build_object('authority_status',offe.authority_status,'mandate_status',offe.mandate_status)));
      max_rank:=greatest(max_rank,3);
    end if;

  elsif item.entity_type='opportunity' then
    select * into opp from public.opportunities where organisation_id=item.organisation_id and id=item.opportunity_id;
    if not found then raise exception 'Opportunity watchlist entity is not accessible'; end if;
    new.protected_context:=new.protected_context or opp.is_protected;
    if opp.next_action_due_at is not null and opp.next_action_due_at<now() and lower(opp.status) not in ('closed','cancelled','completed','lost') then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','next_action_overdue','severity','high','title','Opportunity next action is overdue','message','The recorded next action due time has passed.','evidence',jsonb_build_object('next_action',opp.next_action,'next_action_due_at',opp.next_action_due_at,'status',opp.status)));
      max_rank:=greatest(max_rank,4);
    end if;
    select pc.protocol_step into protocol_step from public.opportunity_protocol_controls pc where pc.organisation_id=item.organisation_id and pc.opportunity_id=opp.id;
    if protocol_step in ('protect','verify') and opp.updated_at<now()-interval '14 days' and lower(opp.status) not in ('closed','cancelled','completed','lost') then
      sigs:=sigs||jsonb_build_array(jsonb_build_object('type','protocol_stale','severity','medium','title','Opportunity protocol may be stalled','message','Opportunity remains in an early protection/verification stage with no update for more than 14 days.','evidence',jsonb_build_object('protocol_step',protocol_step,'opportunity_updated_at',opp.updated_at)));
      max_rank:=greatest(max_rank,3);
    end if;
    if privileged then
      select s.readiness_band,s.total_score,s.risk_penalty into readiness,readiness_score,risk_pen from public.opportunity_score_snapshots s where s.organisation_id=item.organisation_id and s.opportunity_id=opp.id order by s.generated_at desc limit 1;
      if readiness='early' then
        sigs:=sigs||jsonb_build_array(jsonb_build_object('type','opportunity_readiness','severity','medium','title','Opportunity readiness is early','message','Latest deterministic readiness score is below the developing threshold.','evidence',jsonb_build_object('readiness_band',readiness,'readiness_score',readiness_score,'risk_penalty',risk_pen)));
        max_rank:=greatest(max_rank,3);
      end if;
      if risk_pen is not null and risk_pen>=10 then
        sigs:=sigs||jsonb_build_array(jsonb_build_object('type','opportunity_risk_penalty','severity','high','title','Opportunity carries a high risk penalty','message','Latest readiness score includes a risk penalty of at least 10 points.','evidence',jsonb_build_object('risk_penalty',risk_pen,'readiness_score',readiness_score)));
        max_rank:=greatest(max_rank,4);
      end if;
    end if;
  else
    raise exception 'Unsupported watchlist entity type';
  end if;

  if new.protected_context and not privileged then
    raise exception 'Protected watchlist signals require privileged MRCIP authority';
  end if;
  new.signals:=sigs;
  new.signal_count:=jsonb_array_length(sigs);
  new.highest_severity:=case max_rank when 5 then 'critical' when 4 then 'high' when 3 then 'medium' when 2 then 'low' when 1 then 'info' else 'none' end;
  new.algorithm_version:='watchlist-signals-v1';
  new.generated_at:=now();
  new.generated_by:=coalesce((select auth.uid()),new.generated_by);
  return new;
end; $$;
revoke all on function private.compute_mrcip_watchlist_signal_snapshot() from public,anon,authenticated;
create trigger mrcip_watchlist_signal_snapshots_compute_bi before insert on public.mrcip_watchlist_signal_snapshots for each row execute function private.compute_mrcip_watchlist_signal_snapshot();

create policy mrcip_watchlist_signal_snapshots_select on public.mrcip_watchlist_signal_snapshots for select to authenticated using (
  exists (
    select 1 from public.crm_watchlists w
    where w.organisation_id=mrcip_watchlist_signal_snapshots.organisation_id and w.id=mrcip_watchlist_signal_snapshots.watchlist_id
      and (w.owner_user_id=(select auth.uid()) or w.visibility='shared')
  )
  and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);
create policy mrcip_watchlist_signal_snapshots_insert on public.mrcip_watchlist_signal_snapshots for insert to authenticated with check (
  generated_by=(select auth.uid())
  and exists (
    select 1 from public.crm_watchlists w
    where w.organisation_id=mrcip_watchlist_signal_snapshots.organisation_id and w.id=mrcip_watchlist_signal_snapshots.watchlist_id
      and (w.owner_user_id=(select auth.uid()) or w.visibility='shared') and w.status='active'
  )
  and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);

revoke all on public.mrcip_watchlist_signal_snapshots from anon,authenticated;
grant select,insert on public.mrcip_watchlist_signal_snapshots to authenticated;

create or replace function public.refresh_watchlist_signals(p_watchlist_id uuid)
returns integer
language plpgsql
security invoker
set search_path=''
as $$
declare
  wl public.crm_watchlists%rowtype;
  inserted_count integer:=0;
begin
  select * into wl from public.crm_watchlists where id=p_watchlist_id and status='active';
  if not found then raise exception 'Watchlist not found, inactive or not accessible'; end if;
  insert into public.mrcip_watchlist_signal_snapshots(organisation_id,watchlist_id,watchlist_item_id,entity_type,generated_by)
  select i.organisation_id,i.watchlist_id,i.id,i.entity_type,(select auth.uid())
  from public.crm_watchlist_items i
  where i.organisation_id=wl.organisation_id and i.watchlist_id=wl.id;
  get diagnostics inserted_count = row_count;
  return inserted_count;
end; $$;
revoke all on function public.refresh_watchlist_signals(uuid) from public,anon;
grant execute on function public.refresh_watchlist_signals(uuid) to authenticated;

create or replace view public.mrcip_watchlist_signal_current with (security_invoker=true) as
select w.organisation_id,w.id as watchlist_id,w.name as watchlist_name,w.visibility,w.is_protected as watchlist_protected,
  i.id as watchlist_item_id,i.entity_type,i.counterparty_id,i.mine_id,i.laboratory_id,i.buyer_requirement_id,i.seller_offer_id,i.opportunity_id,i.priority,
  s.id as snapshot_id,s.signal_count,s.highest_severity,s.signals,s.protected_context,s.algorithm_version,s.generated_at,s.generated_by
from public.crm_watchlists w
join public.crm_watchlist_items i on i.organisation_id=w.organisation_id and i.watchlist_id=w.id
left join lateral (
  select x.id,x.signal_count,x.highest_severity,x.signals,x.protected_context,x.algorithm_version,x.generated_at,x.generated_by
  from public.mrcip_watchlist_signal_snapshots x
  where x.organisation_id=i.organisation_id and x.watchlist_item_id=i.id
  order by x.generated_at desc limit 1
) s on true;
revoke all on public.mrcip_watchlist_signal_current from public,anon,authenticated;
grant select on public.mrcip_watchlist_signal_current to authenticated;