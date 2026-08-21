# MRCIP Workbook-to-Database Mapping

Status: **DESIGN COMPLETE / IMPORT NOT YET EXECUTED**

This mapping implements the import intent defined for the Mkhonto Resources Global Commodity Intelligence Database while preserving a single canonical company identity and source provenance.

The exact consolidated workbook must be inspected before final field-by-field mapping is approved. Related Mkhonto buyer, seller and mine intelligence workbooks are currently available and confirm the general field patterns described below.

## Import rule

Never import spreadsheet rows directly into production master tables without staging.

Required flow:

`Upload -> Import Batch -> Sheet Parse -> Row Staging -> Normalisation -> Validation -> Duplicate Candidates -> User Review -> Commit -> Audit`

## Canonical identity rule

A company that appears in multiple sheets must become one canonical organisation with multiple roles.

Example:

- a producer appearing in Sellers / Producers;
- the same legal entity appearing in Richards Bay Coal Network;
- the same entity appearing again as a trader/exporter;

must not create three unrelated companies.

The import must resolve the organisation first, then attach roles, locations, commodities, contacts and intelligence observations.

## Proposed sheet mapping

| Source sheet | Primary target domain | Secondary links |
|---|---|---|
| Laboratories | Organisations + Laboratory profile | contacts, addresses, capabilities, commodities, accreditations, source evidence |
| Richards Bay Coal Network | Organisations + roles + operations/export intelligence | mines, terminals, exporters, commodities, contacts, source evidence |
| Global Buyers | Organisations + Buyer role | buyer intelligence profile, contacts, commodities, locations, outreach, verification |
| Sellers / Producers | Organisations + Seller/Producer roles | mines/operations, commodities, products, source evidence, verification |
| Traders | Organisations + Trader/Offtaker roles | commodities, regions, contacts, opportunity roles |
| Commodity Coverage | Commodity Master / Product taxonomy | specification templates, category metadata |
| Outreach Tracker | CRM interactions/tasks | organisation, contact, commodity, opportunity, owner, follow-up |

## Laboratories mapping

### Organisation identity

- laboratory/company name -> canonical organisation
- website/domain -> duplicate key candidate
- country/province/city -> structured address/location
- telephone/email -> organisation/contact communication fields

### Laboratory profile

Map to dedicated laboratory attributes:

- accreditation
- SANAS number where applicable
- accreditation expiry
- commodity coverage
- test capabilities
- sample preparation
- inspection
- sampling
- TML
- marine/cargo capability
- turnaround time
- pricing notes
- preferred status
- last verified date

### Provenance

Every row must retain:

- source URL
- source type
- workbook/sheet
- original row reference
- captured/import date
- original notes
- original verification status

## Global Buyers mapping

Observed buyer workbook fields include concepts such as:

- ID
- Company
- Buyer / Offtaker Class
- Primary Commodities
- HQ Country
- Core Region
- Public Email
- Public Phone
- Official Contact / Procurement URL
- Supplier / Tender Portal
- Source URLs
- Contact Status
- Confidence
- Offtake Capability
- Commodity Fit
- Access Route
- Africa Relevance
- Priority Score
- Priority Tier
- Recommended First Approach
- Required Offer Pack
- Verification Date
- Notes / Risk Flags
- Outreach Status
- Last Contact
- Next Follow-up
- Owner

These should not all be stored on the organisation row.

Recommended distribution:

### Organisation

- company name
- legal/trading identity when known
- country
- website/domain

### Roles

- buyer
- offtaker
- trader
- industrial end user
- other applicable role

### Organisation-commodity links

- commodity coverage
- typical purchasing relationship

### Intelligence/qualification profile

- confidence
- capability score
- commodity-fit score
- access-route score
- regional relevance
- priority score/tier
- risk notes

### Contact/outreach

- public email/phone/contact route
- outreach status
- last contact
- next follow-up
- assigned owner

### Provenance

- source URL 1
- source URL 2
- verification date
- evidence notes

## Sellers / Producers mapping

Observed seller workbook fields include concepts such as:

- Seller ID
- Company
- Seller Type
- Primary Commodity
- Products
- Country
- Province/Region
- Mine / Operation
- Market / Sales Route
- Export Capability
- Logistics / Port Route
- Public Phone
- Public Email
- Website
- Source URL
- Verification Level
- Priority
- Outreach Status
- Verification Date
- Opportunity / Focus
- Notes / Risk Flags

Recommended distribution:

### Organisation

- company identity
- country
- province/region
- website/domain

### Roles

- seller
- producer
- exporter
- trader
- mine owner/operator where supported

### Operation/mine

- operation name
- location
- commodity
- source relationship

### Commodity/product links

- primary commodity
- products/grades

### Logistics intelligence

- export capability
- sales route
- rail/road/port notes

### Verification/provenance

- verification level
- verification date
- source URL
- notes/risk flags

## Detailed Mine Contacts mapping

The currently available Mkhonto mine-intelligence workbook contains fields such as:

- Original Mine / Site Name
- Resolved / Likely Entity
- Parent / Owner / Operator
- Commodity
- Current Status / Site Note
- Mine / Site Location
- Corporate / Registered Address
- Contact Person / Role
- Main / Secondary Phone
- Procurement / Business Email
- Other Public Email
- Website
- Best Contact Route
- Contact Type
- Identity Confidence
- Contact Confidence
- Mkhonto Opportunity
- Recommended First Approach
- Critical Notes
- multiple source URLs
- Last Verified
- Outreach Status

Recommended import behaviour:

1. preserve the original supplied mine/site name;
2. store resolved entity separately;
3. do not convert unresolved names into verified legal entities;
4. create owner/operator links only when supported by evidence;
5. create contact rows only for actual discovered contacts;
6. preserve confidence separately for identity and contact data;
7. retain all source URLs;
8. keep unresolved mines in the research/verification workflow rather than discarding them.

## Commodity Coverage mapping

Commodity taxonomy should populate a reusable relational master, not free-text lists embedded in organisations.

Recommended hierarchy:

- commodity group
- commodity
- product / grade
- specification template
- specification field definitions

Coal receives the deepest initial template, including CV, ash, sulphur, moisture, volatile matter, fixed carbon, HGI, size and other defined attributes.

## Richards Bay Coal Network mapping

Rows should resolve into a network rather than one flat table.

Potential relationships:

- Organisation -> has role Exporter / Producer / Trader / Terminal Operator / Laboratory / Inspector
- Organisation -> owns/operates Mine or Facility
- Mine -> produces Commodity/Product
- Organisation -> has RBCT/export relationship status
- Organisation -> has Port/Terminal relationship
- Organisation -> has Contact(s)
- Intelligence observation -> records source, date, verification and notes

RBCT status, allocation and export capability must not be marked verified unless the source supports the claim.

## Outreach Tracker mapping

Outreach records should become interaction/task records linked to canonical organisations and contacts.

Suggested fields:

- organisation_id
- contact_id
- channel
- interaction_date
- summary
- outcome
- follow_up_at
- commodity_id
- opportunity_id
- owner_user_id
- status
- source_import_batch_id

Do not overwrite prior interactions on re-import.

## Duplicate detection rules

Before committing an organisation, compare at minimum:

1. registration number — strongest identifier when available;
2. legal company name;
3. normalised trading name;
4. website domain;
5. email domain;
6. telephone;
7. address;
8. mine/operation name;
9. parent company relationship;
10. verified geographic location.

The importer may propose a duplicate but must require approval before merging materially different records.

## Import batch audit fields

Every import batch should record:

- batch ID
- filename
- file hash where practical
- uploaded by
- uploaded at
- parser version
- workbook sheets discovered
- rows staged
- rows rejected
- rows approved
- records inserted
- records updated
- duplicate candidates
- errors
- completion/rollback status

Every imported row should retain a pointer back to the import batch and original sheet/row.

## Re-import behaviour

Re-importing the same workbook must not silently duplicate records or overwrite newer verified data.

Recommended precedence:

1. verified current database data;
2. newer verified source evidence;
3. newer public-source-confirmed intelligence;
4. unverified/imported spreadsheet observations.

Conflicts should create a review item rather than automatically replacing authoritative data.

## Phase 1 import test

After schema recovery and MRCIP foundation migration:

1. import a small sample from each available sheet;
2. inspect duplicate suggestions;
3. verify source/evidence retention;
4. verify cross-sheet organisation reuse;
5. verify RLS isolation;
6. verify rollback;
7. only then import the complete workbook.
