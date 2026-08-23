# MRCIP Stage 5 Implementation Audit & Sign-Off

## Stage

**Stage 5 — Facilitator Chain, Commission Protection & Commercial Control**

## Status

**SIGNED OFF — DATABASE / SECURITY / COMMERCIAL CONTROL FOUNDATION COMPLETE**

The Stage 5 implementation is live in the hosted **Mkhonto Resources Hub** Supabase project and is reconciled to source control through the exact hosted migration version `20260821030906_mrcip_stage_5d_lifecycle_hardening`.

## Purpose

Stage 5 extends the Stage 4 protected Deal Room so Mkhonto Resources can register facilitator/intermediary chains, preserve introduction history, document commission entitlement, validate a complete commission pool, link fee protection, control payment triggers and connect commission records to the existing Finance domain without rewriting Finance calculations.

## Implemented scope

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| Facilitator chain | LIVE | `public.facilitator_chains` | Approval and revision lifecycle tested |
| Facilitator participants | LIVE | `public.facilitator_chain_members` | Participant identity, represented party, authority, protection and introduced-by relationships validated |
| Anti-hidden-intermediary control | LIVE | Chain immutability triggers | Post-approval participant insertion regression blocked |
| Chain revision | LIVE | `create_facilitator_chain_revision(uuid,text)` | Revision cloned participants and preserved introduced-by relationship |
| Chain approval | LIVE | `approve_facilitator_chain(uuid)` | Requires authorised role and verified/not-required authority plus protected/waived protection for all participants |
| Commission schedule | LIVE | `public.commission_schedules` | Approval/revision/supersession lifecycle tested |
| Commission allocation | LIVE | `public.commission_allocations` | Exact 100% allocation required before approval |
| Pool bases | LIVE | `percent_of_transaction`, `per_metric_tonne`, `fixed_amount` | Database constraints and allocation synchronisation verified |
| Fee protection linkage | LIVE | `commission_schedules.fee_protection_record_id` | Approval requires current executed/verified fee-protection record for same opportunity |
| Payment triggers | LIVE | `public.commission_trigger_events` | Verified trigger moved approved schedule to `payable` |
| Finance links | LIVE FOUNDATION | `public.commission_finance_links` | Tenant-safe Finance-document link; existing Finance calculations unchanged |
| Tenant identity hardening | LIVE | Composite identity on `opportunity_protection_records` and `payments` | Stage 5 composite FKs resolve within organisation |
| RLS / Data API | LIVE | All six Stage 5 tables | RLS enabled; no anon table grants; explicit authenticated grants only |
| Type generation | LIVE | Hosted Supabase schema generation | Type generation succeeded with Stage 5 tables and RPCs |

## Supported facilitator information

A facilitator-chain participant can record:

- participant counterparty/contact or controlled display identity;
- company name;
- role;
- represented side;
- represented counterparty;
- introduced-by participant;
- authority status;
- protected status;
- commission-entitled flag;
- notes and full actor/timestamp metadata.

Approved/superseded chains are immutable. Amendments use a new revision instead of overwriting approved transaction history.

## Commission-control model

Commission schedules support:

- percentage of transaction;
- amount per metric tonne;
- fixed amount;
- currency;
- quantity basis where relevant;
- buyer-payment, seller-payment, invoice-paid, delivery-completed or custom trigger;
- fee-protection evidence;
- revision history;
- approval actors and effective date.

Commission economic visibility is restricted to executive, Finance and Legal/Compliance roles. Facilitator relationship visibility does not automatically expose commission economics.

## Approval controls

A commission schedule cannot be approved unless:

1. the linked facilitator chain is approved and belongs to the same opportunity;
2. the linked fee-protection record belongs to the same opportunity and is current and executed/verified;
3. at least one commission allocation exists;
4. allocation shares total exactly **100%**;
5. calculated allocation values reconcile to the pool;
6. every allocated participant is in the approved chain;
7. every allocated participant is commission-entitled;
8. every allocated participant has verified/not-required authority and protected/waived protection.

A crystallised or paid schedule cannot be silently superseded.

## Regression verification

The final Stage 5 fixture passed all eight required controls:

| Test | Result |
|---|---|
| Facilitator chain approval | PASS |
| Exact 100% commission allocation | PASS |
| Approved-chain immutability | PASS |
| Approved-allocation immutability | PASS |
| Chain revision preserves introduced-by relationship | PASS |
| Commission schedule revision supersedes prior approved revision | PASS |
| Verified buyer-payment trigger crystallises schedule to `payable` | PASS |
| Direct settlement status bypass is blocked | PASS |

The allocation arithmetic regression used a **R10/MT** pool with **60% / 40%** shares and produced **R6/MT / R4/MT** allocations respectively.

## Controlled amendment behavior

- Approved facilitator chains cannot be edited by inserting hidden intermediaries.
- Approved allocations cannot have their percentages changed in place.
- Facilitator amendments use `create_facilitator_chain_revision`.
- Commission amendments use `create_commission_schedule_revision`.
- Approval of a valid new revision supersedes the prior approved revision.
- Introduced-by lineage is retained when facilitator-chain revisions are created.

## Payment-trigger controls

A commission schedule only becomes `payable` when the configured trigger has a **verified** event.

Trigger verification requires:

- occurrence time; and
- at least one evidence source: document, Finance document, Payment record or controlled external/reference identifier.

The trigger event records verifier and timestamp.

Direct changes to `partially_paid` or `paid` are blocked because actual settlement/reconciliation is deliberately reserved for a dedicated subsequent workflow.

## Finance integration

Stage 5 does **not** implement a second invoicing engine.

`commission_finance_links` connects schedules/allocations to existing `finance_documents`. Existing quotation, invoice, line-item, VAT and payment calculation logic remains authoritative and unchanged.

## Security verification

- RLS is enabled on:
  - `facilitator_chains`
  - `facilitator_chain_members`
  - `commission_schedules`
  - `commission_allocations`
  - `commission_trigger_events`
  - `commission_finance_links`
- `anon` has no table privileges on the six Stage 5 tables.
- Authenticated table grants are explicit and constrained by RLS.
- Commission economics are restricted to `super_admin`, `managing_director`, `finance` and `legal_compliance` roles.
- Facilitator-chain working visibility additionally supports appropriate commodity/business-development roles without exposing commission schedules.
- Internal trigger/helper functions are not callable by anon/authenticated roles.
- Public workflow RPCs use invoker semantics and explicit MRCIP role checks.

## Advisor results

### Security

No new Stage 5 security warnings were introduced.

Remaining warnings are pre-existing platform items:

- authenticated-callable `SECURITY DEFINER` `can_access_portal(...)`;
- authenticated-callable `SECURITY DEFINER` `complete_organisation_onboarding(...)`;
- authenticated-callable `SECURITY DEFINER` `get_my_access()`;
- leaked-password protection disabled in Supabase Auth.

These remain tracked for a dedicated Auth regression/configuration pass.

### Performance

No new Stage 5 missing-foreign-key-index findings remain.

Remaining performance notices are:

- expected unused-index informational notices while new MRCIP tables are empty;
- the pre-existing duplicate index on `organisation_memberships`, which predates MRCIP and is not changed without a separate regression pass.

## Fixture residue

Final residue checks returned:

- Stage 5 test counterparties: **0**
- Stage 5 facilitator chains: **0**
- Stage 5 commission schedules: **0**

Earlier test attempts aborted transactionally and also left no residue.

## Existing systems preserved

Stage 5 did not rewrite:

- Finance quotation/invoice/VAT calculations;
- Finance line-item calculations;
- Payment records or settlement calculations;
- Freight profitability calculations;
- Negotiations logic;
- Stage 4 protected disclosure rules;
- existing Auth/protected-route behavior.

## Known limitations / next gated work

The following are intentionally **not claimed complete**:

- actual commission payment settlement/reconciliation;
- banking/payment execution;
- commission invoice creation UX;
- complete MRCIP Admin UI, because the connected repository contains only a partial application source;
- external sanctions/PEP screening provider integration;
- automated legal e-signature;
- the exact consolidated intelligence seed workbook import.

## Sign-off decision

Stage 5 satisfies the database, tenant-integrity, facilitator-protection, commission-allocation, fee-protection, payment-trigger, RLS and existing-Finance-integration acceptance criteria.

**Stage 5 is SIGNED OFF.**

Next recommended commercial-control stage: **Commission Settlement & Reconciliation**, followed by the dedicated **Sampling / Inspection / Certificate workflow** according to the broader MRCIP roadmap.
