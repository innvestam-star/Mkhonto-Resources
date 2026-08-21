# MRCIP Stage 8 Implementation Audit & Sign-Off

## Stage

**Stage 8 — Outreach CRM, Communications, Tasks & Watchlists**

## Status

**SIGNED OFF — DATABASE / SECURITY / CRM CONTROL FOUNDATION COMPLETE**

Stage 8 is live in the hosted **Mkhonto Resources Hub** project and reconciled to source control through:

`20260821041325_mrcip_stage_8c_performance_hardening`

## Purpose

Stage 8 converts the counterparty, commodity, opportunity and protection foundations into an operational commercial-engagement layer without creating an autonomous messaging engine.

The controlled operating flow is:

**TARGET → CONTROL CONTACTABILITY → OUTREACH → LOG → FOLLOW UP → QUALIFY → LINK REQUIREMENT / OFFER / OPPORTUNITY → WATCH**

Stage 8 records commercial activity and work queues. It does not send email, WhatsApp, LinkedIn messages or other external communications automatically.

## Architecture decisions

### Reused authoritative domains

Stage 8 reuses:

- `counterparties` and `counterparty_contacts` as the canonical company/contact identity;
- `buyer_requirements` and `seller_supply_offers` as commercial supply/demand objects;
- `opportunities` as the protected Deal Room opportunity created through the Stage 3/4 gate;
- `documents` and `mrcip_protected` classification for protected outreach evidence;
- `mrcip_user_roles` / `private.has_mrcip_role` for MRCIP access control;
- `audit_events` for contactability-control audit records.

Stage 8 does not create a duplicate customer master, opportunity model, document store, matching engine or communication provider.

### Protected-context inheritance

CRM rows inherit protected handling from protected contacts, protected seller offers, protected opportunities and protected campaigns. Ordinary business-development/research access is allowed only for non-protected CRM context. Protected CRM context remains limited to the existing privileged roles: Super Admin, Managing Director, Commodity Manager, Trader and Legal/Compliance.

## Implemented tables

### `crm_contact_controls`

Stores counterparty- or contact-level contactability controls:

- `unknown`
- `permitted`
- `restricted`
- `do_not_contact`

Channel controls cover email, phone, WhatsApp, LinkedIn and in-person contact. A `do_not_contact` record forces all outbound channel flags false. Removing DNC status requires executive or Legal/Compliance authority.

### `crm_outreach_campaigns`

Controlled campaigns for buyer acquisition, seller acquisition, laboratory network, logistics partners, relationship nurture, market research and other commercial programmes.

Campaign product must belong to the selected commodity. Campaign owner must be an active organisation member.

### `crm_outreach_targets`

Tracks a campaign/counterparty/contact through:

`researched → ready → contacted → responded → qualified / nurture → converted / closed`

with explicit disqualified and do-not-contact states.

A target may link to a buyer requirement, seller offer or opportunity only when the linked commercial object belongs to the same counterparty and is consistent with campaign commodity/product context.

A target cannot enter `converted` state without at least one linked commercial object.

### `crm_activities`

Append-only interaction history for introductions, follow-ups, qualification, document exchange, meetings, site visits, calls, messages, notes and other activity.

It records channel, direction, outcome, timestamp, subject/summary, evidence, follow-up and optional links to campaign/target/requirement/offer/opportunity.

Activities cannot be updated or deleted through normal CRM access. Corrections are represented by a new activity using `supersedes_activity_id`.

Outbound activities are rejected when contactability or channel controls prohibit the interaction. Inbound activity may still be recorded for audit/relationship history and does not clear DNC status.

### `crm_tasks`

Work queue for research, follow-up, qualification, document review, KYC, inspection, meetings and outreach.

Outbound-channel tasks are subject to the same DNC/channel controls as activities. Completed/cancelled tasks cannot be reopened; a new follow-up task must be created.

### `crm_watchlists`

Private/shared watchlists owned by active organisation members. Protected watchlists remain subject to privileged MRCIP visibility.

### `crm_watchlist_items`

Typed watchlist entries for:

- counterparties;
- mines;
- laboratories;
- buyer requirements;
- seller offers;
- opportunities.

Exactly one supported entity reference is allowed per row. Protected seller offers/opportunities propagate protected context into the watchlist item.

## Contactability / DNC control

`private.crm_channel_is_allowed(...)` is the central channel decision helper.

Database guards enforce it when:

- recording outbound CRM activity;
- creating/updating a task with an outbound channel;
- moving a DNC target into an outreach-active status.

Therefore a UI, import or direct authenticated Data API write cannot simply bypass the DNC rule.

## Activity integrity

CRM communication history is append-only. This prevents silent rewriting of who was contacted, when, through which channel and with what outcome.

Correction workflow:

**ORIGINAL ACTIVITY → CORRECTIVE ACTIVITY (`supersedes_activity_id`)**

The original evidence remains retained.

## Opportunity / protection integration

Stage 8 does not create opportunities directly. A CRM target can reference an existing opportunity only if the counterparty is the buyer or seller on that opportunity.

The Stage 4 **PROTECT → VERIFY → DISCLOSE → CONTRACT** workflow remains authoritative for protected introductions and source disclosure.

CRM records cannot be used as a shortcut around the Deal Room disclosure gate.

## Protected evidence

If an activity inherits protected context, its evidence document must use the existing `mrcip_protected` document classification. A generic document is rejected by the database guard.

## Authenticated regression

A rollback-isolated authenticated Stage 8 fixture passed all exercised controls:

| Control | Result |
|---|---|
| Protected contact control inherits protected context | PASS |
| General outreach target can enter ready state | PASS |
| DNC/protected target retains protected context | PASS |
| Permitted outbound email activity succeeds | PASS |
| Outbound activity updates target contact state/timestamps | PASS |
| DNC outbound email activity is blocked | PASS |
| Inbound activity for DNC target is recordable without clearing DNC | PASS |
| CRM activity UPDATE is rejected as append-only | PASS |
| Normal outbound follow-up task can be created/completed | PASS |
| Completed task cannot be reopened | PASS |
| DNC outbound task is blocked | PASS |
| Target conversion without commercial link is blocked | PASS |
| Target conversion after valid buyer-requirement linkage succeeds | PASS |
| Protected seller offer propagates to watchlist item | PASS |
| Generic evidence is rejected for protected CRM activity | PASS |
| Protected evidence is accepted for protected CRM activity | PASS |
| Cross-counterparty contact/activity linkage is rejected | PASS |

## RLS / Data API security

RLS is enabled on all seven Stage 8 public tables.

`anon` has **zero Stage 8 table privileges**.

Authenticated table grants are explicit:

- `crm_contact_controls`: `SELECT, INSERT, UPDATE`;
- `crm_outreach_campaigns`: `SELECT, INSERT, UPDATE, DELETE` with RLS-limited deletion;
- `crm_outreach_targets`: `SELECT, INSERT, UPDATE, DELETE` with RLS-limited deletion;
- `crm_activities`: `SELECT, INSERT` only;
- `crm_tasks`: `SELECT, INSERT, UPDATE, DELETE` with RLS/lifecycle controls;
- `crm_watchlists`: `SELECT, INSERT, UPDATE, DELETE`;
- `crm_watchlist_items`: `SELECT, INSERT, UPDATE, DELETE`.

All ten Stage 8 private guard/helper functions use fixed search paths and are non-executable by `anon` and `authenticated` roles.

## Advisor results

### Security advisor

No new Stage 8-specific security warning remains.

Tracked pre-existing warnings remain:

- authenticated-callable existing Auth/access `SECURITY DEFINER` RPCs;
- leaked-password protection disabled.

They predate Stage 8 and remain assigned to a dedicated Auth regression/configuration pass.

### Performance advisor

The first Stage 8 performance pass identified missing covering indexes for the campaign product relationship and six optional watchlist-item entity foreign keys.

`20260821041325_mrcip_stage_8c_performance_hardening` adds the required indexes. The rerun no longer reports those Stage 8 unindexed-FK findings.

Remaining notices are expected unused-index messages on new/empty CRM tables and the pre-existing duplicate organisation-membership index. New indexes are not being removed before production workload exists.

## Type generation

Supabase TypeScript database type generation succeeded after Stage 8 and includes all seven CRM tables and their tenant-safe relationships.

## Test isolation / residue

The authenticated regression ran inside a transaction and rolled back. Final production row counts are:

- contact controls: **0**;
- campaigns: **0**;
- targets: **0**;
- activities: **0**;
- tasks: **0**;
- watchlists: **0**;
- watchlist items: **0**.

No Stage 8 fixture data remains.

## Existing systems preserved

Stage 8 does not modify:

- quotation calculations;
- invoice calculations;
- VAT calculations;
- Finance line-item arithmetic;
- Payments semantics;
- Stage 6 commission-settlement arithmetic;
- Stage 7 laboratory-result/certificate arithmetic or evidence lineage;
- Freight profitability calculations;
- Negotiations logic;
- trips, vehicles or driver execution calculations.

## Known limitations / next integration work

- Stage 8 is a CRM control/data foundation; the complete Admin CRM UI is not present in the connected repository.
- No Gmail/SMTP/WhatsApp/LinkedIn provider is connected for automatic sending.
- External provider message IDs can be recorded later in `external_reference`, but Stage 8 does not claim provider delivery or response status.
- Watchlists are persistent user/team collections; automated market-change alert evaluation is a later signal/intelligence stage.
- The exact consolidated seed intelligence workbook remains unresolved for controlled import.

## Sign-off

Stage 8 meets its database, access-control and CRM-governance acceptance criteria:

- canonical counterparties/contacts are reused;
- contactability and DNC controls are database enforced;
- outbound activity/tasks cannot bypass DNC/channel restrictions;
- inbound history remains recordable without clearing restrictions;
- protected context propagates into CRM records;
- protected evidence must remain protected;
- communication history is append-only;
- closed tasks cannot be silently reopened;
- conversion requires a real commercial object;
- cross-counterparty linkage is rejected;
- watchlists are tenant-scoped and protected-context aware;
- RLS is enabled on every Stage 8 table;
- anonymous Stage 8 table access is absent;
- private guards are not Data-API callable;
- advisor findings introduced during Stage 8 were remediated;
- TypeScript type generation succeeded;
- regression fixtures leave zero production residue.

**STAGE 8 SIGN-OFF: APPROVED**

Recommended next database-capable stage: **Data Quality, Risk & Opportunity Scoring plus operational read models**, while full Dashboard/Map/Admin presentation remains blocked until the complete application source is available.
