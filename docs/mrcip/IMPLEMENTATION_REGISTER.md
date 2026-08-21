# MRCIP Implementation Register

This register is the working source of truth for the Mkhonto Resources Commodity Intelligence Platform implementation.

Status vocabulary:

- **LIVE**
- **PARTIALLY IMPLEMENTED**
- **MOCKED**
- **INTEGRATION-READY**
- **NOT IMPLEMENTED**
- **DISABLED**
- **AWAITING CONFIGURATION**
- **AWAITING CREDENTIALS**
- **BLOCKED**

| Requirement | Status | Implementation Location | Database Impact | Integration | Tests | Issues | Remediation | Sign-off |
|---|---|---|---|---|---|---|---|---|
| Supabase project connectivity | LIVE | Hosted Supabase `zjrzzvakwrwkrcqhcnyo` | None | Core platform | Project health checked | SQL tooling password auth failing | Restore valid DB tooling credentials | Pending |
| Browser Supabase client | INTEGRATION-READY | `src/lib/supabase/client.ts` | None | Auth/Data API | Code inspected | Full app source not in repo | Reuse after source restoration | Pending |
| Server Supabase client | INTEGRATION-READY | `src/lib/supabase/server.ts` | None | Server components/actions | Code inspected | Full app source not in repo | Reuse after source restoration | Pending |
| Role-aware route proxy | LIVE | `src/lib/supabase/proxy.ts`, `proxy.ts` | Uses existing RPCs | Admin/Finance/Freight/Driver/Portal | Code inspected | RPC security-definer warnings need review | Review recovered function bodies/grants | Pending |
| Server portal guard | LIVE | `src/lib/supabase/access.ts` | Uses existing RPCs | Protected layouts/actions | Code inspected | Depends on hosted RPCs | Preserve and extend cautiously | Pending |
| Hosted migration history recovery | BLOCKED / AWAITING CREDENTIALS | `supabase/migrations/MIGRATION_MANIFEST.md`, recovery workflow | Critical | All future schema changes | Recovery attempted via connected tooling | DB password authentication failure | Restore `SUPABASE_DB_PASSWORD` + access token and run recovery | Required before Stage 1 DDL |
| Canonical organisation/counterparty identity | PARTIALLY IMPLEMENTED | Existing `public.organisations` identified | Existing table to inspect | Customers/RBAC/MRCIP | Advisor metadata inspected | Columns/FKs/RLS not yet recovered | Confirm schema, then extend rather than duplicate | Pending |
| Organisation memberships/RBAC | LIVE FOUNDATION | Existing `public.organisation_memberships` + RPCs | Existing | Auth/RBAC | Advisor + code inspected | Duplicate index warning; full policies unknown | Review after schema recovery | Pending |
| Existing client/customer model | LIVE | Existing `public.clients` | Existing | Finance/MRCIP conversion | Advisor metadata inspected | Columns/FKs unknown | Reuse after schema recovery | Pending |
| Finance documents | LIVE | Existing `public.finance_documents` | Existing | Quotes/invoices | Advisor metadata inspected | Full schema unknown | Link MRCIP opportunities; do not duplicate | Pending |
| Finance line items | LIVE | Existing `public.finance_line_items` | Existing | Quote/invoice calculations | Advisor metadata inspected | Calculation implementation not in repo | Regression-protect; do not rewrite blindly | Pending |
| Payments | LIVE | Existing `public.payments` | Existing | Settlement | Advisor metadata inspected | Full schema unknown | Link opportunities only after schema review | Pending |
| Freight profitability data | LIVE | Existing `public.freight_analyses` | Existing | MRCIP logistics | Advisor metadata inspected | Full schema/calculation code not in repo | Integrate by reference; do not duplicate calculations | Pending |
| Negotiation records | LIVE | Existing `public.negotiations` | Existing | Potential opportunity integration | Advisor metadata inspected | Structure unknown | Inspect recovered schema before reuse | Pending |
| Documents | LIVE | Existing `public.documents` | Existing | KYC/mandates/certificates | Advisor metadata inspected | Storage linkage unknown | Inspect before adding document categories | Pending |
| Audit events | LIVE | Existing `public.audit_events` | Existing | MRCIP audit trail | Advisor metadata inspected | Event structure unknown | Reuse/extend if fit after schema review | Pending |
| Vehicles/drivers/trips | LIVE | Existing vehicle/driver/trip tables | Existing | Logistics execution | Advisor metadata inspected | Full schema unknown | Link from logistics opportunities later | Pending |
| Counterparty multi-role model | NOT IMPLEMENTED | Proposed MRCIP domain | New relational tables/links | Organisations | Not started | Must avoid duplicate company master | Design against recovered `organisations` schema | Pending |
| Commodity master | NOT IMPLEMENTED | Proposed MRCIP domain | New tables | Requirements/offers/matching | Not started | Schema gate | Implement after recovery | Pending |
| Commodity specification engine | NOT IMPLEMENTED | Proposed MRCIP domain | New relational + controlled JSON structures | Labs/matching | Not started | Schema gate | Implement after recovery | Pending |
| Mines & operations intelligence | NOT IMPLEMENTED | Proposed MRCIP domain | New tables | Organisations/commodities/logistics | Not started | Schema gate | Implement after recovery | Pending |
| Laboratory network | NOT IMPLEMENTED | Proposed MRCIP domain | New tables | Sampling/certificates | Not started | Consolidated seed workbook not located yet | Finalize schema then import verified seed | Pending |
| Buyer requirements | NOT IMPLEMENTED | Proposed MRCIP domain | New tables | Counterparties/matching | Not started | Depends on commodity model | Stage after foundation | Pending |
| Seller supply offers | NOT IMPLEMENTED | Proposed MRCIP domain | New tables | Mines/matching | Not started | Depends on commodity model | Stage after foundation | Pending |
| Provenance/source evidence | NOT IMPLEMENTED | Proposed MRCIP domain | New tables | All intelligence | Not started | Required before imports | Implement in Stage 1 foundation | Pending |
| Verification history | NOT IMPLEMENTED | Proposed MRCIP domain | New tables | Counterparties/supply/demand | Not started | Required before imports | Implement in Stage 1 foundation | Pending |
| Import staging system | NOT IMPLEMENTED | Proposed MRCIP domain | New staging tables | File Library seed/workbooks | Design only | Exact consolidated workbook not located | Build after schema recovery; start with controlled batch | Pending |
| Duplicate detection | NOT IMPLEMENTED | Proposed MRCIP service | New queries/indexes | Import/counterparties | Not started | Requires canonical identity fields | Implement after organisation schema inspection | Pending |
| Matching engine | NOT IMPLEMENTED | Proposed MRCIP service | New match records | Buyer requirements/seller offers | Not started | Depends on structured data | Implement transparent weighted engine first | Pending |
| Opportunity / Deal Room | NOT IMPLEMENTED | Proposed MRCIP domain | New opportunity/link tables | Legal/Freight/Finance/Documents | Not started | Depends on match + protection workflow | Later stage | Pending |
| Protected introductions | NOT IMPLEMENTED | Proposed MRCIP domain/security | New records + RLS | Legal/RBAC | Not started | P0 security requirement | Implement server/RLS/API enforcement | Pending |
| KYC/KYB | NOT IMPLEMENTED / EXISTING DOCS MAY BE REUSABLE | Proposed MRCIP domain | New structured compliance records + document links | Legal/Documents | Not started | Existing document schema unknown | Inspect and reuse document storage | Pending |
| Mandate register | NOT IMPLEMENTED | Proposed MRCIP domain | New tables | Legal/Opportunities | Not started | Schema gate | Later stage | Pending |
| Facilitator chain & commissions | NOT IMPLEMENTED | Proposed MRCIP domain | New tables | Finance/Legal | Not started | Must validate allocation totals | Later stage | Pending |
| Sampling & inspection | NOT IMPLEMENTED | Proposed MRCIP domain | New tables | Labs/Opportunities/Documents | Not started | Depends on lab model | Later stage | Pending |
| Outreach CRM | PARTIAL DATA ONLY | Seed spreadsheets/File Library | New relational activity records or reuse if available | Counterparties/opportunities | Not started | Full application CRM schema not recovered | Inspect existing tables then design | Pending |
| Watchlists | NOT IMPLEMENTED | Proposed MRCIP domain | New tables | Intelligence UI | Not started | None yet | Later stage | Pending |
| Executive dashboard | NOT IMPLEMENTED | Proposed MRCIP UI | Read models/views | All MRCIP domains | Not started | Must not precede core data foundation | Build after transactional data exists | Pending |
| Map intelligence | NOT IMPLEMENTED | Proposed MRCIP UI | Location fields/indexes | Mines/buyers/sellers/labs | Not started | Coordinates must be verified | Build after stored location model | Pending |
| Mkhonto Intelligence AI | NOT IMPLEMENTED | Proposed AI layer | Retrieval/audit metadata | All authorised data | Not started | Requires mature structured/RBAC data | Implement after core workflows | Pending |
| Leaked-password protection | AWAITING CONFIGURATION | Supabase Auth | None | Auth | Security advisor checked | Disabled | Enable after platform/auth review | Pending |
| Auth SECURITY DEFINER functions | REVIEW REQUIRED | Hosted public RPCs | Existing functions | Auth/RBAC | Security advisor checked | Three authenticated-callable definer functions flagged | Inspect bodies/search_path/grants before changes | Pending |
| Full platform regression suite | NOT IMPLEMENTED / NOT AVAILABLE IN REPO | Future tests | None | Finance/Freight/Auth/etc. | Not started | Full source missing | Restore app source, then establish regression tests | Pending |
