create unique index if not exists organisation_memberships_org_user_status_support_idx on public.organisation_memberships(organisation_id,user_id,status);

create table public.crm_contact_controls (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  counterparty_id uuid not null,
  contact_id uuid null,
  contactability_status text not null default 'unknown' check (contactability_status in ('unknown','permitted','restricted','do_not_contact')),
  email_allowed boolean null,
  phone_allowed boolean null,
  whatsapp_allowed boolean null,
  linkedin_allowed boolean null,
  in_person_allowed boolean null,
  restriction_reason text not null default '',
  jurisdiction_notes text not null default '',
  source_document_id uuid null,
  protected_context boolean not null default false,
  verified_at timestamptz null,
  verified_by uuid null references auth.users(id),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint crm_contact_controls_counterparty_fk foreign key (organisation_id,counterparty_id) references public.counterparties(organisation_id,id) on delete cascade,
  constraint crm_contact_controls_contact_fk foreign key (organisation_id,contact_id) references public.counterparty_contacts(organisation_id,id) on delete cascade,
  constraint crm_contact_controls_document_fk foreign key (organisation_id,source_document_id) references public.documents(organisation_id,id) on delete restrict
);
create unique index crm_contact_controls_counterparty_scope_uidx on public.crm_contact_controls(organisation_id,counterparty_id) where contact_id is null;
create unique index crm_contact_controls_contact_scope_uidx on public.crm_contact_controls(organisation_id,contact_id) where contact_id is not null;
create index crm_contact_controls_counterparty_idx on public.crm_contact_controls(organisation_id,counterparty_id,contactability_status);
create index crm_contact_controls_document_idx on public.crm_contact_controls(organisation_id,source_document_id) where source_document_id is not null;
create index crm_contact_controls_verified_by_idx on public.crm_contact_controls(verified_by) where verified_by is not null;
create index crm_contact_controls_created_by_idx on public.crm_contact_controls(created_by);
create index crm_contact_controls_updated_by_idx on public.crm_contact_controls(updated_by);

create table public.crm_outreach_campaigns (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  name text not null,
  campaign_type text not null default 'other' check (campaign_type in ('buyer_acquisition','seller_acquisition','laboratory_network','logistics_partner','relationship_nurture','market_research','other')),
  status text not null default 'draft' check (status in ('draft','active','paused','completed','cancelled')),
  objective text not null default '',
  commodity_id uuid null,
  product_id uuid null,
  owner_user_id uuid not null,
  is_protected boolean not null default false,
  start_date date null,
  end_date date null,
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint crm_outreach_campaigns_commodity_fk foreign key (organisation_id,commodity_id) references public.commodities(organisation_id,id) on delete restrict,
  constraint crm_outreach_campaigns_product_fk foreign key (organisation_id,product_id) references public.commodity_products(organisation_id,id) on delete restrict,
  constraint crm_outreach_campaigns_owner_fk foreign key (organisation_id,owner_user_id) references public.organisation_memberships(organisation_id,user_id) on delete restrict,
  constraint crm_outreach_campaigns_dates_check check (end_date is null or start_date is null or end_date >= start_date)
);
create index crm_outreach_campaigns_status_idx on public.crm_outreach_campaigns(organisation_id,status,start_date,end_date);
create index crm_outreach_campaigns_owner_idx on public.crm_outreach_campaigns(organisation_id,owner_user_id,status);
create index crm_outreach_campaigns_commodity_idx on public.crm_outreach_campaigns(organisation_id,commodity_id,product_id);
create index crm_outreach_campaigns_created_by_idx on public.crm_outreach_campaigns(created_by);
create index crm_outreach_campaigns_updated_by_idx on public.crm_outreach_campaigns(updated_by);

create table public.crm_outreach_targets (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  campaign_id uuid not null,
  counterparty_id uuid not null,
  contact_id uuid null,
  target_role text not null default 'other',
  status text not null default 'researched' check (status in ('researched','ready','contacted','responded','qualified','nurture','disqualified','do_not_contact','converted','closed')),
  priority smallint not null default 3 check (priority between 1 and 5),
  qualification_score numeric(5,2) not null default 0 check (qualification_score between 0 and 100),
  assigned_to uuid null,
  buyer_requirement_id uuid null,
  seller_offer_id uuid null,
  opportunity_id uuid null,
  protected_context boolean not null default false,
  first_contacted_at timestamptz null,
  last_contacted_at timestamptz null,
  next_follow_up_at timestamptz null,
  qualification_notes text not null default '',
  notes text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint crm_outreach_targets_campaign_fk foreign key (organisation_id,campaign_id) references public.crm_outreach_campaigns(organisation_id,id) on delete cascade,
  constraint crm_outreach_targets_counterparty_fk foreign key (organisation_id,counterparty_id) references public.counterparties(organisation_id,id) on delete restrict,
  constraint crm_outreach_targets_contact_fk foreign key (organisation_id,contact_id) references public.counterparty_contacts(organisation_id,id) on delete restrict,
  constraint crm_outreach_targets_requirement_fk foreign key (organisation_id,buyer_requirement_id) references public.buyer_requirements(organisation_id,id) on delete restrict,
  constraint crm_outreach_targets_offer_fk foreign key (organisation_id,seller_offer_id) references public.seller_supply_offers(organisation_id,id) on delete restrict,
  constraint crm_outreach_targets_opportunity_fk foreign key (organisation_id,opportunity_id) references public.opportunities(organisation_id,id) on delete restrict,
  constraint crm_outreach_targets_assigned_fk foreign key (organisation_id,assigned_to) references public.organisation_memberships(organisation_id,user_id) on delete restrict,
  constraint crm_outreach_targets_contact_dates_check check (last_contacted_at is null or first_contacted_at is null or last_contacted_at >= first_contacted_at),
  constraint crm_outreach_targets_converted_check check (status <> 'converted' or opportunity_id is not null or buyer_requirement_id is not null or seller_offer_id is not null)
);
create unique index crm_outreach_targets_campaign_counterparty_uidx on public.crm_outreach_targets(organisation_id,campaign_id,counterparty_id) where contact_id is null;
create unique index crm_outreach_targets_campaign_contact_uidx on public.crm_outreach_targets(organisation_id,campaign_id,contact_id) where contact_id is not null;
create index crm_outreach_targets_status_idx on public.crm_outreach_targets(organisation_id,status,next_follow_up_at,priority);
create index crm_outreach_targets_counterparty_idx on public.crm_outreach_targets(organisation_id,counterparty_id,status);
create index crm_outreach_targets_contact_idx on public.crm_outreach_targets(organisation_id,contact_id) where contact_id is not null;
create index crm_outreach_targets_assigned_idx on public.crm_outreach_targets(organisation_id,assigned_to,status) where assigned_to is not null;
create index crm_outreach_targets_requirement_idx on public.crm_outreach_targets(organisation_id,buyer_requirement_id) where buyer_requirement_id is not null;
create index crm_outreach_targets_offer_idx on public.crm_outreach_targets(organisation_id,seller_offer_id) where seller_offer_id is not null;
create index crm_outreach_targets_opportunity_idx on public.crm_outreach_targets(organisation_id,opportunity_id) where opportunity_id is not null;
create index crm_outreach_targets_created_by_idx on public.crm_outreach_targets(created_by);
create index crm_outreach_targets_updated_by_idx on public.crm_outreach_targets(updated_by);

create table public.crm_activities (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  campaign_id uuid null,
  target_id uuid null,
  counterparty_id uuid not null,
  contact_id uuid null,
  buyer_requirement_id uuid null,
  seller_offer_id uuid null,
  opportunity_id uuid null,
  activity_type text not null default 'other' check (activity_type in ('introduction','follow_up','qualification','document_exchange','meeting','site_visit','call','message','note','other')),
  channel text not null default 'other' check (channel in ('email','phone','whatsapp','linkedin','meeting','in_person','site_visit','portal','internal','other')),
  direction text not null default 'internal' check (direction in ('inbound','outbound','internal')),
  outcome text not null default 'other' check (outcome in ('no_response','responded','interested','not_interested','qualified','requested_information','meeting_scheduled','blocked','other')),
  occurred_at timestamptz not null,
  subject text not null default '',
  summary text not null default '',
  external_reference text not null default '',
  evidence_document_id uuid null,
  next_follow_up_at timestamptz null,
  supersedes_activity_id uuid null,
  protected_context boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint crm_activities_campaign_fk foreign key (organisation_id,campaign_id) references public.crm_outreach_campaigns(organisation_id,id) on delete restrict,
  constraint crm_activities_target_fk foreign key (organisation_id,target_id) references public.crm_outreach_targets(organisation_id,id) on delete restrict,
  constraint crm_activities_counterparty_fk foreign key (organisation_id,counterparty_id) references public.counterparties(organisation_id,id) on delete restrict,
  constraint crm_activities_contact_fk foreign key (organisation_id,contact_id) references public.counterparty_contacts(organisation_id,id) on delete restrict,
  constraint crm_activities_requirement_fk foreign key (organisation_id,buyer_requirement_id) references public.buyer_requirements(organisation_id,id) on delete restrict,
  constraint crm_activities_offer_fk foreign key (organisation_id,seller_offer_id) references public.seller_supply_offers(organisation_id,id) on delete restrict,
  constraint crm_activities_opportunity_fk foreign key (organisation_id,opportunity_id) references public.opportunities(organisation_id,id) on delete restrict,
  constraint crm_activities_document_fk foreign key (organisation_id,evidence_document_id) references public.documents(organisation_id,id) on delete restrict,
  constraint crm_activities_supersedes_fk foreign key (organisation_id,supersedes_activity_id) references public.crm_activities(organisation_id,id) on delete restrict,
  constraint crm_activities_followup_check check (next_follow_up_at is null or next_follow_up_at >= occurred_at)
);
create index crm_activities_counterparty_idx on public.crm_activities(organisation_id,counterparty_id,occurred_at desc);
create index crm_activities_contact_idx on public.crm_activities(organisation_id,contact_id,occurred_at desc) where contact_id is not null;
create index crm_activities_campaign_idx on public.crm_activities(organisation_id,campaign_id,occurred_at desc) where campaign_id is not null;
create index crm_activities_target_idx on public.crm_activities(organisation_id,target_id,occurred_at desc) where target_id is not null;
create index crm_activities_requirement_idx on public.crm_activities(organisation_id,buyer_requirement_id) where buyer_requirement_id is not null;
create index crm_activities_offer_idx on public.crm_activities(organisation_id,seller_offer_id) where seller_offer_id is not null;
create index crm_activities_opportunity_idx on public.crm_activities(organisation_id,opportunity_id) where opportunity_id is not null;
create index crm_activities_document_idx on public.crm_activities(organisation_id,evidence_document_id) where evidence_document_id is not null;
create index crm_activities_supersedes_idx on public.crm_activities(organisation_id,supersedes_activity_id) where supersedes_activity_id is not null;
create index crm_activities_created_by_idx on public.crm_activities(created_by);

create table public.crm_tasks (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  title text not null,
  description text not null default '',
  task_type text not null default 'other' check (task_type in ('research','follow_up','qualification','document_review','kyc','inspection','meeting','outreach','other')),
  outreach_channel text not null default 'none' check (outreach_channel in ('none','email','phone','whatsapp','linkedin','in_person','other')),
  status text not null default 'open' check (status in ('open','in_progress','completed','cancelled')),
  priority smallint not null default 3 check (priority between 1 and 5),
  due_at timestamptz null,
  assigned_to uuid null,
  counterparty_id uuid null,
  contact_id uuid null,
  campaign_id uuid null,
  target_id uuid null,
  buyer_requirement_id uuid null,
  seller_offer_id uuid null,
  opportunity_id uuid null,
  protected_context boolean not null default false,
  completed_at timestamptz null,
  completed_by uuid null references auth.users(id),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint crm_tasks_assigned_fk foreign key (organisation_id,assigned_to) references public.organisation_memberships(organisation_id,user_id) on delete restrict,
  constraint crm_tasks_counterparty_fk foreign key (organisation_id,counterparty_id) references public.counterparties(organisation_id,id) on delete restrict,
  constraint crm_tasks_contact_fk foreign key (organisation_id,contact_id) references public.counterparty_contacts(organisation_id,id) on delete restrict,
  constraint crm_tasks_campaign_fk foreign key (organisation_id,campaign_id) references public.crm_outreach_campaigns(organisation_id,id) on delete restrict,
  constraint crm_tasks_target_fk foreign key (organisation_id,target_id) references public.crm_outreach_targets(organisation_id,id) on delete restrict,
  constraint crm_tasks_requirement_fk foreign key (organisation_id,buyer_requirement_id) references public.buyer_requirements(organisation_id,id) on delete restrict,
  constraint crm_tasks_offer_fk foreign key (organisation_id,seller_offer_id) references public.seller_supply_offers(organisation_id,id) on delete restrict,
  constraint crm_tasks_opportunity_fk foreign key (organisation_id,opportunity_id) references public.opportunities(organisation_id,id) on delete restrict,
  constraint crm_tasks_target_check check (counterparty_id is not null or campaign_id is not null or buyer_requirement_id is not null or seller_offer_id is not null or opportunity_id is not null)
);
create index crm_tasks_queue_idx on public.crm_tasks(organisation_id,status,due_at,priority);
create index crm_tasks_assigned_idx on public.crm_tasks(organisation_id,assigned_to,status,due_at) where assigned_to is not null;
create index crm_tasks_counterparty_idx on public.crm_tasks(organisation_id,counterparty_id) where counterparty_id is not null;
create index crm_tasks_contact_idx on public.crm_tasks(organisation_id,contact_id) where contact_id is not null;
create index crm_tasks_campaign_idx on public.crm_tasks(organisation_id,campaign_id) where campaign_id is not null;
create index crm_tasks_target_idx on public.crm_tasks(organisation_id,target_id) where target_id is not null;
create index crm_tasks_requirement_idx on public.crm_tasks(organisation_id,buyer_requirement_id) where buyer_requirement_id is not null;
create index crm_tasks_offer_idx on public.crm_tasks(organisation_id,seller_offer_id) where seller_offer_id is not null;
create index crm_tasks_opportunity_idx on public.crm_tasks(organisation_id,opportunity_id) where opportunity_id is not null;
create index crm_tasks_completed_by_idx on public.crm_tasks(completed_by) where completed_by is not null;
create index crm_tasks_created_by_idx on public.crm_tasks(created_by);
create index crm_tasks_updated_by_idx on public.crm_tasks(updated_by);

create table public.crm_watchlists (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  name text not null,
  description text not null default '',
  visibility text not null default 'private' check (visibility in ('private','shared')),
  status text not null default 'active' check (status in ('active','archived')),
  owner_user_id uuid not null,
  is_protected boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint crm_watchlists_owner_fk foreign key (organisation_id,owner_user_id) references public.organisation_memberships(organisation_id,user_id) on delete restrict
);
create index crm_watchlists_owner_idx on public.crm_watchlists(organisation_id,owner_user_id,status);
create index crm_watchlists_shared_idx on public.crm_watchlists(organisation_id,visibility,status);
create index crm_watchlists_created_by_idx on public.crm_watchlists(created_by);
create index crm_watchlists_updated_by_idx on public.crm_watchlists(updated_by);

create table public.crm_watchlist_items (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  watchlist_id uuid not null,
  entity_type text not null check (entity_type in ('counterparty','mine','laboratory','buyer_requirement','seller_offer','opportunity')),
  counterparty_id uuid null,
  mine_id uuid null,
  laboratory_id uuid null,
  buyer_requirement_id uuid null,
  seller_offer_id uuid null,
  opportunity_id uuid null,
  priority smallint not null default 3 check (priority between 1 and 5),
  note text not null default '',
  protected_context boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  unique (organisation_id,id),
  constraint crm_watchlist_items_watchlist_fk foreign key (organisation_id,watchlist_id) references public.crm_watchlists(organisation_id,id) on delete cascade,
  constraint crm_watchlist_items_counterparty_fk foreign key (organisation_id,counterparty_id) references public.counterparties(organisation_id,id) on delete restrict,
  constraint crm_watchlist_items_mine_fk foreign key (organisation_id,mine_id) references public.mines(organisation_id,id) on delete restrict,
  constraint crm_watchlist_items_laboratory_fk foreign key (organisation_id,laboratory_id) references public.laboratories(organisation_id,id) on delete restrict,
  constraint crm_watchlist_items_requirement_fk foreign key (organisation_id,buyer_requirement_id) references public.buyer_requirements(organisation_id,id) on delete restrict,
  constraint crm_watchlist_items_offer_fk foreign key (organisation_id,seller_offer_id) references public.seller_supply_offers(organisation_id,id) on delete restrict,
  constraint crm_watchlist_items_opportunity_fk foreign key (organisation_id,opportunity_id) references public.opportunities(organisation_id,id) on delete restrict,
  constraint crm_watchlist_items_entity_check check (
    (entity_type='counterparty' and counterparty_id is not null and mine_id is null and laboratory_id is null and buyer_requirement_id is null and seller_offer_id is null and opportunity_id is null)
    or (entity_type='mine' and counterparty_id is null and mine_id is not null and laboratory_id is null and buyer_requirement_id is null and seller_offer_id is null and opportunity_id is null)
    or (entity_type='laboratory' and counterparty_id is null and mine_id is null and laboratory_id is not null and buyer_requirement_id is null and seller_offer_id is null and opportunity_id is null)
    or (entity_type='buyer_requirement' and counterparty_id is null and mine_id is null and laboratory_id is null and buyer_requirement_id is not null and seller_offer_id is null and opportunity_id is null)
    or (entity_type='seller_offer' and counterparty_id is null and mine_id is null and laboratory_id is null and buyer_requirement_id is null and seller_offer_id is not null and opportunity_id is null)
    or (entity_type='opportunity' and counterparty_id is null and mine_id is null and laboratory_id is null and buyer_requirement_id is null and seller_offer_id is null and opportunity_id is not null)
  )
);
create unique index crm_watchlist_items_counterparty_uidx on public.crm_watchlist_items(organisation_id,watchlist_id,counterparty_id) where counterparty_id is not null;
create unique index crm_watchlist_items_mine_uidx on public.crm_watchlist_items(organisation_id,watchlist_id,mine_id) where mine_id is not null;
create unique index crm_watchlist_items_laboratory_uidx on public.crm_watchlist_items(organisation_id,watchlist_id,laboratory_id) where laboratory_id is not null;
create unique index crm_watchlist_items_requirement_uidx on public.crm_watchlist_items(organisation_id,watchlist_id,buyer_requirement_id) where buyer_requirement_id is not null;
create unique index crm_watchlist_items_offer_uidx on public.crm_watchlist_items(organisation_id,watchlist_id,seller_offer_id) where seller_offer_id is not null;
create unique index crm_watchlist_items_opportunity_uidx on public.crm_watchlist_items(organisation_id,watchlist_id,opportunity_id) where opportunity_id is not null;
create index crm_watchlist_items_created_by_idx on public.crm_watchlist_items(created_by);

alter table public.crm_contact_controls enable row level security;
alter table public.crm_outreach_campaigns enable row level security;
alter table public.crm_outreach_targets enable row level security;
alter table public.crm_activities enable row level security;
alter table public.crm_tasks enable row level security;
alter table public.crm_watchlists enable row level security;
alter table public.crm_watchlist_items enable row level security;

revoke all on public.crm_contact_controls,public.crm_outreach_campaigns,public.crm_outreach_targets,public.crm_activities,public.crm_tasks,public.crm_watchlists,public.crm_watchlist_items from anon,authenticated;