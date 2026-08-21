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

## Verification performed

- Hosted project status: healthy.
- Full public-schema inspection and migration-history queries: successful.
- Exact hosted migration versions are mirrored to GitHub through Stage 4.
- TypeScript database type generation succeeded after Stage 4 and includes Stage 3 requirement/supply/matching objects, all Stage 4 Deal Room tables, `create_opportunity_from_match(uuid)` and `refresh_opportunity_protocol(uuid)`.
- RLS is enabled on every Stage 4 Deal Room table.
- Stage 3 matching remains explainable and audit-preserving: positive fixture **99.80/100**, mandatory-spec failure fixture **50.00/100 disqualified**.
- Stage 4 opportunity creation is restricted to an eligible human-reviewed match rather than treating an AI/generated match as authority to disclose.
- Stage 4 implements the transaction gate **PROTECT → VERIFY → DISCLOSE → CONTRACT**.
- Early protected seller/source disclosure was regression-tested and remained blocked until required protection, buyer verification and authority controls passed.
- Successful disclosure regression retained approver, discloser, timestamps and prerequisite snapshot, and advanced the opportunity to the contract step.
- Protected Deal Room storage uses `<organisation-id>/mrcip-protected/...` and restrictive MRCIP storage/document policies.
- Legacy `documents` ACLs were hardened after audit found inherited anonymous and excessive privileges including `TRUNCATE`; `anon` now has no table privileges and authenticated users retain only required CRUD subject to RLS.
- Stage 4 Finance, Freight and Negotiation integration is reference-only through link tables; no VAT, quote/invoice, payment, Freight profitability or negotiation calculations were duplicated.
- Link-only Freight/Finance/Negotiation tables had unnecessary UPDATE rights removed.
- Composite tenant FKs prevent cross-organisation Deal Room relationships.
- Security advisor rerun: no new Stage 4 security warnings. Remaining findings are pre-existing authenticated-callable Auth SECURITY DEFINER RPCs and leaked-password protection configuration.
- Performance advisor rerun: all Stage 4 missing-FK-index findings were remediated. Remaining unused-index notices are informational on new/empty tables; the duplicate organisation-membership index predates MRCIP.
- All Stage 4 regression fixtures were rolled back or removed; no fixture counterparties, requirements, offers, opportunities, documents or Deal Room links remain.
- Existing Finance, Freight, Payments, Negotiations and Trips data remained unchanged during Stage 4.
- Formal Stage 4 implementation audit is stored at `docs/mrcip/STAGE_4_IMPLEMENTATION_AUDIT.md`.

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
