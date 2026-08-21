revoke all on public.documents from anon;
revoke all on public.documents from authenticated;
grant select, insert, update, delete on public.documents to authenticated;
