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

## Verification performed

- Hosted project status is healthy and migration-history/schema queries are working.
- Exact hosted migration versions are mirrored to GitHub through Stage 11.
- Stage 9 migrations remain byte-identical to hosted SQL: 9a `d5ea35c966dda3167beb3c0237632ee4bf7dd18c`, 9b `9da3d248a8020e885385516bb0f053f975858689`, 9c `5635670cbba84575f7580dc73b9eb0aa84471d16`.
- Stage 10 migrations remain byte-identical to hosted SQL: 10a `8a148d63428f79ac4e41b7fd617f385f63486682`, 10b `d0455c007c5f0e87dc3cbaa9995303936d373658`, 10c `90da61b284357645ebe5273ed498c5aadeabba57`, 10d `8b465600a39ed4f706ba280e518a335cde3defb2`, 10e `683a6842b8cbbcce35fdf6f80f025d3b60eb225b`.
- Stage 11 migrations are byte-identical to hosted SQL: 11a `e0f6193bf06d9a037f6b962db384ea4d2a3146a5`, 11b `bd287b3d30f6686a837af6562a92e1089ca686c1`, 11c `2725939155d12478ce656eae39151b74471cf0d1`, 11d `da1d493749aaaebfd918728419222965142d53cf`.
- TypeScript database type generation succeeded after Stage 11 and includes the six Stage 11 tables, two Stage 11 views and three public Stage 11 RPCs.
- Stage 3 matching regressions remain **99.80/100 candidate** and **50.00/100 disqualified** for the mandatory-CV failure fixture.
- Stage 4 continues to enforce **PROTECT → VERIFY → DISCLOSE → CONTRACT** and reference-only Finance/Freight/Negotiation integration.
- Stage 5/6 facilitator, commission, settlement, overpayment, reversal and closeout controls remain unchanged.
- Stage 7 sampling, custody, laboratory result/certificate/inspection evidence lineage remains unchanged.
- Stage 8 CRM DNC/contactability, append-only communication history and watchlists remain unchanged.
- Stage 9 quality, protected risk and opportunity-readiness scoring formulas remain unchanged.
- Stage 10 reports, watchlist signals and purpose-audited authorised retrieval remain unchanged and form the Stage 11 evidence boundary.
- Stage 11 adds six RLS-controlled public tables: `mrcip_ai_provider_configs`, `mrcip_ai_requests`, `mrcip_ai_context_items`, `mrcip_ai_responses`, `mrcip_ai_citations`, and `mrcip_ai_reviews`.
- Stage 11 provider configuration stores governance metadata only; no provider secrets/API keys are stored. No production provider is active after rollback testing.
- Every Stage 11 request is anchored to a completed Stage 10 retrieval created by the same requester; request/context fields are re-derived from that audited retrieval.
- Frozen context items are rank-bound, fingerprinted and safe-metadata-only. A caller cannot forge the entity/title/metadata/protection state of a context item.
- Supported responses require one or more citations when retrieved context exists.
- External-model responses require an approved active, externally credential-ready provider configuration; protected context additionally requires explicit protected-data approval.
- All response versions start `review_required`. Human review is the only path to approved status.
- Approval requires citation, factuality and protection checks. Protected or risk-summary final review requires executive or legal/compliance authority.
- Authenticated Stage 11 rollback regression passed **11/11** controls, including request/context anti-forgery, citation enforcement, provider gating, review gating, immutable response history, second-final-review rejection and non-member denial.
- All six Stage 11 tables have RLS and `anon` has no Stage 11 table privileges.
- Requests, context items, responses, citations and reviews expose authenticated `SELECT,INSERT` only; provider configs expose `SELECT,INSERT,UPDATE` with executive RLS/trigger governance and no DELETE.
- Public Stage 11 RPCs `prepare_mrcip_ai_request`, `submit_mrcip_ai_response`, and `review_mrcip_ai_response` are SECURITY INVOKER, authenticated-only and fixed-search-path.
- Stage 11 read models `mrcip_ai_request_summary` and `mrcip_ai_citation_trace` use `security_invoker=true`.
- Private lifecycle SECURITY DEFINER helpers are trigger-only, fixed-search-path and not directly executable by `anon`/`authenticated`.
- Security advisor rerun reports no new Stage 11-specific finding. The same pre-existing Auth SECURITY DEFINER warnings and disabled leaked-password protection remain tracked separately.
- The first Stage 11 performance pass found three missing covering indexes; `20260821052512_mrcip_stage_11d_performance_hardening` remediated all three and the rerun cleared those findings.
- Final Stage 11 production row counts are zero across provider configs, AI requests, context items, responses, citations and reviews; rollback fixtures left zero counterparty/retrieval residue.
- Existing quotation, invoice, VAT, Finance line-item, Payment, commission-settlement, laboratory evidence, CRM/DNC, scoring, Freight, Negotiation, logistics-execution and Auth calculation/access logic was not changed.
- Formal Stage 11 implementation audit is stored at `docs/mrcip/STAGE_11_IMPLEMENTATION_AUDIT.md`.

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
29. Stage 11 does not authorise autonomous outreach, source disclosure, negotiation, contracting, trading, payment execution or changes to Finance/Freight/commercial-control records.
30. No system may claim an external AI provider/model is connected merely because a provider metadata row exists; actual provider execution requires a separately implemented and tested execution gateway.
