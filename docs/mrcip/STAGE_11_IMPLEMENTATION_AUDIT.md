# MRCIP Stage 11 Implementation Audit

## Stage 11 — Governed Intelligence AI Orchestration & Citation Foundation

**Project:** Mkhonto Resources Commodity Intelligence Platform (MRCIP)  
**Hosted project:** Mkhonto Resources Hub (`zjrzzvakwrwkrcqhcnyo`)  
**Controlled branch:** `mrcip/phase-0-audit`  
**Status:** **APPROVED / SIGNED OFF AT DATABASE, SECURITY, ORCHESTRATION AND CITATION-CONTROL BOUNDARY**

## 1. Objective and boundary

Stage 11 introduces a provider-agnostic governance layer above the Stage 10 authorised retrieval boundary. It does **not** claim that an external large-language-model provider is connected, credentialed or executing production prompts.

The implemented control flow is:

**AUTHORISED RETRIEVAL → FROZEN CONTEXT → VERSIONED RESPONSE → FROZEN-CONTEXT CITATIONS → HUMAN REVIEW → APPROVAL / CHANGES / REJECTION**

Stage 11 preserves the commercial protection protocol:

**PROTECT → VERIFY → DISCLOSE → CONTRACT**

The AI layer has no authority to bypass protection, disclose protected sources, autonomously contact counterparties, negotiate, approve transactions, contract, trade or execute payments.

## 2. Hosted migrations

| Version | Migration | Purpose |
|---|---|---|
| `20260821052113` | `mrcip_stage_11a_ai_orchestration_and_citation_foundation` | AI provider metadata, requests, frozen context, responses, citations and reviews |
| `20260821052234` | `mrcip_stage_11b_governed_ai_workflow_engine` | Request/context anti-forgery controls, provider gating and response/citation workflow |
| `20260821052322` | `mrcip_stage_11c_ai_review_rls_and_read_models` | Human review gate, RLS, least privilege and security-invoker read models |
| `20260821052512` | `mrcip_stage_11d_performance_hardening` | Covering indexes identified by the performance advisor |

Current hosted Stage 11 endpoint:

`20260821052512_mrcip_stage_11d_performance_hardening`

## 3. New controlled tables

### `mrcip_ai_provider_configs`

Stores provider governance metadata only. It deliberately does **not** store API keys, tokens or provider secrets.

Key controls:

- provider/model identity;
- lifecycle: `disabled`, `integration_ready`, `active`, `revoked`;
- credential state records only whether a credential is externally configured;
- protected-data permission is explicit and defaults to false;
- external processing location and data-handling notes can be recorded;
- only executive MRCIP authority may configure/activate providers;
- an active/integration-ready provider requires an externally configured credential state;
- protected-data processing can be enabled only for an active approved provider;
- provider identity and creation history are immutable after creation.

**Production provider rows after regression:** `0`.

### `mrcip_ai_requests`

Links every governed AI request to an actual completed Stage 10 `mrcip_retrieval_requests` record.

The database re-derives and controls:

- request text;
- purpose;
- entity scope;
- protected-access flag;
- context limit;
- context count;
- protected-context state;
- policy version and policy snapshot.

A caller cannot turn an unrelated, non-protected retrieval into a protected AI request by supplying forged fields.

### `mrcip_ai_context_items`

Freezes the exact ranked Stage 10 retrieval context used by the AI workflow.

Each context item records:

- audited retrieval request;
- result rank;
- entity type and ID;
- safe title/subtitle;
- relevance score;
- protected-context state;
- safe retrieval metadata;
- deterministic context fingerprint;
- capture actor/time.

The insert trigger ignores caller-supplied entity/title/metadata/protection values and re-derives the context item from the audited retrieval result at that rank.

### `mrcip_ai_responses`

Stores versioned response history. Supported origins are:

- `human_draft`;
- `deterministic_system`;
- `external_model`.

All new responses enter `review_required`. An external-model response is rejected unless an approved provider configuration is active and credential-ready. Protected context additionally requires that provider configuration to be explicitly approved for protected data.

Authenticated clients do not receive UPDATE or DELETE authority over response history.

### `mrcip_ai_citations`

Links a response only to frozen context items belonging to the same AI request. Citation type can be `support`, `context` or `contradiction`.

Protected state propagates from the response/context. A supported response with available context cannot be submitted with zero citations.

### `mrcip_ai_reviews`

Records the human governance decision:

- `approve`;
- `changes_requested`;
- `reject`.

Approval requires all three checks to pass:

1. citation check;
2. factuality check;
3. protection check.

Changes requested or rejection require explanatory notes. Protected or risk-summary review requires executive or legal/compliance authority.

A final review is append-only. A second final review of an already reviewed response is blocked; changes require a new response version.

## 4. Public workflow RPCs

All three public Stage 11 RPCs are **SECURITY INVOKER**, authenticated-only and use a fixed empty `search_path`:

1. `prepare_mrcip_ai_request(...)`
2. `submit_mrcip_ai_response(...)`
3. `review_mrcip_ai_response(...)`

`anon` has no execute access to these RPCs.

### Prepare request

Creates a Stage 10 retrieval audit, then creates the Stage 11 request and freezes the resulting context. Context is capped at 25 items.

### Submit response

Creates a new immutable response version and its citations. Supported responses must cite frozen context when context exists. Duplicate citation item IDs are rejected.

### Review response

Creates the controlled review record. Approval is not a client-writable response state: it is applied only after the database accepts the review checks and authority.

## 5. Policy snapshot v1

Each request freezes `mrcip-ai-policy-v1`, including the following explicit controls:

- cite only frozen context items;
- preserve `PROTECT → VERIFY → DISCLOSE → CONTRACT`;
- no autonomous outreach;
- no autonomous disclosure;
- no autonomous contracting;
- no autonomous trading;
- no fabricated sources;
- human review required;
- internal AI outputs must not be represented as external ratings/legal opinions/guarantees;
- use safe authorised retrieval metadata only.

## 6. Human-review authority

General response review requires one of:

- `super_admin`;
- `managing_director`;
- `commodity_manager`;
- `legal_compliance`.

Protected-context or `risk_summary` final review is narrower:

- `super_admin`;
- `managing_director`;
- `legal_compliance`.

This prevents ordinary research/business-development access from becoming protected intelligence approval authority.

## 7. RLS and Data API posture

RLS is enabled on all six Stage 11 public tables:

- `mrcip_ai_provider_configs`;
- `mrcip_ai_requests`;
- `mrcip_ai_context_items`;
- `mrcip_ai_responses`;
- `mrcip_ai_citations`;
- `mrcip_ai_reviews`.

`anon` has no Stage 11 table privileges.

Authenticated table grants:

- provider configurations: `SELECT`, `INSERT`, `UPDATE`, with executive RLS/trigger control and no DELETE;
- requests: `SELECT`, `INSERT` only;
- context items: `SELECT`, `INSERT` only;
- responses: `SELECT`, `INSERT` only;
- citations: `SELECT`, `INSERT` only;
- reviews: `SELECT`, `INSERT` only.

The absence of authenticated UPDATE/DELETE on request/context/response/citation/review history is intentional.

## 8. Private trigger helpers

Most Stage 11 private guard functions are SECURITY INVOKER and not directly executable by authenticated/anonymous clients.

Two private trigger helpers are SECURITY DEFINER because they must synchronise controlled lifecycle state after an insert:

- `private.sync_mrcip_ai_request_after_response()`;
- `private.apply_mrcip_ai_review()`.

Both:

- use fixed `search_path=''`;
- are in the non-exposed `private` schema;
- have no direct `anon` or `authenticated` execute privilege;
- run only from controlled database triggers.

## 9. Read models

Two views are live and both use `security_invoker=true`:

### `mrcip_ai_request_summary`

Provides request and latest-response operational state, including response origin/provider metadata, evidence state, review status and citation/review counts.

### `mrcip_ai_citation_trace`

Provides auditable response → citation → frozen context lineage, including context fingerprint and safe metadata.

The views do not bypass underlying RLS.

## 10. Authenticated rollback regression

All functional Stage 11 fixtures were executed inside an authenticated rollback-only transaction. No synthetic fixture remained in production.

**Result: 11/11 controls passed.**

| Test | Result | Evidence |
|---|---|---|
| Prepared context is frozen | PASS | One context item derived from Stage 10 retrieval; request remained `context_ready` |
| Direct request/context forgery normalised | PASS | Forged request text, scope, protection, count, entity, title and metadata were replaced by audited retrieval values |
| Supported response without citation blocked | PASS | Database rejected supported answer with no citation |
| Unconfigured external model blocked | PASS | `external_model` submission rejected without approved provider config |
| Provider activation without credential blocked | PASS | Active provider rejected when credential state was not externally configured |
| Cited response requires review | PASS | Response version 1 created as `review_required` with one citation |
| Approval without all checks blocked | PASS | Approval rejected when citation check was false |
| Human review is only approval path | PASS | Valid review moved response and request to `approved` |
| Response history update blocked | PASS | Authenticated direct answer rewrite denied |
| Second final review blocked | PASS | Already approved response cannot receive another final review |
| Non-member AI request blocked | PASS | User outside authorised organisation/MRCIP access could not prepare request |

## 11. Anti-fabrication findings

The regression deliberately attempted caller-controlled manipulation.

### Request/context forgery

A direct insert supplied forged:

- request text and purpose;
- entity scope;
- protected flag;
- context count;
- approved status;
- fake policy label;
- fake context entity/title/metadata/fingerprint.

The database normalised the request and context to the real Stage 10 audited retrieval. The resulting context referred to the actual fixture counterparty and safe retrieval metadata.

### Citation enforcement

A response declaring `evidence_state='supported'` but supplying no citations was rejected.

### Approval enforcement

A response could not become approved until a governed reviewer passed citation, factuality and protection checks.

## 12. Provider boundary

**No external AI provider is currently connected or activated by Stage 11.**

The provider table is governance metadata and integration readiness only. No production provider configuration exists after the rollback regression.

Stage 11 therefore does not claim:

- OpenAI/Anthropic/Google/other provider connectivity;
- active provider credentials;
- external prompt execution;
- provider response delivery;
- token/cost accounting;
- provider-side retention controls;
- production generative answers.

Those require a separately governed execution gateway and credentials/configuration.

## 13. Security advisor

Final security advisor result:

- **no new Stage 11-specific security finding**.

The remaining findings are pre-existing and tracked separately:

1. authenticated-callable `public.can_access_portal` SECURITY DEFINER;
2. authenticated-callable `public.complete_organisation_onboarding` SECURITY DEFINER;
3. authenticated-callable `public.get_my_access` SECURITY DEFINER;
4. leaked-password protection disabled in Supabase Auth configuration.

Stage 11 deliberately did not modify these Auth-sensitive functions/settings.

## 14. Performance advisor

The first Stage 11 performance pass identified three missing covering indexes:

1. AI context-item retrieval foreign key;
2. AI request `requested_by` foreign key;
3. AI review `reviewer_id` foreign key.

Migration `20260821052512_mrcip_stage_11d_performance_hardening` added the required indexes.

The advisor rerun no longer reports those Stage 11 missing-FK-index findings.

Remaining notices are expected unused-index information on new/empty tables plus the pre-existing duplicate organisation-membership index warning. The pre-existing index warning was not altered during Stage 11.

## 15. Type generation

Supabase TypeScript schema generation succeeded after Stage 11 and includes:

- all six Stage 11 tables;
- both Stage 11 security-invoker views;
- all three public Stage 11 workflow RPCs.

## 16. Production residue

After rollback-isolated testing, production counts are:

- `mrcip_ai_provider_configs`: **0**;
- `mrcip_ai_requests`: **0**;
- `mrcip_ai_context_items`: **0**;
- `mrcip_ai_responses`: **0**;
- `mrcip_ai_citations`: **0**;
- `mrcip_ai_reviews`: **0**;
- Stage 10 retrieval requests: **0**;
- Stage 11 synthetic fixture counterparties: **0**.

No test intelligence or provider configuration was left behind.

## 17. Hosted ↔ GitHub migration byte identity

Every Stage 11 repository migration is byte-identical to the hosted migration SQL. Hosted-computed Git blob SHA-1 matches GitHub blob SHA exactly:

| Migration | Hosted/GitHub Git blob SHA-1 |
|---|---|
| 11a | `e0f6193bf06d9a037f6b962db384ea4d2a3146a5` |
| 11b | `bd287b3d30f6686a837af6562a92e1089ca686c1` |
| 11c | `2725939155d12478ce656eae39151b74471cf0d1` |
| 11d | `da1d493749aaaebfd918728419222965142d53cf` |

The migration chronology must remain 11a → 11b → 11c → 11d. Do not squash later hardening backward into earlier migration history.

## 18. Regression boundary — existing systems unchanged

Stage 11 did not change or duplicate:

- quotation calculations;
- invoice calculations;
- VAT logic;
- Finance line-item arithmetic;
- Payment semantics;
- Stage 5/6 facilitator/commission/settlement controls;
- Stage 7 sampling/laboratory/certificate/inspection evidence lineage;
- Stage 8 CRM DNC/contactability/history controls;
- Stage 9 quality/risk/readiness scoring formulas;
- Stage 10 report/watchlist/retrieval semantics except using the authorised retrieval boundary;
- Freight profitability calculations;
- Negotiation calculations;
- trip/vehicle/driver execution calculations;
- existing Auth/access RPC behaviour.

## 19. Known limitations / not implemented

- No external LLM/provider execution is live.
- No provider credential is stored in MRCIP; future credentials must remain in an approved external secret mechanism.
- No production prompt-execution gateway exists yet.
- No token/cost/latency/model-response telemetry exists yet.
- No automatic AI action is authorised.
- Full visual Admin AI/dashboard/review UI remains blocked because the complete application source is not present in the connected repository.
- No external sanctions/PEP/adverse-media provider is connected.
- The exact consolidated seed workbook remains unresolved for controlled import.
- Browser-level full platform regression remains blocked by the partial frontend source.

## 20. Stage 11 acceptance criteria

Stage 11 passes its current boundary because:

- every AI request is anchored to audited Stage 10 retrieval;
- request/context forgery is normalised at the database boundary;
- context is frozen and fingerprinted;
- supported answers require citations to frozen context;
- external-model submissions require an approved provider configuration;
- protected context additionally requires provider approval for protected data;
- provider secrets are not stored in Stage 11 tables;
- all responses are versioned and start as review-required;
- approval requires a governed human review;
- citation/factuality/protection checks are mandatory for approval;
- protected/risk final review has narrower authority;
- response/citation/review history is append-only to authenticated clients;
- all six public tables have RLS;
- `anon` has no Stage 11 table privileges;
- public RPCs are SECURITY INVOKER and authenticated-only;
- read models use `security_invoker=true`;
- no new Stage 11 security-advisor finding remains;
- all three Stage 11 performance FK-index findings were remediated;
- TypeScript types generate successfully;
- 11/11 rollback regressions pass;
- production test residue is zero;
- all four migrations match hosted SQL byte-for-byte;
- prior MRCIP and Finance/Freight/Auth commercial controls remain unchanged.

# STAGE 11 SIGN-OFF: APPROVED

Recommended next database-capable stage:

**Stage 12 — Controlled AI Provider Execution Gateway & Prompt/Model Audit**

That stage should connect an external model only after explicit provider/credential configuration, preserve the Stage 11 frozen-context and citation contracts, record prompt/model/version/provider request IDs, track execution telemetry/cost where available, apply protected-data provider policy before any external processing, and continue to require human review before any response can be treated as approved MRCIP intelligence.
