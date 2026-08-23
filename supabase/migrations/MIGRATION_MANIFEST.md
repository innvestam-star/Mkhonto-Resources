# Hosted migration manifest

The active hosted project is **Mkhonto Resources Hub** with project reference `zjrzzvakwrwkrcqhcnyo`.

## Recovery status

The original migration-history recovery blocker is **resolved**. The authoritative migration records and SQL statement bodies are available in hosted `supabase_migrations.schema_migrations`.

The historical pre-repository migrations were recovered and committed. Stage 13 has one remaining provenance exception: the hosted 13c and 13d SQL bodies exist and are authoritative, but their exact SQL files are not present in GitHub. Do not fabricate or hand-reconstruct them. They may only be restored when the resulting Git blob SHA exactly matches the hosted authority recorded below.

Do not create a fresh baseline. The hosted history is authoritative.

## Applied hosted migrations

| Version | Migration | Repository status |
|---|---|---|
| `20260803202920` | `mkhonto_hub_phase_4_foundation` | Recovered and committed |
| `20260803203051` | `mkhonto_hub_fk_indexes` | Recovered and committed |
| `20260805191833` | `auth_access_and_protected_route_foundation` | Recovered and committed |
| `20260805191850` | `restrict_auth_rpc_execution` | Recovered and committed |
| `20260821020531` | `mrcip_stage_1a_access_and_counterparties` | Applied and committed |
| `20260821020602` | `mrcip_stage_1b_commodities_and_provenance` | Applied and committed |
| `20260821020620` | `mrcip_stage_1c_rls_core` | Applied and committed |
| `20260821020632` | `mrcip_stage_1d_rls_commodity_and_provenance` | Applied and committed |
| `20260821020648` | `mrcip_stage_1e_access_hardening` | Applied and committed |
| `20260821020739` | `mrcip_stage_1f_extension_security` | Applied and committed |
| `20260821021629` | `mrcip_stage_1g_performance_hardening` | Applied and committed |
| `20260821022028` | `mrcip_stage_2a_mines_and_laboratories` | Applied and committed |
| `20260821022047` | `mrcip_stage_2b_import_staging` | Applied and committed |
| `20260821022109` | `mrcip_stage_2c_rls_and_access` | Applied and committed |
| `20260821022131` | `mrcip_stage_2d_performance_hardening` | Applied and committed |
| `20260821022859` | `mrcip_stage_3a_supply_demand_and_specifications` | Applied and committed |
| `20260821022922` | `mrcip_stage_3b_supply_demand_rls_and_grants` | Applied and committed |
| `20260821023105` | `mrcip_stage_3c_explainable_matching_engine` | Applied and committed |
| `20260821023242` | `mrcip_stage_3d_data_api_least_privilege_hardening` | Applied and committed |
| `20260821023355` | `mrcip_stage_3e_performance_hardening` | Applied and committed |
| `20260821023527` | `mrcip_stage_3f_certificate_tenant_integrity` | Applied and committed |
| `20260821024154` | `mrcip_stage_4a_document_acl_hardening` | Applied and committed |
| `20260821024314` | `mrcip_stage_4b_opportunity_and_protocol_foundation` | Applied and committed |
| `20260821024343` | `mrcip_stage_4c_opportunity_protocol_rls` | Applied and committed |
| `20260821024432` | `mrcip_stage_4d_protect_verify_disclose_contract_engine` | Applied and committed |
| `20260821024626` | `mrcip_stage_4e_deal_room_module_links` | Applied and committed |
| `20260821024645` | `mrcip_stage_4f_protected_document_storage_hardening` | Applied and committed |
| `20260821024843` | `mrcip_stage_4g_performance_and_grant_hardening` | Applied and committed |
| `20260821030523` | `mrcip_stage_5a_facilitator_chain_foundation` | Applied and committed |
| `20260821030615` | `mrcip_stage_5b0_tenant_identity_hardening` | Applied and committed |
| `20260821030657` | `mrcip_stage_5b_commission_control_foundation` | Applied and committed |
| `20260821030756` | `mrcip_stage_5c_approval_revision_and_trigger_engine` | Applied and committed |
| `20260821030906` | `mrcip_stage_5d_lifecycle_hardening` | Applied and committed |
| `20260821032352` | `mrcip_stage_6a_commission_settlement_foundation` | Applied and committed |
| `20260821032555` | `mrcip_stage_6b_settlement_reconciliation_engine` | Applied and committed |
| `20260821032908` | `mrcip_stage_6c_internal_guard_context_hardening` | Applied and committed |
| `20260821032955` | `mrcip_stage_6d_closeout_guard_alias_hardening` | Applied and committed |
| `20260821033201` | `mrcip_stage_6e_performance_hardening` | Applied and committed |
| `20260821034553` | `mrcip_stage_7a_sampling_inspection_lab_foundation` | Applied and committed |
| `20260821034833` | `mrcip_stage_7b_traceability_workflow_and_security` | Applied and committed |
| `20260821035207` | `mrcip_stage_7c_deal_room_document_role_compatibility` | Applied and committed |
| `20260821035501` | `mrcip_stage_7d_performance_and_audit_policy_hardening` | Applied and committed |
| `20260821041017` | `mrcip_stage_8a_outreach_crm_foundation` | Applied and committed |
| `20260821041203` | `mrcip_stage_8b_crm_workflow_and_security` | Applied and committed |
| `20260821041325` | `mrcip_stage_8c_performance_hardening` | Applied and committed |
| `20260821042643` | `mrcip_stage_9a_quality_risk_scoring_foundation` | Applied and committed |
| `20260821042835` | `mrcip_stage_9b_deterministic_scoring_and_read_models` | Applied and committed |
| `20260821043244` | `mrcip_stage_9c_scoring_integrity_hardening` | Applied and committed |
| `20260821045132` | `mrcip_stage_10a_reports_signals_retrieval_foundation` | Applied and committed |
| `20260821045323` | `mrcip_stage_10b_report_engine_and_security` | Applied and committed |
| `20260821045414` | `mrcip_stage_10c_watchlist_signal_engine` | Applied and committed |
| `20260821045457` | `mrcip_stage_10d_authorised_retrieval_foundation` | Applied and committed |
| `20260821045834` | `mrcip_stage_10e_performance_hardening` | Applied and committed |
| `20260821052113` | `mrcip_stage_11a_ai_orchestration_and_citation_foundation` | Applied and committed |
| `20260821052234` | `mrcip_stage_11b_governed_ai_workflow_engine` | Applied and committed |
| `20260821052322` | `mrcip_stage_11c_ai_review_rls_and_read_models` | Applied and committed |
| `20260821052512` | `mrcip_stage_11d_performance_hardening` | Applied and committed |
| `20260821054219` | `mrcip_stage_12a_prompt_execution_gateway_foundation` | Applied and committed |
| `20260821054510` | `mrcip_stage_12b_prompt_approval_and_execution_control` | Applied and committed |
| `20260821054537` | `mrcip_stage_12c_execution_rls_and_read_models` | Applied and committed |
| `20260821054726` | `mrcip_stage_12d_gateway_service_authorization_fix` | Applied and committed |
| `20260821054833` | `mrcip_stage_12e_provider_request_event_audit` | Applied and committed |
| `20260821054900` | `mrcip_stage_12f_provider_failure_state_hardening` | Applied and committed |
| `20260821055114` | `mrcip_stage_12g_performance_hardening` | Applied and committed |
| `20260821060725` | `mrcip_stage_13a_ai_evaluation_foundation` | Applied; exact GitHub match verified |
| `20260821060752` | `mrcip_stage_13b_provider_commercial_and_onboarding_foundation` | Applied; exact GitHub match verified |
| `20260821060927` | `mrcip_stage_13c_evaluation_workflow_engine` | **Applied; GitHub SQL file missing — hosted body authoritative** |
| `20260821061049` | `mrcip_stage_13d_provider_onboarding_budget_and_activation_gates` | **Applied; GitHub SQL file missing — hosted body authoritative** |
| `20260821061129` | `mrcip_stage_13e_rls_grants_and_read_models` | Applied; exact GitHub match verified |
| `20260821061339` | `mrcip_stage_13e_rls_read_models_and_drift_reconciliation` | Applied; exact GitHub match verified |
| `20260821061513` | `mrcip_stage_13f_onboarding_revocation_and_refusal_hardening` | Applied; exact GitHub match verified |
| `20260821061623` | `mrcip_stage_13g_evaluation_gateway_payload_hardening` | Applied; exact GitHub match verified |
| `20260821061636` | `mrcip_stage_13h_eval_gateway_service_rpc_grants` | Applied; exact GitHub match verified |
| `20260823081757` | `mrcip_retrospective_acl_hardening_stages_1_13` | Applied and committed; exact match verified |

## Stage 13 hosted/source hashes

| Migration | Hosted Git blob SHA | Verification |
|---|---|---|
| 13a | `a826b4214fe3af0c7c467d36e226cb055c2ea13f` | GitHub exact match |
| 13b | `43c931898a842065361bb6b549966e6d1624b9e0` | GitHub exact match |
| 13c | `4bafdf0acbee619e4949bd21ab7b6eb5a49f3635` | **Source file recovery open** |
| 13d | `3e986530652939cd381d1c337e548c14f50bb9eb` | **Source file recovery open** |
| 13e / 61129 | `0d7e9f9dac1bf241a0ad2f0a24fc8a83bc569e4f` | GitHub exact match |
| 13e / 61339 | `b7ac746901402e86face5c14070e46de190c5958` | GitHub exact match |
| 13f | `d69f4c436a16c1c8d55b68333c48b66bee33f4e8` | GitHub exact match |
| 13g | `0eed99b877945d44cdfc830b9401a770e763f7f8` | GitHub exact match |
| 13h | `7c5bc53b9bd685eb6a6bceacebec6494856e3572` | GitHub exact match |
| retrospective ACL hardening | `41b1d561798ca48b1cee68db22692bce934b860e` | GitHub exact match |

## Verification performed

- Hosted project migration-history/schema queries are operational.
- Exact hosted migration files are source-controlled through Stage 12.
- Seven of nine Stage 13 migration files are source-controlled and byte-identical to hosted SQL; 13c/13d are the only provenance exceptions.
- Stage 9 migrations remain byte-identical to hosted SQL: 9a `d5ea35c966dda3167beb3c0237632ee4bf7dd18c`, 9b `9da3d248a8020e885385516bb0f053f975858689`, 9c `5635670cbba84575f7580dc73b9eb0aa84471d16`.
- Stage 10 migrations remain byte-identical to hosted SQL: 10a `8a148d63428f79ac4e41b7fd617f385f63486682`, 10b `d0455c007c5f0e87dc3cbaa9995303936d373658`, 10c `90da61b284357645ebe5273ed498c5aadeabba57`, 10d `8b465600a39ed4f706ba280e518a335cde3defb2`, 10e `683a6842b8cbbcce35fdf6f80f025d3b60eb225b`.
- Stage 11 migrations remain byte-identical to hosted SQL: 11a `e0f6193bf06d9a037f6b962db384ea4d2a3146a5`, 11b `bd287b3d30f6686a837af6562a92e1089ca686c1`, 11c `2725939155d12478ce656eae39151b74471cf0d1`, 11d `da1d493749aaaebfd918728419222965142d53cf`.
- Stage 12 migrations remain byte-identical to hosted SQL: 12a `918392007f951c7d424e45d9cb6b723cfe55e91c`, 12b `0858dd8f170baf8f3aaeb37004cca412c8d6f321`, 12c `9b0931ce9284e2e638d007efa974423fe9d2da93`, 12d `9760a7450afd3ed38b7e7937a2486853b439441f`, 12e `a17d3b97e616b3f1bb7a943dde86aece5d85a660`, 12f `a549cc6a36e33571306fcc27b2a2018501a72893`, 12g `36fba79b0fdf77e0cf81e6e63638602670f38cb6`.
- TypeScript database type generation succeeded after Stage 13 and includes Stage 13 evaluation, provider-rate, budget, onboarding, read-model and RPC surfaces.
- Stage 3 matching regressions remain **99.80/100 candidate** and **50.00/100 disqualified** for the mandatory-CV failure fixture.
- Stage 4 continues to enforce **PROTECT → VERIFY → DISCLOSE → CONTRACT** and reference-only Finance/Freight/Negotiation integration.
- Stages 5–12 remain within their previously signed-off database/security/integration boundaries.
- Stage 13 evaluation gateway lifecycle functions are service-role-only where external runtime mutation occurs; no MRCIP RPC is executable by `anon`.
- No production AI provider is active and current Stage 11–13 AI/provider/evaluation/rate/budget/onboarding tables contain no residual test data.
- The superseded `mrcip-ai-eval-gateway` is an HTTP 410 decommissioned JWT-verified stub. The temporary `mrcip-stage13-reconcile-export` helper has also been redeployed as an HTTP 410 JWT-verified decommissioned stub.
- The retrospective audit discovered excessive legacy ACLs on 19 early Stage 1–2 tables. Migration `20260823081757` removed all MRCIP `anon` table privileges and authenticated `TRUNCATE`, `REFERENCES` and `TRIGGER` privileges.
- Post-remediation ACL result: **86 MRCIP tables / 0 anon-exposed tables / 0 authenticated dangerous-grant tables**.
- All public constraints are validated.
- Security advisor reports no new MRCIP warning; remaining findings are the three pre-existing Auth `SECURITY DEFINER` RPC warnings and disabled leaked-password protection.
- Performance advisor shows no new missing-FK-index defect; current output is unused-index information plus the pre-existing duplicate `organisation_memberships` index warning.
- Existing quotation, invoice, VAT, Finance, Payment, commission settlement, laboratory evidence, CRM/DNC, scoring, Freight, Negotiation, logistics and Auth calculation/access logic was not modified by the retrospective ACL hardening.
- Formal Stage 13 audit is `docs/mrcip/STAGE_13_IMPLEMENTATION_AUDIT.md`.

## Ongoing rules

1. Never replace the recovered hosted history with a manually invented baseline.
2. Every DDL change must have a corresponding SQL migration file using the exact hosted migration version and authoritative body.
3. Never call a migration reconciled unless its Git blob SHA matches the hosted migration-body SHA.
4. Restore Stage 13c/13d only from an exact authoritative export matching `4bafdf0acbee619e4949bd21ab7b6eb5a49f3635` and `3e986530652939cd381d1c337e548c14f50bb9eb` respectively.
5. MRCIP public tables must have RLS enabled, no `anon` table privileges, and authenticated users must not receive `TRUNCATE`, `REFERENCES` or `TRIGGER` unless a separately audited exception explicitly requires it.
6. Run security and performance advisors after structural database changes.
7. Regenerate TypeScript database types after schema changes when application source is synchronized.
8. Preserve Finance, Freight, Auth and existing protected-route behaviour unless a separately tested remediation requires modification.
9. Intelligence imports must enter through staging/validation/duplicate review; never silently overwrite master records.
10. Matching must remain explainable and auditable; hard filters, component scores, failed mandatory fields, algorithm version and human decisions must be retained.
11. Do not duplicate Freight profitability or Finance arithmetic inside MRCIP; integrate by reference.
12. Protected seller/source disclosure must remain governed by **PROTECT → VERIFY → DISCLOSE → CONTRACT** and must not be bypassed by UI, retrieval, reporting or AI convenience.
13. Protected Deal Room documents and source/contact/coordinate/commercial data must retain restrictive storage and RLS boundaries.
14. Approved facilitator chains and commission schedules are controlled revisioned records; do not silently rewrite approved history.
15. Commission allocations must reconcile to exactly 100% before approval, and schedules must not be marked paid outside Stage 6 settlement controls.
16. Verified settlement entries, custody events, laboratory results/certificates/inspections and publication evidence are auditable history; corrections require controlled revision/reversal workflows.
17. CRM DNC/channel controls must be enforced before outbound contact; CRM communication history is append-only and Stage 8 does not authorise autonomous outreach.
18. Stage 9 quality/risk/readiness scores are deterministic internal decision support, not external credit, sanctions or legal opinions and not guarantees.
19. Stage 10 retrieval remains RLS-aware, purpose-audited and bounded and must not expose protected contacts, mine protected details, pricing/payment terms, KYC/banking, facilitator/commission or protected source information.
20. Stage 11 AI requests must remain anchored to audited Stage 10 retrieval; frozen context and citations remain versioned, fingerprinted and reviewable.
21. Human review remains mandatory before an AI response is approved; protected-context/risk approval remains executive/legal controlled.
22. AI provider secrets must never be stored in MRCIP tables; credentials must use an approved external secret mechanism.
23. External-model responses remain gateway-only and require active verified provider, approved prompt version and auditable request/context lineage.
24. Stage 11–13 do not authorise autonomous outreach, source disclosure, negotiation, contracting, trading, payment execution or changes to Finance/Freight/commercial-control records.
25. Prompt/evaluation suite versions and approved thresholds are immutable history; changes require new controlled versions.
26. Protected external processing requires provider-level and prompt-version-level protected-data approval plus successful Stage 13 evaluation/onboarding controls.
27. Gateway service RPCs must remain service-role-only and `SECURITY INVOKER` unless a separately audited change proves another model safer.
28. Runtime telemetry must never persist API keys, Authorization headers, raw secret-bearing requests or unfiltered provider payloads.
29. Provider cost must not be fabricated; cost remains unknown/null unless backed by provider telemetry or an explicitly approved Stage 13 rate calculation.
30. Missing provider credentials, failed verification, failed evaluation, expired/invalid budget controls or revoked onboarding must fail closed.
31. Edge gateways must retain JWT verification and allowlisted/fixed provider endpoints; callers must never supply arbitrary outbound URLs.
32. A deployed gateway or provider metadata alone does not mean a production model is operational; activation requires the full evaluated onboarding decision.
33. Stage 14 must not be formally signed off over an unresolved Stage 13 migration-provenance gap unless an authorised maintainer explicitly accepts the documented exception.