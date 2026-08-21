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

## Verification performed

- Hosted project status: healthy.
- Full public-schema inspection and migration-history queries: successful.
- Exact hosted migration versions are mirrored to GitHub through Stage 3.
- TypeScript database type generation succeeded after Stage 3 and includes the Stage 3 tables and matching RPC.
- RLS is enabled on `buyer_requirements`, `buyer_requirement_specs`, `seller_supply_offers`, `seller_offer_specs`, and `commodity_matches`.
- Stage 3 Data API exposure is explicit: `authenticated` receives only `SELECT`, `INSERT`, `UPDATE`, and `DELETE`; excess `TRUNCATE`, `REFERENCES`, and `TRIGGER` privileges discovered from legacy default ACLs were revoked.
- Protected seller offers and all dependent seller specification/match records inherit privileged MRCIP visibility rules.
- Tenant integrity is enforced with composite `(organisation_id, id)` foreign keys, including assay/certificate document linkage after Stage 3f hardening.
- The matching RPC `refresh_buyer_requirement_matches(uuid)` is `SECURITY INVOKER`, has no anon/public execute grant, and retains an explicit privileged MRCIP-role check.
- Positive matching regression: compatible coal fixture scored **99.80/100**, passed hard filters, and had zero mandatory specification failures.
- Negative matching regression: a mandatory calorific-value failure scored **50.00/100**, failed hard filters, and was persisted as `disqualified` with one failed-specification evidence item.
- Both regression fixtures ran in rolled-back transactions; no test rows remain in live intelligence tables.
- Security advisor rerun: no new Stage 3 security warnings. Remaining warnings are the pre-existing authenticated-callable Auth SECURITY DEFINER RPCs and leaked-password configuration finding.
- Performance advisor rerun: all Stage 3 missing-FK-index findings were remediated. Remaining unused-index notices are expected while new tables are empty; the duplicate organisation-membership index predates MRCIP.
- Existing Finance, Freight, Payments, Negotiations and Trips schemas/calculations were not modified and their row counts remained unchanged during Stage 3.

## Ongoing rules

1. Never replace the recovered history with a manually invented baseline.
2. Every future DDL change must have a corresponding migration file using the exact hosted migration version.
3. Run security and performance advisors after structural database changes.
4. Regenerate `src/types/database.types.ts` after schema changes when the complete application source is synchronized.
5. Preserve Finance, Freight, Auth and existing protected-route behaviour unless a separately tested remediation requires modification.
6. Intelligence imports must enter through staging/validation/duplicate review; never silently overwrite master records.
7. Matching must remain explainable and auditable: component scores, hard filters, failed mandatory fields, algorithm version and reviewer decisions must be retained.
8. Do not duplicate Freight profitability calculations inside the matching engine; future logistics economics must integrate the existing Freight module by reference.
