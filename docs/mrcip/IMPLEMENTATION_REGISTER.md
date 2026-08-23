# MRCIP Implementation Register

This register is the current stage-level source of truth for the **Mkhonto Resources Commodity Intelligence Platform (MRCIP)**. Detailed implementation, regression, remediation and migration evidence remains in `PHASE_0_CURRENT_STATE_AUDIT.md` and the permanent `STAGE_N_IMPLEMENTATION_AUDIT.md` files.

Status vocabulary: **LIVE**, **LIVE FOUNDATION**, **LIVE GATE**, **LIVE / PROTECTED**, **REMEDIATED**, **VERIFIED**, **DISABLED**, **AWAITING CONFIGURATION**, **BLOCKED**, **REVIEWED / PRE-EXISTING WARNING**.

> **23 August 2026 Stage 14 close-out:** Stages 0–14 are signed off at their documented database/security/commercial-control boundaries. Stage 14 adds governed pilot→production AI release/runtime controls, protected-data release gates, immutable execution→release provenance, emergency-stop and circuit-breaker controls, gateway start-rejection cleanup and direct-DML protection. The final rollback regression passed **14/14**. Eight Stage 14 missing-FK-index advisor findings were remediated by `20260823212918_mrcip_stage_14h_fk_performance_hardening`; the rerun cleared them. Production AI provider execution remains deliberately **DISABLED / UNCONFIGURED**.

## Stage-level register

| Requirement | Status | Implementation / Integration | Verification | Open issue / boundary | Sign-off |
|---|---|---|---|---|---|
| Phase 0 — current-state audit / migration recovery | LIVE / CLOSED | Hosted Supabase remains schema authority; recovered history retained in source control | Connectivity, migration history and schema/type access restored | Complete Admin frontend source still absent | **SIGNED OFF** |
| Stage 1 — Counterparty Master, RBAC, commodities, products, specification and provenance | LIVE FOUNDATION | Canonical counterparties, multi-role assignments, contacts, commodity catalogue, source and verification model | Tenant/RLS checks; retrospective ACL pass | Production intelligence import pending | **SIGNED OFF AFTER ACL REMEDIATION** |
| Stage 2 — Mines, protected source details, laboratories, import staging and duplicate review | LIVE FOUNDATION / PROTECTED | Mine/lab intelligence and `UPLOAD → MAP → VALIDATE → REVIEW → APPROVE → IMPORT → AUDIT` staging | RLS/protected separation; retrospective ACL pass | Exact consolidated seed workbook unresolved; importer UI/parser absent | **SIGNED OFF AFTER ACL REMEDIATION** |
| Stage 3 — Buyer requirements, seller offers, structured specs and explainable matching v1 | LIVE | Deterministic matching with hard filters and auditable score components | **99.80/100 compatible candidate**; **50.00/100 disqualified** mandatory-CV fixture | FX/unit/route-cost extensions not implemented; Freight remains separate | **SIGNED OFF v1** |
| Stage 4 — Opportunity / Deal Room and disclosure protocol | LIVE FOUNDATION | Opportunities, protection/KYC/mandate/disclosure controls; reference-only Finance/Freight/Negotiation links | Early disclosure denied; compliant **PROTECT → VERIFY → DISCLOSE → CONTRACT** path verified | Full Admin Deal Room UI absent | **SIGNED OFF** |
| Stage 5 — Facilitator chain and commission approval | LIVE | Revisioned facilitator/commercial entitlement controls | Approved-history mutation blocked; allocation reconciles to 100% | Admin UI absent | **SIGNED OFF** |
| Stage 6 — Commission settlement, reconciliation, reversal and closeout | LIVE | Settlement subledger linked to existing Finance/Payments by reference | Fixed, R/MT, percentage, partial/full, overpayment, reversal and closeout controls exercised | No bank/payment execution automation | **SIGNED OFF** |
| Stage 7 — Sampling, custody, laboratory results/certificates and inspection | LIVE / PROTECTED | Chain-of-custody and revisioned evidence lineage linked to mines/offers/documents | Custody, correction, certificate and inspection publication controls verified | No external LIMS/barcode/courier integration | **SIGNED OFF** |
| Stage 8 — CRM, DNC/contactability, communications, tasks and watchlists | LIVE FOUNDATION | Controlled outreach history and monitored-entity model | DNC/channel blocking, conversion and append-only history verified | No autonomous sending provider/UI | **SIGNED OFF** |
| Stage 9 — Data quality, protected risk and opportunity readiness scoring | LIVE | Deterministic append-only score snapshots/read models | Quality **5/E → 100/A**; risk **0/low → 50/high**; opportunity **72.10/strong** | Internal decision support only | **SIGNED OFF** |
| Stage 10 — Deterministic reports, watchlist signals and authorised intelligence retrieval | LIVE | RLS-aware bounded retrieval and purpose-audited report/signal derivation | Forged report/signal payloads replaced by DB-derived values; protected retrieval **0 unprivileged / 1 privileged** | Visual export/dashboard UI absent | **SIGNED OFF** |
| Stage 11 — Governed AI request/context, citations and mandatory human review | LIVE | Audited retrieval → frozen context → versioned response/citation/review lineage | **11/11** governance regression controls | No autonomous approval/outreach/negotiation/execution | **SIGNED OFF** |
| Stage 12 — Prompt governance, provider verification, execution ledger and Edge gateway | LIVE GATE / PROVIDER DISABLED | Immutable prompt versions, provider readiness, service-only execution lifecycle, JWT gateway | **14/14** Stage 12 rollback controls; fail-closed missing-secret behavior | No production provider credential/model execution | **SIGNED OFF for gateway/control boundary** |
| Stage 13 — Evaluation suites/cases and workflow | LIVE | Synthetic safety/evaluation corpus, run/attempt/result workflow, review/finalisation | Nine Stage 13 migrations reconciled; live schema/RPC/type verification | No production evaluation corpus retained | **SIGNED OFF** |
| Stage 13 — Provider rates, budgets and production onboarding | LIVE FOUNDATION / LIVE GATE | Versioned rate cards, spend limits, evaluated onboarding/refusal/revocation controls | Provider/onboarding schema and gates verified | Provider deliberately unconfigured | **SIGNED OFF for foundation/gate** |
| Stage 13 — Security/provenance close-out | LIVE / REMEDIATED | Programme ACL hardening + service-role gateway boundary + migration-source recovery | **86 MRCIP tables / 0 anon / 0 dangerous authenticated grants**; 9/9 Stage 13 migrations reconciled | Same pre-existing Auth warnings remain | **SIGNED OFF** |
| Stage 14 — Governed release-plan foundation | LIVE GATE | `mrcip_ai_release_plans` ties provider/onboarding/prompt to pilot or production control terms | Draft→approval workflow and immutable terms verified | No production release configured | **SIGNED OFF** |
| Stage 14 — Pilot activation and production promotion | LIVE GATE | Controlled pilot activation; production requires evidence, failure-rate threshold and human review | Pilot and production promotion regression paths pass | Production activation remains an explicit future decision | **SIGNED OFF** |
| Stage 14 — Protected AI release gating | LIVE / PROTECTED | Release scope, protected-data allowance, role keys and protected-execution limits enforced server-side | Protected execution rejected when outside approval | No protected production release configured | **SIGNED OFF** |
| Stage 14 — Runtime / emergency stop / circuit breakers | LIVE | `mrcip_ai_runtime_controls`; pause/stop/revoke; Stage 13 budget/protection events can auto-pause | Emergency stop blocks execution; budget breach auto-pauses | None within Stage 14 | **SIGNED OFF** |
| Stage 14 — Execution→release provenance | LIVE | Immutable `mrcip_ai_execution_release_links` records release/runtime snapshot per governed execution | Pilot execution linked in regression | None | **SIGNED OFF** |
| Stage 14 — Gateway start-time rejection cleanup | LIVE | `mrcip-ai-gateway` v3 converts Stage 14 start rejection to `blocked / STAGE14_START_REJECTED` before provider request | Prepare→pause→start race exercised | No real provider call made | **SIGNED OFF** |
| Stage 14 — Control-table write boundary | LIVE / REMEDIATED | Workflow-only mutations; statement-scoped internal tokens reset after authorised statement | Direct release/runtime/event DML blocked; replay path closed by 14g | None | **SIGNED OFF** |
| Stage 14 — RLS / grants / tenant isolation | LIVE | RLS on release/runtime/event/link tables; no anon grants; no authenticated TRUNCATE/REFERENCES/TRIGGER | Unauthorized user sees zero fixture rows | None | **SIGNED OFF** |
| Stage 14 — Performance hardening | REMEDIATED / VERIFIED | 14h adds eight missing FK-support indexes | Performance Advisor rerun clears all eight Stage 14 unindexed-FK findings | Expected unused-index INFO remains on empty/new tables | **SIGNED OFF** |
| Stage 14 — Type-generation verification | VERIFIED | Live Supabase generated types include Stage 14 tables/views/RPCs | Type generation succeeds after 14h | Full app type-file wiring pending source restoration | **SIGNED OFF for verification** |
| Stage 14 — Formal implementation audit | LIVE / CLOSED | `docs/mrcip/STAGE_14_IMPLEMENTATION_AUDIT.md` | Final rollback **14/14**, zero residue, no provider call | Full browser/UI test not possible from current repo | **SIGNED OFF** |

## Protected existing modules

| Existing module | Status | MRCIP rule |
|---|---|---|
| Finance / quotations / invoices / VAT / payments | LIVE / UNCHANGED LOGIC | Integrate by reference. Do not duplicate or redefine arithmetic, VAT or payment semantics. |
| Freight profitability | LIVE / UNCHANGED LOGIC | Integrate by reference. Do not duplicate Freight formulas inside MRCIP. |
| Negotiations / vehicles / drivers / trips / logistics execution | LIVE / UNCHANGED | Link opportunities to execution records without redefining existing logic. |
| Auth / protected routes | LIVE / PRESERVED | Do not alter during unrelated MRCIP stages. Dedicated login/protected-route regression is required before Auth remediation. |

## Security and configuration items tracked outside Stage 14

| Item | Status | Current position |
|---|---|---|
| `public.can_access_portal(...)` SECURITY DEFINER advisor warning | REVIEWED / PRE-EXISTING WARNING | Dedicated Auth review only; do not change blindly. |
| `public.complete_organisation_onboarding(...)` SECURITY DEFINER advisor warning | REVIEWED / PRE-EXISTING WARNING | Dedicated Auth review only. |
| `public.get_my_access()` SECURITY DEFINER advisor warning | REVIEWED / PRE-EXISTING WARNING | Dedicated Auth review only. |
| Supabase leaked-password protection | AWAITING CONFIGURATION | Enable only with dedicated login regression. |
| Duplicate `organisation_memberships` index | REVIEWED / PRE-EXISTING WARNING | Do not remove without workload/regression evidence. |
| External sanctions / PEP / adverse-media screening | NOT IMPLEMENTED | Current KYC fields are status fields only; no external screening run may be claimed. |

## Data / UI / provider boundaries

| Item | Status | Required next action |
|---|---|---|
| Exact consolidated commodity-intelligence seed workbook | BLOCKED / FILE NOT RESOLVED | Locate authoritative workbook; do not fabricate or blindly merge substitute datasets. |
| Complete MRCIP Admin frontend source | BLOCKED ON FULL APP SOURCE | Restore/connect complete application source before claiming browser/UI end-to-end regression. |
| Dashboard / Map / Reports / AI UI | PARTIALLY IMPLEMENTED / UI BLOCKED | Database/read/control foundations exist; wire only after complete frontend is available. |
| Production AI provider | DISABLED / UNCONFIGURED | Requires explicit provider credential, evaluated onboarding, rates/budget approval, approved release plan and controlled go-live decision. |

## Stage 14 checkpoint

Authoritative Stage 14 migrations:

- `20260823121520_mrcip_stage_14a_release_runtime_foundation.sql`
- `20260823121824_mrcip_stage_14b_release_workflow_controls.sql`
- `20260823122140_mrcip_stage_14c_runtime_gate_and_circuit_breakers.sql`
- `20260823122438_mrcip_stage_14d_rls_grants_and_read_models.sql`
- `20260823123311_mrcip_stage_14e_gateway_completion_context_hardening.sql`
- `20260823124908_mrcip_stage_14f_control_write_token_hardening.sql`
- `20260823130516_mrcip_stage_14g_statement_scoped_control_tokens.sql`
- `20260823212918_mrcip_stage_14h_fk_performance_hardening.sql`

The final Stage 14 rollback suite passed **14/14** and left zero fixture residue. The final Security Advisor state contains only the same four pre-existing Auth/password warnings. The Stage 14 missing-FK-index findings were remediated by 14h and cleared on rerun. Type generation succeeds. `mrcip-ai-gateway` v3 is active with JWT verification, but **production provider execution remains disabled/unconfigured and Stage 14 sign-off is not provider go-live approval**.

## Current checkpoint

**Stages 0–14 are signed off at their documented database/security/commercial-control boundaries.**

Stage 14 is formally closed. The programme may proceed to the next controlled implementation stage while preserving:

**IMPLEMENT → TEST → AUDIT → REMEDIATE → SIGN OFF → PROCEED**.
