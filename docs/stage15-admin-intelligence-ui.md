# MRCIP Stage 15 — Admin Intelligence UI Contract

## Status

The live Supabase backend contains the Stage 15 intelligence/import/verification/protection foundation. This repository does not currently contain the full Admin Portal application UI, so this document defines the route and data contract to use when the full frontend source is restored.

## Required Admin routes

### `/admin/intelligence/imports`

Purpose: Import Centre landing page.

Show:
- import batches ordered newest first;
- source file name and type;
- status badge;
- total, valid, warning, error, duplicate and imported row counts;
- started/completed timestamps;
- actions: open batch, continue mapping, review duplicates, retry validation, cancel where permitted.

Use:
- `listImportBatches()`
- `refreshImportBatchStats()`

### `/admin/intelligence/imports/[batchId]`

Purpose: mapping, validation and preview workspace.

Sections:
1. source metadata;
2. column mapping;
3. validation summary;
4. row preview;
5. filters by entity type and validation status;
6. duplicate-review queue;
7. approval/rejection controls.

Use:
- `listImportRows()`
- `updateImportBatchMapping()`
- `detectDuplicates()`
- `refreshImportBatchStats()`
- `reviewImportRow()`

Do not mark a row imported from the browser unless the import executor has successfully created the target record and provenance entry.

### `/admin/intelligence/duplicates`

Purpose: human review of deterministic duplicate candidates.

Show:
- incoming normalized record;
- candidate record;
- match score 0–100;
- matched fields;
- candidate entity type;
- provenance on both records where available;
- decision controls.

Allowed decisions:
- `merge`
- `keep_separate`
- `not_duplicate`
- `rejected`

Use `decideDuplicateCandidate()`.

A merge decision is a review outcome, not permission to perform destructive browser-side record merging. Actual merge execution must preserve source history and audit trail.

### `/admin/intelligence/counterparties`

Purpose: intelligence company directory.

Show:
- legal/trading name;
- role classifications;
- registration/domain/contact indicators;
- verification status;
- confidence score;
- last verified date;
- open data-quality/risk indicators when available.

Use `listCounterpartiesForIntelligence()`.

### `/admin/intelligence/mines`

Purpose: mine intelligence directory.

Show public/authorised fields only by default. Protected mine gate coordinates, stockpile coordinates and sensitive commercial notes must never be requested or rendered for users who do not have the applicable RLS/role permission.

Use `listMinesForIntelligence()` for the standard list. Read `mine_protected_details` only from an authorised protected-detail screen and rely on RLS as the final enforcement layer.

### `/admin/intelligence/laboratories`

Purpose: laboratory directory and verification workspace.

Show:
- laboratory name/location;
- accreditation body/number/expiry;
- capabilities;
- typical turnaround;
- preferred status;
- verification state and last verified timestamp.

Use `listLaboratoriesForIntelligence()`.

### `/admin/intelligence/verification`

Purpose: verification queue for counterparties, contacts, mines and laboratories.

A verification record must target exactly one entity.

Use `createVerificationRecord()`.

Allowed verification states:
- `unverified`
- `partially_verified`
- `public_source_confirmed`
- `contact_confirmed`
- `documentation_verified`
- `commercially_verified`
- `verified_directly`
- `failed`
- `expired`
- `rejected`

### `/admin/intelligence/sources`

Purpose: provenance browser.

Each material intelligence claim should retain source name, source URL/type, discovery/check dates, confidence score, verification status and any source document/import-row linkage.

Use `createIntelligenceSource()` for controlled writes.

## Security rules

1. All client/server requests must use authenticated Supabase sessions.
2. Never use a service-role key in browser code.
3. Do not duplicate role logic in the UI as the primary access control; UI checks are convenience only. RLS remains authoritative.
4. Protected contacts and `mine_protected_details` must not be prefetched into generic list views.
5. Keep provenance when importing or merging. Do not overwrite the last known source with a new source.
6. Duplicate review and verification decisions must include the acting user where the schema provides `decided_by`, `reviewed_by` or `verified_by`.
7. Browser imports must not bypass validation or duplicate review by writing directly to master records.

## Suggested visual layout

Use the existing Mkhonto Resources premium navy/gold system. Prioritise dense enterprise data presentation over decorative cards.

Recommended pattern:
- persistent left Admin navigation;
- top intelligence summary strip;
- filter/search toolbar;
- primary data table;
- right-side review drawer for row details, provenance, verification and duplicate comparison;
- explicit warning styling for unverified, expired and duplicate-review records;
- protected-data indicator for fields hidden by policy.

## Stage 15 sign-off boundary

Backend: implemented and audited in the live Supabase project.

Repository integration layer: implemented on feature branch `stage15-admin-intelligence-ui-contract`.

Full visual Admin Portal: pending restoration/synchronisation of the application's complete frontend source into this repository or access to the live site-editing surface.
