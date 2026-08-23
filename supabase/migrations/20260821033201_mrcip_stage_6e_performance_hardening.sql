create index commission_settlement_batches_source_payment_cover_idx
  on public.commission_settlement_batches(organisation_id, source_payment_id)
  where source_payment_id is not null;
