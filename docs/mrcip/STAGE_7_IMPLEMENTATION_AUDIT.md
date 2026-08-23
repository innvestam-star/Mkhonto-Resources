# MRCIP Stage 7 Implementation Audit & Sign-Off

## Stage

**Stage 7 — Sampling, Inspection & Laboratory Certificate Workflow**

## Status

**SIGNED OFF — DATABASE / SECURITY / EVIDENCE TRACEABILITY FOUNDATION COMPLETE**

Stage 7 is live in the hosted **Mkhonto Resources Hub** project and is reconciled to source control through the exact hosted migration version:

`20260821035501_mrcip_stage_7d_performance_and_audit_policy_hardening`

## Purpose

Stage 7 turns the existing laboratory, commodity-specification, seller-offer and protected Deal Room foundations into an auditable quality-evidence workflow.

The controlled operating chain is:

**OPPORTUNITY / SELLER OFFER / MINE → SAMPLING REQUEST → PHYSICAL SAMPLE → CHAIN OF CUSTODY → LAB TEST ORDER → REPORTED RESULT → PROTECTED CERTIFICATE / COA → HUMAN VERIFICATION → CONTROLLED PUBLICATION TO SELLER SPECIFICATIONS → DEAL ROOM EVIDENCE**

Stage 7 deliberately reuses existing MRCIP records rather than creating a second commodity-specification engine or a second document repository.

## Architecture decisions

### Reused existing authoritative domains

Stage 7 reuses:

- `public.laboratories` and `public.laboratory_capabilities` for the laboratory network;
- `public.commodity_spec_fields` for structured commodity-quality fields;
- `public.seller_offer_specs` for the commercial seller-offer assay/specification surface;
- `public.documents` and the `mrcip_protected` document classification for certificate/evidence storage metadata;
- `public.opportunity_document_links` for Deal Room evidence;
- `public.audit_events` for governed audit events.

No Finance, Freight, Payments, Negotiations or quotation/invoice calculation logic was duplicated or changed.

### Evidence immutability

Stage 7 treats custody events, verified laboratory evidence and publication history as commercial evidence. They are append-only or revision-controlled rather than silently rewritten.

## Implemented tables

| Requirement | Status | Implementation |
|---|---|---|
| Sampling / inspection requests | LIVE | `public.commodity_sampling_requests` |
| Physical samples and split/duplicate lineage | LIVE | `public.commodity_samples` |
| Chain-of-custody ledger | LIVE | `public.sample_custody_events` |
| Laboratory test orders | LIVE | `public.laboratory_test_orders` |
| Revisioned laboratory results | LIVE | `public.laboratory_test_results` |
| Laboratory certificates / COAs | LIVE | `public.laboratory_certificates` |
| Commodity inspection records | LIVE | `public.commodity_inspections` |
| Verified-result publication ledger | LIVE | `public.lab_result_publications` |

All Stage 7 entity relationships are organisation-scoped. Composite tenant relationships are used when linking to opportunities, seller offers, mines, laboratories, commodities, products, documents, specification fields and seller-offer specifications.

## Controlled workflow RPCs

The public Stage 7 workflow exposes six authenticated, `SECURITY INVOKER` RPCs:

1. `record_sample_custody_event(...)`
2. `verify_laboratory_certificate(uuid,text)`
3. `verify_laboratory_test_result(uuid,uuid,text)`
4. `create_laboratory_result_revision(...)`
5. `verify_commodity_inspection(uuid,text)`
6. `publish_verified_laboratory_result(uuid,uuid,uuid,boolean,text)`

The internal trigger/helper functions are in the private schema, use controlled `SECURITY DEFINER` execution where required, set an empty search path, and are not executable by `anon` or `authenticated` roles.

## Sampling request controls

A sampling request may be linked to an opportunity, seller offer and/or mine. When linked to an opportunity or seller offer, the request enforces consistency for:

- seller offer;
- commodity;
- product;
- mine;
- laboratory;
- protected-record state.

Protected seller offers force the sampling request into protected handling.

## Physical sample and chain-of-custody controls

Samples support primary, split, duplicate, reference, retained, composite and other sample types.

Once chain-of-custody has started, core sample identity and collection fields cannot be silently rewritten.

Custody events are append-only and include events such as:

- sealed;
- handover;
- received;
- split;
- repacked;
- seal checked;
- test started;
- retained;
- released;
- disposed;
- exception.

Custody events cannot predate sample collection. Protected custody evidence must reference an `mrcip_protected` Document.

Custody events also derive operational sample states such as sealed, in-transit, received-at-lab and under-test.

## Laboratory order controls

A laboratory order must reference a sample belonging to the same sampling request and, when a laboratory has been assigned at request level, must use that laboratory.

A laboratory cannot mark a sample as received without a corresponding chain-of-custody `received` event.

Direct order verification is blocked. Verification is driven by the verified-certificate and verified-result workflow.

## Laboratory result controls

Laboratory results use the existing `commodity_spec_fields` catalogue.

Controls include:

- the specification field must belong to the sampling request commodity;
- numeric specification fields require numeric values;
- non-numeric specification fields require text values;
- reported values become immutable;
- verified results are immutable;
- corrections use a controlled revision chain;
- a revision must be exactly the previous revision number + 1 and link to its predecessor;
- verification of a corrected result supersedes the previous verified result.

This prevents a laboratory value from being silently changed after it has become commercial evidence.

## Certificate / COA controls

Certificates must:

- belong to the same laboratory as the test order;
- reference an existing protected MRCIP Document;
- begin in `received` state;
- retain a snapshot of the protected Document checksum;
- be explicitly verified by an authorised human workflow before they can support commercial publication.

A verified certificate linked to an opportunity is automatically linked into the protected Deal Room using the existing Stage 4 `assay` document role.

## Inspection controls

Inspection records support stockpile, pre-shipment, sampling supervision, loading, weighbridge, vessel, quality-visual and other inspection types.

A completed inspection requires an inspection time and non-pending outcome. Verification requires findings or supporting evidence. Protected inspection evidence must use a protected MRCIP document.

Verified inspection evidence linked to an opportunity is added to the Deal Room using the existing Stage 4 `inspection` document role.

## Controlled publication into seller specifications

Stage 7 does not create a parallel public assay record. A verified laboratory result can be published into the existing `seller_offer_specs` record only when:

- the result is verified;
- the certificate is verified;
- result and certificate belong to the same laboratory order;
- the seller offer matches the sampling request and opportunity context;
- commodity context is consistent.

If the seller-offer specification does not exist, Stage 7 inserts it with certificate evidence.

If the same value/evidence already exists, the action is recorded as `no_change`.

If a different seller-offer value already exists, publication is blocked unless the caller explicitly approves replacement. A replacement captures the previous value in the append-only publication ledger.

Cross-offer publication is blocked.

## Audit-event hardening

During Stage 7 implementation, a legacy exposure was identified on `public.audit_events`: authenticated/anonymous table grants were broader than required, including privileges that were inappropriate for an audit ledger.

Stage 7 hardened the table to:

- no `anon` table privileges;
- authenticated `SELECT` and `INSERT` only;
- a consolidated authorised SELECT policy covering existing management roles and MRCIP executive/commodity/legal roles.

No audit-event data model or Finance calculation was changed.

## End-to-end regression

The final authenticated Stage 7 fixture passed **14/14 controls**:

| Test | Result |
|---|---|
| Protected opportunity/seller-offer context inherited by sampling request | PASS |
| Custody events drive sample status | PASS |
| Core sample identity immutable after custody starts | PASS |
| Direct laboratory-order verification blocked | PASS |
| Generic/non-protected certificate document rejected | PASS |
| Verified protected COA linked to Deal Room as `assay` | PASS |
| Reported result + verified COA produces verified result/order | PASS |
| Verified 5850 kcal/kg result published to seller specification | PASS |
| Verified result value cannot be rewritten | PASS |
| Controlled corrected-result revision supersedes prior verified revision | PASS |
| Silent seller-spec overwrite blocked; explicit replacement publishes 5900 kcal/kg | PASS |
| Publication to unrelated seller offer blocked | PASS |
| Verified inspection evidence linked to protected Deal Room | PASS |
| Custody ledger authenticated UPDATE rejected | PASS |

The corrected-result scenario specifically verified:

- initial result: **5850 kcal/kg ADB**, ASTM D5865;
- verified protected COA;
- controlled publication to seller offer;
- corrected revision: **5900 kcal/kg ADB**;
- previous verified result superseded;
- replacement blocked without explicit approval;
- approved replacement updates the seller specification while retaining publication history.

## Defects / compatibility issues found and remediated

### 1. Stage 4 Deal Room document-role compatibility

The first Stage 7 integration pass attempted new role labels `laboratory_certificate` and `inspection_report`, but Stage 4 already had a controlled vocabulary containing `assay` and `inspection`.

**Remediation:** `20260821035207_mrcip_stage_7c_deal_room_document_role_compatibility` reuses the established Stage 4 roles rather than widening vocabulary or bypassing the Deal Room constraint.

### 2. Missing product-FK covering index

The performance advisor identified a missing covering index for the optional sampling-request product FK.

**Remediation:** `20260821035501_mrcip_stage_7d_performance_and_audit_policy_hardening` adds the required product index.

### 3. Overlapping audit-event SELECT policies

The performance advisor identified overlapping authenticated SELECT policies after MRCIP audit access was added.

**Remediation:** Stage 7d replaces the overlapping policies with one consolidated `audit_events_select_authorised` policy preserving both existing management access and MRCIP executive/commodity/legal access.

## RLS / Data API security

RLS is enabled on all eight Stage 7 public tables.

`anon` has **zero Stage 7 table privileges**.

Authenticated grants are explicit:

- sampling requests: `SELECT, INSERT, UPDATE, DELETE` with DELETE limited by RLS to draft records and Super Admin / Managing Director;
- samples: `SELECT, INSERT, UPDATE`;
- custody events: `SELECT, INSERT` only;
- laboratory orders: `SELECT, INSERT, UPDATE, DELETE` with DELETE limited to draft records and Super Admin / Managing Director;
- laboratory results: `SELECT, INSERT, UPDATE`;
- laboratory certificates: `SELECT, INSERT, UPDATE`;
- inspections: `SELECT, INSERT, UPDATE`;
- publication ledger: `SELECT, INSERT` only.

The public workflow RPCs are not anonymously executable.

## Advisor results

### Security advisor

No new Stage 7-specific security finding remains.

Tracked pre-existing warnings remain:

- authenticated-callable Auth/access `SECURITY DEFINER` RPCs;
- leaked-password protection disabled.

Those controls predate MRCIP Stage 7 and remain assigned to a dedicated Auth regression/configuration pass.

### Performance advisor

The Stage 7 product-FK and overlapping-policy findings were remediated.

Remaining advisor notices are:

- expected unused-index notices on new/empty tables;
- the pre-existing duplicate organisation-membership index.

Unused indexes are not being removed merely because the new tables do not yet contain production volume.

## Type generation

Supabase TypeScript type generation succeeded after Stage 7 and includes all eight Stage 7 tables and all six controlled public workflow RPCs.

## Test isolation / residue

The evidence controls intentionally prevent normal deletion of append-only publication/custody history. The test harness therefore used database-maintenance cleanup only for uniquely tagged Stage 7 fixture rows after the authenticated regression completed.

Final residue checks returned:

- fixture counterparties: **0**;
- sampling requests: **0**;
- samples: **0**;
- laboratory test orders: **0**;
- laboratory test results: **0**;
- laboratory certificates: **0**;
- inspections: **0**;
- protected fixture documents: **0**;
- publication ledger fixture rows: **0**.

No production Stage 7 test data remains.

## Existing systems preserved

Stage 7 does not modify:

- quotation calculations;
- invoice calculations;
- VAT calculations;
- Finance line-item arithmetic;
- Payments semantics;
- Stage 6 commission settlement arithmetic;
- Freight profitability calculations;
- Negotiations logic;
- trip/vehicle/driver execution calculations.

## Known limitations / next integration work

- Stage 7 manages and verifies laboratory evidence but does not call an external laboratory LIMS/API.
- Certificate OCR/extraction is not automated in this stage.
- A verified record represents an authorised internal verification workflow; it does not independently guarantee the external laboratory's authenticity beyond the evidence captured.
- The full Admin UI for sampling, custody, laboratory review and publication is still unavailable because the connected GitHub repository contains only the partial application source.
- External e-signature and third-party inspection integrations remain future integrations.

## Sign-off

Stage 7 meets the database, security, evidence-traceability and commercial-publication acceptance criteria:

- protected opportunity/offer context is preserved;
- physical sample lineage is traceable;
- chain-of-custody is append-only;
- laboratory receipt depends on custody evidence;
- reported and verified results cannot be silently rewritten;
- corrections are revision-controlled;
- certificates are protected and checksum-linked;
- human verification gates commercial publication;
- silent seller-spec replacement is blocked;
- cross-offer publication is blocked;
- inspection evidence is protected and Deal Room-linked;
- RLS and tenant boundaries are enforced;
- no anonymous Stage 7 access exists;
- advisor findings introduced during Stage 7 were remediated;
- regression fixtures leave zero production residue.

**STAGE 7 SIGN-OFF: APPROVED**

Recommended next stage: **Outreach CRM, Communications, Tasks & Watchlists**.
