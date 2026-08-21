revoke all on public.buyer_requirements from authenticated;
revoke all on public.seller_supply_offers from authenticated;
revoke all on public.buyer_requirement_specs from authenticated;
revoke all on public.seller_offer_specs from authenticated;
revoke all on public.commodity_matches from authenticated;

grant select, insert, update, delete on public.buyer_requirements to authenticated;
grant select, insert, update, delete on public.seller_supply_offers to authenticated;
grant select, insert, update, delete on public.buyer_requirement_specs to authenticated;
grant select, insert, update, delete on public.seller_offer_specs to authenticated;
grant select, insert, update, delete on public.commodity_matches to authenticated;