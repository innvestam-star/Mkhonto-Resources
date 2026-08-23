# MRCIP Implementation Register

This register is the current stage-level source of truth for the **Mkhonto Resources Commodity Intelligence Platform (MRCIP)**. Granular implementation, regression, remediation and migration evidence remains in `PHASE_0_CURRENT_STATE_AUDIT.md` and the permanent `STAGE_N_IMPLEMENTATION_AUDIT.md` files.

Status vocabulary: **LIVE**, **LIVE FOUNDATION**, **LIVE GATE**, **PARTIALLY IMPLEMENTED**, **DISABLED**, **AWAITING CONFIGURATION**, **BLOCKED**, **REVIEWED / PRE-EXISTING WARNING**.

> **23 August 2026 Stage 13 close-out:** Stages 0–13 are signed off at their documented database/security/commercial-control boundaries. The Stage 1–2 legacy ACL defect is retained in the audit history and was remediated by `20260823081757_mrcip_retrospective_acl_hardening_stages_1_13`. Authoritative post-fix result: **86 MRCIP public tables / 0 anon-exposed tables / 0 authenticated tables retaining TRUNCATE, REFERENCES or TRIGGER**. All **9/9 Stage 13 migrations** are now exact GitHub ↔ hosted Supabase matches. Production AI provider execution remains deliberately **DISABLED / UNCONFIGURED**.

## Stage-level register

| Requirement | Status | Implementation / Integration | Verification | Open issue / boundary | Sign-off |
|---|---|---|---|---|---|
| Phase 0 — current-state audit / migration recovery | LIVE / CLOSED | Hosted Supabase is schema authority; recovered history retained in source control | Connectivity, migration history and schema/type access restored | Complete Admin frontend source still absent | **SIGNED OFF** |
| Stage 1 — Counterparty Master, RBAC, commodities, products, specification and provenance | LIVE FOUNDATION | Canonical `counterparties`, multi-role assignments, contacts, commodity catalogue, source and verification model | Tenant/RLS checks; catalogue/spec foundations; retrospective ACL pass | Production intelligence import still pending | **SIGNED OFF AFTER ACL REMEDIATION** |
| Stage 2 — Mines, protected source details, laboratories, import staging and duplicate review | LIVE FOUNDATION / PROTECTED | Mine/lab intelligence and controlled `UPLOAD → MAP → VALIDATE → REVIEW → APPROVE → IMPORT → AUDIT` staging | RLS/protected separation; retrospective ACL pass | Exact consolidated seed workbook unresolved; importer UI/parser absent | **SIGNED OFF AFTER ACL REMEDIATION** |
| Stage 3 — Buyer requirements, seller offers, structured specs and explainable matching v1 | LIVE | Deterministic matching with hard filters and auditable component scores | **99.80/100 compatible candidate**; **50.00/100 disqualified** mandatory-CV fixture | FX/unit/route-cost extensions not implemented; Freight remains separate | **SIGNED OFF v1** |
| Stage 4 — Opportunity / Deal Room and disclosure protocol | LIVE FOUNDATION | Opportunities, protection/KYC/mandate/disclosure controls and reference-only Finance/Freight/Negotiation links | Early disclosure denied; compliant **PROTECT → VERIFY → DISCLOSE → CONTRACT** path verified | Full Admin Deal Room UI absent | **SIGNED OFF** |
| Stage 5 — Facilitator chain and commission approval | LIVE | Revisioned facilitator/commercial entitlement controls | Approved-history mutation blocked; allocation reconciliation to 100% | Admin UI absent | **SIGNED OFF** |
| Stage 6 — Commission settlement, reconciliation, reversal and closeout | LIVE | Dedicated settlement subledger linked to existing Finance/Payments by reference | Fixed, R/MT, percentage, partial/full, overpayment, reversal and closeout controls exercised | No bank/payment execution automation | **SIGNED OFF** |
| Stage 7 — Sampling, custody, laboratory results/certificates and inspection | LIVE / PROTECTED | Chain-of-custody and revisioned evidence lineage linked to mines/offers/documents | Custody, result correction, certificate and inspection publication controls verified | No external LIMS/barcode/courier integration | **SIGNED OFF** |
| Stage 8 — CRM, DNC/contactability, communications, tasks and watchlists | LIVE FOUNDATION | Controlled outreach history and monitored-entity model | DNC/channel blocking, conversion and append-only history verified | No autonomous sending provider/UI | **SIGNED OFF** |
| Stage 9 — Data quality, protected risk and opportunity readiness scoring | LIVE | Deterministic append-only score snapshots and operational read models | Quality **5/E → 100/A**; risk **0/low → 50/high**; opportunity **72.10/strong** fixtures | Internal decision support only; not external credit/sanctions/legal opinion | **SIGNED OFF** |
| Stage 10 — Deterministic reports, watchlist signals and authorised intelligence retrieval | LIVE | RLS-aware bounded retrieval and purpose-audited report/signal derivation | Forged report/signal payloads replaced by DB-derived values; protected retrieval **0 unprivileged / 1 privileged** | Visual export/dashboard UI absent | **SIGNED OFF** |
| Stage 11 — Governed AI request/context, citations and mandatory human review | LIVE | Audited Stage 10 retrieval → frozen context → versioned response/citation/review lineage | **11/11** governance regression controls | No autonomous approval, outreach, negotiation or execution | **SIGNED OFF** |
| Stage 12 — Prompt governance, provider verification, execution ledger and Edge gateway | LIVE GATE / PROVIDER DISABLED | Immutable prompt versions, provider readiness state, service-only execution lifecycle and JWT-protected `mrcip-ai-gateway` | **14/14** combined rollback controls; execution provenance and fail-closed missing-secret behavior verified | No production provider row/credential/model execution | **SIGNED OFF for gateway/control boundary** |
| Stage 13 — Evaluation suites/cases and evaluation workflow | LIVE | Synthetic safety/evaluation corpus, run/attempt/result workflow, review and finalisation | Exact 13a/13c/13e/13f/13g/13h migration provenance; live schema/RPC/type verification | No production evaluation corpus retained | **SIGNED OFF** |
| Stage 13 — Provider rates and budget policies | LIVE FOUNDATION | Versioned commercial rate cards and governed spend limits | Exact 13b/13d provenance; schema/types verified | Production rate cards and budgets unconfigured | **SIGNED OFF for foundation** |
| Stage 13 — Production provider onboarding / revocation gate | LIVE GATE / PROVIDER DISABLED | Evaluated onboarding, approval, refusal and revocation controls | Exact 13d/13f provenance; no active production provider/onboarding rows | Provider deliberately unconfigured; sign-off is not go-live approval | **SIGNED OFF for gate** |
| Stage 13 — Migration provenance | LIVE / RECONCILED | Hosted `supabase_migrations.schema_migrations` ↔ GitHub migration files | **9/9 Stage 13 migration Git blob SHAs exact**; 13c/13d recovered in `c8395610b35a59fab1dbd23c2ac9e1d19afb5bec` | None | **SIGNED OFF** |
| Stage 13 — Security / ACL / runtime closeout | LIVE / REMEDIATED | Programme ACL hardening + service-role gateway boundaries + decommissioned temporary exporters | **86 / 0 / 0** ACL audit; temporary privileged export RPC removed; temporary exporter returns JWT-protected HTTP 410 | Same pre-existing Auth warnings remain separately tracked | **SIGNED OFF** |

## Protected existing modules

| Existing module | Status | MRCIP rule |
|---|---|---|
| Finance / quotations / invoices / VAT / payments | LIVE / UNCHANGED LOGIC | Integrate by reference. Do not duplicate or redefine arithmetic, VAT or payment semantics. |
| Freight profitability | LIVE / UNCHANGED LOGIC | Integrate by reference. Do not duplicate Freight formulas inside MRCIP. |
| Negotiations / vehicles / drivers / trips / logistics execution | LIVE / UNCHANGED | Link opportunities to execution records without redefining existing logic. |
| Auth / protected routes | LIVE / PRESERVED | Do not alter during unrelated MRCIP stages. Dedicated login/protected-route regression is required before Auth remediation. |

## Security and configuration items tracked outside Stage 13

| Item | Status | Current position |
|---|---|---|
| `public.can_access_portal(...)` SECURITY DEFINER advisor warning | REVIEWED / PRE-EXISTING WARNING | Dedicated Auth review only; do not change blindly. |
| `public.complete_organisation_onboarding(...)` SECURITY DEFINER advisor warning | REVIEWED / PRE-EXISTING WARNING | Dedicated Auth review only. |
| `public.get_my_access()` SECURITY DEFINER advisor warning | REVIEWED / PRE-EXISTING WARNING | Dedicated Auth review only. |
| Supabase leaked-password protection | AWAITING CONFIGURATION | Enable only with dedicated login regression. |
| Duplicate `organisation_memberships` index | REVIEWED / PRE-EXISTING WARNING | Do not remove without workload/regression evidence. |
| External sanctions / PEP / adverse-media screening | NOT IMPLEMENTED | Current KYC fields are status fields only; no external screening run may be claimed. |

## Data / UI blockers

| Item | Status | Required next action |
|---|---|---|
| Exact consolidated commodity-intelligence seed workbook | BLOCKED / FILE NOT RESOLVED | Locate authoritative workbook; do not fabricate or blindly merge substitute datasets. |
| Complete MRCIP Admin frontend source | BLOCKED ON FULL APP SOURCE | Restore/connect complete application source before claiming browser/UI end-to-end regression. |
| Dashboard / Map / Reports / AI UI | PARTIALLY IMPLEMENTED / UI BLOCKED | Database/read/control foundations exist; wire only after complete frontend is available. |
| Production AI provider | DISABLED / UNCONFIGURED | Requires an approved provider, external credential, evaluated rate/budget/onboarding decision and controlled go-live. |

## Stage 13 provenance checkpoint

All nine Stage 13 hosted migrations have exact source-controlled counterparts:

- 13a `a826b4214fe3af0c7c467d36e226cb055c2ea13f`
- 13b `43c931898a842065361bb6b549966e6d1624b9e0`
- 13c `4bafdf0acbee619e4949bd21ab7b6eb5a49f3635`
- 13d `3e986530652939cd381d1c337e548c14f50bb9eb`
- 13e / `20260821061129` `0d7e9f9dac1bf241a0ad2f0a24fc8a83bc569e4f`
- 13e / `20260821061339` `b7ac746901402e86face5c14070e46de190c5958`
- 13f `d69f4c436a16c1c8d55b68333c48b66bee33f4e8`
- 13g `0eed99b877945d44cdfc830b9401a770e763f7f8`
- 13h `7c5bc53b9bd685eb6a6bceacebec6494856e3572`

The previously missing 13c and 13d files were recovered only after exact hosted Git-blob verification. The recovery process made no production business-data mutation. Its temporary privileged export RPC was removed and the short-lived Edge exporter was decommissioned.

## Current checkpoint

**Stages 0–13 are signed off at their documented database/security/commercial-control boundaries.** The Stage 1–2 ACL defect remains explicitly recorded as a historical defect that was later remediated; it is not erased from the audit trail.

**Stage 13 provenance is closed.** Production AI provider execution remains deliberately **DISABLED / UNCONFIGURED**; Stage 13 sign-off approves the evaluation, commercial-control and provider-onboarding gates, not provider go-live.

The complete Admin frontend source is still not present in the connected repository, so full browser/UI regression remains pending.

**Recommended next controlled stage: Stage 14.**
