create unique index if not exists documents_org_id_uidx on public.documents (organisation_id, id);
alter table public.seller_offer_specs drop constraint if exists seller_offer_specs_certificate_document_id_fkey;
alter table public.seller_offer_specs add constraint seller_offer_specs_certificate_document_fk foreign key (organisation_id, certificate_document_id) references public.documents(organisation_id, id);
drop index if exists public.seller_offer_specs_certificate_idx;
create index seller_offer_specs_certificate_idx on public.seller_offer_specs (organisation_id, certificate_document_id) where certificate_document_id is not null;