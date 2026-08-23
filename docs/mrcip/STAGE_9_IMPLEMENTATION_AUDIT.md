# MRCIP Stage 9 Implementation Audit & Sign-Off

## Stage

**Stage 9 — Data Quality, Risk & Opportunity Scoring + Operational Read Models**

## Status

**SIGNED OFF — DATABASE / SECURITY / DETERMINISTIC DECISION-SUPPORT FOUNDATION COMPLETE**

Stage 9 is live in the hosted **Mkhonto Resources Hub** project and reconciled to source control through:

`20260821043244_mrcip_stage_9c_scoring_integrity_hardening`

## Purpose

Stage 9 adds deterministic, evidence-bearing decision support to MRCIP without introducing opaque AI scoring, autonomous commercial decisions, a duplicate matching engine, or a replacement Finance/Freight model.

The Stage 9 operating model is:

**MEASURE DATA QUALITY → RECORD EVIDENCE-BACKED RISK → SNAPSHOT QUALITY/RISK → SCORE OPPORTUNITY READINESS → READ OPERATIONAL SUMMARIES → HUMAN REVIEW**

Quality and risk are deliberately separate. General data completeness may be visible to authorised research/business-development roles, while counterparty risk evidence, risk snapshots and opportunity readiness remain privileged commercial/legal context.

## Hosted migrations

| Version | Migration | Purpose |
|---|---|---|
| `20260821042643` | `mrcip_stage_9a_quality_risk_scoring_foundation` | Five Stage 9 tables, tenant-safe relationships, indexes, initial RLS/grant lockdown |
| `20260821042835` | `mrcip_stage_9b_deterministic_scoring_and_read_models` | Scoring guards, refresh RPCs, RLS policies, explicit grants and three security-invoker read models |
| `20260821043244` | `mrcip_stage_9c_scoring_integrity_hardening` | Algorithm-version normalisation, immutable generated quality evidence and complete-protocol scoring correction |

The three repository SQL files are byte-identical to the hosted migration SQL. Hosted SQL was converted to Git blob SHA-1 and compared with the GitHub blob SHA for each migration:

- Stage 9a: `d5ea35c966dda3167beb3c0237632ee4bf7dd18c`
- Stage 9b: `9da3d248a8020e885385516bb0f053f975858689`
- Stage 9c: `5635670cbba84575f7580dc73b9eb0aa84471d16`

## Implemented tables

### `mrcip_data_quality_issues`

Actionable quality findings for:

- counterparties;
- mines;
- laboratories;
- buyer requirements;
- seller offers;
- opportunities.

Supported dimensions include identity, contact, provenance, verification, commercial, specification, logistics, compliance and workflow.

Auto-generated counterparty issues are evidence-bearing lifecycle records. Stage 9c makes generated issue identity/content immutable; authorised users may resolve or waive an issue, but a waiver requires a reason.

Protected seller-offer/opportunity quality evidence inherits protected context. If protected evidence uses a document, it must use the existing `mrcip_protected` document classification.

### `counterparty_risk_flags`

Privileged evidence-backed risk flags across identity, verification, authority, compliance, commercial, delivery, reputation, legal and other categories.

Risk-flag identity/evidence is immutable. Resolved/false-positive flags cannot be silently reopened. Risk-flag status changes generate `audit_events` records. Document evidence must be `mrcip_protected`.

### `counterparty_quality_snapshots`

Append-only quality snapshots containing:

- score 0–100;
- grade A–E;
- component breakdown;
- open issue count;
- controlled algorithm version.

The database recalculates all score fields before insert, so a client cannot author its own quality score.

### `counterparty_risk_snapshots`

Append-only privileged risk snapshots containing:

- risk score 0–100;
- risk band low/moderate/high/critical;
- baseline component breakdown;
- active flag contribution breakdown;
- open flag count.

Risk snapshots remain protected and are not exposed to ordinary research/business-development access.

### `opportunity_score_snapshots`

Append-only protected opportunity-readiness snapshots. Each score records the exact buyer/seller quality and risk snapshots used, an algorithm version and an explanation object.

A client cannot write a chosen readiness score: the before-insert guard recalculates every component from authoritative MRCIP records.

## Counterparty Quality v1

Quality starts at 100 and applies deterministic penalties:

| Condition | Penalty |
|---|---:|
| Registration number missing | 15 |
| Country/headquarters missing | 5 |
| Website/domain missing | 5 |
| No contacts | 15 |
| Contacts exist but none verified | 7 |
| No provenance source | 15 |
| Counterparty verification not verified | 10 |
| Verification missing/stale (>180 days) | 10 |
| No market role | 10 |
| No commodity relationship | 10 |

Grades:

- A: 90–100
- B: 80–89.99
- C: 65–79.99
- D: 50–64.99
- E: below 50

The controlled algorithm identifier is `counterparty-quality-v1`.

## Counterparty Risk v1

Baseline risk points are deterministic:

- verification: verified 0; pending 10; other/unverified 15; failed/rejected 40;
- confidence: <40 = 25; <60 = 15; <80 = 5; otherwise 0;
- missing registration = 10;
- missing/stale verification (>180 days) = 10.

Open flag points:

- low 5;
- medium 15;
- high 30;
- critical 50.

Mitigated flags contribute half of the corresponding open value. Flag contribution is capped at 70 and total risk is capped at 100.

Bands:

- low: below 20;
- moderate: 20–44.99;
- high: 45–69.99;
- critical: 70–100.

The controlled algorithm identifier is `counterparty-risk-v1`.

This is internal decision support, not a third-party credit rating, sanctions opinion or legal conclusion.

## Opportunity Readiness v1

Formula:

**match(30) + buyer readiness(15) + seller readiness(15) + protocol(15) + evidence(10) + logistics(5) + commercial(10) − risk penalty(max 15)**

### Match — maximum 30

Uses the Stage 3 explainable match score multiplied by 0.30. Stage 9 does not replace Stage 3 matching.

### Buyer readiness — maximum 15

Uses structured Stage 4 buyer KYC/KYB state including verified case status, registration, authority, sanctions-status capture, PEP-status capture and capability evidence.

Stage 9 does not claim external sanctions/PEP screening when no external screening provider has run.

### Seller readiness — maximum 15

Uses the Stage 3 seller offer's authority, mandate, protection and provenance-source state.

### Protocol — maximum 15

- protect: 3;
- verify: 7;
- disclose: 11;
- contract: 15;
- complete: 15.

### Evidence — maximum 10

- verified laboratory certificate: 5;
- verified inspection: 5.

### Logistics — maximum 5

Uses destination/loading/transport context plus an existing Freight analysis link. Stage 9 does not duplicate Freight route-cost or profitability calculations.

### Commercial — maximum 10

Uses buyer/seller payment-term presence plus existing Negotiation and Finance links. Stage 9 does not duplicate quotation/invoice/VAT/payment calculations.

### Risk penalty — maximum 15

`max(buyer risk, seller risk) × 0.15`

Readiness bands:

- high: 80–100;
- strong: 65–79.99;
- developing: 50–64.99;
- early: below 50.

The controlled algorithm identifier is `opportunity-readiness-v1`.

## Controlled refresh RPCs

All three public scoring actions are **SECURITY INVOKER** and authenticated-only:

- `refresh_counterparty_quality(uuid)`;
- `refresh_counterparty_risk(uuid)`;
- `refresh_opportunity_score(uuid)`.

`refresh_opportunity_score` first creates fresh buyer/seller quality and risk snapshots, then creates the opportunity snapshot that references those exact inputs.

No anonymous execution is granted.

## Operational read models

Three read models are live, all configured with `security_invoker=true` so underlying RLS remains authoritative:

### `mrcip_counterparty_operational_summary`

Combines canonical counterparty identity with role/contact/commodity counts, latest quality/risk snapshot available to the caller, and CRM task/activity state.

### `mrcip_opportunity_operational_summary`

Combines opportunity stage/status, protection state, commodity/product, Stage 3 match, Stage 4 protocol, latest Stage 9 readiness score, and CRM work-queue state.

### `mrcip_pipeline_operational_summary`

Aggregates opportunity count, average readiness, disclosure-eligible count and overdue next-action count by organisation/commodity/stage/status.

These are read models only. They do not bypass workflow gates or mutate commercial records.

## Authenticated regression

Rollback-isolated testing ran under the actual `authenticated` role with MRCIP executive privileges.

### Score-forgery regression

A deliberately incomplete counterparty was inserted with a client-supplied quality snapshot of **100 / A** and fabricated component JSON.

Database result:

- score: **5.00**;
- grade: **E**;
- open quality issues: **9**;
- fabricated component key removed.

This confirms score fields are database-derived rather than client-authored.

### Complete counterparty quality regression

Complete buyer and seller fixtures each produced:

- quality score: **100.00**;
- grade: **A**;
- open issues: **0**.

### Risk regression

Buyer fixture:

- risk: **0.00 / low**.

Seller fixture with one critical open synthetic risk flag:

- risk: **50.00 / high**;
- open flags: **1**.

### Opportunity regression

Fixture inputs included:

- Stage 3 match score: 92;
- verified buyer KYC;
- verified seller authority/mandate/protection;
- contract protocol step;
- no laboratory/inspection evidence;
- no Freight, Negotiation or Finance link.

Result:

- total readiness: **72.10 / strong**;
- match: 27.60;
- buyer readiness: 15;
- seller readiness: 15;
- protocol: 15;
- evidence: 0;
- logistics: 3;
- commercial: 4;
- risk penalty: 7.50.

The counterparty, opportunity and pipeline operational views returned the expected latest values.

### Lifecycle/integrity controls

The regression also confirmed:

- quality snapshot UPDATE is blocked by least-privilege grants;
- resolved risk flags cannot be reopened;
- quality issue waiver without a reason is blocked;
- generated score snapshots are not mutable in place.

## Stage 9c integrity remediation

Testing identified two issues before sign-off.

### 1. `complete` protocol score mapping

The initial v1 scoring function explicitly handled `contract` but not the Stage 4 `complete` state, causing `complete` to fall through to the early-protocol score.

Remediation:

`20260821043244_mrcip_stage_9c_scoring_integrity_hardening` maps both `contract` and `complete` to the full **15/15** protocol component.

Regression result: PASS.

### 2. Caller-controlled algorithm label timing

The initial quality trigger normalised `algorithm_version` only after generating/resolving quality issues. A caller-supplied label could therefore influence the issue-lifecycle query even though the stored snapshot label was later corrected.

Remediation:

Stage 9c sets `counterparty-quality-v1` before any issue generation/resolution and makes generated issue identity/content immutable.

Hardening regression:

- caller supplied `caller-controlled-evil`;
- stored snapshot version = `counterparty-quality-v1`;
- all generated issues = `counterparty-quality-v1`;
- generated issue message tampering rejected;
- `complete` protocol score = 15.

Result: PASS.

## RLS / Data API security

RLS is enabled on all five Stage 9 public tables.

`anon` has **zero Stage 9 table privileges**.

Authenticated table grants are explicit:

- `mrcip_data_quality_issues`: `SELECT, UPDATE`;
- `counterparty_risk_flags`: `SELECT, INSERT, UPDATE`;
- `counterparty_quality_snapshots`: `SELECT, INSERT`;
- `counterparty_risk_snapshots`: `SELECT, INSERT`;
- `opportunity_score_snapshots`: `SELECT, INSERT`.

Risk flags, risk snapshots and opportunity readiness are limited to privileged MRCIP roles:

- Super Admin;
- Managing Director;
- Commodity Manager;
- Trader;
- Legal/Compliance.

Counterparty quality is available to the broader authorised MRCIP research/business-development role set because it measures data completeness rather than privileged risk evidence.

## Advisor results

### Security advisor

No new Stage 9-specific security warning remains.

Tracked pre-existing warnings remain unchanged:

- `can_access_portal` SECURITY DEFINER;
- `complete_organisation_onboarding` SECURITY DEFINER;
- `get_my_access` SECURITY DEFINER;
- leaked-password protection disabled.

These predate MRCIP Stage 9 and were not modified because Auth behavior requires a dedicated regression/configuration pass.

### Performance advisor

No Stage 9 missing-foreign-key-index finding remains.

Remaining notices are expected unused-index informational findings on new/empty tables plus the pre-existing duplicate organisation-membership index. Stage 9 indexes are retained until real production workload exists.

## Type generation

Supabase TypeScript database type generation succeeded after Stage 9 and includes:

- all five Stage 9 tables;
- all three Stage 9 operational views;
- all three Stage 9 refresh RPCs.

The complete Admin application source remains incomplete in the connected repository, so generated application type-file integration and browser/UI regression are not claimed here.

## Test isolation / production residue

All Stage 9 functional tests ran in rollback-isolated transactions.

Final production Stage 9 row counts are:

- data-quality issues: **0**;
- counterparty risk flags: **0**;
- counterparty quality snapshots: **0**;
- counterparty risk snapshots: **0**;
- opportunity score snapshots: **0**.

No Stage 9 fixture data remains.

## Existing systems preserved

Stage 9 does not modify or duplicate:

- quotation calculations;
- invoice calculations;
- VAT calculations;
- Finance line-item arithmetic;
- Payment semantics;
- Stage 6 commission settlement/reconciliation arithmetic;
- Stage 7 laboratory result/certificate evidence lineage;
- Stage 8 DNC/contactability or communication-history controls;
- Freight profitability calculations;
- Negotiation calculations;
- trip/vehicle/driver execution calculations;
- existing Auth/access RPC behavior.

Finance, Freight and Negotiation contribute only reference/readiness signals through already-existing link tables.

## Known limitations

- Stage 9 scoring is internal deterministic decision support, not an external credit rating, sanctions opinion, legal opinion or guarantee of counterparty performance.
- Sanctions/PEP fields are existing workflow status capture; no external screening provider is connected.
- Risk flags require evidence-backed human governance; Stage 9 does not autonomously discover adverse media or legal events.
- Opportunity readiness ranks evidence/workflow maturity; it does not automatically approve a deal, disclose a protected seller/source, execute a contract or send outreach.
- Full Admin dashboards, maps and visual scoring workflows remain blocked until the complete application source is restored/connected.
- The exact consolidated intelligence seed workbook remains unresolved for controlled production import.

## Sign-off

Stage 9 meets its database, security, deterministic-scoring and operational-read-model acceptance criteria:

- quality and privileged risk are separate;
- quality and risk formulas are explicit and versioned;
- caller-supplied scores are recalculated by the database;
- generated quality evidence cannot be silently rewritten;
- risk-flag identity/evidence cannot be silently rewritten;
- closed risk flags cannot silently reopen;
- opportunity score components and source snapshots are retained;
- risk is a transparent penalty rather than a hidden model feature;
- operational views use `security_invoker=true`;
- RLS is enabled on every Stage 9 table;
- anonymous Stage 9 table access is absent;
- public refresh RPCs are security-invoker and non-anonymous;
- Stage 9 security/performance advisor findings are clean;
- TypeScript type generation succeeded;
- migration files match hosted SQL byte-for-byte;
- regression fixtures leave zero production residue;
- Finance/Freight/Auth and prior MRCIP workflow logic remain unchanged.

**STAGE 9 SIGN-OFF: APPROVED**

Recommended next database-capable stage: **Reports, Watchlist Signals & Authorised Intelligence Retrieval Foundation**, while the full visual Admin Dashboard/Map remains blocked until the complete application source is available.
