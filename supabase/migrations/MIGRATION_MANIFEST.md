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

## Verification performed

- Hosted project status: healthy.
- Full public-schema inspection and migration-history queries: successful.
- Exact hosted migration versions are mirrored to GitHub through Stage 10.
- The three Stage 9 SQL files are byte-identical to hosted `schema_migrations.statements`, verified by matching hosted-computed Git blob SHA-1 against GitHub blob SHA: Stage 9a `d5ea35c966dda3167beb3c0237632ee4bf7dd18c`, Stage 9b `9da3d248a8020e885385516bb0f053f975858689`, Stage 9c `5635670cbba84575f7580dc73b9eb0aa84471d16`.
- The five Stage 10 SQL files are byte-identical to hosted migration SQL: Stage 10a `8a148d63428f79ac4e41b7fd617f385f63486682`, Stage 10b `d0455c007c5f0e87dc3cbaa9995303936d373658`, Stage 10c `90da61b284357645ebe5273ed498c5aadeabba57`, Stage 10d `8b465600a39ed4f706ba280e518a335cde3defb2`, Stage 10e `683a6842b8cbbcce35fdf6f80f025d3b60eb225b`.
- TypeScript database type generation succeeded after Stage 10 and includes the four Stage 10 tables, three Stage 10 views and three public Stage 10 RPCs.
- Stages 1–9 remain signed off; Stage 3 matching regressions remain **99.80/100 candidate** and **50.00/100 disqualified** for the mandatory-CV failure fixture.
- Stage 4 continues to enforce **PROTECT → VERIFY → DISCLOSE → CONTRACT** and reference-only Finance/Freight/Negotiation integration.
- Stage 5 continues to enforce revisioned facilitator-chain control, exact 100% commission allocation, fee-protection linkage and verified trigger crystallisation before settlement.
- Stage 6 continues to enforce a commission-specific settlement subledger, all three approved commission bases, overpayment protection, reversals and controlled recurring closeout without redefining existing Finance/Payments semantics.
- Stage 7 continues to enforce protected sampling, append-only custody, revisioned laboratory results, protected certificate verification, inspection evidence and controlled seller-spec publication.
- Stage 8 continues to enforce database-level DNC/channel controls, append-only communication history, protected CRM evidence, controlled conversion and tenant-scoped watchlists without autonomous external sending.
- Stage 9 continues to enforce explicit/versioned quality, protected risk and explainable opportunity-readiness snapshots.
- Stage 10 adds `mrcip_report_definitions`, `mrcip_report_runs`, `mrcip_watchlist_signal_snapshots`, and `mrcip_retrieval_requests` without duplicating Stage 8 watchlists or Stage 9 operational read models.
- Stage 10 report runs are database-derived. The regression attempted a forged `row_count=999` and forged JSON summary; the database replaced both with the deterministic `mrcip-report-v1` result.
- Stage 10 watchlist signals are database-derived. The regression attempted a forged 999/critical/fake snapshot; the database recalculated the test entity to exactly **2 signals / high** and removed the fabricated payload.
- Stage 10 retrieval is purpose-audited, bounded to 50 results, RLS-aware and protected-context gated. The protected-offer regression returned **0** without protected access and **1** with privileged protected retrieval.
- A submitted retrieval audit `result_count=999` was recalculated to **1**. Authenticated UPDATE of retrieval audit history was denied.
- A research analyst could retrieve non-protected intelligence but was denied protected retrieval and denied a protected risk-register report.
- All three Stage 10 public RPCs are SECURITY INVOKER and non-anonymous: `generate_mrcip_report`, `refresh_watchlist_signals`, `search_mrcip_intelligence`.
- All three Stage 10 public views use `security_invoker=true`: `mrcip_report_catalog_summary`, `mrcip_watchlist_signal_current`, `mrcip_retrieval_audit_summary`.
- RLS is enabled on all four Stage 10 public tables and `anon` has no Stage 10 table privileges.
- Report-run, signal-snapshot and retrieval-request history is append-only through authenticated grants (`SELECT,INSERT` only).
- `private.mrcip_retrieval_candidates(...)` is intentionally authenticated-executable because the public SECURITY INVOKER search RPC calls it; it remains in `private`, is SECURITY INVOKER and all underlying RLS remains authoritative.
- Final Stage 10 production row counts remain zero across report definitions, report runs, signal snapshots and retrieval requests after rollback-isolated tests.
- Security advisor rerun: no new Stage 10-specific security finding. Remaining warnings are the same pre-existing authenticated-callable Auth SECURITY DEFINER functions and disabled leaked-password protection.
- Performance advisor initially found five Stage 10 FK relationships lacking covering indexes; `20260821045834_mrcip_stage_10e_performance_hardening` remediated all five, and the rerun no longer reports those findings.
- Existing quotation, invoice, VAT, Finance line-item, Payment, Stage 6 commission-settlement, Stage 7 laboratory evidence, Stage 8 CRM/DNC, Stage 9 scoring, Freight, Negotiation, logistics-execution and Auth calculation/access logic was not changed.
- Formal Stage 10 implementation audit is stored at `docs/mrcip/STAGE_10_IMPLEMENTATION_AUDIT.md`.

## Ongoing rules

1. Never replace the recovered history with a manually invented baseline.
2. Every future DDL change must have a corresponding migration file using the exact hosted migration version.
3. Run security and performance advisors after structural database changes.
4. Regenerate `src/types/database.types.ts` after schema changes when the complete application source is synchronized.
5. Preserve Finance, Freight, Auth and existing protected-route behaviour unless a separately tested remediation requires modification.
6. Intelligence imports must enter through staging/validation/duplicate review; never silently overwrite master records.
7. Matching must remain explainable and auditable: component scores, hard filters, failed mandatory fields, algorithm version and reviewer decisions must be retained.
8. Do not duplicate Freight profitability calculations inside MRCIP; integrate the existing Freight module by reference.
9. Do not duplicate Finance calculations inside MRCIP; link existing quotation/invoice/payment records by reference.
10. Protected seller/source disclosure must remain governed by **PROTECT → VERIFY → DISCLOSE → CONTRACT** and must not be bypassed by UI convenience or direct client writes.
11. Protected Deal Room documents must retain restrictive metadata/storage policies and must not fall back to generic organisation-member visibility.
12. Approved facilitator chains and commission schedules are controlled records. Amendments must create revisions rather than silently rewriting approved history.
13. Commission allocations must reconcile to exactly 100% of the approved pool before approval.
14. Commission schedules must not be marked paid outside the Stage 6 settlement/reconciliation controls.
15. Verified settlement entries are evidence-bearing commercial records; they may be reversed only through the controlled reversal workflow with a reason and must never be silently deleted or rewritten.
16. Recurring R/MT and percentage schedules require explicit closeout after all settlement cycles are settled; fixed schedules auto-close only after full verified settlement.
17. Chain-of-custody events are append-only commercial evidence and must never be silently edited or deleted.
18. Reported or verified laboratory-result values must not be rewritten in place; corrections must use controlled result revisions with predecessor/supersession lineage.
19. Protected sampling, laboratory-certificate and inspection evidence must remain in the protected document path/classification and follow Deal Room sharing controls.
20. Seller-offer specifications may be populated from laboratory evidence only through a verified result plus verified certificate with matching order/offer context; a different existing value requires explicit replacement approval and publication-history capture.
21. Verified laboratory/inspection/publication evidence is auditable history and must not be silently deleted for operational convenience.
22. CRM DNC and per-channel contactability controls must be enforced at the database/action boundary before recording or scheduling outbound contact.
23. CRM communication history is append-only. Corrections must create a superseding activity rather than rewriting the original record.
24. Protected CRM context and evidence must inherit existing MRCIP protection rules; protected activity evidence must remain `mrcip_protected`.
25. CRM conversion and outreach must not fabricate or bypass buyer requirements, seller offers, opportunities or the Stage 4 disclosure protocol.
26. Stage 8 does not authorise autonomous external outreach. Any future sending/provider integration must be separately governed, auditable and subject to contactability/protection controls.
27. Stage 9 quality/risk/opportunity scores are internal deterministic decision support. They must not be represented as external credit ratings, sanctions opinions, legal opinions or guarantees.
28. Quality, risk and opportunity scoring snapshots are append-only historical records. Recalculate by creating a new controlled snapshot; never silently rewrite an existing score.
29. Counterparty risk evidence remains protected. General data-completeness access must not be used to infer or expose privileged risk flags, risk components or protected opportunity scoring.
30. All scoring algorithms must remain explicit, versioned and auditable. Changes to weights/formulas require a new migration/version and regression evidence rather than silent formula changes.
31. Stage 10 report runs must remain database-derived snapshots; clients must not author report summaries or row counts.
32. Stage 10 signal snapshots must remain derived from the canonical watched entity and existing Stage 8 watchlists; do not create a duplicate watchlist model or allow caller-authored alert payloads.
33. Protected watchlist signals and protected retrieval remain privileged MRCIP context and must not leak into general research/business-development access.
34. Intelligence retrieval must remain RLS-aware, purpose-audited and bounded; it must not expose protected contacts, mine protected details, commercial pricing/payment terms, KYC/banking or facilitator/commission information through convenience search metadata.
35. Retrieval/reporting is decision support only. It must not automatically contact a party, disclose a protected source, approve a deal, execute a contract, change a score, or mutate Finance/Freight/Negotiation calculations.
36. Report-run, signal-snapshot and retrieval-request histories are append-only audit records through authenticated grants. Recompute by adding a new run/snapshot/request rather than rewriting history.
