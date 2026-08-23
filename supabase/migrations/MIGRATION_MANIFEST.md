# Hosted Supabase Migration Manifest

The active hosted project is **Mkhonto Resources Hub** with project reference `zjrzzvakwrwkrcqhcnyo`.

## Authority and recovery status

The hosted `supabase_migrations.schema_migrations` history is the authoritative migration record. The original migration-history recovery blocker is resolved, including the historical migrations that pre-date the reconstructed repository.

**Stage 13 provenance is fully reconciled.** All nine Stage 13 migrations now have exact source-controlled SQL counterparts. The previously missing 13c and 13d bodies were recovered directly from the hosted migration authority in commit `c8395610b35a59fab1dbd23c2ac9e1d19afb5bec`, with `git hash-object` required to match the hosted Git blob SHAs before commit.

Do **not** replace this history with a fresh or manually invented baseline.

## Authoritative source-controlled chain

### Historical platform migrations

- `20260803202920_mkhonto_hub_phase_4_foundation.sql`
- `20260803203051_mkhonto_hub_fk_indexes.sql`
- `20260805191833_auth_access_and_protected_route_foundation.sql`
- `20260805191850_restrict_auth_rpc_execution.sql`

### Stage 1 — Counterparty / commodity / provenance / access foundation

- `20260821020531_mrcip_stage_1a_access_and_counterparties.sql`
- `20260821020602_mrcip_stage_1b_commodities_and_provenance.sql`
- `20260821020620_mrcip_stage_1c_rls_core.sql`
- `20260821020632_mrcip_stage_1d_rls_commodity_and_provenance.sql`
- `20260821020648_mrcip_stage_1e_access_hardening.sql`
- `20260821020739_mrcip_stage_1f_extension_security.sql`
- `20260821021629_mrcip_stage_1g_performance_hardening.sql`

### Stage 2 — Mines / laboratories / controlled import staging

- `20260821022028_mrcip_stage_2a_mines_and_laboratories.sql`
- `20260821022047_mrcip_stage_2b_import_staging.sql`
- `20260821022109_mrcip_stage_2c_rls_and_access.sql`
- `20260821022131_mrcip_stage_2d_performance_hardening.sql`

### Stage 3 — Supply / demand / structured specifications / matching

- `20260821022859_mrcip_stage_3a_supply_demand_and_specifications.sql`
- `20260821022922_mrcip_stage_3b_supply_demand_rls_and_grants.sql`
- `20260821023105_mrcip_stage_3c_explainable_matching_engine.sql`
- `20260821023242_mrcip_stage_3d_data_api_least_privilege_hardening.sql`
- `20260821023355_mrcip_stage_3e_performance_hardening.sql`
- `20260821023527_mrcip_stage_3f_certificate_tenant_integrity.sql`

### Stage 4 — Opportunity / Deal Room / protection protocol

- `20260821024154_mrcip_stage_4a_document_acl_hardening.sql`
- `20260821024314_mrcip_stage_4b_opportunity_and_protocol_foundation.sql`
- `20260821024343_mrcip_stage_4c_opportunity_protocol_rls.sql`
- `20260821024432_mrcip_stage_4d_protect_verify_disclose_contract_engine.sql`
- `20260821024626_mrcip_stage_4e_deal_room_module_links.sql`
- `20260821024645_mrcip_stage_4f_protected_document_storage_hardening.sql`
- `20260821024843_mrcip_stage_4g_performance_and_grant_hardening.sql`

### Stage 5 — Facilitator chain / commission commercial control

- `20260821030523_mrcip_stage_5a_facilitator_chain_foundation.sql`
- `20260821030615_mrcip_stage_5b0_tenant_identity_hardening.sql`
- `20260821030657_mrcip_stage_5b_commission_control_foundation.sql`
- `20260821030756_mrcip_stage_5c_approval_revision_and_trigger_engine.sql`
- `20260821030906_mrcip_stage_5d_lifecycle_hardening.sql`

### Stage 6 — Commission settlement / reconciliation / closeout

- `20260821032352_mrcip_stage_6a_commission_settlement_foundation.sql`
- `20260821032555_mrcip_stage_6b_settlement_reconciliation_engine.sql`
- `20260821032908_mrcip_stage_6c_internal_guard_context_hardening.sql`
- `20260821032955_mrcip_stage_6d_closeout_guard_alias_hardening.sql`
- `20260821033201_mrcip_stage_6e_performance_hardening.sql`

### Stage 7 — Sampling / chain of custody / laboratory / inspection

- `20260821034553_mrcip_stage_7a_sampling_inspection_lab_foundation.sql`
- `20260821034833_mrcip_stage_7b_traceability_workflow_and_security.sql`
- `20260821035207_mrcip_stage_7c_deal_room_document_role_compatibility.sql`
- `20260821035501_mrcip_stage_7d_performance_and_audit_policy_hardening.sql`

### Stage 8 — CRM / DNC / outreach / watchlists

- `20260821041017_mrcip_stage_8a_outreach_crm_foundation.sql`
- `20260821041203_mrcip_stage_8b_crm_workflow_and_security.sql`
- `20260821041325_mrcip_stage_8c_performance_hardening.sql`

### Stage 9 — Quality / protected risk / opportunity readiness

- `20260821042643_mrcip_stage_9a_quality_risk_scoring_foundation.sql`
- `20260821042835_mrcip_stage_9b_deterministic_scoring_and_read_models.sql`
- `20260821043244_mrcip_stage_9c_scoring_integrity_hardening.sql`

### Stage 10 — Reports / watchlist signals / authorised retrieval

- `20260821045132_mrcip_stage_10a_reports_signals_retrieval_foundation.sql`
- `20260821045323_mrcip_stage_10b_report_engine_and_security.sql`
- `20260821045414_mrcip_stage_10c_watchlist_signal_engine.sql`
- `20260821045457_mrcip_stage_10d_authorised_retrieval_foundation.sql`
- `20260821045834_mrcip_stage_10e_performance_hardening.sql`

### Stage 11 — Governed AI evidence / citations / review

- `20260821052113_mrcip_stage_11a_ai_orchestration_and_citation_foundation.sql`
- `20260821052234_mrcip_stage_11b_governed_ai_workflow_engine.sql`
- `20260821052322_mrcip_stage_11c_ai_review_rls_and_read_models.sql`
- `20260821052512_mrcip_stage_11d_performance_hardening.sql`

### Stage 12 — Prompt governance / controlled AI execution gateway

- `20260821054219_mrcip_stage_12a_prompt_execution_gateway_foundation.sql`
- `20260821054510_mrcip_stage_12b_prompt_approval_and_execution_control.sql`
- `20260821054537_mrcip_stage_12c_execution_rls_and_read_models.sql`
- `20260821054726_mrcip_stage_12d_gateway_service_authorization_fix.sql`
- `20260821054833_mrcip_stage_12e_provider_request_event_audit.sql`
- `20260821054900_mrcip_stage_12f_provider_failure_state_hardening.sql`
- `20260821055114_mrcip_stage_12g_performance_hardening.sql`

### Stage 13 — Evaluation / safety calibration / provider commercial and onboarding controls

- `20260821060725_mrcip_stage_13a_ai_evaluation_foundation.sql`
- `20260821060752_mrcip_stage_13b_provider_commercial_and_onboarding_foundation.sql`
- `20260821060927_mrcip_stage_13c_evaluation_workflow_engine.sql`
- `20260821061049_mrcip_stage_13d_provider_onboarding_budget_and_activation_gates.sql`
- `20260821061129_mrcip_stage_13e_rls_grants_and_read_models.sql`
- `20260821061339_mrcip_stage_13e_rls_read_models_and_drift_reconciliation.sql`
- `20260821061513_mrcip_stage_13f_onboarding_revocation_and_refusal_hardening.sql`
- `20260821061623_mrcip_stage_13g_evaluation_gateway_payload_hardening.sql`
- `20260821061636_mrcip_stage_13h_eval_gateway_service_rpc_grants.sql`

### Programme-wide retrospective ACL hardening

- `20260823081757_mrcip_retrospective_acl_hardening_stages_1_13.sql`

## Stage 13 hosted/source identity

| Migration | Hosted Git blob SHA | Source-control status |
|---|---|---|
| 13a | `a826b4214fe3af0c7c467d36e226cb055c2ea13f` | Exact GitHub match |
| 13b | `43c931898a842065361bb6b549966e6d1624b9e0` | Exact GitHub match |
| 13c | `4bafdf0acbee619e4949bd21ab7b6eb5a49f3635` | Exact GitHub match — recovered in `c8395610b35a59fab1dbd23c2ac9e1d19afb5bec` |
| 13d | `3e986530652939cd381d1c337e548c14f50bb9eb` | Exact GitHub match — recovered in `c8395610b35a59fab1dbd23c2ac9e1d19afb5bec` |
| 13e / `20260821061129` | `0d7e9f9dac1bf241a0ad2f0a24fc8a83bc569e4f` | Exact GitHub match |
| 13e / `20260821061339` | `b7ac746901402e86face5c14070e46de190c5958` | Exact GitHub match |
| 13f | `d69f4c436a16c1c8d55b68333c48b66bee33f4e8` | Exact GitHub match |
| 13g | `0eed99b877945d44cdfc830b9401a770e763f7f8` | Exact GitHub match |
| 13h | `7c5bc53b9bd685eb6a6bceacebec6494856e3572` | Exact GitHub match |
| retrospective ACL hardening | `41b1d561798ca48b1cee68db22692bce934b860e` | Exact GitHub match |

**Stage 13 migration provenance: 9/9 exact — SIGNED OFF.**

## Stage 13 recovery and cleanup evidence

The missing 13c and 13d SQL files were recovered through a short-lived, tightly scoped export path from the hosted migration table. The recovery path required exact final Git blob verification before source-control commit.

After successful recovery:

- the one-time GitHub recovery workflow removed itself;
- the temporary privileged export RPC was dropped from the database;
- generated TypeScript types no longer expose that temporary RPC;
- the temporary `mrcip-stage13-export` Edge Function was redeployed as a JWT-verified HTTP 410 decommissioned stub;
- no production business data was changed by source recovery;
- the production AI provider remained disabled/unconfigured.

## Programme verification checkpoint

- Hosted migration/schema operations remain healthy.
- TypeScript database type generation succeeds after Stage 13 cleanup.
- Stage 3 matching remains **99.80/100 candidate** and **50.00/100 disqualified** for the documented regression fixtures.
- Stage 4 retains **PROTECT → VERIFY → DISCLOSE → CONTRACT** as the protected disclosure gate.
- Stages 5–12 remain within their previously signed-off database/security/integration boundaries.
- Programme ACL remediation remains authoritative at **86 MRCIP public tables / 0 anon-exposed / 0 authenticated dangerous-grant tables**.
- No Stage 13 provenance cleanup redefined Finance, quotation/invoice/VAT, Payments, Freight, Negotiation, logistics or Auth behavior.
- Security Advisor still reports only the three pre-existing Auth `SECURITY DEFINER` warnings plus disabled leaked-password protection.
- Performance Advisor continues to show mostly unused-index information plus the pre-existing duplicate `organisation_memberships` index warning; no new Stage 13 provenance-related missing-FK-index defect was introduced.
- Full Admin browser/UI regression remains unclaimed because the complete application source is not present in the connected repository.

## Ongoing migration-control rules

1. The hosted migration history remains authoritative; never invent a replacement baseline.
2. Every future DDL change must have an exact source-controlled migration using the hosted version and body.
3. A migration is not reconciled until its Git blob SHA matches the hosted migration body.
4. Run security and performance advisors after structural database changes.
5. Regenerate TypeScript database types after schema changes when application source is synchronized.
6. Preserve existing Finance, Freight and Auth behavior unless a separately scoped regression-tested remediation requires change.
7. Intelligence imports must use staging, validation and duplicate review; never silently overwrite canonical records.
8. Matching must remain explainable and auditable; hard filters, score components, failed mandatory fields and human decisions are retained.
9. Do not duplicate Finance or Freight arithmetic inside MRCIP; integrate by reference.
10. Protected seller/source disclosure must remain governed by **PROTECT → VERIFY → DISCLOSE → CONTRACT**.
11. Protected Deal Room documents, contacts, coordinates, pricing, banking, KYC and commission data retain restrictive server-side authorization.
12. Approved facilitator, commission, settlement, custody, laboratory, CRM, scoring, report, retrieval and AI histories are controlled audit records; corrections use explicit revision/reversal workflows.
13. Stage 11–13 AI controls do not authorise autonomous outreach, source disclosure, negotiation, contracting, trading, payment execution or Finance/Freight mutation.
14. AI provider secrets must remain outside MRCIP tables in an approved external secret mechanism.
15. No provider/model may be represented as production-active without completed evaluated onboarding, credentials, rates/budget approval and the applicable go-live decision.
16. Production AI provider execution is currently **DISABLED / UNCONFIGURED**.

## Current checkpoint

**Stages 0–13 are signed off at their documented database/security/commercial-control boundaries. Stage 13 migration provenance is fully reconciled.**

The next schema stage, if authorised, must begin from this chain without rewriting history.
