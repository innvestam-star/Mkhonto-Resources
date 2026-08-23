# MRCIP Stage 3 Implementation Audit

**Stage:** Buyer Requirements, Seller Supply Offers, Structured Specifications and Explainable Matching  
**Hosted project:** `zjrzzvakwrwkrcqhcnyo`  
**Branch:** `mrcip/phase-0-audit`  
**Status:** **DATABASE FOUNDATION SIGNED OFF**

## 1. Scope delivered

Stage 3 establishes the transactional supply/demand layer required to convert commodity intelligence into auditable buyer–seller matching.

Delivered:

- Buyer requirement register.
- Seller supply-offer register.
- Structured buyer specification constraints.
- Structured seller assay/specification values.
- Optional laboratory/certificate document linkage.
- Explainable deterministic matching ledger.
- Versioned matching RPC.
- Protected seller-offer visibility inheritance.
- Explicit Data API least-privilege grants.
- Composite tenant-integrity foreign keys.
- Performance hardening and advisor verification.

No Finance, Freight, Payments, Negotiations, Trips or existing quotation/invoice calculation logic was rewritten.

## 2. Applied migrations

| Version | Migration | Purpose |
|---|---|---|
| `20260821022859` | `mrcip_stage_3a_supply_demand_and_specifications` | Requirements, offers and structured specification values |
| `20260821022922` | `mrcip_stage_3b_supply_demand_rls_and_grants` | RLS and initial Data API access |
| `20260821023105` | `mrcip_stage_3c_explainable_matching_engine` | Match ledger, scoring model and refresh RPC |
| `20260821023242` | `mrcip_stage_3d_data_api_least_privilege_hardening` | Remove excess authenticated table privileges |
| `20260821023355` | `mrcip_stage_3e_performance_hardening` | Missing composite product-FK indexes |
| `20260821023527` | `mrcip_stage_3f_certificate_tenant_integrity` | Enforce same-tenant certificate/document linkage |

## 3. New relational model

### `buyer_requirements`

Stores the buyer's commercial requirement and authority/protection state, including:

- buyer and optional buyer contact;
- commodity/product;
- total/monthly/minimum lot quantities;
- contract term and delivery window;
- destination and preferred origins;
- Incoterm and pricing basis;
- target price/currency;
- payment instrument/terms;
- inspection requirements;
- logistics responsibility and Mkhonto transport request;
- authority, mandate and protection status;
- validity and provenance source.

### `seller_supply_offers`

Stores an offer capable of being matched transactionally, including:

- seller and optional seller contact;
- optional mine;
- commodity/product;
- available/monthly/minimum lot quantities;
- origin and loading information;
- price/currency/basis/Incoterm;
- payment and inspection terms;
- logistics responsibility and Mkhonto transport availability;
- authority, mandate and protection state;
- validity and provenance source;
- explicit `is_protected` flag.

### `buyer_requirement_specs`

Stores field-level constraints using the commodity specification catalogue:

- mandatory/optional status;
- weight;
- minimum, maximum and target numeric values;
- expected text value;
- unit and basis.

### `seller_offer_specs`

Stores the seller's actual specification/assay values:

- numeric or text value;
- unit and basis;
- test method;
- test date;
- optional certificate document.

The certificate document relationship was hardened in Stage 3f to require the same `organisation_id`, preventing cross-tenant document linkage even if another document UUID were known.

### `commodity_matches`

Persists generated matching evidence and human review state. Generated score evidence is separate from human outcomes such as `shortlisted`, `accepted`, or `rejected`.

## 4. Matching algorithm v1

Function: `public.refresh_buyer_requirement_matches(uuid)`

Security characteristics:

- `SECURITY INVOKER`.
- Empty `search_path`.
- Execute granted to `authenticated` and `service_role` only.
- No `anon` or `public` execute grant.
- Explicit privileged MRCIP role check before refresh.

### Hard filters

A candidate is disqualified when:

1. product compatibility fails; or
2. one or more mandatory structured specifications fail.

Seller candidates are first constrained to the same organisation, same commodity, active status and valid availability window.

### Score weights

| Component | Maximum |
|---|---:|
| Commodity | 20 |
| Product | 10 |
| Structured specifications | 30 |
| Quantity | 10 |
| Origin | 5 |
| Incoterm | 5 |
| Logistics | 5 |
| Commercial/price | 5 |
| Seller verification | 10 |
| **Total** | **100** |

The stored explanation contains component scores, hard-filter results, failed mandatory specification detail, requirement/offer references and algorithm version.

If a refresh is run again, generated candidate/disqualified rows are recalculated, while human decisions `shortlisted`, `accepted`, and `rejected` are preserved.

## 5. Functional regression tests

All Stage 3 functional fixtures were executed inside database transactions and rolled back.

### Positive path

Fixture characteristics:

- coal requirement and coal offer;
- same product;
- buyer minimum calorific value: 6000 kcal/kg;
- seller value: 6500 kcal/kg;
- sufficient monthly volume;
- compatible South African origin;
- matching FOB Incoterm;
- Mkhonto logistics compatibility;
- seller price below buyer target;
- verified seller.

Result:

- **99.80 / 100** total score;
- `hard_filter_pass = true`;
- `failed_mandatory_specs = 0`;
- status `candidate`;
- component evidence persisted correctly.

### Mandatory-specification failure path

Fixture characteristics:

- buyer minimum calorific value: 6000 kcal/kg;
- seller value: 5500 kcal/kg.

Result:

- **50.00 / 100** generated score;
- `hard_filter_pass = false`;
- `failed_mandatory_specs = 1`;
- status `disqualified`;
- one failed-specification evidence object persisted.

### Fixture cleanup

After rollback, test-fixture counts were verified as zero for:

- test counterparties;
- test buyer requirements;
- test seller offers;
- test commodity matches.

## 6. RLS and Data API verification

RLS is enabled on all five Stage 3 public tables:

- `buyer_requirements`;
- `seller_supply_offers`;
- `buyer_requirement_specs`;
- `seller_offer_specs`;
- `commodity_matches`.

Each table has separate SELECT/INSERT/UPDATE/DELETE policies rather than a broad `FOR ALL` policy.

Protected seller offers are visible only to privileged MRCIP roles. Dependent seller specification and match rows inherit the seller-offer visibility through RLS-aware existence checks.

During the grant audit, legacy project default ACLs were found to have added `TRUNCATE`, `REFERENCES`, and `TRIGGER` privileges for `authenticated` on new tables. Because RLS does not protect `TRUNCATE`, these grants were removed. The authenticated role now receives only:

- SELECT;
- INSERT;
- UPDATE;
- DELETE.

No Stage 3 tables are granted to `anon`.

## 7. Tenant-integrity verification

Stage 3 uses composite foreign keys containing `organisation_id` for linked MRCIP entities. This prevents a valid UUID from another tenant being attached to a requirement, offer, specification, match or certificate record.

The Stage 3f audit specifically corrected the initial certificate-document relationship from global document ID only to:

`(organisation_id, certificate_document_id) -> documents(organisation_id, id)`

## 8. Security advisor result

After Stage 3f, no new Stage 3 security lints were reported.

Remaining project-level warnings are pre-existing and separately tracked:

- authenticated execution of `SECURITY DEFINER` `can_access_portal`;
- authenticated execution of `SECURITY DEFINER` `complete_organisation_onboarding`;
- authenticated execution of `SECURITY DEFINER` `get_my_access`;
- leaked-password protection disabled in Supabase Auth.

These were not modified in Stage 3 to avoid unrelated Auth regression risk.

## 9. Performance advisor result

The two Stage 3 unindexed composite product foreign keys were remediated in Stage 3e. The certificate composite FK has its covering index after Stage 3f.

No new unindexed-foreign-key warning remains for Stage 3.

Remaining notices are predominantly unused-index information expected on empty/new intelligence tables, plus the organisation-membership duplicate-index warning that predates MRCIP.

## 10. Existing-module regression protection

The following existing domains remained structurally untouched by Stage 3:

- Finance documents;
- Finance line items and VAT calculation data;
- Payments;
- Freight analyses;
- Negotiations;
- Trips.

Their live row counts remained unchanged during the Stage 3 work.

The matching engine deliberately does **not** recreate the Freight profitability calculator. Future route economics must link to the existing Freight module rather than fork calculation logic.

## 11. Known v1 boundaries

These are intentional limitations rather than hidden functionality:

- No automatic currency conversion. A currency mismatch lowers the commercial component rather than fabricating an FX conversion.
- No automatic unit conversion. Unit/basis mismatches are handled conservatively until a controlled normalisation layer is implemented.
- No route-distance or CPK profitability calculation inside the matching engine; this belongs to the existing Freight integration.
- No real buyer/seller intelligence imported yet because the exact consolidated source workbook is not resolved in the implementation runtime.
- No Stage 3 Admin UI is implemented because the connected GitHub repository contains only the partial application foundation.

## 12. Sign-off

**Stage 3 database foundation: SIGNED OFF.**

The next transaction-domain stage is the **Opportunity / Deal Room and protected-introduction workflow**, linking an approved match to protection, KYC/KYB, mandate authority, disclosure gates, legal documents, Freight and Finance by reference.
