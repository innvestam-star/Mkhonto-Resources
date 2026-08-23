# MRCIP Stage 12 Implementation Audit

## Controlled AI Provider Execution Gateway & Prompt/Model Audit

**Project:** Mkhonto Resources Commodity Intelligence Platform (MRCIP)  
**Hosted project:** Mkhonto Resources Hub (`zjrzzvakwrwkrcqhcnyo`)  
**Stage:** 12  
**Status:** **APPROVED — CONTROL/GATEWAY FOUNDATION**  
**External provider execution status:** **AWAITING CONFIGURATION / AWAITING CREDENTIALS — NO PRODUCTION PROVIDER ACTIVE**

## 1. Objective

Stage 12 introduces the controlled execution boundary that may, after explicit provider and secret configuration, send a governed Stage 11 intelligence request to an external model provider.

The stage does **not** weaken the existing evidence, protection or human-review controls. It extends them so that every external-model response has auditable prompt, model, provider, execution and citation provenance.

The governing protocol remains:

**PROTECT → VERIFY → DISCLOSE → CONTRACT**

The AI execution policy remains decision-support only. Stage 12 does not authorise autonomous outreach, protected-source disclosure, negotiation, contracting, trading, payment execution, scoring changes, or Finance/Freight mutation.

## 2. Implementation boundary

Stage 12 implements:

- versioned prompt templates and immutable prompt versions;
- executive/legal approval of prompt versions;
- explicit protected-data prompt approval;
- provider runtime-adapter metadata and Edge secret-reference metadata;
- provider connection verification state;
- immutable execution records with provider/model/prompt/context snapshots;
- execution fingerprints and lifecycle events;
- service-role-only external-response insertion;
- provider request IDs, token/latency telemetry and safe cost fields;
- safe telemetry filtering;
- explicit failure/blocked/cancelled execution states;
- a JWT-protected Supabase Edge Function execution gateway;
- a dormant allowlisted `openai_responses_v1` adapter path;
- mandatory handoff into the Stage 11 response/citation/human-review controls.

Stage 12 does **not** implement or claim:

- an active production provider configuration;
- a production API key/secret;
- a completed production external-model request;
- autonomous action authority;
- browser/Admin UI for prompt/provider/execution management;
- provider-specific billing reconciliation beyond recorded telemetry fields;
- external sanctions/PEP/adverse-media screening.

## 3. Hosted migrations

| Version | Migration | Purpose |
|---|---|---|
| `20260821054219` | `mrcip_stage_12a_prompt_execution_gateway_foundation` | Prompt/execution/event schema, provider runtime metadata, response execution provenance |
| `20260821054510` | `mrcip_stage_12b_prompt_approval_and_execution_control` | Prompt/provider/execution guards, user RPCs, service gateway RPCs, external-response provenance control |
| `20260821054537` | `mrcip_stage_12c_execution_rls_and_read_models` | RLS, grants and security-invoker operational views |
| `20260821054726` | `mrcip_stage_12d_gateway_service_authorization_fix` | Service gateway authorization remediation discovered during regression |
| `20260821054833` | `mrcip_stage_12e_provider_request_event_audit` | Explicit provider-request lifecycle event |
| `20260821054900` | `mrcip_stage_12f_provider_failure_state_hardening` | Missing-secret/provider-failure state hardening |
| `20260821055114` | `mrcip_stage_12g_performance_hardening` | Covering index for execution→response FK |

## 4. New public tables

### `mrcip_ai_prompt_templates`

Canonical prompt-purpose catalogue. Key controls:

- tenant scoped;
- controlled prompt key;
- fixed output type;
- active/retired lifecycle;
- creation identity immutable;
- RLS protected.

### `mrcip_ai_prompt_versions`

Immutable prompt-version history. Key controls:

- database-assigned monotonically increasing version number;
- system instructions and response instructions retained per version;
- database-derived content fingerprint;
- draft → approved → retired lifecycle;
- approval restricted to executive/legal-compliance authority;
- protected-data permission must be explicitly approved;
- approved content cannot be silently rewritten.

### `mrcip_ai_executions`

Provider-execution ledger. It records:

- governed Stage 11 request reference;
- provider configuration reference;
- approved prompt-version reference;
- provider/model/adapter snapshots;
- prompt/context/input fingerprints;
- provider request ID;
- response provenance;
- input/output/total token telemetry;
- latency;
- optional cost metadata without fabricated cost;
- safe provider telemetry;
- prepared/running/completed/failed/blocked/cancelled lifecycle;
- failure code/message;
- requester and timestamps.

Authenticated clients have `SELECT, INSERT` only. They cannot rewrite execution history.

### `mrcip_ai_execution_events`

Append-only gateway lifecycle evidence for:

- prepared;
- started;
- provider request;
- provider response;
- completed;
- failed;
- blocked;
- cancelled.

Authenticated users have read-only access through RLS. Gateway writes are service-role controlled.

## 5. Stage 11 integration

`mrcip_ai_responses` now supports `execution_id` provenance.

An `external_model` response:

- cannot be inserted directly by an authenticated client;
- must be created by the Stage 12 service gateway;
- must reference a running execution;
- must reference the exact provider configuration used by that execution;
- must carry a provider request ID;
- receives the provider/model snapshots from the execution;
- remains `review_required` after generation.

Citations created by the gateway may reference only frozen Stage 11 context belonging to the same request.

Human review remains the only path to `approved` response status.

## 6. Prompt governance

Prompt content is not treated as an informal application string.

A provider execution requires:

1. an active prompt template;
2. an approved immutable prompt version;
3. output type matching the Stage 11 request;
4. explicit prompt approval for protected data when the request contains protected context.

Prompt approval requires `super_admin`, `managing_director` or `legal_compliance` authority.

## 7. Provider governance

Stage 12 extends `mrcip_ai_provider_configs` with:

- `adapter_key`;
- `credential_secret_ref`;
- `connection_status`;
- connection verification timestamp/reference;
- last connection error.

The table stores **no secret value**.

`credential_secret_ref` is restricted to the `MRCIP_AI_*` namespace. The Edge Function resolves the corresponding secret at runtime.

Provider activation requires all of the following:

- credential status marked as externally configured;
- allowlisted runtime adapter;
- non-empty MRCIP AI secret reference;
- successful gateway connection verification;
- executive provider activation.

Protected-data processing requires a separately active provider permission.

If a configured Edge secret is missing, the provider is automatically demoted to:

- `status = disabled`;
- `credential_status = not_configured`;
- `connection_status = failed`;
- `protected_data_allowed = false`.

This prevents stale metadata from representing a provider as ready when the execution secret is absent.

## 8. Edge Function gateway

Deployed function:

- slug: `mrcip-ai-gateway`;
- function ID: `22f9ff32-7e77-4d85-9665-76b45ac59943`;
- version: `1`;
- status: `ACTIVE`;
- JWT verification: **enabled**;
- deployment SHA-256: `df2823d0299b0c15df90486f32cfb3aebb6ac32dc4854647f49ec895294f2ae7`;
- source mirrored at `supabase/functions/mrcip-ai-gateway/index.ts`.

Supported actions:

- `verify_provider`;
- `execute`.

The current allowlisted adapter key is `openai_responses_v1`. The external endpoint is fixed by code; callers cannot supply an arbitrary URL.

The gateway:

- requires a valid JWT;
- derives the requester from the JWT;
- uses authenticated RPCs for requester-authorised preparation;
- uses service-role-only RPCs for gateway lifecycle mutation;
- loads only approved frozen prompt/context data from the database;
- adds a fixed MRCIP gateway policy overlay;
- requires governed JSON output containing `answer`, `evidence_state`, and `citation_ranks`;
- rejects citation ranks outside frozen context;
- records safe provider request/response metadata;
- removes secret/body/output keys from stored telemetry;
- does not calculate or guess provider cost when a reliable cost source is unavailable;
- creates a Stage 11 response only after database validation;
- leaves the resulting response at `review_required`.

## 9. Gateway policy overlay

The Stage 12 gateway instructs the model to:

- use only supplied frozen MRCIP context;
- not fabricate sources, parties, specifications, prices, legal/compliance conclusions or citations;
- not disclose information outside supplied context;
- return citations only as supplied context ranks;
- perform no autonomous outreach, disclosure, negotiation, contracting, trading, score mutation, payment or Finance/Freight mutation.

Database enforcement remains authoritative even if a provider disregards instructions.

## 10. Public and service RPC boundary

Authenticated SECURITY INVOKER RPCs:

- `prepare_mrcip_ai_execution(uuid,uuid,uuid)`;
- `approve_mrcip_ai_prompt_version(uuid,boolean)`;
- `authorize_mrcip_ai_provider_verification(uuid)`.

Service-role-only SECURITY INVOKER RPCs:

- `mrcip_ai_gateway_get_provider_config(uuid,uuid)`;
- `mrcip_ai_gateway_record_provider_check(uuid,uuid,boolean,text,text,text)`;
- `mrcip_ai_gateway_start_execution(uuid,uuid)`;
- `mrcip_ai_gateway_record_provider_request(uuid,uuid)`;
- `mrcip_ai_gateway_complete_execution(...)`;
- `mrcip_ai_gateway_fail_execution(...)`.

The service-only functions are not executable by `anon` or `authenticated`.

## 11. Read models

All three Stage 12 views use `security_invoker=true`:

- `mrcip_ai_prompt_catalog_summary`;
- `mrcip_ai_execution_summary`;
- `mrcip_ai_execution_event_trace`.

Underlying table RLS remains authoritative.

## 12. RLS and Data API posture

All four new public Stage 12 tables have RLS enabled.

`anon` has no Stage 12 table privileges.

Authenticated grants are intentionally constrained:

- prompt templates: `SELECT, INSERT, UPDATE` under prompt-author role policies;
- prompt versions: `SELECT, INSERT, UPDATE`, with approval/retirement update restricted to executive/legal authority;
- executions: `SELECT, INSERT` only;
- execution events: `SELECT` only.

No authenticated direct write path can mark an external execution completed or manufacture an external-model response.

## 13. Regression testing

All functional fixtures were executed in rollback-isolated transactions.

### Main authenticated/service gateway regression — 13/13 passed

1. audited Stage 11 context frozen;
2. approved prompt version created correctly;
3. approved prompt content rewrite blocked;
4. provider activation before gateway verification blocked;
5. gateway-verified provider may be activated;
6. execution preflight snapshots/fingerprints derived by database;
7. direct authenticated `external_model` response blocked;
8. gateway start payload derives approved prompt/frozen context;
9. invalid citation rank blocked;
10. gateway completion creates external response with execution/provider provenance;
11. provider telemetry secret/output keys scrubbed;
12. Stage 11 human review remains the only approval path;
13. authenticated client execution-history update blocked.

### Missing-secret state regression — passed

A rollback-only provider was marked as having an external credential reference, then the gateway recorded `SECRET_MISSING`.

Authoritative resulting state:

- provider `disabled`;
- credential `not_configured`;
- connection `failed`;
- protected-data permission `false`;
- missing-secret audit marker retained.

Combined Stage 12 control set: **14/14 passed**.

## 14. Defects discovered and remediated

### Defect 1 — service gateway helper permission

The first rollback regression failed because a service-role gateway RPC attempted to invoke an intentionally private/revoked role helper.

Impact:

- regression transaction rolled back fully;
- no production/test residue;
- no protection bypass.

Remediation:

- `20260821054726_mrcip_stage_12d_gateway_service_authorization_fix` made gateway authorization self-contained;
- private-schema execute privileges were **not** widened.

### Defect 2 — provider readiness after missing secret

A missing secret should not leave a provider presented as integration-ready.

Remediation:

- `20260821054900_mrcip_stage_12f_provider_failure_state_hardening` automatically demotes missing-secret providers to disabled/not-configured and removes protected-data permission.

### Performance finding — execution response FK

The first performance advisor pass found the new execution→response FK lacked a covering index.

Remediation:

- `20260821055114_mrcip_stage_12g_performance_hardening` added `mrcip_ai_executions_response_cover_idx`;
- the rerun cleared the Stage 12 FK finding.

## 15. Security advisor

Final security advisor result:

**No new Stage 12-specific security finding.**

The same pre-existing platform warnings remain tracked separately:

- authenticated-callable `public.can_access_portal` SECURITY DEFINER;
- authenticated-callable `public.complete_organisation_onboarding` SECURITY DEFINER;
- authenticated-callable `public.get_my_access` SECURITY DEFINER;
- leaked-password protection disabled.

These are Auth-sensitive pre-existing controls and were intentionally not changed during Stage 12.

## 16. Performance advisor

After Stage 12g, no Stage 12 missing-FK-index finding remains.

Remaining advisor notices are:

- expected unused-index notices on new/empty tables;
- the pre-existing duplicate organisation-membership index warning.

No existing index is removed during this stage.

## 17. Production residue

After rollback tests, production counts are zero for:

- AI provider configurations;
- prompt templates;
- prompt versions;
- executions;
- execution events;
- AI requests;
- AI context items;
- AI responses;
- AI citations;
- AI reviews;
- synthetic Stage 12 counterparty fixture.

No production provider row was created.
No production API secret was configured.
No production external-model request was made.

## 18. Type generation

Supabase TypeScript database type generation succeeded after Stage 12.

The generated schema includes:

- four Stage 12 tables;
- provider-config runtime fields;
- response execution provenance;
- three Stage 12 read models;
- authenticated Stage 12 workflow RPCs;
- service gateway RPCs.

## 19. Migration byte identity

Hosted-computed Git blob SHA-1 equals the GitHub blob SHA for every Stage 12 migration:

- 12a `918392007f951c7d424e45d9cb6b723cfe55e91c`;
- 12b `0858dd8f170baf8f3aaeb37004cca412c8d6f321`;
- 12c `9b0931ce9284e2e638d007efa974423fe9d2da93`;
- 12d `9760a7450afd3ed38b7e7937a2486853b439441f`;
- 12e `a17d3b97e616b3f1bb7a943dde86aece5d85a660`;
- 12f `a549cc6a36e33571306fcc27b2a2018501a72893`;
- 12g `36fba79b0fdf77e0cf81e6e63638602670f38cb6`.

The exact hosted migration chronology must be preserved.

## 20. Existing platform regression boundary

Stage 12 does not alter or duplicate:

- quotation calculations;
- invoice calculations;
- VAT logic;
- Finance line-item arithmetic;
- Payment semantics;
- Stage 5/6 facilitator/commission/settlement controls;
- Stage 7 sampling/laboratory/certificate/inspection evidence lineage;
- Stage 8 CRM DNC/contactability/history controls;
- Stage 9 scoring formulas;
- Stage 10 reporting/watchlist/retrieval semantics;
- Stage 11 frozen evidence/citation/human review requirements except adding controlled execution provenance;
- Freight profitability calculations;
- Negotiation calculations;
- trip/vehicle/driver execution calculations;
- existing Auth/access RPC behaviour.

## 21. Current operational status

| Capability | Status |
|---|---|
| Prompt/version governance | **LIVE** |
| Execution ledger/events | **LIVE** |
| Gateway DB control plane | **LIVE** |
| Edge Function code | **DEPLOYED / ACTIVE** |
| JWT enforcement | **LIVE** |
| OpenAI Responses adapter code path | **DEPLOYED BUT DORMANT** |
| Production provider row | **NOT CONFIGURED** |
| Production provider credential secret | **NOT CONFIGURED** |
| Gateway connection verification | **AWAITING CONFIGURATION** |
| Production external-model execution | **NOT ACTIVE** |
| Human review requirement | **LIVE / MANDATORY** |
| Autonomous actions | **DISABLED / NOT AUTHORISED** |

## 22. Acceptance criteria

Stage 12 passes its current boundary because:

- external-model responses cannot be manufactured by authenticated clients;
- prompts are versioned, fingerprinted and approval-controlled;
- protected context requires both provider and prompt protected-data approval;
- provider activation requires gateway verification;
- secret values are not stored in MRCIP tables;
- only `MRCIP_AI_*` secret references are accepted;
- execution/provider/model/prompt/context fingerprints are retained;
- provider request lifecycle is auditable;
- invalid citations are rejected by the database;
- telemetry is filtered before persistence;
- response approval still requires Stage 11 human review;
- gateway service RPCs are not available to normal authenticated users;
- all four Stage 12 tables have RLS;
- `anon` has no Stage 12 table access;
- no new Stage 12 security-advisor finding remains;
- the Stage 12 performance finding was remediated;
- combined rollback regression is **14/14 passed**;
- production fixture residue is zero;
- TypeScript generation succeeds;
- all seven migration files are byte-identical to hosted history;
- no production provider or credential was fabricated.

# STAGE 12 SIGN-OFF: APPROVED AT CONTROL/GATEWAY FOUNDATION BOUNDARY

The execution gateway is deployed but remains **operationally provider-disabled** until an explicit provider configuration and approved external Edge secret are supplied and verified.

Recommended next controlled stage:

**Stage 13 — AI Evaluation, Safety Calibration & Production Provider Onboarding**

Stage 13 should establish production prompt evaluation fixtures, answer/citation quality thresholds, protected-context red-team tests, provider/model onboarding criteria, budget/rate controls and production go-live approval before any external model is treated as operational MRCIP intelligence infrastructure.
