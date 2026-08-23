create or replace function private.crm_channel_is_allowed(p_organisation_id uuid,p_counterparty_id uuid,p_contact_id uuid,p_channel text)
returns boolean language plpgsql security definer set search_path=''
as $$
declare ctl public.crm_contact_controls%rowtype; blocked boolean:=false; allowed boolean:=true;
begin
  for ctl in
    select * from public.crm_contact_controls c
    where c.organisation_id=p_organisation_id
      and c.counterparty_id=p_counterparty_id
      and (c.contact_id is null or c.contact_id=p_contact_id)
  loop
    if ctl.contactability_status='do_not_contact' then return false; end if;
    allowed:=case p_channel
      when 'email' then coalesce(ctl.email_allowed,true)
      when 'phone' then coalesce(ctl.phone_allowed,true)
      when 'whatsapp' then coalesce(ctl.whatsapp_allowed,true)
      when 'linkedin' then coalesce(ctl.linkedin_allowed,true)
      when 'in_person' then coalesce(ctl.in_person_allowed,true)
      when 'meeting' then coalesce(ctl.in_person_allowed,true)
      when 'site_visit' then coalesce(ctl.in_person_allowed,true)
      else true end;
    if not allowed then blocked:=true; end if;
  end loop;
  return not blocked;
end; $$;
revoke all on function private.crm_channel_is_allowed(uuid,uuid,uuid,text) from public,anon,authenticated;

create or replace function private.guard_crm_contact_control()
returns trigger language plpgsql security definer set search_path=''
as $$
declare cp public.counterparties%rowtype; ct public.counterparty_contacts%rowtype; old_dnc boolean:=false;
begin
  select * into cp from public.counterparties where organisation_id=new.organisation_id and id=new.counterparty_id;
  if not found then raise exception 'Counterparty not found for contact control'; end if;
  if new.contact_id is not null then
    select * into ct from public.counterparty_contacts where organisation_id=new.organisation_id and id=new.contact_id;
    if not found or ct.counterparty_id<>new.counterparty_id then raise exception 'Contact control contact must belong to the selected counterparty'; end if;
    new.protected_context:=coalesce(new.protected_context,false) or ct.is_protected;
  end if;
  if tg_op='UPDATE' and old.contactability_status='do_not_contact' and new.contactability_status<>'do_not_contact' then
    if not private.has_mrcip_role(new.organisation_id,array['super_admin','managing_director','commodity_manager','legal_compliance']) then
      raise exception 'Removing do-not-contact status requires executive or legal/compliance authority' using errcode='42501';
    end if;
  end if;
  if new.contactability_status='do_not_contact' then
    new.email_allowed:=false; new.phone_allowed:=false; new.whatsapp_allowed:=false; new.linkedin_allowed:=false; new.in_person_allowed:=false;
  end if;
  if new.verified_at is not null and new.verified_by is null then new.verified_by:=(select auth.uid()); end if;
  new.updated_at:=now(); new.updated_by:=(select auth.uid());
  return new;
end; $$;
revoke all on function private.guard_crm_contact_control() from public,anon,authenticated;
create trigger crm_contact_controls_guard_biu before insert or update on public.crm_contact_controls for each row execute function private.guard_crm_contact_control();

create or replace function private.audit_crm_contact_control()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if tg_op='INSERT' or new.contactability_status is distinct from old.contactability_status then
    insert into public.audit_events(organisation_id,entity_type,entity_id,action,summary,metadata,actor_id)
    values(new.organisation_id,'crm_contact_control',new.id,
      case when new.contactability_status='do_not_contact' then 'do_not_contact_set' when tg_op='INSERT' then 'contact_control_created' else 'contactability_changed' end,
      'CRM contactability control changed',
      jsonb_build_object('counterparty_id',new.counterparty_id,'contact_id',new.contact_id,'status',new.contactability_status,'restriction_reason',new.restriction_reason),
      coalesce((select auth.uid()),new.updated_by));
  end if;
  return new;
end; $$;
revoke all on function private.audit_crm_contact_control() from public,anon,authenticated;
create trigger crm_contact_controls_audit_aiu after insert or update on public.crm_contact_controls for each row execute function private.audit_crm_contact_control();

create or replace function private.guard_crm_campaign()
returns trigger language plpgsql security definer set search_path=''
as $$
declare p public.commodity_products%rowtype;
begin
  if not exists(select 1 from public.organisation_memberships m where m.organisation_id=new.organisation_id and m.user_id=new.owner_user_id and m.status='active') then raise exception 'Campaign owner must be an active organisation member'; end if;
  if new.product_id is not null then
    select * into p from public.commodity_products where organisation_id=new.organisation_id and id=new.product_id;
    if not found then raise exception 'Campaign product not found'; end if;
    if new.commodity_id is null then new.commodity_id:=p.commodity_id;
    elsif new.commodity_id<>p.commodity_id then raise exception 'Campaign product must belong to the selected commodity'; end if;
  end if;
  new.updated_at:=now(); new.updated_by:=(select auth.uid());
  return new;
end; $$;
revoke all on function private.guard_crm_campaign() from public,anon,authenticated;
create trigger crm_outreach_campaigns_guard_biu before insert or update on public.crm_outreach_campaigns for each row execute function private.guard_crm_campaign();

create or replace function private.guard_crm_target()
returns trigger language plpgsql security definer set search_path=''
as $$
declare camp public.crm_outreach_campaigns%rowtype; ct public.counterparty_contacts%rowtype; req public.buyer_requirements%rowtype; offe public.seller_supply_offers%rowtype; opp public.opportunities%rowtype; dnc boolean:=false;
begin
  select * into camp from public.crm_outreach_campaigns where organisation_id=new.organisation_id and id=new.campaign_id;
  if not found then raise exception 'Campaign not found for outreach target'; end if;
  if new.contact_id is not null then
    select * into ct from public.counterparty_contacts where organisation_id=new.organisation_id and id=new.contact_id;
    if not found or ct.counterparty_id<>new.counterparty_id then raise exception 'Outreach target contact must belong to the selected counterparty'; end if;
    new.protected_context:=coalesce(new.protected_context,false) or ct.is_protected;
  end if;
  if new.assigned_to is not null and not exists(select 1 from public.organisation_memberships m where m.organisation_id=new.organisation_id and m.user_id=new.assigned_to and m.status='active') then raise exception 'Assigned outreach owner must be an active organisation member'; end if;
  if new.buyer_requirement_id is not null then
    select * into req from public.buyer_requirements where organisation_id=new.organisation_id and id=new.buyer_requirement_id;
    if not found or req.buyer_counterparty_id<>new.counterparty_id then raise exception 'Buyer requirement must belong to the outreach target counterparty'; end if;
    if camp.commodity_id is not null and req.commodity_id<>camp.commodity_id then raise exception 'Buyer requirement commodity does not match campaign commodity'; end if;
    if camp.product_id is not null and req.product_id is not null and req.product_id<>camp.product_id then raise exception 'Buyer requirement product does not match campaign product'; end if;
  end if;
  if new.seller_offer_id is not null then
    select * into offe from public.seller_supply_offers where organisation_id=new.organisation_id and id=new.seller_offer_id;
    if not found or offe.seller_counterparty_id<>new.counterparty_id then raise exception 'Seller offer must belong to the outreach target counterparty'; end if;
    if camp.commodity_id is not null and offe.commodity_id<>camp.commodity_id then raise exception 'Seller offer commodity does not match campaign commodity'; end if;
    if camp.product_id is not null and offe.product_id is not null and offe.product_id<>camp.product_id then raise exception 'Seller offer product does not match campaign product'; end if;
    new.protected_context:=coalesce(new.protected_context,false) or offe.is_protected;
  end if;
  if new.opportunity_id is not null then
    select * into opp from public.opportunities where organisation_id=new.organisation_id and id=new.opportunity_id;
    if not found or new.counterparty_id not in (opp.buyer_counterparty_id,opp.seller_counterparty_id) then raise exception 'Opportunity must involve the outreach target counterparty'; end if;
    if camp.commodity_id is not null and opp.commodity_id<>camp.commodity_id then raise exception 'Opportunity commodity does not match campaign commodity'; end if;
    if camp.product_id is not null and opp.product_id is not null and opp.product_id<>camp.product_id then raise exception 'Opportunity product does not match campaign product'; end if;
    new.protected_context:=coalesce(new.protected_context,false) or opp.is_protected;
  end if;
  new.protected_context:=coalesce(new.protected_context,false) or camp.is_protected;
  dnc:=not private.crm_channel_is_allowed(new.organisation_id,new.counterparty_id,new.contact_id,'other');
  if dnc and new.status not in ('researched','do_not_contact','disqualified','closed') then raise exception 'Do-not-contact target cannot enter an outreach-active status'; end if;
  new.updated_at:=now(); new.updated_by:=(select auth.uid());
  return new;
end; $$;
revoke all on function private.guard_crm_target() from public,anon,authenticated;
create trigger crm_outreach_targets_guard_biu before insert or update on public.crm_outreach_targets for each row execute function private.guard_crm_target();

create or replace function private.guard_crm_activity()
returns trigger language plpgsql security definer set search_path=''
as $$
declare targ public.crm_outreach_targets%rowtype; camp public.crm_outreach_campaigns%rowtype; ct public.counterparty_contacts%rowtype; req public.buyer_requirements%rowtype; offe public.seller_supply_offers%rowtype; opp public.opportunities%rowtype; prev public.crm_activities%rowtype; doc public.documents%rowtype;
begin
  if tg_op<>'INSERT' then raise exception 'CRM activity history is append-only; record a corrective activity instead'; end if;
  if new.target_id is not null then
    select * into targ from public.crm_outreach_targets where organisation_id=new.organisation_id and id=new.target_id;
    if not found then raise exception 'CRM target not found'; end if;
    if targ.counterparty_id<>new.counterparty_id then raise exception 'CRM activity counterparty must match its target'; end if;
    if new.contact_id is null then new.contact_id:=targ.contact_id;
    elsif targ.contact_id is not null and targ.contact_id<>new.contact_id then raise exception 'CRM activity contact must match its target contact'; end if;
    if new.campaign_id is null then new.campaign_id:=targ.campaign_id;
    elsif targ.campaign_id<>new.campaign_id then raise exception 'CRM activity campaign must match its target campaign'; end if;
    new.protected_context:=coalesce(new.protected_context,false) or targ.protected_context;
  end if;
  if new.campaign_id is not null then
    select * into camp from public.crm_outreach_campaigns where organisation_id=new.organisation_id and id=new.campaign_id;
    if not found then raise exception 'CRM activity campaign not found'; end if;
    new.protected_context:=coalesce(new.protected_context,false) or camp.is_protected;
  end if;
  if new.contact_id is not null then
    select * into ct from public.counterparty_contacts where organisation_id=new.organisation_id and id=new.contact_id;
    if not found or ct.counterparty_id<>new.counterparty_id then raise exception 'CRM activity contact must belong to its counterparty'; end if;
    new.protected_context:=coalesce(new.protected_context,false) or ct.is_protected;
  end if;
  if new.buyer_requirement_id is not null then
    select * into req from public.buyer_requirements where organisation_id=new.organisation_id and id=new.buyer_requirement_id;
    if not found or req.buyer_counterparty_id<>new.counterparty_id then raise exception 'CRM activity buyer requirement must belong to its counterparty'; end if;
  end if;
  if new.seller_offer_id is not null then
    select * into offe from public.seller_supply_offers where organisation_id=new.organisation_id and id=new.seller_offer_id;
    if not found or offe.seller_counterparty_id<>new.counterparty_id then raise exception 'CRM activity seller offer must belong to its counterparty'; end if;
    new.protected_context:=coalesce(new.protected_context,false) or offe.is_protected;
  end if;
  if new.opportunity_id is not null then
    select * into opp from public.opportunities where organisation_id=new.organisation_id and id=new.opportunity_id;
    if not found or new.counterparty_id not in (opp.buyer_counterparty_id,opp.seller_counterparty_id) then raise exception 'CRM activity opportunity must involve its counterparty'; end if;
    new.protected_context:=coalesce(new.protected_context,false) or opp.is_protected;
  end if;
  if new.supersedes_activity_id is not null then
    select * into prev from public.crm_activities where organisation_id=new.organisation_id and id=new.supersedes_activity_id;
    if not found or prev.counterparty_id<>new.counterparty_id then raise exception 'Corrective CRM activity must supersede an activity for the same counterparty'; end if;
    new.protected_context:=coalesce(new.protected_context,false) or prev.protected_context;
  end if;
  if new.direction='outbound' and not private.crm_channel_is_allowed(new.organisation_id,new.counterparty_id,new.contact_id,new.channel) then raise exception 'Outbound CRM activity is blocked by contactability/channel controls'; end if;
  if new.evidence_document_id is not null then
    select * into doc from public.documents where organisation_id=new.organisation_id and id=new.evidence_document_id;
    if not found then raise exception 'CRM activity evidence document not found'; end if;
    if new.protected_context and doc.category<>'mrcip_protected' then raise exception 'Protected CRM activity evidence must use an mrcip_protected document'; end if;
  end if;
  if new.created_by<>(select auth.uid()) then raise exception 'CRM activity actor must be the authenticated user'; end if;
  return new;
end; $$;
revoke all on function private.guard_crm_activity() from public,anon,authenticated;
create trigger crm_activities_guard_biud before insert or update or delete on public.crm_activities for each row execute function private.guard_crm_activity();

create or replace function private.apply_crm_activity_to_target()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if new.target_id is null or new.direction='internal' then return new; end if;
  update public.crm_outreach_targets t
  set first_contacted_at=case when new.direction='outbound' then coalesce(t.first_contacted_at,new.occurred_at) else t.first_contacted_at end,
      last_contacted_at=case when t.last_contacted_at is null or new.occurred_at>t.last_contacted_at then new.occurred_at else t.last_contacted_at end,
      next_follow_up_at=coalesce(new.next_follow_up_at,t.next_follow_up_at),
      status=case
        when t.status='do_not_contact' then t.status
        when new.direction='inbound' and t.status in ('researched','ready','contacted') then 'responded'
        when new.direction='outbound' and t.status in ('researched','ready') then 'contacted'
        else t.status end,
      updated_at=now(),updated_by=new.created_by
  where t.organisation_id=new.organisation_id and t.id=new.target_id;
  return new;
end; $$;
revoke all on function private.apply_crm_activity_to_target() from public,anon,authenticated;
create trigger crm_activities_apply_ai after insert on public.crm_activities for each row execute function private.apply_crm_activity_to_target();

create or replace function private.guard_crm_task()
returns trigger language plpgsql security definer set search_path=''
as $$
declare ct public.counterparty_contacts%rowtype; camp public.crm_outreach_campaigns%rowtype; targ public.crm_outreach_targets%rowtype; req public.buyer_requirements%rowtype; offe public.seller_supply_offers%rowtype; opp public.opportunities%rowtype;
begin
  if tg_op='UPDATE' and old.status in ('completed','cancelled') and new.status is distinct from old.status then raise exception 'Closed CRM tasks cannot be reopened; create a new follow-up task'; end if;
  if new.assigned_to is not null and not exists(select 1 from public.organisation_memberships m where m.organisation_id=new.organisation_id and m.user_id=new.assigned_to and m.status='active') then raise exception 'CRM task assignee must be an active organisation member'; end if;
  if new.contact_id is not null then
    if new.counterparty_id is null then raise exception 'CRM task with a contact must also specify its counterparty'; end if;
    select * into ct from public.counterparty_contacts where organisation_id=new.organisation_id and id=new.contact_id;
    if not found or ct.counterparty_id<>new.counterparty_id then raise exception 'CRM task contact must belong to its counterparty'; end if;
    new.protected_context:=coalesce(new.protected_context,false) or ct.is_protected;
  end if;
  if new.campaign_id is not null then select * into camp from public.crm_outreach_campaigns where organisation_id=new.organisation_id and id=new.campaign_id; if not found then raise exception 'CRM task campaign not found'; end if; new.protected_context:=coalesce(new.protected_context,false) or camp.is_protected; end if;
  if new.target_id is not null then select * into targ from public.crm_outreach_targets where organisation_id=new.organisation_id and id=new.target_id; if not found then raise exception 'CRM task target not found'; end if; if new.counterparty_id is null then new.counterparty_id:=targ.counterparty_id; elsif new.counterparty_id<>targ.counterparty_id then raise exception 'CRM task counterparty must match its outreach target'; end if; if new.contact_id is null then new.contact_id:=targ.contact_id; end if; if new.campaign_id is null then new.campaign_id:=targ.campaign_id; end if; new.protected_context:=coalesce(new.protected_context,false) or targ.protected_context; end if;
  if new.buyer_requirement_id is not null then select * into req from public.buyer_requirements where organisation_id=new.organisation_id and id=new.buyer_requirement_id; if not found then raise exception 'CRM task buyer requirement not found'; end if; if new.counterparty_id is null then new.counterparty_id:=req.buyer_counterparty_id; elsif new.counterparty_id<>req.buyer_counterparty_id then raise exception 'CRM task buyer requirement must belong to its counterparty'; end if; end if;
  if new.seller_offer_id is not null then select * into offe from public.seller_supply_offers where organisation_id=new.organisation_id and id=new.seller_offer_id; if not found then raise exception 'CRM task seller offer not found'; end if; if new.counterparty_id is null then new.counterparty_id:=offe.seller_counterparty_id; elsif new.counterparty_id<>offe.seller_counterparty_id then raise exception 'CRM task seller offer must belong to its counterparty'; end if; new.protected_context:=coalesce(new.protected_context,false) or offe.is_protected; end if;
  if new.opportunity_id is not null then select * into opp from public.opportunities where organisation_id=new.organisation_id and id=new.opportunity_id; if not found then raise exception 'CRM task opportunity not found'; end if; if new.counterparty_id is not null and new.counterparty_id not in (opp.buyer_counterparty_id,opp.seller_counterparty_id) then raise exception 'CRM task opportunity must involve its counterparty'; end if; new.protected_context:=coalesce(new.protected_context,false) or opp.is_protected; end if;
  if new.outreach_channel<>'none' and new.counterparty_id is not null and not private.crm_channel_is_allowed(new.organisation_id,new.counterparty_id,new.contact_id,new.outreach_channel) then raise exception 'CRM outreach task is blocked by contactability/channel controls'; end if;
  if new.status='completed' and new.completed_at is null then new.completed_at:=now(); new.completed_by:=(select auth.uid()); end if;
  new.updated_at:=now(); new.updated_by:=(select auth.uid());
  return new;
end; $$;
revoke all on function private.guard_crm_task() from public,anon,authenticated;
create trigger crm_tasks_guard_biu before insert or update on public.crm_tasks for each row execute function private.guard_crm_task();

create or replace function private.guard_crm_watchlist()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if not exists(select 1 from public.organisation_memberships m where m.organisation_id=new.organisation_id and m.user_id=new.owner_user_id and m.status='active') then raise exception 'Watchlist owner must be an active organisation member'; end if;
  new.updated_at:=now(); new.updated_by:=(select auth.uid());
  return new;
end; $$;
revoke all on function private.guard_crm_watchlist() from public,anon,authenticated;
create trigger crm_watchlists_guard_biu before insert or update on public.crm_watchlists for each row execute function private.guard_crm_watchlist();

create or replace function private.guard_crm_watchlist_item()
returns trigger language plpgsql security definer set search_path=''
as $$
declare w public.crm_watchlists%rowtype; offe public.seller_supply_offers%rowtype; opp public.opportunities%rowtype;
begin
  select * into w from public.crm_watchlists where organisation_id=new.organisation_id and id=new.watchlist_id;
  if not found then raise exception 'Watchlist not found'; end if;
  new.protected_context:=coalesce(new.protected_context,false) or w.is_protected;
  if new.seller_offer_id is not null then select * into offe from public.seller_supply_offers where organisation_id=new.organisation_id and id=new.seller_offer_id; if not found then raise exception 'Watchlist seller offer not found'; end if; new.protected_context:=coalesce(new.protected_context,false) or offe.is_protected; end if;
  if new.opportunity_id is not null then select * into opp from public.opportunities where organisation_id=new.organisation_id and id=new.opportunity_id; if not found then raise exception 'Watchlist opportunity not found'; end if; new.protected_context:=coalesce(new.protected_context,false) or opp.is_protected; end if;
  return new;
end; $$;
revoke all on function private.guard_crm_watchlist_item() from public,anon,authenticated;
create trigger crm_watchlist_items_guard_biu before insert or update on public.crm_watchlist_items for each row execute function private.guard_crm_watchlist_item();

create policy crm_contact_controls_select on public.crm_contact_controls for select to authenticated using (((not protected_context) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']));
create policy crm_contact_controls_insert on public.crm_contact_controls for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()) and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));
create policy crm_contact_controls_update on public.crm_contact_controls for update to authenticated using (((not protected_context) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])) with check (updated_by=(select auth.uid()) and ((not protected_context and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));

create policy crm_outreach_campaigns_select on public.crm_outreach_campaigns for select to authenticated using (((not is_protected) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']));
create policy crm_outreach_campaigns_insert on public.crm_outreach_campaigns for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance']) and owner_user_id=(select auth.uid()) and created_by=(select auth.uid()) and updated_by=(select auth.uid()) and ((not is_protected) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));
create policy crm_outreach_campaigns_update on public.crm_outreach_campaigns for update to authenticated using (((not is_protected) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])) with check (updated_by=(select auth.uid()) and ((not is_protected and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));
create policy crm_outreach_campaigns_delete on public.crm_outreach_campaigns for delete to authenticated using (status='draft' and private.has_mrcip_role(organisation_id,array['super_admin','managing_director']));

create policy crm_outreach_targets_select on public.crm_outreach_targets for select to authenticated using (((not protected_context) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']));
create policy crm_outreach_targets_insert on public.crm_outreach_targets for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()) and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));
create policy crm_outreach_targets_update on public.crm_outreach_targets for update to authenticated using (((not protected_context) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])) with check (updated_by=(select auth.uid()) and ((not protected_context and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));
create policy crm_outreach_targets_delete on public.crm_outreach_targets for delete to authenticated using (status='researched' and private.has_mrcip_role(organisation_id,array['super_admin','managing_director']));

create policy crm_activities_select on public.crm_activities for select to authenticated using (((not protected_context) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']));
create policy crm_activities_insert on public.crm_activities for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance']) and created_by=(select auth.uid()) and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));

create policy crm_tasks_select on public.crm_tasks for select to authenticated using (((not protected_context) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']));
create policy crm_tasks_insert on public.crm_tasks for insert to authenticated with check (private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance']) and created_by=(select auth.uid()) and updated_by=(select auth.uid()) and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));
create policy crm_tasks_update on public.crm_tasks for update to authenticated using (((not protected_context) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])) with check (updated_by=(select auth.uid()) and ((not protected_context and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));
create policy crm_tasks_delete on public.crm_tasks for delete to authenticated using (status='open' and private.has_mrcip_role(organisation_id,array['super_admin','managing_director']));

create policy crm_watchlists_select on public.crm_watchlists for select to authenticated using (((owner_user_id=(select auth.uid())) or visibility='shared') and (((not is_protected) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));
create policy crm_watchlists_insert on public.crm_watchlists for insert to authenticated with check (owner_user_id=(select auth.uid()) and created_by=(select auth.uid()) and updated_by=(select auth.uid()) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance']) and ((not is_protected) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));
create policy crm_watchlists_update on public.crm_watchlists for update to authenticated using (((owner_user_id=(select auth.uid())) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director'])) and (((not is_protected) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))) with check (updated_by=(select auth.uid()) and ((owner_user_id=(select auth.uid())) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director'])) and (((not is_protected) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));
create policy crm_watchlists_delete on public.crm_watchlists for delete to authenticated using (((owner_user_id=(select auth.uid())) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director'])) and status='active');

create policy crm_watchlist_items_select on public.crm_watchlist_items for select to authenticated using (exists(select 1 from public.crm_watchlists w where w.organisation_id=crm_watchlist_items.organisation_id and w.id=crm_watchlist_items.watchlist_id and ((w.owner_user_id=(select auth.uid())) or w.visibility='shared')) and (((not protected_context) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));
create policy crm_watchlist_items_insert on public.crm_watchlist_items for insert to authenticated with check (created_by=(select auth.uid()) and exists(select 1 from public.crm_watchlists w where w.organisation_id=crm_watchlist_items.organisation_id and w.id=crm_watchlist_items.watchlist_id and ((w.owner_user_id=(select auth.uid())) or w.visibility='shared')) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance']) and ((not protected_context) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));
create policy crm_watchlist_items_update on public.crm_watchlist_items for update to authenticated using (exists(select 1 from public.crm_watchlists w where w.organisation_id=crm_watchlist_items.organisation_id and w.id=crm_watchlist_items.watchlist_id and ((w.owner_user_id=(select auth.uid())) or w.visibility='shared')) and (((not protected_context) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance']))) with check (exists(select 1 from public.crm_watchlists w where w.organisation_id=crm_watchlist_items.organisation_id and w.id=crm_watchlist_items.watchlist_id and ((w.owner_user_id=(select auth.uid())) or w.visibility='shared')) and (((not protected_context) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));
create policy crm_watchlist_items_delete on public.crm_watchlist_items for delete to authenticated using (exists(select 1 from public.crm_watchlists w where w.organisation_id=crm_watchlist_items.organisation_id and w.id=crm_watchlist_items.watchlist_id and ((w.owner_user_id=(select auth.uid())) or w.visibility='shared')) and (((not protected_context) and private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','business_development','trader','research_analyst','legal_compliance'])) or private.has_mrcip_role(organisation_id,array['super_admin','managing_director','commodity_manager','trader','legal_compliance'])));

revoke all on public.crm_contact_controls,public.crm_outreach_campaigns,public.crm_outreach_targets,public.crm_activities,public.crm_tasks,public.crm_watchlists,public.crm_watchlist_items from anon,authenticated;
grant select,insert,update on public.crm_contact_controls to authenticated;
grant select,insert,update,delete on public.crm_outreach_campaigns to authenticated;
grant select,insert,update,delete on public.crm_outreach_targets to authenticated;
grant select,insert on public.crm_activities to authenticated;
grant select,insert,update,delete on public.crm_tasks to authenticated;
grant select,insert,update,delete on public.crm_watchlists to authenticated;
grant select,insert,update,delete on public.crm_watchlist_items to authenticated;