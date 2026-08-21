create table public.commodities (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  group_key text not null,
  name text not null,
  description text not null default '',
  regulated_workflow boolean not null default false,
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organisation_id, group_key)
);

create table public.commodity_products (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  commodity_id uuid not null references public.commodities(id) on delete cascade,
  product_key text not null,
  name text not null,
  description text not null default '',
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (commodity_id, product_key)
);

create index commodity_products_org_commodity_idx on public.commodity_products (organisation_id, commodity_id, active);

create table public.commodity_spec_fields (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  commodity_id uuid not null references public.commodities(id) on delete cascade,
  field_key text not null,
  label text not null,
  data_type text not null default 'numeric' check (data_type in ('numeric','text','boolean','date','select')),
  default_unit text not null default '',
  allowed_units text[] not null default '{}',
  allowed_bases text[] not null default '{}',
  allowed_values text[] not null default '{}',
  supports_min boolean not null default true,
  supports_max boolean not null default true,
  supports_typical boolean not null default true,
  test_method_hint text not null default '',
  required_by_default boolean not null default false,
  display_order integer not null default 0,
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (commodity_id, field_key)
);

create index commodity_spec_fields_org_commodity_idx on public.commodity_spec_fields (organisation_id, commodity_id, display_order);

create table public.counterparty_commodities (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  counterparty_id uuid not null references public.counterparties(id) on delete cascade,
  commodity_id uuid not null references public.commodities(id) on delete cascade,
  product_id uuid references public.commodity_products(id) on delete set null,
  relationship_type text not null default 'interested' check (relationship_type in ('produces','sells','buys','trades','offtakes','exports','imports','tests','inspects','transports','interested')),
  notes text not null default '',
  active boolean not null default true,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique nulls not distinct (counterparty_id, commodity_id, product_id, relationship_type)
);

create index counterparty_commodities_org_commodity_idx on public.counterparty_commodities (organisation_id, commodity_id, relationship_type, active);

create table public.intelligence_sources (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  counterparty_id uuid references public.counterparties(id) on delete cascade,
  contact_id uuid references public.counterparty_contacts(id) on delete cascade,
  commodity_id uuid references public.commodities(id) on delete cascade,
  product_id uuid references public.commodity_products(id) on delete cascade,
  source_name text not null,
  source_url text not null default '',
  source_type text not null default 'public' check (source_type in ('public','private','internal','document','direct_contact','import')),
  discovered_at timestamptz,
  imported_at timestamptz,
  last_checked_at timestamptz,
  captured_by uuid references auth.users(id) on delete set null,
  confidence_score numeric(5,2) not null default 0 check (confidence_score between 0 and 100),
  verification_status text not null default 'unverified',
  source_document_id uuid references public.documents(id) on delete set null,
  source_sheet text not null default '',
  source_row text not null default '',
  notes text not null default '',
  created_at timestamptz not null default now(),
  check (num_nonnulls(counterparty_id, contact_id, commodity_id, product_id) = 1)
);

create index intelligence_sources_org_checked_idx on public.intelligence_sources (organisation_id, last_checked_at);
create index intelligence_sources_counterparty_idx on public.intelligence_sources (counterparty_id) where counterparty_id is not null;
create index intelligence_sources_contact_idx on public.intelligence_sources (contact_id) where contact_id is not null;

create table public.verification_records (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  counterparty_id uuid references public.counterparties(id) on delete cascade,
  contact_id uuid references public.counterparty_contacts(id) on delete cascade,
  verification_type text not null default 'general',
  status text not null check (status in ('unverified','partially_verified','public_source_confirmed','contact_confirmed','documentation_verified','commercially_verified','verified_directly','failed','expired','rejected')),
  verified_at timestamptz,
  verified_by uuid references auth.users(id) on delete set null,
  source_id uuid references public.intelligence_sources(id) on delete set null,
  valid_until date,
  confidence_score numeric(5,2) not null default 0 check (confidence_score between 0 and 100),
  notes text not null default '',
  created_at timestamptz not null default now(),
  check (num_nonnulls(counterparty_id, contact_id) = 1)
);

create index verification_records_org_status_idx on public.verification_records (organisation_id, status, valid_until);

insert into public.commodities (organisation_id, group_key, name, regulated_workflow, created_by)
select o.id, seed.group_key, seed.name, seed.regulated, o.created_by
from public.organisations o
cross join (values
  ('coal','Coal',false),('chrome','Chrome',false),('manganese','Manganese',false),('iron_ore','Iron Ore',false),
  ('base_metals','Base Metals',false),('industrial_minerals','Industrial Minerals',false),('precious_metals','Precious Metals',false),
  ('diamonds_precious_stones','Diamonds & Precious Stones',false),('critical_minerals','Critical Minerals',false),
  ('energy_products','Energy Products',true),('other','Other Commodities',false)
) as seed(group_key,name,regulated);

insert into public.commodity_products (organisation_id, commodity_id, product_key, name, created_by)
select c.organisation_id, c.id, seed.product_key, seed.name, o.created_by
from public.commodities c
join public.organisations o on o.id = c.organisation_id
join (values
  ('coal','rb1','RB1'),('coal','rb2','RB2'),('coal','rb3','RB3'),('coal','rb4','RB4'),('coal','rb5','RB5'),
  ('coal','rbct_export','RBCT Export Coal'),('coal','rom','ROM Coal'),('coal','duff','Coal Duff / Fines'),('coal','peas','Coal Peas'),
  ('coal','small_nuts','Small Nuts'),('coal','large_nuts','Large Nuts'),('coal','cobbles','Cobbles'),('coal','anthracite','Anthracite'),
  ('coal','washed','Washed Coal'),('coal','unwashed','Unwashed Coal'),('coal','thermal','Thermal Coal'),('coal','metallurgical','Metallurgical Coal'),
  ('coal','coking','Coking Coal'),('coal','custom','Custom Specification'),
  ('chrome','rom_chrome','ROM Chrome Ore'),('chrome','chrome_concentrate','Chrome Concentrate'),('chrome','lumpy_chrome','Lumpy Chrome'),('chrome','ferrochrome','Ferrochrome'),
  ('manganese','manganese_ore','Manganese Ore'),('manganese','manganese_concentrate','Manganese Concentrate'),
  ('iron_ore','iron_ore','Iron Ore'),('iron_ore','magnetite','Magnetite'),('iron_ore','hematite','Hematite'),('iron_ore','concentrate','Iron Ore Concentrate'),
  ('base_metals','copper','Copper'),('base_metals','copper_concentrate','Copper Concentrate'),('base_metals','cobalt','Cobalt'),('base_metals','nickel','Nickel'),('base_metals','zinc','Zinc'),('base_metals','lead','Lead'),
  ('industrial_minerals','limestone','Limestone'),('industrial_minerals','dolomite','Dolomite'),('industrial_minerals','silica','Silica'),('industrial_minerals','aggregates','Aggregates'),('industrial_minerals','graphite','Graphite'),('industrial_minerals','mineral_sands','Mineral Sands'),
  ('precious_metals','gold','Gold'),('precious_metals','platinum','Platinum'),('precious_metals','palladium','Palladium'),('precious_metals','rhodium','Rhodium'),('precious_metals','pgms','PGMs'),
  ('diamonds_precious_stones','rough_diamonds','Rough Diamonds'),('diamonds_precious_stones','emeralds','Emeralds'),('diamonds_precious_stones','rubies','Rubies'),('diamonds_precious_stones','sapphires','Sapphires'),
  ('critical_minerals','lithium','Lithium'),('critical_minerals','cobalt','Cobalt'),('critical_minerals','nickel','Nickel'),('critical_minerals','graphite','Graphite'),
  ('energy_products','diesel','Diesel'),('energy_products','petroleum_products','Petroleum Products'),('energy_products','lubricants','Lubricants'),('energy_products','gas','Gas')
) as seed(group_key,product_key,name) on seed.group_key = c.group_key;

insert into public.commodity_spec_fields (organisation_id, commodity_id, field_key, label, data_type, default_unit, allowed_units, allowed_bases, supports_min, supports_max, supports_typical, display_order, created_by)
select c.organisation_id, c.id, seed.field_key, seed.label, seed.data_type, seed.unit, seed.units, seed.bases, seed.min_ok, seed.max_ok, seed.typ_ok, seed.display_order, o.created_by
from public.commodities c
join public.organisations o on o.id = c.organisation_id
join (values
  ('calorific_value','Calorific Value','numeric','kcal/kg',array['kcal/kg','MJ/kg']::text[],array['ADB','ARB','NAR','GAR']::text[],true,true,true,10),
  ('total_moisture','Total Moisture','numeric','%',array['%']::text[],array['ARB','ADB']::text[],true,true,true,20),
  ('inherent_moisture','Inherent Moisture','numeric','%',array['%']::text[],array['ADB']::text[],true,true,true,30),
  ('ash','Ash','numeric','%',array['%']::text[],array['ADB','ARB']::text[],true,true,true,40),
  ('volatile_matter','Volatile Matter','numeric','%',array['%']::text[],array['ADB','DAF']::text[],true,true,true,50),
  ('fixed_carbon','Fixed Carbon','numeric','%',array['%']::text[],array['ADB','DAF']::text[],true,true,true,60),
  ('total_sulphur','Total Sulphur','numeric','%',array['%']::text[],array['ADB','ARB']::text[],true,true,true,70),
  ('phosphorus','Phosphorus','numeric','%',array['%']::text[],array['ADB']::text[],true,true,true,80),
  ('hgi','HGI','numeric','',array[]::text[],array[]::text[],true,true,true,90),
  ('size','Size','text','mm',array['mm']::text[],array[]::text[],false,false,true,100),
  ('sizing_tolerance','Sizing Tolerance','text','',array[]::text[],array[]::text[],false,false,true,110),
  ('aft','Ash Fusion Temperature','numeric','°C',array['°C']::text[],array[]::text[],true,true,true,120),
  ('chlorine','Chlorine','numeric','%',array['%']::text[],array['ADB','ARB']::text[],true,true,true,130),
  ('origin','Origin','text','',array[]::text[],array[]::text[],false,false,true,140),
  ('washing_status','Washing Status','select','',array[]::text[],array[]::text[],false,false,true,150)
) as seed(field_key,label,data_type,unit,units,bases,min_ok,max_ok,typ_ok,display_order) on c.group_key = 'coal';
