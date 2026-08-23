# MRCIP Stage 1 Implementation Audit

Date: 2026-08-21

## Scope

Stage 1 established the production database foundation for MRCIP without modifying existing Finance, Freight, Trips, Payments or authentication business logic.

## Migration remediation

**Status: SIGNED OFF**

The migration blocker caused by unavailable/stale database tooling credentials is resolved. The hosted project can be queried, inspected and type-generated. The four historical migrations that existed only in hosted Supabase after the original repository was deleted were recovered from `supabase_migrations.schema_migrations` and restored to source control.

The repository now contains the exact hosted migration versions through `mrcip_stage_1g_performance_hardening`.

## Implemented Stage 1 foundation

| Requirement | Status | Implementation |
|---|---|---|
| MRCIP role overlay | LIVE | `mrcip_user_roles`, `private.has_mrcip_role` |
| Counterparty Master | LIVE FOUNDATION | `counterparties` |
| Multi-role parties | LIVE FOUNDATION | `counterparty_roles`, `counterparty_role_assignments` |
| Multiple contacts | LIVE FOUNDATION | `counterparty_contacts` |
| Commodity Master | LIVE FOUNDATION | `commodities` |
| Commodity Products | LIVE FOUNDATION | `commodity_products` |
| Structured spec templates | LIVE FOUNDATION | `commodity_spec_fields` |
| Counterparty commodity relationships | LIVE FOUNDATION | `counterparty_commodities` |
| Source provenance | LIVE FOUNDATION | `intelligence_sources` |
| Verification history | LIVE FOUNDATION | `verification_records` |
| Fuzzy search foundation | LIVE FOUNDATION | `pg_trgm` + trigram indexes |
| RLS / role-aware access | LIVE | All new public MRCIP tables |
| Protected-contact read controls | LIVE FOUNDATION | RLS on `counterparty_contacts` |
| Protected-source read controls | LIVE FOUNDATION | RLS on `intelligence_sources` |
| FK/index hardening | LIVE | Stage 1g migration |

## Seed verification

- Counterparty role catalogue: **28** roles.
- Commodity groups: **11**.
- Commodity products: **58**.
- Coal specification fields: **15**.
- Initial executive MRCIP role assignments: **2** (`super_admin`, `managing_director`) for the existing organisation owner.
- Counterparty records: **0** pending controlled intelligence import.

## Security verification

All 11 new public MRCIP tables were confirmed with RLS enabled.

The first policy pass was remediated before sign-off:

1. Non-owner organisation members originally had an overly broad path when `allowed_roles` was null. This was corrected so non-owners require explicit MRCIP role assignment.
2. Protected contacts now require privileged MRCIP roles.
3. Sensitive intelligence sources now require privileged MRCIP roles.
4. The `pg_trgm` extension was moved from `public` to the `extensions` schema after the security advisor flagged it.
5. `FOR ALL` write policies that also participated in SELECT were split into explicit INSERT/UPDATE/DELETE policies.

Remaining security advisor warnings are pre-existing platform findings concerning the authenticated SECURITY DEFINER access/onboarding RPCs and disabled leaked-password protection. The RPC bodies have fixed search paths and authenticated-user checks; they were not changed during MRCIP Stage 1 because existing Auth routes depend on them. They remain tracked for a separate regression-tested security remediation.

## Performance verification

Stage 1 foreign-key paths were indexed after the first performance-advisor pass. The new unindexed-FK warnings and multiple-permissive-policy warnings were removed.

Unused-index notices are expected at this point because the MRCIP tables are new and contain no imported counterparty data yet. The duplicate organisation-membership index predates MRCIP and was not changed in this stage.

## Regression protection

No MRCIP migration altered the definition or data of:

- `clients`
- `finance_documents`
- `finance_line_items`
- `payments`
- `freight_analyses`
- `negotiations`
- `trips`

Their row counts remained unchanged during the Stage 1 work.

The complete Admin/Finance/Freight frontend source is not present in the connected GitHub repository, so browser/UI regression testing cannot yet be claimed. Database-level regression checks passed.

## Stage 1 conclusion

**Stage 1 database foundation: SIGNED OFF.**

The next implementation work should build the Mines & Operations registry, Laboratory & Inspection network, import staging/validation/deduplication workflow, then seed verified intelligence. Buyer requirements and seller supply should follow once these foundation registries are in place.
