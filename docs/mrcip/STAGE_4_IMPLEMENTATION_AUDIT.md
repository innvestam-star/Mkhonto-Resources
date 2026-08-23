# MRCIP Stage 4 Implementation Audit & Sign-Off

## Stage

**Stage 4 — Opportunity / Deal Room + PROTECT → VERIFY → DISCLOSE → CONTRACT controls**

## Status

**SIGNED OFF — DATABASE / SECURITY / INTEGRATION FOUNDATION COMPLETE**

The Stage 4 implementation was applied to the hosted **Mkhonto Resources Hub** Supabase project and reconciled to source control using the exact hosted migration versions.

## Implemented scope

| Requirement | Status | Implementation location | Verification |
|---|---|---|---|
| Legacy document ACL hardening | LIVE | `20260821024154_mrcip_stage_4a_document_acl_hardening.sql` | `anon` removed; authenticated document access constrained to required CRUD under RLS |
| Opportunity / Deal Room foundation | LIVE | `public.opportunities` | Opportunity creation path, tenant FKs, lifecycle fields and protected-disclosure state verified |
| Protocol controls | LIVE | `public.opportunity_protocol_controls` | Protection, verification, disclosure eligibility and contract-stage state verified |
| Protection register | LIVE | `public.opportunity_protection_records` | NCNDA, transaction registration and related protection evidence supported |
| KYC/KYB cases | LIVE FOUNDATION | `public.opportunity_kyc_cases` | Buyer/seller verification state, screening-status fields and risk metadata supported |
| Mandate / authority register | LIVE FOUNDATION | `public.opportunity_mandates` | Buyer/seller/facilitator authority and expiry fields supported |
| Controlled disclosure ledger | LIVE | `public.opportunity_disclosures` | Request, approval, disclosure actor/time and prerequisite snapshot retained |
| Opportunity document links | LIVE | `public.opportunity_document_links` | Composite tenant-safe link to existing `documents` model |
| Existing Freight integration | LIVE FOUNDATION | `public.opportunity_freight_links` | Links existing `freight_analyses` by reference; no Freight formula duplication |
| Existing Finance integration | LIVE FOUNDATION | `public.opportunity_finance_links` | Links existing `finance_documents` by reference; no VAT/invoice formula duplication |
| Existing Negotiation integration | LIVE FOUNDATION | `public.opportunity_negotiation_links` | Links existing `negotiations` records by reference |
| Protected storage convention | LIVE | `mkhonto-documents` paths under `<organisation-id>/mrcip-protected/...` | Protected-document policies restricted to approved MRCIP roles |
| Opportunity creation RPC | LIVE | `public.create_opportunity_from_match(uuid)` | Human-shortlisted/accepted match prerequisite enforced |
| Protocol refresh RPC | LIVE | `public.refresh_opportunity_protocol(uuid)` | Eligibility recomputation and gate enforcement verified |

## Protocol behavior verified

The implemented transaction sequence is:

**PROTECT → VERIFY → DISCLOSE → CONTRACT**

Stage 4 does not treat a generated match as authority to disclose protected seller/source information. An opportunity is created from an eligible human-reviewed match, after which the protocol checklist controls progression.

Disclosure remains blocked until the required protection and verification conditions are satisfied. The regression path verified that:

1. a valid opportunity can be created from a shortlisted/accepted match;
2. an early seller/source disclosure attempt remains ineligible while required controls are incomplete;
3. NCNDA / transaction-registration protection evidence can be marked satisfied;
4. required buyer KYC/KYB and authority checks can be completed;
5. protocol refresh changes disclosure eligibility only after the required controls pass;
6. disclosure approval and execution record the approving/disclosing users and a prerequisite snapshot;
7. the opportunity can then progress to the contract step.

The successful end-state regression returned:

- opportunity stage: `disclosed`;
- disclosure locked: `false`;
- protocol step: `contract`;
- protection status: `protected`;
- verification status: `verified`;
- disclosure status: `disclosed`;
- disclosure eligible: `true`;
- approval audit evidence: present;
- disclosure audit evidence: present;
- prerequisite snapshot: JSON object retained.

All test fixtures were executed inside rollback-safe test transactions or removed after verification. No Stage 4 fixture rows remain in live counterparties, requirements, seller offers, opportunities, documents or opportunity-document links.

## Security audit

### Row Level Security

RLS is enabled on all Stage 4 public tables:

- `opportunities`
- `opportunity_protocol_controls`
- `opportunity_protection_records`
- `opportunity_kyc_cases`
- `opportunity_mandates`
- `opportunity_disclosures`
- `opportunity_document_links`
- `opportunity_freight_links`
- `opportunity_finance_links`
- `opportunity_negotiation_links`

### Data API privileges

- `anon`: no table privileges on Stage 4 Deal Room tables or the legacy `documents` table.
- `authenticated`: only explicitly required privileges remain.
- link-only Freight/Finance/Negotiation tables do not retain unnecessary UPDATE rights.
- legacy `documents` ACLs were hardened after discovering inherited `TRUNCATE`, `REFERENCES`, `TRIGGER` and anonymous privileges.

This was a critical remediation because RLS does not protect `TRUNCATE`.

### Tenant isolation

Stage 4 uses composite `(organisation_id, id)` relationships for transaction-critical links. This prevents cross-tenant relationships from being created by supplying another organisation's UUID.

### Protected documents

Protected MRCIP Deal Room content must use the storage path convention:

`<organisation-id>/mrcip-protected/...`

Protected document metadata and storage access are separated from general member document visibility by restrictive MRCIP policies.

## Performance audit

The Supabase performance advisor initially identified missing composite indexes on new Opportunity foreign-key relationships. Stage 4g added the required covering indexes.

After remediation:

- no Stage 4 unindexed-foreign-key findings remain;
- remaining `unused_index` notices are informational and expected on new/empty tables;
- the pre-existing duplicate `organisation_memberships` index remains outside Stage 4 scope.

## Integration safety / regression

Stage 4 integrates existing operational domains by reference rather than re-implementing them.

The following existing tables remained structurally and functionally protected:

- `finance_documents`
- `finance_line_items`
- `payments`
- `freight_analyses`
- `negotiations`
- `trips`

Stage 4 did not rewrite Finance calculations, VAT logic, quote/invoice calculations, Freight profitability formulas, payments, or Trips logic.

Regression reconciliation confirmed no Stage 4 test residue and no unexpected changes to the existing protected-module row counts.

## Hosted migration chain

Stage 4 consists of the following exact hosted migrations:

| Version | Migration |
|---|---|
| `20260821024154` | `mrcip_stage_4a_document_acl_hardening` |
| `20260821024314` | `mrcip_stage_4b_opportunity_and_protocol_foundation` |
| `20260821024343` | `mrcip_stage_4c_opportunity_protocol_rls` |
| `20260821024432` | `mrcip_stage_4d_protect_verify_disclose_contract_engine` |
| `20260821024626` | `mrcip_stage_4e_deal_room_module_links` |
| `20260821024645` | `mrcip_stage_4f_protected_document_storage_hardening` |
| `20260821024843` | `mrcip_stage_4g_performance_and_grant_hardening` |

All seven successful migrations are committed on `mrcip/phase-0-audit` with versions matching the hosted migration history.

## Type generation

Hosted TypeScript database type generation succeeded after Stage 4 and includes:

- the complete Stage 3 requirement/supply/matching model;
- all Stage 4 Opportunity/Deal Room tables;
- `create_opportunity_from_match`;
- `refresh_opportunity_protocol`.

The complete application source is still only partially present in the connected repository, so the generated hosted schema is authoritative while final Admin UI type-file synchronization remains an application-source task.

## Remaining known findings outside Stage 4

The Supabase security advisor still reports these pre-existing findings:

1. authenticated-callable `SECURITY DEFINER` function `can_access_portal`;
2. authenticated-callable `SECURITY DEFINER` function `complete_organisation_onboarding`;
3. authenticated-callable `SECURITY DEFINER` function `get_my_access`;
4. leaked-password protection disabled in Supabase Auth.

These were reviewed but deliberately not modified inside Stage 4 because they affect the existing authentication/onboarding system and require a dedicated Auth regression pass.

## Stage 4 limitations / truthful status

The following are **not** represented as complete by Stage 4:

- external sanctions/PEP screening integration;
- full Admin Deal Room UI, because the connected repository still lacks the full Admin application source;
- complete legal-document automation/e-signature workflow;
- facilitator commission schedules and payment triggers;
- laboratory sampling/inspection orchestration;
- full system UI regression across Finance/Freight/Auth.

The database, security, disclosure-gate and module-link foundation required for those later workflows is live.

## Final decision

**Stage 4 passes IMPLEMENT → TEST → AUDIT → REMEDIATE → SIGN OFF.**

Stage 4 is complete for the scope that can be implemented and verified in the connected hosted database and current repository.

### Sign-off

- Opportunity / Deal Room DB foundation: **SIGNED OFF**
- PROTECT → VERIFY → DISCLOSE → CONTRACT gate: **SIGNED OFF**
- KYC/KYB structured foundation: **SIGNED OFF**
- Mandate/authority structured foundation: **SIGNED OFF**
- Controlled seller/source disclosure ledger: **SIGNED OFF**
- Protected document/storage controls: **SIGNED OFF**
- Finance/Freight/Negotiation reference integration: **SIGNED OFF**
- Stage 4 RLS / tenant isolation: **SIGNED OFF**
- Stage 4 performance remediation: **SIGNED OFF**
- Stage 4 source-control reconciliation: **SIGNED OFF**

**Overall Stage 4 status: SIGNED OFF.**
