revoke execute on function public.get_my_access() from anon;
revoke execute on function public.can_access_portal(text, uuid) from anon;
revoke execute on function public.complete_organisation_onboarding(text, text, text) from anon;

grant execute on function public.get_my_access() to authenticated;
grant execute on function public.can_access_portal(text, uuid) to authenticated;
grant execute on function public.complete_organisation_onboarding(text, text, text) to authenticated;
