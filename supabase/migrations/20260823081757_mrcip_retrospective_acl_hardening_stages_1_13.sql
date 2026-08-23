do $$
declare
  r record;
begin
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname not in (
        'organisations','organisation_memberships','clients','drivers','vehicles','trips','trip_events','expenses','documents','finance_documents','finance_line_items','payments','freight_analyses','negotiations','audit_events','profiles'
      )
  loop
    execute format('revoke all privileges on table public.%I from anon', r.relname);
    execute format('revoke truncate, references, trigger on table public.%I from authenticated', r.relname);
  end loop;
end
$$;