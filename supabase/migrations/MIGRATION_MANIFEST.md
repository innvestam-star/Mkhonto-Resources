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

## Verification performed

- Hosted project status: healthy.
- Full public-schema inspection and migration-history queries: successful.
- Exact hosted migration versions are mirrored to GitHub through Stage 6.
- TypeScript database type generation succeeded after Stage 6 and includes the four settlement tables plus all six controlled settlement RPCs.
- Stages 1–5 remain signed off; Stage 3 matching regressions remain **99.80/100 candidate** and **50.00/100 disqualified** for the mandatory-CV failure fixture.
- Stage 4 continues to enforce **PROTECT → VERIFY → DISCLOSE → CONTRACT** and reference-only Finance/Freight/Negotiation integration.
- Stage 5 continues to enforce revisioned facilitator-chain control, exact 100% commission allocation, fee-protection linkage and verified trigger crystallisation before settlement.
- Stage 6 adds a commission-specific settlement subledger rather than replacing or redefining the existing Finance/Payments models.
- Stage 6 settlement cycles support all three approved commission bases: `percent_of_transaction`, `per_metric_tonne`, and `fixed_amount`.
- Per-metric-tonne regression: **R10/MT × 1,000 MT = R10,000**, allocated **R6,000/R4,000** on a 60/40 split.
- Percentage regression: **2.5% × R200,000 = R5,000**.
- Fixed-amount regression: **R5,000**, with duplicate active fixed-fee settlement cycles blocked.
- Main Stage 6 recurring settlement regression passed **9/9 controls**: pool arithmetic, partial reconciliation, overpayment blocking, derived-field immutability, full recurring-cycle settlement, direct paid-bypass blocking, controlled closeout, payout reversal/reopen, and replacement-payout restoration.
- Fixed schedules become `paid` automatically only after their single settlement cycle is fully verified/settled.
- Recurring R/MT and percentage schedules remain `partially_paid` after fully settled cycles until an explicit final closeout confirms all obligations are complete.
- Verified payout reversals recalculate facilitator, batch and schedule balances; replacement payouts can then restore the settled/paid state.
- Settlement approval and verified payout transitions require controlled source/evidence references; overpayment above a facilitator settlement-item balance is blocked.
- Stage 6 tests exposed an internal reconciliation guard-context leak; `20260821032908_mrcip_stage_6c_internal_guard_context_hardening` now saves/restores internal guard state on success and exception.
- Stage 6 tests also exposed a closeout PL/pgSQL alias collision; `20260821032955_mrcip_stage_6d_closeout_guard_alias_hardening` remediated it before final regression sign-off.
- RLS is enabled on all four Stage 6 public tables: `commission_settlement_batches`, `commission_settlement_items`, `commission_settlement_entries`, and `commission_schedule_closeouts`.
- `anon` has no Stage 6 table privileges. Authenticated table access is explicit and RLS-controlled; settlement economics remain limited to executive, Finance and Legal/Compliance roles.
- Public Stage 6 settlement RPCs are invoker-mode; private reconciliation helpers are non-executable by `anon` and `authenticated`.
- Settlement-item DELETE access was intentionally removed so derived facilitator obligations cannot be erased through the Data API.
- Stage 6 retains tenant-safe composite relationships to commission schedules/allocations, facilitator members, Finance documents, Payments and evidence Documents.
- Existing quotation, invoice, VAT, Finance line-item, Payment and Freight calculation logic was not changed. Finance/Payment records are optional settlement evidence/reference only.
- Final Stage 6 fixture residue checks returned zero test counterparties, settlement batches, settlement items, settlement entries and closeouts. No production settlement data was created by regression tests.
- Security advisor rerun: no new Stage 6-specific security findings. Remaining warnings are the same pre-existing authenticated-callable Auth `SECURITY DEFINER` functions and disabled leaked-password protection.
- Performance advisor initially identified one Stage 6 missing covering index for the optional Payment FK. `20260821033201_mrcip_stage_6e_performance_hardening` remediated it; rerun no longer reports the Stage 6 FK warning.
- Remaining performance notices are expected unused-index messages on empty/new tables plus the pre-existing duplicate organisation-membership index.
- Formal Stage 6 implementation audit is stored at `docs/mrcip/STAGE_6_IMPLEMENTATION_AUDIT.md`.

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
