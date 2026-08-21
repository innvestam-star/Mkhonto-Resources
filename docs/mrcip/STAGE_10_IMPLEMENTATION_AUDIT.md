# MRCIP Stage 10 Implementation Audit & Sign-Off

## Stage

**Stage 10 — Reports, Watchlist Signals & Authorised Intelligence Retrieval Foundation**

## Status

**SIGNED OFF — DATABASE / SECURITY / REPORTING / SIGNAL / RETRIEVAL FOUNDATION COMPLETE**

Stage 10 is live in the hosted **Mkhonto Resources Hub** project and reconciled to source control through:

`20260821045834_mrcip_stage_10e_performance_hardening`

## Purpose

Stage 10 converts the structured MRCIP domains built in Stages 1–9 into governed operational reporting, deterministic watchlist signals and authorised intelligence retrieval without creating a second CRM/watchlist model, duplicating Finance/Freight calculations, or authorising autonomous AI/outreach/deal decisions.

The Stage 10 operating model is:

**DEFINE REPORT → DERIVE AUTHORITATIVE SNAPSHOT → WATCH CANONICAL ENTITIES → REFRESH DETERMINISTIC SIGNALS → SEARCH RLS-AUTHORISED INTELLIGENCE → AUDIT PURPOSE/SCOPE/RESULT COUNT → HUMAN REVIEW**

Stage 10 reuses:

- Stage 1 canonical counterparties/commodities/RBAC;
- Stage 2 mines/laboratories;
- Stage 3 requirements/offers/matching;
- Stage 4 protected opportunities and disclosure controls;
- Stage 8 CRM watchlists;
- Stage 9 quality/risk/readiness snapshots and operational read models.

It does not create competing master-data or dashboard models.

## Hosted migrations

| Version | Migration | Purpose |
|---|---|---|
| `20260821045132` | `mrcip_stage_10a_reports_signals_retrieval_foundation` | Report definitions/runs, watchlist signal snapshots, retrieval audit requests, tenant-safe relationships and initial RLS/grant lockdown |
| `20260821045323` | `mrcip_stage_10b_report_engine_and_security` | Deterministic report engine, report RLS/grants, report RPC and security-invoker report catalog view |
| `20260821045414` | `mrcip_stage_10c_watchlist_signal_engine` | Deterministic entity/watchlist signal derivation, protected-context enforcement, refresh RPC and current-signal view |
| `20260821045457` | `mrcip_stage_10d_authorised_retrieval_foundation` | RLS-aware canonical intelligence search, protected retrieval gating, purpose/result audit and retrieval audit view |
| `20260821045834` | `mrcip_stage_10e_performance_hardening` | Covering indexes for the five Stage 10 FK relationships identified by the performance advisor |

## Migration byte identity

The five repository SQL files are byte-identical to the hosted `supabase_migrations.schema_migrations` SQL bodies.

Hosted-computed Git blob SHA-1 values matched GitHub blob SHAs exactly:

- Stage 10a: `8a148d63428f79ac4e41b7fd617f385f63486682`
- Stage 10b: `d0455c007c5f0e87dc3cbaa9995303936d373658`
- Stage 10c: `90da61b284357645ebe5273ed498c5aadeabba57`
- Stage 10d: `8b465600a39ed4f706ba280e518a335cde3defb2`
- Stage 10e: `683a6842b8cbbcce35fdf6f80f025d3b60eb225b`

The corresponding hosted SQL MD5 values were also captured:

- 10a `83ffd7f32d18fec3862a2092ed7a2a7d`
- 10b `e381587a6db08493429a7ed8e03a8c6c`
- 10c `1ae36a02c3c0893f350a70f99d366842`
- 10d `bfefa10120d9094bf9237ec41c518ebd`
- 10e `f1fb609bcb60ae50244f61fe8272e563`

Do not squash later Stage 10 migrations backward into earlier historical files.

## Stage 10 tables

### 1. `mrcip_report_definitions`

Controlled report configuration with:

- tenant scope;
- report key/name/description;
- report kinds: `counterparty_health`, `opportunity_pipeline`, `risk_register`, `watchlist_signals`;
- private/shared/executive visibility;
- owner;
- optional commodity/watchlist scope;
- JSON filters for future governed expansion;
- protected-context marker;
- active lifecycle.

No arbitrary SQL text is stored in report definitions.

Risk-register and opportunity-pipeline reports are automatically protected. Watchlist-signal reports inherit watchlist protection. Executive reports require executive authority.

### 2. `mrcip_report_runs`

Append-only report snapshots containing only database-derived:

- report kind;
- row count;
- structured summary;
- protection state;
- algorithm version;
- generation actor/time.

`mrcip-report-v1` recalculates the report output in a trigger. Caller-supplied summary/count values are not authoritative.

### 3. `mrcip_watchlist_signal_snapshots`

Append-only derived signal snapshots for existing Stage 8 watchlist items. The table does not replace `crm_watchlists` or `crm_watchlist_items`.

Each snapshot records:

- typed watched entity;
- signal count;
- highest severity;
- structured signal/evidence payload;
- inherited protected context;
- deterministic algorithm version;
- generation actor/time.

### 4. `mrcip_retrieval_requests`

Append-only authorised retrieval audit containing:

- query text;
- explicit purpose;
- entity scope;
- protected-intelligence request flag;
- result limit;
- system-calculated result count;
- status/algorithm version;
- requester/timestamps.

The audit row cannot be edited through authenticated Data API grants after insertion.

## Deterministic reports

### Counterparty health

Derives:

- counterparty count;
- verified count;
- stale/missing verification count;
- average latest quality score;
- quality-grade A–E distribution;
- optional commodity scope.

### Opportunity pipeline

Derives from the Stage 9 security-invoker operational opportunity view:

- opportunity count;
- average readiness;
- readiness-band distribution;
- disclosure-eligible count;
- overdue next actions;
- stage distribution;
- optional commodity scope.

### Risk register

Privileged/protected report deriving:

- scored-counterparty count;
- low/moderate/high/critical risk distribution;
- open/mitigated risk-flag count;
- optional commodity scope.

### Watchlist signals

Derives latest snapshot metrics for a selected Stage 8 watchlist:

- watched items with signal snapshots;
- items currently carrying signals;
- total signal count;
- highest-severity distribution.

## Watchlist signal engine v1

Signal snapshots are recalculated by the database and cannot be authored by supplying custom signal JSON/count/severity.

Current deterministic signals include:

### Counterparty

- verification missing/stale >180 days — medium;
- quality grade D — medium;
- quality grade E — high;
- privileged users only: high/critical latest internal risk state.

### Mine

- verification missing/stale >180 days;
- `care_maintenance` — medium;
- suspended/closed — high.

No protected mine coordinates or gate/stockpile locations are included.

### Laboratory

- verification missing/stale >180 days;
- accreditation expired — high;
- accreditation expiring within 30 days — medium.

### Buyer requirement

- expired validity — high;
- validity ending within 7 days — medium.

### Seller offer

- protected-context inheritance;
- expired validity — high;
- validity ending within 7 days — medium;
- active offer with unverified authority and/or mandate — medium.

### Opportunity

- protected-context inheritance;
- overdue next action — high;
- protect/verify protocol unchanged for >14 days — medium;
- privileged users only: early readiness — medium;
- privileged users only: readiness risk penalty >=10 — high.

Stage 10 does not autonomously send alerts externally. The signal data is an operational foundation for a later UI/notification layer.

## Authorised intelligence retrieval v1

Public RPC:

`search_mrcip_intelligence(organisation, query, purpose, entity_types, include_protected, limit)`

The retrieval layer searches canonical RLS-visible data only across:

- counterparties;
- mines;
- laboratories;
- buyer requirements;
- seller offers;
- opportunities.

Ranking is deterministic using exact/prefix/substring matching plus `pg_trgm` similarity.

Maximum result count is 50.

### Protection rules

- `include_protected=false` filters protected buyer requirements, seller offers and opportunities from retrieval output.
- Protected retrieval requires a privileged MRCIP role.
- Research/business-development users can retrieve non-protected intelligence without receiving privileged protected context.
- RLS remains authoritative underneath the search function.
- Retrieval metadata intentionally excludes protected mine coordinates, protected contacts, seller pricing/payment terms, KYC/banking data, facilitator/commission data and protected source notes.
- Search is retrieval only: it cannot approve, disclose, contract, contact or mutate commercial entities.

### Retrieval audit

Every successful public search writes a system-normalised retrieval audit record with:

- actor;
- purpose;
- query;
- entity scope;
- whether protected access was requested;
- bounded maximum results;
- system-derived result count;
- algorithm version;
- request/completion timestamps.

A caller-supplied `result_count` is overwritten by the database.

## Public RPCs

All three Stage 10 public RPCs are **SECURITY INVOKER**, authenticated-only, and non-executable by `anon`:

- `generate_mrcip_report(uuid)`;
- `refresh_watchlist_signals(uuid)`;
- `search_mrcip_intelligence(uuid,text,text,text[],boolean,integer)`.

## Private helpers

The following private trigger/helpers are not executable by `anon` or `authenticated`:

- `private.guard_mrcip_report_definition()`;
- `private.compute_mrcip_report_run()`;
- `private.compute_mrcip_watchlist_signal_snapshot()`;
- `private.compute_mrcip_retrieval_request()`.

`private.mrcip_retrieval_candidates(...)` is intentionally executable by `authenticated` because the public SECURITY INVOKER search RPC must call it. It remains in the `private` schema rather than the public Data API schema, is itself SECURITY INVOKER, and all underlying table RLS remains in force. It is not executable by `anon`.

## Security-invoker views

The three Stage 10 views all have `security_invoker=true`:

- `mrcip_report_catalog_summary`;
- `mrcip_watchlist_signal_current`;
- `mrcip_retrieval_audit_summary`.

## RLS / grants

RLS is enabled on all four Stage 10 public tables.

`anon` has no Stage 10 table privileges.

Authenticated Data API grants are intentionally limited to:

- report definitions: `SELECT, INSERT, UPDATE, DELETE`, constrained by RLS and report guards;
- report runs: `SELECT, INSERT` only;
- watchlist signal snapshots: `SELECT, INSERT` only;
- retrieval requests: `SELECT, INSERT` only.

Report-run, signal-snapshot and retrieval-audit history cannot be rewritten or deleted through authenticated table grants.

Protected report/signal/retrieval context is restricted to privileged MRCIP roles.

## Authenticated rollback-isolated regression

The Stage 10 fixture executed under real `authenticated` role/JWT context and rolled back completely.

### Passed controls

1. A synthetic research analyst was created with active organisation membership and explicit `research_analyst` MRCIP role.
2. An incomplete counterparty was created and scored with the existing Stage 9 quality engine.
3. A caller attempted to insert a fabricated watchlist signal snapshot with `signal_count=999`, `highest_severity=critical` and a fake signal payload.
4. The database recalculated that snapshot to exactly **2 signals**, highest severity **high**, and removed the forged payload.
5. A caller attempted to insert a fabricated report run with `row_count=999` and `{"forged":true}`.
6. The database replaced the supplied report data with the deterministic `mrcip-report-v1` summary/count.
7. A protected seller offer was searched with `include_protected=false`: **0 results**.
8. The same protected offer was searched by a privileged actor with `include_protected=true`: **1 result**.
9. A caller attempted to create an audit row with `result_count=999`; the database recalculated the result count to **1**.
10. The research analyst successfully retrieved non-protected counterparty intelligence.
11. The research analyst was denied protected-intelligence retrieval.
12. The research analyst was denied creation of a protected risk-register report.
13. Authenticated UPDATE of retrieval audit history was denied.

No Stage 10 fixture data was committed.

## Production residue

After rollback-isolated testing, production row counts were verified as:

- `mrcip_report_definitions`: **0**;
- `mrcip_report_runs`: **0**;
- `mrcip_watchlist_signal_snapshots`: **0**;
- `mrcip_retrieval_requests`: **0**.

## Security advisor

Final security advisor rerun produced **no Stage 10-specific security finding**.

The remaining warnings are pre-existing and intentionally not modified during this commodity-intelligence stage:

- `can_access_portal` authenticated-callable SECURITY DEFINER;
- `complete_organisation_onboarding` SECURITY DEFINER;
- `get_my_access` SECURITY DEFINER;
- leaked-password protection disabled in Auth configuration.

Those remain separate Auth-regression/configuration work.

## Performance advisor

The first Stage 10 performance pass found five unindexed foreign-key relationships:

- report definition owner;
- report definition created-by;
- report definition updated-by;
- retrieval request requester;
- watchlist signal snapshot composite item relationship.

`20260821045834_mrcip_stage_10e_performance_hardening` added the required covering indexes.

The advisor rerun no longer reports those Stage 10 missing-FK-index findings.

Remaining notices are expected unused-index messages on new/empty tables plus the pre-existing duplicate organisation-membership index. The pre-existing membership index was not changed without a dedicated regression pass.

## Type generation

Supabase TypeScript database type generation succeeded after Stage 10 and includes:

### Tables

- `mrcip_report_definitions`;
- `mrcip_report_runs`;
- `mrcip_watchlist_signal_snapshots`;
- `mrcip_retrieval_requests`.

### Views

- `mrcip_report_catalog_summary`;
- `mrcip_watchlist_signal_current`;
- `mrcip_retrieval_audit_summary`.

### Functions

- `generate_mrcip_report`;
- `refresh_watchlist_signals`;
- `search_mrcip_intelligence`.

Type generation success does not mean a generated type file was committed into the partial frontend repository unless separately recorded.

## Existing systems preserved

Stage 10 does not modify or duplicate:

- quotation calculations;
- invoice calculations;
- VAT calculations;
- Finance line-item arithmetic;
- Payment semantics;
- Stage 6 commission-settlement arithmetic;
- Stage 7 laboratory result/certificate/inspection evidence lineage;
- Stage 8 DNC/contactability or append-only CRM communication controls;
- Stage 9 quality/risk/readiness formulas;
- Freight profitability calculations;
- Negotiation calculations;
- trip/vehicle/driver execution calculations;
- existing Auth/access RPC behaviour.

Finance/Freight/Negotiation remain existing linked domains. Stage 10 reports/retrieval do not redefine their calculations.

## Known limitations

- Stage 10 is a database/report/read/search foundation; the complete visual Admin dashboard/map/report UI cannot be truthfully completed because the full application source is not present in the connected repository.
- Watchlist signals are refreshed on request; Stage 10 does not add an external notification scheduler/provider.
- Retrieval is structured canonical search, not a generative AI answer engine.
- No autonomous AI decision-making, outreach, disclosure, contracting or trading is authorised.
- External sanctions/PEP/adverse-media providers remain unconnected.
- The exact consolidated seed workbook `Mkhonto Resources Global Commodity Intelligence Database.xlsx` remains unresolved for controlled production import.

## Sign-off

Stage 10 meets its database/security/report/signal/retrieval acceptance criteria:

- report summaries are database-derived, not caller-authored;
- report protection/visibility is role-governed;
- watchlist signals reuse Stage 8 watchlists and are deterministic/versioned;
- signal payload/count/severity cannot be forged through insert input;
- protected signals require privileged authority;
- retrieval is RLS-aware and purpose-audited;
- non-privileged protected retrieval is blocked;
- protected commercial/source/KYC/commission fields are excluded from retrieval output;
- retrieval result counts are system-derived;
- report/signal/retrieval history is append-only through authenticated grants;
- all Stage 10 public tables have RLS;
- `anon` has no Stage 10 table privileges;
- all public Stage 10 RPCs are SECURITY INVOKER and non-anonymous;
- all three public Stage 10 views are `security_invoker=true`;
- security advisor has no Stage 10-specific finding;
- the five Stage 10 FK-index findings were remediated;
- TypeScript schema generation succeeded;
- all five migration files match hosted SQL byte-for-byte;
- rollback fixtures leave zero production residue;
- Finance/Freight/Auth and prior MRCIP commercial controls remain unchanged.

**STAGE 10 SIGN-OFF: APPROVED**

Recommended next database-capable stage: **Governed Intelligence AI Orchestration & Citation Foundation** over the authorised retrieval layer, while the full visual Admin Dashboard/Map/Reports experience remains blocked until the complete application source is connected.