create or replace function private.guard_mrcip_report_definition()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  wl public.crm_watchlists%rowtype;
  uid uuid := (select auth.uid());
begin
  if tg_op='UPDATE' then
    if old.organisation_id<>new.organisation_id or old.report_key<>new.report_key or old.owner_user_id<>new.owner_user_id or old.created_by<>new.created_by or old.created_at<>new.created_at then
      raise exception 'Report organisation, key, owner and creation identity are immutable';
    end if;
  end if;
  if not exists (
    select 1 from public.organisation_memberships m
    where m.organisation_id=new.organisation_id and m.user_id=new.owner_user_id and m.status='active'
  ) then
    raise exception 'Report owner must be an active organisation member';
  end if;
  if new.report_kind in ('risk_register','opportunity_pipeline') then
    new.protected_context:=true;
  end if;
  if new.report_kind='watchlist_signals' then
    select * into wl from public.crm_watchlists
    where organisation_id=new.organisation_id and id=new.watchlist_id;
    if not found then raise exception 'Watchlist not found or not accessible'; end if;
    new.protected_context:=coalesce(new.protected_context,false) or wl.is_protected;
  end if;
  if new.visibility='executive' and not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director']) then
    raise exception 'Executive reports require executive authority';
  end if;
  if new.protected_context and not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']) then
    raise exception 'Protected reports require privileged MRCIP authority';
  end if;
  new.updated_at:=now();
  new.updated_by:=coalesce(uid,new.updated_by);
  if tg_op='INSERT' then
    new.created_by:=coalesce(uid,new.created_by);
    new.owner_user_id:=coalesce(new.owner_user_id,uid);
  end if;
  return new;
end; $$;
revoke all on function private.guard_mrcip_report_definition() from public,anon,authenticated;
create trigger mrcip_report_definitions_guard_biu before insert or update on public.mrcip_report_definitions for each row execute function private.guard_mrcip_report_definition();

create or replace function private.compute_mrcip_report_run()
returns trigger
language plpgsql
set search_path=''
as $$
declare
  def public.mrcip_report_definitions%rowtype;
  total_count bigint:=0;
  verified_count bigint:=0;
  stale_count bigint:=0;
  grade_a bigint:=0; grade_b bigint:=0; grade_c bigint:=0; grade_d bigint:=0; grade_e bigint:=0;
  avg_quality numeric:=null;
  readiness_high bigint:=0; readiness_strong bigint:=0; readiness_developing bigint:=0; readiness_early bigint:=0;
  disclosure_count bigint:=0; overdue_count bigint:=0;
  avg_readiness numeric:=null;
  stage_breakdown jsonb:='{}'::jsonb;
  risk_low bigint:=0; risk_moderate bigint:=0; risk_high bigint:=0; risk_critical bigint:=0; open_flags bigint:=0;
  signal_items bigint:=0; signal_total bigint:=0; sev_info bigint:=0; sev_low bigint:=0; sev_medium bigint:=0; sev_high bigint:=0; sev_critical bigint:=0;
begin
  select * into def from public.mrcip_report_definitions where organisation_id=new.organisation_id and id=new.definition_id and active;
  if not found then raise exception 'Report definition not found, inactive or not accessible'; end if;
  new.report_kind:=def.report_kind;
  new.protected_context:=def.protected_context;
  new.algorithm_version:='mrcip-report-v1';
  new.generated_at:=now();
  new.generated_by:=coalesce((select auth.uid()),new.generated_by);

  if def.report_kind='counterparty_health' then
    with base as (
      select cp.id,cp.verification_status,cp.last_verified_at,
        q.score as quality_score,q.grade as quality_grade
      from public.counterparties cp
      left join lateral (
        select s.score,s.grade from public.counterparty_quality_snapshots s
        where s.organisation_id=cp.organisation_id and s.counterparty_id=cp.id
        order by s.generated_at desc limit 1
      ) q on true
      where cp.organisation_id=def.organisation_id
        and (def.commodity_id is null or exists (
          select 1 from public.counterparty_commodities cc
          where cc.organisation_id=cp.organisation_id and cc.counterparty_id=cp.id and cc.commodity_id=def.commodity_id and cc.active
        ))
    )
    select count(*),
      count(*) filter(where lower(verification_status)='verified'),
      count(*) filter(where last_verified_at is null or last_verified_at<now()-interval '180 days'),
      round(avg(quality_score),2),
      count(*) filter(where quality_grade='A'),count(*) filter(where quality_grade='B'),count(*) filter(where quality_grade='C'),count(*) filter(where quality_grade='D'),count(*) filter(where quality_grade='E')
    into total_count,verified_count,stale_count,avg_quality,grade_a,grade_b,grade_c,grade_d,grade_e from base;
    new.row_count:=total_count::integer;
    new.result_summary:=jsonb_build_object(
      'report_kind',def.report_kind,'counterparties',total_count,'verified',verified_count,'verification_stale_or_missing',stale_count,
      'average_quality_score',avg_quality,'quality_grades',jsonb_build_object('A',grade_a,'B',grade_b,'C',grade_c,'D',grade_d,'E',grade_e),
      'commodity_id',def.commodity_id
    );

  elsif def.report_kind='opportunity_pipeline' then
    with base as (
      select * from public.mrcip_opportunity_operational_summary o
      where o.organisation_id=def.organisation_id and (def.commodity_id is null or o.commodity_id=def.commodity_id)
    )
    select count(*),round(avg(readiness_score),2),
      count(*) filter(where readiness_band='high'),count(*) filter(where readiness_band='strong'),count(*) filter(where readiness_band='developing'),count(*) filter(where readiness_band='early'),
      count(*) filter(where disclosure_eligible),count(*) filter(where next_action_due_at is not null and next_action_due_at<now())
    into total_count,avg_readiness,readiness_high,readiness_strong,readiness_developing,readiness_early,disclosure_count,overdue_count from base;
    select coalesce(jsonb_object_agg(x.stage,x.cnt),'{}'::jsonb) into stage_breakdown
    from (
      select coalesce(o.stage,'unspecified') as stage,count(*) as cnt
      from public.mrcip_opportunity_operational_summary o
      where o.organisation_id=def.organisation_id and (def.commodity_id is null or o.commodity_id=def.commodity_id)
      group by coalesce(o.stage,'unspecified')
    ) x;
    new.row_count:=total_count::integer;
    new.result_summary:=jsonb_build_object(
      'report_kind',def.report_kind,'opportunities',total_count,'average_readiness_score',avg_readiness,
      'readiness_bands',jsonb_build_object('high',readiness_high,'strong',readiness_strong,'developing',readiness_developing,'early',readiness_early),
      'disclosure_eligible',disclosure_count,'overdue_next_actions',overdue_count,'stage_breakdown',stage_breakdown,'commodity_id',def.commodity_id
    );

  elsif def.report_kind='risk_register' then
    with base as (
      select cp.id,r.risk_score,r.risk_band,r.open_flag_count
      from public.counterparties cp
      left join lateral (
        select s.risk_score,s.risk_band,s.open_flag_count from public.counterparty_risk_snapshots s
        where s.organisation_id=cp.organisation_id and s.counterparty_id=cp.id
        order by s.generated_at desc limit 1
      ) r on true
      where cp.organisation_id=def.organisation_id
        and (def.commodity_id is null or exists (
          select 1 from public.counterparty_commodities cc
          where cc.organisation_id=cp.organisation_id and cc.counterparty_id=cp.id and cc.commodity_id=def.commodity_id and cc.active
        ))
    )
    select count(*) filter(where risk_score is not null),
      count(*) filter(where risk_band='low'),count(*) filter(where risk_band='moderate'),count(*) filter(where risk_band='high'),count(*) filter(where risk_band='critical'),
      coalesce(sum(open_flag_count),0)
    into total_count,risk_low,risk_moderate,risk_high,risk_critical,open_flags from base;
    new.row_count:=total_count::integer;
    new.result_summary:=jsonb_build_object(
      'report_kind',def.report_kind,'scored_counterparties',total_count,
      'risk_bands',jsonb_build_object('low',risk_low,'moderate',risk_moderate,'high',risk_high,'critical',risk_critical),
      'open_or_mitigated_flags',open_flags,'commodity_id',def.commodity_id
    );

  elsif def.report_kind='watchlist_signals' then
    with latest as (
      select distinct on (s.watchlist_item_id) s.watchlist_item_id,s.signal_count,s.highest_severity
      from public.mrcip_watchlist_signal_snapshots s
      where s.organisation_id=def.organisation_id and s.watchlist_id=def.watchlist_id
      order by s.watchlist_item_id,s.generated_at desc
    )
    select count(*),count(*) filter(where signal_count>0),coalesce(sum(signal_count),0),
      count(*) filter(where highest_severity='info'),count(*) filter(where highest_severity='low'),count(*) filter(where highest_severity='medium'),count(*) filter(where highest_severity='high'),count(*) filter(where highest_severity='critical')
    into total_count,signal_items,signal_total,sev_info,sev_low,sev_medium,sev_high,sev_critical from latest;
    new.row_count:=total_count::integer;
    new.result_summary:=jsonb_build_object(
      'report_kind',def.report_kind,'watchlist_id',def.watchlist_id,'items_with_snapshots',total_count,'items_with_signals',signal_items,'total_signals',signal_total,
      'highest_severity_counts',jsonb_build_object('info',sev_info,'low',sev_low,'medium',sev_medium,'high',sev_high,'critical',sev_critical)
    );
  else
    raise exception 'Unsupported report kind';
  end if;
  return new;
end; $$;
revoke all on function private.compute_mrcip_report_run() from public,anon,authenticated;
create trigger mrcip_report_runs_compute_bi before insert on public.mrcip_report_runs for each row execute function private.compute_mrcip_report_run();

create policy mrcip_report_definitions_select on public.mrcip_report_definitions for select to authenticated using (
  private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])
  and (private.has_mrcip_role(organisation_id,array['super_admin','managing_director']) or visibility='shared' or (visibility='private' and owner_user_id=(select auth.uid())))
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);
create policy mrcip_report_definitions_insert on public.mrcip_report_definitions for insert to authenticated with check (
  owner_user_id=(select auth.uid()) and created_by=(select auth.uid()) and updated_by=(select auth.uid())
  and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])
  and (visibility<>'executive' or private.has_mrcip_role(organisation_id,array['super_admin','managing_director']))
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);
create policy mrcip_report_definitions_update on public.mrcip_report_definitions for update to authenticated using (
  (owner_user_id=(select auth.uid()) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director']))
  and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])
) with check (
  updated_by=(select auth.uid()) and (owner_user_id=(select auth.uid()) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director']))
  and (visibility<>'executive' or private.has_mrcip_role(organisation_id,array['super_admin','managing_director']))
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);
create policy mrcip_report_definitions_delete on public.mrcip_report_definitions for delete to authenticated using (
  owner_user_id=(select auth.uid()) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director'])
);

create policy mrcip_report_runs_select on public.mrcip_report_runs for select to authenticated using (
  exists (select 1 from public.mrcip_report_definitions d where d.organisation_id=mrcip_report_runs.organisation_id and d.id=mrcip_report_runs.definition_id)
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);
create policy mrcip_report_runs_insert on public.mrcip_report_runs for insert to authenticated with check (
  generated_by=(select auth.uid())
  and exists (select 1 from public.mrcip_report_definitions d where d.organisation_id=mrcip_report_runs.organisation_id and d.id=mrcip_report_runs.definition_id and d.active)
  and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))
);

revoke all on public.mrcip_report_definitions,public.mrcip_report_runs from anon,authenticated;
grant select,insert,update,delete on public.mrcip_report_definitions to authenticated;
grant select,insert on public.mrcip_report_runs to authenticated;

create or replace function public.generate_mrcip_report(p_definition_id uuid)
returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare
  def public.mrcip_report_definitions%rowtype;
  run_id uuid;
begin
  select * into def from public.mrcip_report_definitions where id=p_definition_id and active;
  if not found then raise exception 'Report definition not found, inactive or not accessible'; end if;
  insert into public.mrcip_report_runs(organisation_id,definition_id,report_kind,generated_by)
  values(def.organisation_id,def.id,def.report_kind,(select auth.uid())) returning id into run_id;
  return run_id;
end; $$;
revoke all on function public.generate_mrcip_report(uuid) from public,anon;
grant execute on function public.generate_mrcip_report(uuid) to authenticated;

create or replace view public.mrcip_report_catalog_summary with (security_invoker=true) as
select d.organisation_id,d.id as definition_id,d.report_key,d.name,d.description,d.report_kind,d.visibility,d.owner_user_id,d.watchlist_id,d.commodity_id,d.protected_context,d.active,d.updated_at,
  r.id as latest_run_id,r.row_count as latest_row_count,r.result_summary as latest_result_summary,r.generated_at as latest_generated_at,r.generated_by as latest_generated_by
from public.mrcip_report_definitions d
left join lateral (
  select x.id,x.row_count,x.result_summary,x.generated_at,x.generated_by from public.mrcip_report_runs x
  where x.organisation_id=d.organisation_id and x.definition_id=d.id
  order by x.generated_at desc limit 1
) r on true;
revoke all on public.mrcip_report_catalog_summary from public,anon,authenticated;
grant select on public.mrcip_report_catalog_summary to authenticated;