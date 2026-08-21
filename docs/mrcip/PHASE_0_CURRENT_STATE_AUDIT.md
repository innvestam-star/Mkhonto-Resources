# Mkhonto Resources Commodity Intelligence Platform (MRCIP)

## Phase 0 — Current-State Audit and Stage 1 Gate

Status: **IN PROGRESS — SCHEMA RECOVERY BLOCKER IDENTIFIED**

This audit records only functionality and infrastructure that has been inspected or independently surfaced by the connected Mkhonto Resources GitHub and Supabase environments. It does not assume that a feature exists merely because it appears in a planning prompt.

## 1. Connected production foundation

### Supabase project

- Project: `Mkhonto Resources Hub`
- Project reference: `zjrzzvakwrwkrcqhcnyo`
- Region: `eu-west-2`
- Database: PostgreSQL 17
- Project health: `ACTIVE_HEALTHY`
- Supabase Auth service: running
- Supabase Storage: configured in local Supabase config
- Supabase Realtime: configured in local Supabase config
- Edge Functions: none currently deployed

Classification: **LIVE**

## 2. GitHub repository assessment

Repository: `innvestam-star/Mkhonto-Resources`

The connected repository is not currently a complete copy of the full Mkhonto Resources Admin Platform application. The repository README explicitly states that it contains the Next.js/Supabase integration foundation and that the full application source still needs to be restored.

Observed repository components include:

- `src/lib/supabase/client.ts`
- `src/lib/supabase/server.ts`
- `src/lib/supabase/proxy.ts`
- `src/lib/supabase/access.ts`
- root `proxy.ts`
- `supabase/config.toml`
- Supabase recovery/verification workflows
- migration manifest

No complete admin-page/application source tree is currently present in this repository.

Classification: **PARTIALLY IMPLEMENTED / SOURCE RECOVERY REQUIRED**

## 3. Existing Auth and protected-route foundation

Verified reusable components:

### Browser Supabase client

`src/lib/supabase/client.ts`

Uses the publishable Supabase key and relies on Auth + RLS for data protection.

Classification: **INTEGRATION-READY**

### Server Supabase client

`src/lib/supabase/server.ts`

Uses a request-scoped Supabase SSR client and cookie-based session propagation.

Classification: **INTEGRATION-READY**

### Route/session proxy

`src/lib/supabase/proxy.ts`

Recognises protected portal families:

- `admin`
- `finance`
- `freight`
- `driver`
- `portal`

The proxy validates claims and calls database RPCs to determine portal access.

Classification: **LIVE FOUNDATION / REUSABLE**

### Server-side portal guard

`src/lib/supabase/access.ts`

Uses:

- `can_access_portal(...)`
- `get_my_access()`

Classification: **LIVE FOUNDATION / REUSABLE**

## 4. Existing database surface identified

Direct schema inspection is temporarily blocked by database credential authentication failure. However, the Supabase Database Advisors expose the following existing public tables through index/advisor metadata:

- `organisations`
- `organisation_memberships`
- `clients`
- `drivers`
- `vehicles`
- `trips`
- `trip_events`
- `expenses`
- `documents`
- `finance_documents`
- `finance_line_items`
- `payments`
- `freight_analyses`
- `negotiations`
- `audit_events`

These table names are verified as existing, but their complete columns, constraints, foreign keys and RLS policies have not yet been recovered.

Classification: **LIVE — STRUCTURE PARTIALLY INSPECTED**

## 5. Existing modules that MRCIP should reuse

Subject to column-level verification after schema recovery, the MRCIP architecture should prefer reuse of the following existing entities rather than duplication:

| Existing entity | Proposed MRCIP reuse |
|---|---|
| `organisations` | Canonical company/counterparty identity |
| `organisation_memberships` | User-to-organisation access, tenant and RBAC foundation |
| `clients` | Existing formal customer/client relationship layer |
| `documents` | Commodity certificates, KYC, mandates, NCNDA and supporting files where structurally suitable |
| `finance_documents` | Quotations/invoices/approved commercial documents integration |
| `finance_line_items` | Existing financial line-item engine; do not duplicate calculations |
| `payments` | Settlement/payment linkage where applicable |
| `freight_analyses` | Logistics/freight economics and transport analysis integration |
| `negotiations` | Potential commercial negotiation linkage after schema review |
| `audit_events` | MRCIP audit trail integration if the current structure supports required sensitivity/event metadata |
| `vehicles`, `drivers`, `trips`, `trip_events` | Logistics execution integration where commodity opportunities convert to haulage work |

## 6. Functionality that must not be broken

The following areas are protected regression zones for MRCIP work:

- Supabase Auth and session handling
- role-aware protected routes
- Admin access
- Finance Admin
- Freight Admin
- customer/client records
- quotations and invoices
- VAT calculations
- fixed-amount line items
- finance document relationships
- freight profitability analysis
- payments
- fleet/driver/trip records
- document storage/records
- existing audit history
- public website routing

No MRCIP migration may rename, replace or destructively repurpose these entities without an explicit compatibility migration and regression test.

## 7. Hosted migration history

The repository migration manifest records these applied hosted migrations:

1. `20260803202920` — `mkhonto_hub_phase_4_foundation`
2. `20260803203051` — `mkhonto_hub_fk_indexes`
3. `20260805191833` — `auth_access_and_protected_route_foundation`
4. `20260805191850` — `restrict_auth_rpc_execution`

The manifest explicitly warns that the original SQL migration files must be recovered from the hosted project before new schema changes are committed.

Classification: **BLOCKED / REQUIRES SCHEMA RECOVERY**

## 8. Current schema-recovery blocker

Attempts to:

- list database tables with full metadata;
- execute read-only SQL; and
- generate TypeScript database types

currently fail with database password authentication errors for the Supabase database roles used by the connected tooling.

The hosted project itself remains healthy and Supabase service logs are available, so this is a tooling/database credential problem rather than evidence that production is down.

Required remediation before Stage 1 DDL:

1. restore valid `SUPABASE_DB_PASSWORD` access for the repository/workflow tooling;
2. ensure `SUPABASE_ACCESS_TOKEN` is available to the recovery workflow;
3. run the existing hosted-schema recovery workflow/script;
4. review recovered migration SQL;
5. regenerate `src/types/database.types.ts`;
6. run security/performance advisors;
7. only then create the MRCIP Stage 1 migration.

Until this is complete, **do not run a fresh baseline, destructive push, or manually invent a replacement migration history**.

## 9. Current security findings

Supabase Security Advisor currently reports warnings requiring review before MRCIP increases the platform's sensitive-data footprint:

### SECURITY DEFINER RPC exposure

The following authenticated-callable functions are currently `SECURITY DEFINER`:

- `public.can_access_portal(p_portal text, p_organisation_id uuid)`
- `public.complete_organisation_onboarding(p_name text, p_trading_name text, p_industry text)`
- `public.get_my_access()`

These may be intentional, but their bodies, search paths, grants and caller validation must be reviewed during schema recovery before MRCIP relies on them for protected commodity intelligence.

Status: **REVIEW REQUIRED — DO NOT CHANGE BLINDLY**

### Leaked password protection

Supabase Auth leaked-password protection is currently disabled.

Status: **SECURITY HARDENING RECOMMENDED**

### Auth deprecation notices

Recent Auth logs contain deprecation notices for unsupported GoTrue group-name environment settings.

Status: **CONFIGURATION REVIEW REQUIRED**

## 10. Performance findings

The performance advisor reports numerous currently-unused indexes, including indexes on organisations, clients, finance, freight, trips and audit tables, plus one duplicate-index warning on `organisation_memberships`.

These findings do not justify deleting indexes during MRCIP work. The application is still evolving and index usage must be evaluated against real workloads before removal.

Status: **OBSERVE / DO NOT OPTIMISE PREMATURELY**

## 11. MRCIP gap analysis

The following major MRCIP domains are not verified as existing in the current database and should be treated as **NOT IMPLEMENTED until schema recovery proves otherwise**:

- counterparty multi-role model
- commodity master
- commodity products
- structured commodity specifications
- mines/operations intelligence
- laboratories and laboratory capabilities
- buyer requirements
- seller/supply offers
- research sources and provenance
- verification history
- buyer/seller match engine
- opportunity/deal-room records
- protected introductions
- KYC/KYB transaction profiles
- mandate register
- facilitator chain
- commission schedules for commodity opportunities
- sample/inspection/test requests
- laboratory certificates linked to specifications
- commodity outreach CRM
- watchlists
- intelligence quality scoring
- opportunity/risk scoring
- MRCIP executive dashboard
- MRCIP map intelligence
- AI intelligence retrieval layer

## 12. Recommended Stage 1 data architecture

This architecture is provisional until the recovered schema confirms exact column names and relationships.

### Canonical identity

Prefer extending or linking the existing `organisations` table rather than creating a second disconnected company master.

Recommended new relational concepts:

- `organisation_roles` or `counterparty_roles`
- `organisation_contacts` if no reusable contact table already exists
- `organisation_addresses` if no reusable address structure exists
- `organisation_relationships`
- `commodities`
- `commodity_products`
- `commodity_spec_templates`
- `commodity_spec_fields`
- `organisation_commodities`
- `operations` / `mines`
- `operation_products`
- `research_sources`
- `verification_records`

### Transaction intelligence

Later-stage entities:

- `buyer_requirements`
- `seller_offers`
- `matches`
- `commodity_opportunities`
- `introductions`
- `kyc_records`
- `mandates`
- `facilitator_chain`
- `commission_schedules`
- `test_requests`
- `certificates`
- `communications`
- `tasks`
- `watchlists`

### Integration links

MRCIP records should link, not copy, existing:

- finance documents;
- freight analyses;
- clients;
- documents;
- negotiations;
- payments;
- vehicles/drivers/trips where execution requires logistics.

## 13. RLS/RBAC architecture direction

MRCIP must be organisation/tenant-aware and must enforce protected-data access server-side.

Required access layers:

1. table privileges / Data API grants;
2. RLS policies;
3. application/server authorization;
4. field/redaction strategy for protected sources;
5. export/report authorization;
6. audit events for protected information access.

Protected source details, KYC documents, pricing, banking information and commission data must never rely on UI-only hiding.

Current Supabase platform behaviour also requires migrations to use explicit table grants where Data API exposure is intended; RLS remains a separate control layer.

## 14. Seed-data status

The currently searchable Mkhonto file library contains related commodity intelligence datasets including:

- global buyers/offtakers database;
- commodity sellers database;
- detailed mine contacts database.

The exact consolidated workbook named in the implementation prompt has not yet been located through the connected file-library search in this audit session. No import should claim completion until that source workbook is available and its sheets are inspected.

Related data should therefore be treated as **SEED INTELLIGENCE / NOT AUTOMATICALLY VERIFIED**.

## 15. Workbook import architecture

The importer should use a staging workflow:

`UPLOAD -> PARSE -> MAP -> NORMALISE -> VALIDATE -> DUPLICATE REVIEW -> PREVIEW -> APPROVE -> IMPORT -> AUDIT`

Required staging controls:

- original filename;
- sheet name;
- row number/source reference;
- original source URL;
- original verification status;
- import batch ID;
- parse/validation errors;
- duplicate candidates;
- user approval;
- final record IDs;
- rollback/failed-row handling.

No import may silently overwrite canonical organisations.

## 16. Phase 1 implementation gate

### Can proceed now

- current-state architecture documentation;
- implementation register;
- workbook-to-domain mapping design;
- RLS/RBAC design;
- Stage 1 migration design review;
- source-data normalization rules;
- UI/navigation specification.

### Cannot safely apply yet

- production MRCIP DDL;
- new production tables;
- RLS migration changes;
- destructive schema refactors;
- data import into production tables.

Reason: authoritative hosted migration SQL and database types have not yet been recovered.

## 17. Stage 1 recommendation

Once schema recovery succeeds, Stage 1 should be implemented in this order:

1. confirm whether `organisations` is the canonical Counterparty Master;
2. extend multi-role organisation classification without duplicating companies;
3. add commodity/product/specification foundation;
4. add source-provenance and verification primitives;
5. add mines/operations and laboratory foundations;
6. add RLS and explicit API grants;
7. add indexes and constraints;
8. generate TypeScript types;
9. test cross-tenant access and protected-data denial;
10. run security/performance advisors;
11. import a small controlled seed batch;
12. audit and remediate before expanding the import.

Phase 1 is not signed off until the migration is recoverable, tested and regression-safe.
