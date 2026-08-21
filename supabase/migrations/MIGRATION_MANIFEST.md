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

## Verification performed

- Hosted project status: healthy.
- Full public-schema inspection and migration-history queries: successful.
- Exact hosted migration versions are mirrored to GitHub through Stage 5.
- TypeScript database type generation succeeded after Stage 5 and includes facilitator-chain, commission-control tables and Stage 5 RPCs.
- Stages 1–4 remain signed off; Stage 3 matching regressions remain **99.80/100 candidate** and **50.00/100 disqualified** for the mandatory-CV failure fixture.
- Stage 4 continues to enforce **PROTECT → VERIFY → DISCLOSE → CONTRACT** and reference-only Finance/Freight/Negotiation integration.
- Stage 5 introduces revisioned `facilitator_chains` and `facilitator_chain_members`; approved/superseded chains are immutable and hidden intermediary insertion into an approved chain is blocked.
- Facilitator approval requires every participant to be authority `verified/not_required` and protection `protected/waived`.
- Stage 5 introduces commission schedules with supported pool bases `percent_of_transaction`, `per_metric_tonne`, and `fixed_amount`.
- Commission allocations are derived from the schedule pool and approval requires the allocation shares to total exactly **100%**.
- Commission approval requires a current executed/verified fee-protection record and an approved facilitator chain for the same opportunity.
- Approved commission commercial terms and allocations are immutable; changes use revision RPCs and prior approved revisions are superseded under controlled rules.
- Payment-trigger events can link evidence Documents, Finance documents and Payments using tenant-safe relationships. A schedule becomes `payable` only after its configured trigger is verified.
- Direct `partially_paid`/`paid` status mutation is blocked pending the dedicated settlement workflow.
- Stage 5 Finance integration is reference-only through `commission_finance_links`; existing Finance/VAT/quote/invoice calculations were not changed.
- Composite `(organisation_id,id)` identity was added where needed to `opportunity_protection_records` and `payments` so Stage 5 FKs remain tenant-safe.
- RLS is enabled on all six Stage 5 public tables: `facilitator_chains`, `facilitator_chain_members`, `commission_schedules`, `commission_allocations`, `commission_trigger_events`, and `commission_finance_links`.
- `anon` has no Stage 5 table privileges. Authenticated grants are explicit and RLS-controlled; the finance-link table is intentionally link-only with no UPDATE grant.
- End-to-end Stage 5 regression passed eight controls: chain approval; exact 100% 60/40 allocation; approved-chain immutability; approved-allocation immutability; chain-revision introducer preservation; schedule-revision supersession; verified payment-trigger crystallisation to `payable`; and direct settlement bypass blocking.
- The R10/MT regression pool with 60/40 allocation derived **R6/MT** and **R4/MT** correctly.
- Stage 5 fixtures were explicitly closed and deleted after the final test; residue checks returned zero fixture counterparties, chains and schedules.
- Security advisor rerun: no new Stage 5 security findings. Remaining warnings are the same pre-existing authenticated-callable Auth `SECURITY DEFINER` functions and disabled leaked-password protection.
- Performance advisor rerun: no new Stage 5 missing-FK-index findings. The remaining duplicate organisation-membership index predates MRCIP; unused-index messages are informational while new tables are empty.

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
14. Do not mark commission as paid without the dedicated settlement workflow and auditable Finance/payment evidence.
