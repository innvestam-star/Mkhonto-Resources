create table public.intelligence_import_batches (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  source_file_name text not null,
  source_file_type text not null check (source_file_type in ('xlsx','csv')),
  source_checksum text not null default '',
  source_document_id uuid references public.documents(id) on delete set null,
  source_description text not null default '',
  status text not null default 'uploaded' check (status in ('uploaded','mapping','validating','review_required','ready','importing','completed','partial_failure','failed','cancelled')),
  column_mapping jsonb not null default '{}'::jsonb,
  total_rows integer not null default 0 check (total_rows >= 0),
  valid_rows integer not null default 0 check (valid_rows >= 0),
  warning_rows integer not null default 0 check (warning_rows >= 0),
  error_rows integer not null default 0 check (error_rows >= 0),
  duplicate_rows integer not null default 0 check (duplicate_rows >= 0),
  imported_rows integer not null default 0 check (imported_rows >= 0),
  started_at timestamptz,
  completed_at timestamptz,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organisation_id, source_checksum, source_file_name)
);

create index intelligence_import_batches_org_status_idx on public.intelligence_import_batches (organisation_id, status, created_at desc);
create index intelligence_import_batches_document_idx on public.intelligence_import_batches (source_document_id) where source_document_id is not null;
create index intelligence_import_batches_created_by_idx on public.intelligence_import_batches (created_by);

create table public.intelligence_import_rows (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  batch_id uuid not null references public.intelligence_import_batches(id) on delete cascade,
  source_sheet text not null default '',
  source_row_number integer not null check (source_row_number > 0),
  entity_type text not null default 'counterparty' check (entity_type in ('counterparty','contact','mine','laboratory','commodity','outreach','other')),
  raw_data jsonb not null default '{}'::jsonb,
  normalized_data jsonb not null default '{}'::jsonb,
  validation_status text not null default 'pending' check (validation_status in ('pending','valid','warning','error','duplicate_review','approved','rejected','imported')),
  validation_messages jsonb not null default '[]'::jsonb,
  target_table text not null default '',
  target_record_id uuid,
  imported_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (batch_id, source_sheet, source_row_number)
);

create index intelligence_import_rows_batch_status_idx on public.intelligence_import_rows (batch_id, validation_status, source_row_number);
create index intelligence_import_rows_org_entity_idx on public.intelligence_import_rows (organisation_id, entity_type, validation_status);
create index intelligence_import_rows_reviewed_by_idx on public.intelligence_import_rows (reviewed_by) where reviewed_by is not null;

create table public.intelligence_duplicate_candidates (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  import_row_id uuid not null references public.intelligence_import_rows(id) on delete cascade,
  candidate_counterparty_id uuid references public.counterparties(id) on delete cascade,
  candidate_contact_id uuid references public.counterparty_contacts(id) on delete cascade,
  candidate_mine_id uuid references public.mines(id) on delete cascade,
  candidate_laboratory_id uuid references public.laboratories(id) on delete cascade,
  match_score numeric(5,2) not null check (match_score between 0 and 100),
  matched_fields jsonb not null default '[]'::jsonb,
  decision text not null default 'pending' check (decision in ('pending','merge','keep_separate','not_duplicate','rejected')),
  decided_by uuid references auth.users(id) on delete set null,
  decided_at timestamptz,
  notes text not null default '',
  created_at timestamptz not null default now(),
  check (num_nonnulls(candidate_counterparty_id, candidate_contact_id, candidate_mine_id, candidate_laboratory_id) = 1)
);

create index intelligence_duplicate_candidates_row_idx on public.intelligence_duplicate_candidates (import_row_id, decision, match_score desc);
create index intelligence_duplicate_candidates_counterparty_idx on public.intelligence_duplicate_candidates (candidate_counterparty_id) where candidate_counterparty_id is not null;
create index intelligence_duplicate_candidates_contact_idx on public.intelligence_duplicate_candidates (candidate_contact_id) where candidate_contact_id is not null;
create index intelligence_duplicate_candidates_mine_idx on public.intelligence_duplicate_candidates (candidate_mine_id) where candidate_mine_id is not null;
create index intelligence_duplicate_candidates_lab_idx on public.intelligence_duplicate_candidates (candidate_laboratory_id) where candidate_laboratory_id is not null;
create index intelligence_duplicate_candidates_decided_by_idx on public.intelligence_duplicate_candidates (decided_by) where decided_by is not null;

create trigger intelligence_import_batches_touch_updated_at before update on public.intelligence_import_batches for each row execute function private.touch_updated_at();
