create index if not exists opportunities_org_commodity_idx on public.opportunities (organisation_id, commodity_id);
create index if not exists opportunities_org_match_idx on public.opportunities (organisation_id, match_id);
create index if not exists opportunities_org_offer_idx on public.opportunities (organisation_id, seller_offer_id);
create index if not exists opportunities_org_requirement_idx on public.opportunities (organisation_id, buyer_requirement_id);
create index if not exists opportunity_protocol_controls_org_opportunity_idx on public.opportunity_protocol_controls (organisation_id, opportunity_id);

revoke update on public.opportunity_freight_links from authenticated;
revoke update on public.opportunity_finance_links from authenticated;
revoke update on public.opportunity_negotiation_links from authenticated;
