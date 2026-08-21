# Hosted migration manifest

The active hosted project is **Mkhonto Resources Hub** with project reference `zjrzzvakwrwkrcqhcnyo`.

## Recovery status

The migration-history recovery blocker is **resolved**.

The authoritative migration records and SQL statement bodies were recovered from the hosted `supabase_migrations.schema_migrations` history after database connectivity was restored. The four migrations that pre-date the reconstructed GitHub repository have been restored as SQL files in this branch.

Do not create a fresh baseline. The files below correspond to the hosted migration history and must remain the source-controlled migration chain.

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

## Verification performed

- Hosted project status is healthy and migration-history/schema queries are working.
- Exact hosted migration versions are mirrored to GitHub through Stage 12.
- Stage 9 migrations remain byte-identical to hosted SQL: 9a `d5ea35c966dda3167beb3c0237632ee4bf7dd18c`, 9b `9da3d248a8020e885385516bb0f053f975858689`, 9c `5635670cbba84575f7580dc73b9eb0aa84471d16`.
- Stage 10 migrations remain byte-identical to hosted SQL: 10a `8a148d63428f79ac4e41b7fd617f385f63486682`, 10b `d0455c007c5f0e87dc3cbaa9995303936d373658`, 10c `90da61b284357645ebe5273ed498c5aadeabba57`, 10d `8b465600a39ed4f706ba280e518a335cde3defb2`, 10e `683a6842b8cbbcce35fdf6f80f025d3b60eb225b`.
- Stage 11 migrations remain byte-identical to hosted SQL: 11a `e0f6193bf06d9a037f6b962db384ea4d2a3146a5`, 11b `bd287b3d30f6686a837af6562a92e1089ca686c1`, 11c `2725939155d12478ce656eae39151b74471cf0d1`, 11d `da1d493749aaaebfd918728419222965142d53cf`.
- Stage 12 migrations are byte-identical to hosted SQL: 12a `918392007f951c7d424e45d9cb6b723cfe55e91c`, 12b `0858dd8f170baf8f3aaeb37004cca412c8d6f321`, 12c `9b0931ce9284e2e638d007efa974423fe9d2da93`, 12d `9760a7450afd3ed38b7e7937a2486853b439441f`, 12e `a17d3b97e616b3f1bb7a943dde86aece5d85a660`, 12f `a549cc6a36e33571306fcc27b2a2018501a72893`, 12g `36fba79b0fdf77e0cf81e6e63638602670f38cb6`.
- TypeScript database type generation succeeded after Stage 12 and includes the four Stage 12 tables, provider runtime fields, response execution provenance, three Stage 12 read models and Stage 12 workflow/gateway RPCs.
- Stage 3 matching regressions remain **99.80/100 candidate** and **50.00/100 disqualified** for the mandatory-CV failure fixture.
- Stage 4 continues to enforce **PROTECT → VERIFY → DISCLOSE → CONTRACT** and reference-only Finance/Freight/Negotiation integration.
- Stage 5/6 facilitator, commission, settlement, overpayment, reversal and closeout controls remain unchanged.
- Stage 7 sampling, custody, laboratory result/certificate/inspection evidence lineage remains unchanged.
- Stage 8 CRM DNC/contactability, append-only communication history and watchlists remain unchanged.
- Stage 9 quality, protected risk and opportunity-readiness scoring formulas remain unchanged.
- Stage 10 reports, watchlist signals and purpose-audited authorised retrieval remain unchanged and remain the evidence-retrieval boundary.
- Stage 11 frozen request/context/citation/human-review controls remain authoritative and are extended only with controlled external execution provenance.
- Stage 12 adds four RLS-controlled public tables: `mrcip_ai_prompt_templates`, `mrcip_ai_prompt_versions`, `mrcip_ai_executions`, and `mrcip_ai_execution_events`.
- Stage 12 provider metadata stores a secret-reference name only; no API key/token/secret value is stored in MRCIP tables.
- Prompt versions are immutable after creation; approval requires executive/legal-compliance authority and protected-data approval is explicit.
- External-model responses are gateway-only and cannot be created directly by authenticated users.
- Every external response must reference a running execution, provider configuration, provider request ID and Stage 11 request/context lineage.
- Stage 12 gateway/service RPCs for external lifecycle mutation are service-role-only and are not executable by `anon` or `authenticated`.
- The deployed Edge Function `mrcip-ai-gateway` is version 1, ACTIVE, JWT-verified and mirrored to `supabase/functions/mrcip-ai-gateway/index.ts`; deployment SHA-256 is `df2823d0299b0c15df90486f32cfb3aebb6ac32dc4854647f49ec895294f2ae7`.
- The current adapter code path is `openai_responses_v1`, but **no production provider row, external credential secret or production model call exists** after Stage 12.
- Provider activation requires an allowlisted adapter, external credential metadata and successful gateway verification.
- A missing runtime secret demotes the provider to disabled/not-configured/failed and removes protected-data permission.
- Stage 12 rollback regression passed **14/14** controls across prompt immutability, provider verification, execution provenance, citation enforcement, telemetry filtering, response gateway exclusivity, human-review handoff, history immutability and missing-secret demotion.
- One gateway-helper permission defect was discovered during the first regression and remediated in Stage 12d without widening private-schema access.
- Security advisor rerun reports no new Stage 12-specific finding. The same pre-existing Auth SECURITY DEFINER warnings and disabled leaked-password protection remain tracked separately.
- The first Stage 12 performance pass found one missing covering index on the execution→response FK; Stage 12g remediated it and the rerun cleared that finding.
- Final production counts remain zero across provider configs, prompt templates/versions, executions/events, AI requests/context/responses/citations/reviews and the synthetic Stage 12 counterparty fixture.
- Existing quotation, invoice, VAT, Finance line-item, Payment, commission-settlement, laboratory evidence, CRM/DNC, scoring, Freight, Negotiation, logistics-execution and Auth calculation/access logic was not changed.
- Formal Stage 12 implementation audit is stored at `docs/mrcip/STAGE_12_IMPLEMENTATION_AUDIT.md`.

## Ongoing rules

1. Never replace the recovered history with a manually invented baseline.
2. Every future DDL change must have a corresponding migration file using the exact hosted migration version.
3. Run security and performance advisors after structural database changes.
4. Regenerate TypeScript database types after schema changes when application source is synchronized.
5. Preserve Finance, Freight, Auth and existing protected-route behaviour unless a separately tested remediation requires modification.
6. Intelligence imports must enter through staging/validation/duplicate review; never silently overwrite master records.
7. Matching must remain explainable and auditable; hard filters, component scores, failed mandatory fields, algorithm version and human decisions must be retained.
8. Do not duplicate Freight profitability or Finance arithmetic inside MRCIP; integrate by reference.
9. Protected seller/source disclosure must remain governed by **PROTECT → VERIFY → DISCLOSE → CONTRACT** and must not be bypassed by UI, retrieval, reporting or AI convenience.
10. Protected Deal Room documents and source/contact/coordinate/commercial data must retain their restrictive storage and RLS boundaries.
11. Approved facilitator chains and commission schedules are controlled revisioned records; do not silently rewrite approved history.
12. Commission allocations must reconcile to exactly 100% before approval, and schedules must not be marked paid outside Stage 6 settlement controls.
13. Verified settlement entries, custody events, laboratory results/certificates/inspections and publication evidence are auditable history; corrections require the controlled revision/reversal workflow.
14. CRM DNC/channel controls must be enforced before outbound contact; CRM communication history is append-only.
15. Stage 8 does not authorise autonomous external outreach.
16. Stage 9 quality/risk/readiness scores are internal deterministic decision support, not external credit, sanctions or legal opinions and not guarantees.
17. Stage 9 score snapshots are append-only and scoring-formula changes require explicit versioned migrations and regression evidence.
18. Stage 10 report runs and signal snapshots remain database-derived; callers must not author report summaries, row counts or alert payloads.
19. Stage 10 retrieval remains RLS-aware, purpose-audited and bounded and must not expose protected contacts, mine protected details, pricing/payment terms, KYC/banking, facilitator/commission or protected source information.
20. Stage 10 report/signal/retrieval histories remain append-only audit records.
21. Stage 11 AI requests must remain anchored to an audited Stage 10 retrieval; clients must not provide their own unaudited evidence bundle.
22. Stage 11 frozen context must remain re-derived from the audited retrieval and fingerprinted; do not silently rewrite context after answer generation.
23. A Stage 11 response represented as supported must cite frozen context. Fabricated or out-of-request citations are prohibited.
24. Stage 11 responses are versioned history. Changes create a new response version rather than rewriting an existing answer.
25. Human review remains mandatory before an AI response is approved. Approval requires citation, factuality and protection checks.
26. Protected-context and risk-summary approval remains restricted to executive/legal-compliance authority.
27. AI provider secrets must never be stored in `mrcip_ai_provider_configs`; credentials must use an approved external secret mechanism.
28. An external-model response must not be accepted unless the selected provider is active, externally credential-ready and, for protected context, explicitly approved for protected-data processing.
29. Stage 11/12 do not authorise autonomous outreach, source disclosure, negotiation, contracting, trading, payment execution or changes to Finance/Freight/commercial-control records.
30. No system may claim an external AI provider/model is connected merely because provider metadata or adapter code exists; actual provider execution requires an active verified provider and approved external secret.
31. Stage 12 prompt content is versioned and immutable. Changes require a new prompt version and a new approval decision.
32. Protected external processing requires both provider-level and prompt-version-level protected-data approval.
33. Authenticated clients must never be granted direct execution-completion, external-response creation or execution-event write authority.
34. Gateway service RPCs must remain service-role-only and SECURITY INVOKER unless a separately audited change proves a different model is safer.
35. Provider/model/prompt/context/input execution fingerprints and provider request IDs must remain auditable history.
36. Runtime telemetry must never persist API keys, Authorization headers, raw request bodies, raw provider response bodies or unfiltered output payloads.
37. Provider cost must not be fabricated; keep cost unknown/null unless a reliable provider-reported or explicitly configured-rate calculation is implemented and audited.
38. A missing provider secret must fail closed and must not leave stale active/integration-ready protected-processing state.
39. The deployed Edge gateway must retain JWT verification and fixed/allowlisted provider endpoints; callers must not be able to supply arbitrary outbound URLs.
40. Production provider onboarding requires a separate evaluated go-live decision; the Stage 12 gateway being deployed does not by itself make external AI operational.
