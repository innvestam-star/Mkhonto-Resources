# MRCIP Stage 2 Implementation Audit

Date: 2026-08-21

## Scope

Stage 2 extended the signed-off MRCIP foundation with the Mines & Sources registry, Laboratory/Inspection network foundation, and a controlled intelligence import-staging and duplicate-review workflow.

## Implemented

| Requirement | Status | Implementation |
|---|---|---|
| Mines & Sources registry | LIVE FOUNDATION | `public.mines` |
| Protected mine/source data | LIVE FOUNDATION | `public.mine_protected_details` |
| Mine ↔ commodity/product relationships | LIVE FOUNDATION | `public.mine_products` |
| Laboratory registry | LIVE FOUNDATION | `public.laboratories` |
| Laboratory capability model | LIVE FOUNDATION | `public.laboratory_capabilities` |
| Import batch control | LIVE FOUNDATION | `public.intelligence_import_batches` |
| Row-level import staging | LIVE FOUNDATION | `public.intelligence_import_rows` |
| Duplicate-review candidates | LIVE FOUNDATION | `public.intelligence_duplicate_candidates` |
| Stage 2 RLS/RBAC | LIVE | Explicit authenticated MRCIP-role policies |
| Stage 2 performance hardening | LIVE | Tenant/FK indexes and advisor pass |

## Security design

- Mine direct coordinates, mine-gate data, stockpile location/coordinates and protected commercial/source notes are stored separately from the general mine profile.
- `mine_protected_details` is readable only by privileged MRCIP roles: Super Admin, Managing Director, Commodity Manager, Trader and Legal/Compliance.
- Research/import staging is restricted to authorised intelligence/compliance roles.
- All eight new Stage 2 public tables were confirmed with RLS enabled.
- No UI-only masking is relied upon for protected mine/source data.

## Import safety

The import architecture now supports:

**UPLOAD → MAP → VALIDATE → DUPLICATE REVIEW → APPROVE → IMPORT → AUDIT**

It stores the original row payload and a separate normalised payload, records validation messages, tracks import state, and requires duplicate candidates to be explicitly reviewed rather than silently merged.

No buyer, seller, mine or laboratory intelligence was automatically inserted into master tables during this stage. This is deliberate: source workbooks must first enter the staging/review process and retain provenance/verification state.

## Verification

- Exact Stage 2 migration versions are applied in hosted Supabase and mirrored to GitHub.
- TypeScript database type generation succeeds after Stage 2.
- Security advisor: no new Stage 2 warnings; remaining warnings predate MRCIP.
- Performance advisor: Stage 2 unindexed-FK warning remediated. Remaining new-table notices are informational unused-index notices because the tables have no imported data yet.
- Existing `clients`, `finance_documents` and `freight_analyses` row counts remained unchanged.

## Current data state

- Mines: 0
- Laboratories: 0
- Import batches: 0
- Import rows: 0

The schema is ready for controlled seed ingestion once the relevant source workbook(s) are accessible to the implementation runtime.

## Limitations / dependencies

1. The exact consolidated workbook named `Mkhonto Resources Global Commodity Intelligence Database.xlsx` has not been resolved as an implementation-accessible file.
2. Separate buyer/offtaker and seller database files were located in the File Library search, but were not imported blindly.
3. The complete Mkhonto Admin frontend source is still not present in the connected GitHub repository, so Mines/Laboratories/Import screens cannot yet be truthfully marked LIVE.

## Stage 2 conclusion

**Stage 2 database and security foundation: SIGNED OFF.**

Next database stage: structured Buyer Requirements + Seller Supply Offers + specification values, followed by deterministic explainable matching. Data seeding can proceed independently once the source workbook is available to the implementation path.
