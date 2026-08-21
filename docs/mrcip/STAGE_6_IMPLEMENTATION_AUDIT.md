# MRCIP Stage 6 Implementation Audit & Sign-Off

## Stage

**Stage 6 — Commission Settlement & Reconciliation**

## Status

**SIGNED OFF — DATABASE / SECURITY / SETTLEMENT RECONCILIATION FOUNDATION COMPLETE**

The Stage 6 implementation is live in the hosted **Mkhonto Resources Hub** Supabase project and is reconciled to source control through the exact hosted migration version `20260821033201_mrcip_stage_6e_performance_hardening`.

## Purpose

Stage 6 converts a Stage 5 commission schedule that has legitimately crystallised to `payable` into a controlled settlement workflow. It creates a commission-specific settlement subledger, calculates each facilitator's due amount from the approved commission allocation, records payout evidence, verifies or reverses payouts, reconciles partial/full payment states, and closes recurring commission obligations without rewriting the existing Finance or Payments calculation models.

The operating sequence is:

**PAYABLE → SETTLEMENT CYCLE → ALLOCATION RECONCILIATION → PAYOUT EVIDENCE → VERIFIED PAYMENT → PARTIAL/FULL SETTLEMENT → CLOSEOUT**

## Architecture decision

The existing `public.payments` model is document-linked and is preserved as an existing Finance-domain record. It is **not** repurposed as an outbound facilitator payout ledger. Stage 6 maintains its own commission settlement subledger and may reference existing Finance documents, Payments or protected Documents as supporting evidence.

This prevents MRCIP from silently changing existing Finance/payment semantics.

## Implemented scope

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| Settlement cycles | LIVE | `public.commission_settlement_batches` | R/MT, fixed and percentage cycles tested |
| Settlement allocation items | LIVE | `public.commission_settlement_items` | Generated from approved Stage 5 allocations; 100% reconciliation preserved |
| Payout evidence entries | LIVE | `public.commission_settlement_entries` | Pending → verified/rejected; verified → reversed controlled transitions |
| Recurring commission closeout | LIVE | `public.commission_schedule_closeouts` | Final paid state requires settled cycles plus explicit closeout |
| R/MT settlement | LIVE | schedule rate × actual MT | R10/MT × 1,000 MT = R10,000 verified |
| Percentage settlement | LIVE | schedule % × actual transaction basis | 2.5% × R200,000 = R5,000 verified |
| Fixed settlement | LIVE | fixed approved pool | R5,000 verified; duplicate active fixed cycle blocked |
| Partial reconciliation | LIVE | verified payout aggregation | Partial payout updated facilitator, batch and schedule states correctly |
| Overpayment prevention | LIVE | verified payout guard | Attempted verified payout above amount due blocked |
| Payout reversal | LIVE | `reverse_commission_settlement_entry(uuid,text)` | Reversal reopened batch/schedule and recalculated balances |
| Replacement payout | LIVE | normal record/verify workflow | Replacement after reversal restored settled/paid state |
| Direct financial mutation protection | LIVE | triggers/derived-field guards | Direct edits to derived due/paid/balance fields rejected |
| Settlement approval | LIVE | `approve_commission_settlement_batch(uuid)` | Requires authorised role and source/evidence reference |
| Settlement creation | LIVE | `create_commission_settlement_batch(...)` | Only payable/partially-paid schedules accepted |
| Payout recording | LIVE | `record_commission_settlement_entry(...)` | Only approved/partially-settled batches accepted |
| Payout verification | LIVE | `verify_commission_settlement_entry(uuid)` | Evidence/reference and overpayment controls enforced |
| Final closeout | LIVE | `close_commission_schedule(...)` | Recurring schedule cannot become paid while open cycles remain |
| Fixed auto-close | LIVE | reconciliation engine | Fully settled fixed schedule automatically becomes paid |
| RLS / Data API | LIVE | Four Stage 6 tables | RLS enabled; no anon table grants; role-limited settlement visibility |
| Type generation | LIVE | hosted Supabase schema | Type generation succeeded with all Stage 6 tables and RPCs |

## Settlement data model

### `commission_settlement_batches`

Represents one settlement cycle and stores:

- source commission schedule;
- cycle number and settlement reference;
- pool basis/rate/currency;
- actual transaction basis amount for percentage commissions;
- actual quantity basis for R/MT commissions;
- calculated pool amount;
- amount paid and balance due;
- period start/end;
- optional Finance document, Payment and Document evidence links;
- source reference and notes;
- approval actor/timestamp;
- lifecycle status.

### `commission_settlement_items`

Represents each approved facilitator allocation inside a settlement cycle. Items are system-generated from the approved Stage 5 allocation and retain:

- facilitator allocation/member identity;
- pool share %;
- currency;
- amount due;
- amount paid;
- balance due;
- derived settlement status.

Users cannot manually create arbitrary settlement items or rewrite their derived financial values.

### `commission_settlement_entries`

Represents individual payout events and retains:

- batch/item/schedule/allocation identity;
- payout amount and currency;
- payment date/reference/method;
- optional evidence Document, Finance document or Payment link;
- verification actor/timestamp;
- reversal actor/timestamp/reason;
- immutable commercial fields after creation.

### `commission_schedule_closeouts`

Used only for recurring percentage/R/MT commission schedules. It prevents a recurring commission from being marked fully paid simply because one settlement cycle has been paid.

## Commission-basis rules

### Per metric tonne

Settlement pool is calculated from actual cycle quantity:

`pool = approved R/MT rate × actual settled MT`

Regression fixture:

- Rate: **R10/MT**
- Actual quantity: **1,000 MT**
- Pool: **R10,000**
- 60/40 facilitators: **R6,000 / R4,000**

### Percentage of transaction

Settlement pool is calculated from actual transaction value:

`pool = approved % × actual transaction basis amount`

Regression fixture:

- Rate: **2.5%**
- Transaction basis: **R200,000**
- Pool: **R5,000**

### Fixed amount

The approved fixed commission is the settlement pool. Only one active fixed-fee settlement cycle may exist for a schedule. Once fully verified as settled, the schedule automatically becomes `paid`.

Regression fixture: **R5,000**.

## Core end-to-end regression

The final Stage 6 recurring R/MT fixture passed **9/9 controls**:

| Test | Result |
|---|---|
| R10/MT × 1,000 MT pool calculation and 60/40 allocation | PASS |
| Partial payout reconciliation | PASS |
| Overpayment prevention | PASS |
| Derived financial-field immutability | PASS |
| Fully settled recurring cycle | PASS |
| Direct recurring `paid` bypass prevention | PASS |
| Controlled recurring closeout to `paid` | PASS |
| Verified payout reversal reopens reconciliation | PASS |
| Replacement payout restores settled/paid closeout | PASS |

## Additional basis regression

| Test | Result |
|---|---|
| Fixed R5,000 settlement calculation | PASS |
| Duplicate active fixed-fee cycle blocked | PASS |
| Fixed schedule auto-closes after full settlement | PASS |
| 2.5% × R200,000 percentage calculation = R5,000 | PASS |
| Percentage recurring schedule remains partially paid until closeout | PASS |
| Percentage final closeout to paid | PASS |

## Defects found and remediated during Stage 6

### 1. Internal reconciliation guard context leakage

During regression, the transaction-local internal flags used to authorise system-derived reconciliation updates were found to remain set after the helper completed. This could have relaxed derived-field mutation protection for later statements in the same transaction.

**Remediation:** `20260821032908_mrcip_stage_6c_internal_guard_context_hardening` now saves and restores the previous internal guard state on both success and exception.

Final regression confirmed direct financial-field edits remain blocked after reconciliation.

### 2. Closeout guard alias collision

The closeout path exposed a PL/pgSQL naming collision between a facilitator-chain local variable and a closeout query alias.

**Remediation:** `20260821032955_mrcip_stage_6d_closeout_guard_alias_hardening` renamed the local records and query alias. The unchanged end-to-end regression then passed.

### 3. Missing FK covering index

The performance advisor identified the optional settlement-batch → Payment composite FK as lacking a dedicated covering index.

**Remediation:** `20260821033201_mrcip_stage_6e_performance_hardening` added the covering index. Advisor rerun no longer reports the Stage 6 FK warning.

## Security and RLS

RLS is enabled on all Stage 6 public tables:

- `commission_settlement_batches`
- `commission_settlement_items`
- `commission_settlement_entries`
- `commission_schedule_closeouts`

`anon` has no Stage 6 table privileges.

Commission settlement records are restricted to:

- Super Admin;
- Managing Director;
- Finance;
- Legal/Compliance.

The six public Stage 6 RPCs are `SECURITY INVOKER` and executable by authenticated users subject to their internal role checks/RLS. Internal reconciliation helpers are `SECURITY DEFINER` in the private schema and are not executable by `anon` or `authenticated`.

Settlement items deliberately have no authenticated DELETE grant after lifecycle hardening.

## Tenant integrity

Stage 6 uses composite `(organisation_id, id)` relationships for settlement links to:

- commission schedules;
- commission allocations;
- facilitator members;
- Finance documents;
- Payments;
- evidence Documents.

This prevents cross-organisation settlement linkage.

## Existing Finance and Payments regression protection

Stage 6 did not modify existing:

- quotation calculations;
- invoice calculations;
- VAT calculations;
- Finance line-item calculations;
- `finance_documents` commercial arithmetic;
- existing `payments` record calculations/semantics;
- Freight profitability calculations.

Finance documents and Payments are reference/evidence sources only for Stage 6 settlement records.

## Advisor results

### Security advisor

No new Stage 6-specific security finding remains.

Pre-existing tracked warnings remain:

- authenticated-callable `SECURITY DEFINER` Auth/access RPCs;
- leaked-password protection disabled.

These predate Stage 6 and remain assigned to a dedicated Auth regression/configuration pass.

### Performance advisor

The single new Stage 6 missing-FK-covering-index warning was remediated in Stage 6e.

Remaining advisor notices are:

- expected unused-index notices on new/empty tables;
- the pre-existing duplicate organisation-membership index.

## Test isolation / residue

All Stage 6 regression fixtures were executed in explicit transactions and rolled back.

Final residue checks returned:

- test counterparties: **0**;
- settlement batches: **0**;
- settlement items: **0**;
- settlement entries: **0**;
- closeouts: **0**.

No production settlement row was created by Stage 6 testing.

## Known limitations / next integration work

- Stage 6 records and reconciles payout evidence; it does not execute bank payments.
- The full Admin settlement UI is not available in the connected partial application repository.
- External accounting/banking integration remains a later integration concern.
- The existing Auth advisor warnings remain separately tracked.
- Central audit-event hooks for every MRCIP mutation can be expanded later; Stage 6 itself retains actor/time/evidence/reversal metadata.

## Sign-off

Stage 6 satisfies its database/security/commercial-control acceptance criteria:

- all three approved commission bases can be settled;
- partial and full settlement reconcile correctly;
- overpayment is blocked;
- payout evidence is verified before it affects paid balances;
- reversals reopen balances correctly;
- recurring schedules require explicit final closeout;
- fixed schedules auto-close only after full verified settlement;
- derived amounts cannot be directly rewritten;
- tenant boundaries and RLS remain enforced;
- existing Finance and Payments calculations remain unchanged;
- test fixtures leave no production residue.

**STAGE 6 SIGN-OFF: APPROVED**

Recommended next stage: **Sampling, Inspection & Laboratory Certificate Workflow**.
