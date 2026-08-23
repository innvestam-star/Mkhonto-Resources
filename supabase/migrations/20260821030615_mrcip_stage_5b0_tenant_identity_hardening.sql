alter table public.opportunity_protection_records
  add constraint opportunity_protection_records_org_id_unique unique (organisation_id, id);

alter table public.payments
  add constraint payments_org_id_unique unique (organisation_id, id);