# Mkhonto Resources Commodity Intelligence Platform (MRCIP)

## Phase 0 — Current-State Audit and Stage 1 Gate

**Original audit date:** August 2026  
**Close-out date:** 23 August 2026  
**Status:** **CLOSED — SCHEMA RECOVERY RESOLVED; IMPLEMENTATION ADVANCED THROUGH STAGE 13**

This document preserves the conclusions of the original Phase 0 current-state audit while reconciling facts that changed after the initial inspection. The original audit correctly treated unverified functionality as absent and identified schema/migration recovery as a blocker. That blocker was subsequently resolved; the earlier “blocked” statements are historical point-in-time findings, not the present platform state.

## 1. Connected production foundation

### Supabase project

- Project: `Mkhonto Resources Hub`
- Project reference: `zjrzzvakwrwkrcqhcnyo`
- Region: `eu-west-2`
- Database: PostgreSQL 17
- Hosted schema/migration access: **operational**
- Supabase Auth: live
- Supabase Storage: available
- Supabase Edge Functions: now used by the governed AI gateway layer introduced after Phase 0

Classification: **LIVE**

## 2. GitHub repository assessment

Repository: `innvestam-star/Mkhonto-Resources`

The connected repository remains a partial application source rather than the complete Mkhonto Resources Admin Platform. It contains the Supabase/Next.js foundation, migrations, MRCIP governance documentation and Edge gateway source, but the complete Admin/Finance/Freight UI source is still not present.

Verified reusable application foundation includes:

- `src/lib/supabase/client.ts`
- `src/lib/supabase/server.ts`
- `src/lib/supabase/proxy.ts`
- `src/lib/supabase/access.ts`
- root `proxy.ts`
- `supabase/config.toml`
- `supabase/migrations/`
- `supabase/functions/`
- MRCIP stage audit/register documentation

Classification: **PARTIAL APPLICATION SOURCE / LIVE DATABASE FOUNDATION**

This limitation means database/security/control-layer sign-off must not be represented as full browser/UI regression sign-off.

## 3. Existing Auth and protected-route foundation

The original audit identified reusable Auth/session/protected-route components and protected route families:

- `admin`
- `finance`
- `freight`
- `driver`
- `portal`

The existing access RPCs include:

- `can_access_portal(...)`
- `get_my_access()`
- organisation onboarding/access logic

MRCIP implementation has intentionally reused/preserved these boundaries rather than redesigning Auth during commodity-intelligence stages.

Current Security Advisor still reports three authenticated-callable `SECURITY DEFINER` Auth/access RPC warnings:

- `public.can_access_portal(p_portal text, p_organisation_id uuid)`
- `public.complete_organisation_onboarding(p_name text, p_trading_name text, p_industry text)`
- `public.get_my_access()`

These remain **pre-existing tracked warnings** and require a dedicated Auth/login/protected-route regression pass before modification. Supabase leaked-password protection also remains disabled and is tracked as configuration hardening.

## 4. Schema-recovery blocker — resolved

At the time of the original Phase 0 audit, direct schema inspection, read-only SQL and TypeScript type generation were temporarily blocked by database-role authentication failures. The hosted project itself remained healthy.

That blocker was later resolved. The authoritative hosted migration records and SQL statement bodies were recovered from:

`supabase_migrations.schema_migrations`

The four migrations predating the reconstructed repository were restored to source control, and later MRCIP DDL has been applied as versioned hosted migrations and mirrored to GitHub.

The current migration source of truth is:

`supabase/migrations/MIGRATION_MANIFEST.md`

**Do not create a fresh baseline or replace hosted history with manually invented SQL.**

## 5. Existing platform entities protected from MRCIP regressions

Phase 0 identified the existing platform entities that MRCIP should integrate with rather than duplicate:

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
- `profiles`

Protected regression zones remain:

- Supabase Auth/session handling;
- role-aware protected routes;
- Admin/Finance/Freight access;
- customer/client records;
- quotations/invoices;
- quantity × rate and fixed-amount semantics;
- VAT exclusive/VAT/inclusive arithmetic;
- quote-to-invoice relationships;
- payments;
- freight profitability calculations;
- drivers/vehicles/trips;
- documents/storage;
- existing audit history.

MRCIP stages integrate Finance, Freight, Negotiation and Documents by reference and do not duplicate their arithmetic or execution semantics.

## 6. Canonical identity conclusion

A significant Phase 0 architectural conclusion was refined during Stage 1:

- `organisations` is the tenant/account organisation model;
- market counterparties use a separate canonical `counterparties` master scoped by `organisation_id`;
- a counterparty may carry multiple business roles;
- formal customer relationships may link to existing `clients` rather than duplicating Finance customers.

Core principle:

**One company, one canonical market identity, multiple business roles.**

## 7. MRCIP domains implemented after Phase 0

The domains listed as unverified/not implemented in the initial audit were subsequently built in controlled stages. The live database/control foundation now includes:

- counterparty multi-role master;
- commodity/product/specification taxonomy;
- provenance and verification records;
- mines and protected mine details;
- laboratories and capabilities;
- import staging and duplicate review;
- buyer requirements and seller supply offers;
- deterministic explainable matching;
- opportunities/Deal Room;
- KYC/mandate/protection/disclosure protocol;
- facilitator chains and commission controls;
- commission settlement/reconciliation;
- sampling, chain-of-custody, laboratory results/certificates and inspection evidence;
- CRM DNC/outreach/task/watchlist foundations;
- quality/risk/opportunity readiness scoring;
- deterministic reports/signals and authorised retrieval;
- governed AI requests/frozen context/citations/human review;
- prompt/provider/execution gateway governance;
- Stage 13 AI evaluation, safety calibration, rate/budget and provider-onboarding controls.

Stage-level evidence is retained in `docs/mrcip/STAGE_N_IMPLEMENTATION_AUDIT.md` and `docs/mrcip/IMPLEMENTATION_REGISTER.md`.

## 8. Security architecture retained from Phase 0

MRCIP security continues to enforce multiple layers:

1. explicit table/Data API privileges;
2. RLS policies;
3. application/server authorisation;
4. protected-data separation/redaction;
5. export/report/retrieval authorisation;
6. audit trails for sensitive access and workflow changes.

Protected source details, KYC data, pricing, banking, commission/facilitator data and sensitive coordinates must never rely on UI-only hiding.

The disclosure protocol remains:

**PROTECT → VERIFY → DISCLOSE → CONTRACT**

and protected seller identity may remain:

**PROTECTED SELLER — WITHHELD PENDING PROTOCOL COMPLETION**

## 9. Retrospective ACL defect and remediation

The 23 August 2026 cross-stage audit identified a material security defect that earlier Stage 1–2 sign-offs had missed: 19 early MRCIP tables still inherited excessive default ACLs. `anon` retained direct table privileges and `authenticated` retained dangerous privileges including `TRUNCATE`, `REFERENCES` and `TRIGGER`.

Because RLS does not protect `TRUNCATE`, this was treated as a genuine security regression rather than a documentation issue.

Remediation migration:

`20260823081757_mrcip_retrospective_acl_hardening_stages_1_13`

Hosted/GitHub Git blob SHA:

`41b1d561798ca48b1cee68db22692bce934b860e`

Post-remediation verification:

- MRCIP public tables audited: **86**
- MRCIP tables with `anon` privileges: **0**
- MRCIP tables where `authenticated` retains `TRUNCATE`, `REFERENCES` or `TRIGGER`: **0**
- MRCIP public tables without RLS: **0**
- unvalidated public constraints: **0**

The original Stage 1–2 sign-offs are therefore considered valid only **after this retrospective remediation**; they must not be used as evidence that the ACL defect never existed.

## 10. Performance posture

The current performance advisor reports many unused-index informational notices, which are expected on an implementation with little/no production MRCIP traffic, plus the pre-existing duplicate `organisation_memberships` index warning.

No index should be removed simply because it is currently unused. Production workload evidence is required before pruning.

No new missing-FK-index regression was identified in the Stage 13 close-out audit.

## 11. Seed-data / import status

The exact consolidated workbook intended as the authoritative MRCIP seed source remains unresolved. Related buyers/offtakers, sellers and mine-contact workbooks have been identified historically, but they must not be silently merged and represented as the authoritative consolidated dataset.

Import remains governed by:

**UPLOAD → PARSE/MAP → NORMALISE → VALIDATE → DUPLICATE REVIEW → PREVIEW → APPROVE → IMPORT → AUDIT**

No import may silently overwrite canonical master records.

## 12. Phase 0 gate outcome

The original Phase 0 gate required schema recovery before production MRCIP DDL. That gate was satisfied, and Stages 1–13 were subsequently implemented under the controlled migration/audit process.

Current programme status is not “Phase 0 blocked.” It is:

- **Phase 0: CLOSED**
- **Stages 1–12: verified complete at documented database/security/control boundaries after retrospective ACL remediation**
- **Stage 13 live database/runtime/security: implemented and verified**
- **Stage 13 source-control provenance: conditional/open for two missing SQL files**

The two unresolved Stage 13 source-control files are:

- `20260821060927_mrcip_stage_13c_evaluation_workflow_engine.sql` — expected Git blob SHA `4bafdf0acbee619e4949bd21ab7b6eb5a49f3635`
- `20260821061049_mrcip_stage_13d_provider_onboarding_budget_and_activation_gates.sql` — expected Git blob SHA `3e986530652939cd381d1c337e548c14f50bb9eb`

Their hosted SQL bodies remain authoritative. A non-matching reconstruction must be rejected rather than committed.

## 13. Current gate before further stages

The preferred next action is to recover those two migration files exactly and close the Stage 13 provenance exception.

Until then:

- the live Stage 13 database/runtime controls remain usable as implemented;
- production AI provider activation remains disabled/unconfigured;
- no claim of full Stage 13 governance sign-off should be made;
- no full Admin browser/UI sign-off should be made because the complete frontend source is not present;
- Stage 14 should not be formally signed off over the provenance gap unless an authorised maintainer explicitly accepts the documented exception.

Phase 0 itself is closed; the remaining blocker is a **Stage 13 source-control provenance issue**, not a schema-connectivity blocker.