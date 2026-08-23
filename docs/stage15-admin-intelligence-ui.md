# Stage 15 — Admin Intelligence UI

## Status

Implemented on branch `stage15-admin-intelligence-ui-contract` as an isolated Next.js 16 Admin Intelligence shell connected to the live Mkhonto Resources Hub Supabase project.

## Implemented routes

- `/admin/intelligence`
- `/admin/intelligence/imports`
- `/admin/intelligence/imports/[batchId]`
- `/admin/intelligence/duplicates`
- `/admin/intelligence/counterparties`
- `/admin/intelligence/mines`
- `/admin/intelligence/laboratories`
- `/admin/intelligence/verification`
- `/admin/intelligence/sources`

## Security model

All routes are server-rendered and protected by `requirePortalAccess('admin')`. Data access uses the browser-safe Supabase publishable key and relies on authenticated sessions plus Row Level Security. Service-role credentials are never exposed to browser code. Protected mine coordinates and sensitive commercial notes are deliberately excluded from ordinary intelligence list screens and remain behind their dedicated RLS policies.

## Stage 15 workflows represented

The UI exposes import batches and rows, validation outcomes, duplicate-review queues, counterparty intelligence, mine intelligence, laboratory intelligence, verification history and source provenance. Mutation helpers exist in `src/lib/mrcip/intelligence/client.ts` for duplicate decisions, import-row review, mapping updates, deterministic duplicate detection, import-batch reconciliation, verification creation and source creation.

## Build validation

`.github/workflows/stage15-admin-build.yml` performs dependency installation, TypeScript checking and a Next.js production build using the repository's public Supabase configuration. The PR remains draft until GitHub reports a successful build run.

## Integration boundary

The historical repository did not contain the original full Admin Portal frontend. Stage 15 therefore reconstructs only the Commodity Intelligence admin surface in an isolated branch. It does not replace or redesign the live public website or unrelated finance, fleet, legal or operations portals. Integration into a subsequently restored full portal should preserve these route contracts and the RLS-first security model.
