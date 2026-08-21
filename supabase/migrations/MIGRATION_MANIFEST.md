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

## Verification performed

- Hosted project status: healthy.
- Full public-schema inspection and migration-history queries: successful.
- Exact hosted migration versions are mirrored to GitHub through Stage 7.
- TypeScript database type generation succeeded after Stage 7 and includes the eight Stage 7 traceability tables and all six controlled Stage 7 workflow RPCs.
- Stages 1–6 remain signed off; Stage 3 matching regressions remain **99.80/100 candidate** and **50.00/100 disqualified** for the mandatory-CV failure fixture.
- Stage 4 continues to enforce **PROTECT → VERIFY → DISCLOSE → CONTRACT** and reference-only Finance/Freight/Negotiation integration.
- Stage 5 continues to enforce revisioned facilitator-chain control, exact 100% commission allocation, fee-protection linkage and verified trigger crystallisation before settlement.
- Stage 6 continues to enforce a commission-specific settlement subledger, all three approved commission bases, overpayment protection, reversals and controlled recurring closeout without redefining existing Finance/Payments semantics.
- Stage 7 adds `commodity_sampling_requests`, `commodity_samples`, `sample_custody_events`, `laboratory_test_orders`, `laboratory_test_results`, `laboratory_certificates`, `commodity_inspections`, and `lab_result_publications`.
- Stage 7 reuses existing `laboratories`, `commodity_spec_fields`, `seller_offer_specs`, protected `documents`, `opportunity_document_links` and `audit_events`; no duplicate specification engine or document store was introduced.
- Sampling requests preserve opportunity/seller-offer/commodity/product/mine context and inherit protected handling from protected seller offers.
- Chain-of-custody events are append-only; sample identity/collection fields become immutable after custody begins; protected custody evidence must use `mrcip_protected` Documents.
- Laboratory receipt requires a custody `received` event. Direct test-order verification is blocked.
- Reported/verified laboratory-result values cannot be silently rewritten; corrections use controlled revision lineage and a verified correction supersedes the previous verified revision.
- Certificates must reference an `mrcip_protected` Document, match the test-order laboratory, retain a checksum snapshot, and be human-verified before supporting publication.
- Verified laboratory certificates link into the protected Deal Room using the existing Stage 4 `assay` role; verified inspection reports reuse the existing `inspection` role.
- Verified laboratory results can publish to the existing seller-offer specification only when result/certificate/order/offer context agrees. Silent replacement of an existing different specification is blocked; explicit replacement records the previous value in the append-only publication ledger.
- Cross-offer laboratory-result publication is blocked.
- Stage 7 authenticated end-to-end regression passed **14/14 controls**, including protected request inheritance, custody-state derivation, sample immutability, direct-order-verification blocking, protected-certificate enforcement, Deal Room COA linkage, result/order verification, 5850 kcal/kg publication, verified-result immutability, controlled correction to 5900 kcal/kg, explicit replacement enforcement, cross-offer isolation, inspection evidence linkage and custody-ledger append-only protection.
- Stage 7 testing exposed a Stage 4 Deal Room document-role compatibility issue. `20260821035207_mrcip_stage_7c_deal_room_document_role_compatibility` remediated it by reusing existing `assay` and `inspection` roles rather than widening the controlled vocabulary.
- Stage 7 hardened legacy `audit_events` table grants to authenticated `SELECT,INSERT` only and no `anon` table privileges. Stage 7d consolidates overlapping SELECT policies while preserving existing management and MRCIP-authorised reads.
- RLS is enabled on all eight Stage 7 tables. `anon` has no Stage 7 table privileges. Public Stage 7 workflow RPCs are invoker-mode and not anonymously executable; private trigger helpers are non-executable by `anon` and `authenticated`.
- Stage 7 test cleanup left zero fixture counterparties, sampling requests, samples, test orders, results, certificates, inspections, protected fixture Documents and publication-ledger rows.
- Security advisor rerun: no new Stage 7-specific security findings. Remaining warnings are the same pre-existing authenticated-callable Auth `SECURITY DEFINER` functions and disabled leaked-password protection.
- Performance advisor identified a sampling-request product-FK covering index and overlapping `audit_events` SELECT policies during Stage 7. `20260821035501_mrcip_stage_7d_performance_and_audit_policy_hardening` remediated both; rerun no longer reports those Stage 7 findings.
- Remaining performance notices are expected unused-index messages on new/empty tables plus the pre-existing duplicate organisation-membership index.
- Existing quotation, invoice, VAT, Finance line-item, Payment, Stage 6 commission-settlement, Freight and Negotiation calculation logic was not changed.
- Formal Stage 7 implementation audit is stored at `docs/mrcip/STAGE_7_IMPLEMENTATION_AUDIT.md`.

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
