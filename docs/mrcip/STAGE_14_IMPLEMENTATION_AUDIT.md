# MRCIP Stage 14 Implementation Audit

**Stage:** 14 — Governed AI Release, Pilot/Production Runtime Control & Circuit Breakers  
**Audit date:** 23 August 2026  
**Status:** **SIGNED OFF — GOVERNED RELEASE / RUNTIME CONTROL FOUNDATION COMPLETE; PRODUCTION PROVIDER REMAINS DISABLED**

## 1. Scope

This audit verifies the actual Stage 14 implementation in the hosted **Mkhonto Resources Hub** Supabase project and the corresponding source-controlled artifacts on branch `mrcip/phase-0-audit`.

Stage 14 establishes the governed release/runtime control plane that sits above the Stage 12–13 AI execution, evaluation, provider-onboarding, rate and budget controls. It does **not** activate a production provider, does **not** authorise autonomous business action, and does **not** claim full browser/Admin UI regression because the connected repository still does not contain the complete frontend application source.

The governing sequence remains:

**IMPLEMENT → TEST → AUDIT → REMEDIATE → SIGN OFF → PROCEED**

## 2. Authoritative Stage 14 migration chain

| Version | Migration | GitHub blob SHA | Source-control status |
| --- | --- | --- | --- |
| 20260823121520 | `mrcip_stage_14a_release_runtime_foundation` | `adc6e2450aabf3b24b48e698161dc3919435e418` | Present |
| 20260823121824 | `mrcip_stage_14b_release_workflow_controls` | `b0f5abbfee1ac297a62f79b30e07a2e50a1f4869` | Present |
| 20260823122140 | `mrcip_stage_14c_runtime_gate_and_circuit_breakers` | `cd681c2146cc9717a64751ea1bbe045c30e940ba` | Present |
| 20260823122438 | `mrcip_stage_14d_rls_grants_and_read_models` | `a3f5ead66ae4d1d4a75fb66f82f09463cb00f333` | Present |
| 20260823123311 | `mrcip_stage_14e_gateway_completion_context_hardening` | `ecd14282bad6d88c9ff489ed8dda6bdf434fbf0b` | Present |
| 20260823124908 | `mrcip_stage_14f_control_write_token_hardening` | `17f8ad0f60e66dd351d0fa99eb8bc6b42779564e` | Present |
| 20260823130516 | `mrcip_stage_14g_statement_scoped_control_tokens` | `a3ad57eca044a3060cecaaba830ccd4d959625bc` | Present |
| 20260823212918 | `mrcip_stage_14h_fk_performance_hardening` | `afa1546c5f29d736415f0d0b835622b1af34c45b` | Present; audit remediation |

The accidental `20260823125820_noop_probe` entry contained only `select 1;`, made no schema or business-data change, and was removed from the authoritative hosted migration history. It is therefore not part of the Stage 14 migration chain.

## 3. Implemented Stage 14 data model

Stage 14 introduces the following governed control-plane tables:

- `mrcip_ai_release_plans`
- `mrcip_ai_runtime_controls`
- `mrcip_ai_execution_release_links`
- `mrcip_ai_runtime_events`

Read models include:

- `mrcip_ai_release_readiness`
- `mrcip_ai_runtime_status`

The release plan records the evaluated onboarding/prompt/provider scope, pilot/production mode, protected-data allowance, permitted role keys, pilot execution limits, protected execution limits, minimum pilot evidence, failure-rate threshold and human-review requirement.

The runtime control is the authoritative provider-level switch for `disabled`, `pilot`, `production` and paused/stopped states, including `emergency_stop` and the active release-plan reference.

Every governed execution can be linked immutably to the release plan and runtime state under which it was authorised.

## 4. Release and runtime workflow

Verified Stage 14 public workflow controls include:

- `prepare_mrcip_ai_release_plan(...)`
- `approve_mrcip_ai_release_plan(...)`
- `activate_mrcip_ai_release_plan(...)`
- `pause_mrcip_ai_runtime(...)`
- `stop_mrcip_ai_runtime(...)`
- `revoke_mrcip_ai_release_plan(...)`

The controlled progression is:

**production-approved Stage 13 onboarding → draft release → approval → pilot activation → pilot evidence / human review → production release revision → production approval → production activation**

Critical gates verified:

- no active approved release = fail closed;
- runtime state must match release scope;
- protected execution is blocked unless the release explicitly permits protected data and the requester role is allowed;
- pilot execution and protected-execution limits are enforced;
- production promotion requires the configured completed-execution evidence, failure-rate threshold and mandatory human review;
- revoked/retired releases cannot be silently reactivated;
- emergency stop blocks new execution;
- budget/protection failures can automatically pause runtime.

## 5. Gateway integration

The deployed `mrcip-ai-gateway` is **version 3**, **ACTIVE**, and requires JWT verification.

Stage 14 start-time enforcement is applied before any provider request is emitted. If the execution is prepared but the release/runtime state changes before provider start, the gateway now converts that start rejection into an auditable terminal execution:

- status: `blocked`
- failure code: `STAGE14_START_REJECTED`

This closes the prepare→pause/stop/revoke→start race without leaving a prepared execution stranded and without sending a provider request.

No real provider invocation was required or made during the Stage 14 sign-off regression.

## 6. Direct-DML and write-boundary hardening

The release/runtime control plane may not be mutated by arbitrary direct DML.

Stage 14f introduced internal write tokens. Audit testing then identified that a transaction-local token could remain reusable after a legitimate workflow mutation. Stage 14g remediated this with a statement-scoped guard/reset pattern:

- the token remains valid across all trigger phases of the one authorised SQL statement, including UPSERT conflict handling;
- an `AFTER ... FOR EACH STATEMENT` reset disables the token after that statement completes;
- a later direct INSERT/UPDATE in the same transaction cannot replay the token.

Verified direct-DML failures include:

- release-plan direct mutation → `Use controlled release-plan workflow RPCs`
- runtime-control direct mutation → `Use controlled AI runtime transition RPCs`
- runtime-event direct insertion → `Runtime events may only be written by controlled workflows`

Runtime events remain append-only controlled audit records.

## 7. Final rollback regression — 14/14 PASS

The final Stage 14 regression was executed transactionally and rolled back. No provider call was made.

| Assertion | Result |
| --- | --- |
| Fail closed without an active release | PASS |
| Pilot release activates with emergency stop cleared | PASS |
| Direct release-plan DML is blocked | PASS |
| Direct runtime-control DML is blocked | PASS |
| Direct runtime-event DML is blocked | PASS |
| Protected execution requires release approval | PASS |
| Execution is linked to the pilot release | PASS |
| Pilot completed-execution evidence is counted | PASS |
| Production promotion requires human review | PASS |
| Production promotes after required review/evidence | PASS |
| Emergency stop blocks new execution | PASS |
| Start rejection is cleaned up as `blocked / STAGE14_START_REJECTED` | PASS |
| Stage 13 budget breach automatically pauses Stage 14 runtime | PASS |
| RLS hides control records from an unassigned user | PASS |

**Final regression result: 14/14 PASS.**

## 8. RLS, grants and tenant isolation

All Stage 14 control tables have RLS enabled.

Final grant review confirmed:

- no `anon` privilege on the Stage 14 control tables;
- `authenticated` has no `TRUNCATE`, `REFERENCES` or `TRIGGER` privilege on those tables;
- workflow tables retain only the CRUD/read surface required by the controlled RLS/RPC model;
- service-only/private enforcement functions are not exposed to anonymous or normal authenticated execution;
- unauthorized tenant/user visibility returned zero rows in the rollback regression.

## 9. Security advisor status

The final Supabase Security Advisor rerun reports **no new Stage 14-specific finding**.

The only warnings remain the same pre-existing platform/Auth items:

1. `public.can_access_portal(...)` — authenticated-callable `SECURITY DEFINER`;
2. `public.complete_organisation_onboarding(...)` — authenticated-callable `SECURITY DEFINER`;
3. `public.get_my_access()` — authenticated-callable `SECURITY DEFINER`;
4. leaked-password protection disabled.

These are deliberately not changed inside Stage 14 because Auth remediation requires a separately scoped login/protected-route regression.

## 10. Performance advisor and remediation

The initial final-audit Performance Advisor pass identified eight Stage 14 `unindexed_foreign_keys` informational findings on release/runtime audit relationships.

They were remediated by:

`20260823212918_mrcip_stage_14h_fk_performance_hardening.sql`

The post-remediation advisor rerun confirms those eight Stage 14 missing-FK-index findings are cleared.

Remaining advisor output consists primarily of expected `unused_index` information on new/empty structures plus the pre-existing duplicate `organisation_memberships` index warning. That pre-existing index issue is outside Stage 14 and is not removed without workload/regression evidence.

## 11. Type-generation verification

Supabase TypeScript database type generation succeeds after Stage 14h and includes the Stage 14 tables, views and public release/runtime workflow RPC surface.

A generated application type file is not fabricated where the connected partial repository does not contain the corresponding full application source location.

## 12. Regression residue and protected existing modules

Post-rollback residue checks confirmed zero Stage 14 fixture rows for:

- provider configurations;
- release plans;
- runtime controls;
- execution-release links;
- runtime events;
- Stage 14 fixture requests/executions.

Stage 14 did not redefine or modify:

- quotation/invoice/VAT arithmetic;
- Finance line-item or payment semantics;
- Freight profitability calculations;
- Negotiation logic;
- logistics/trip execution logic;
- existing Auth/protected-route functions.

The complete Admin frontend source is still not present in the connected repository. Full browser/UI regression therefore remains unclaimed.

## 13. Requirement status matrix

| Requirement | Status | Evidence | Issue / boundary | Action |
| --- | --- | --- | --- | --- |
| Release-plan foundation | LIVE | 14a/14b | No production release configured | Retain controlled workflow |
| Pilot activation gate | LIVE | 14b/14c + regression | None | Retain |
| Production-promotion gate | LIVE | 14b/14c + human-review regression | Requires real production approval before go-live | Retain fail-closed policy |
| Protected-data release scope | LIVE / PROTECTED | 14a–14d + regression | No protected production release configured | Retain server-side enforcement |
| Runtime emergency stop | LIVE | 14c + regression | None | Retain |
| Budget/protection circuit breakers | LIVE | 14c + regression | Depends on Stage 13 governed evidence | Retain |
| Execution→release provenance | LIVE | 14a/14c | None | Retain immutable linkage |
| Gateway start rejection cleanup | LIVE | gateway v3 + regression | None | Retain |
| Direct control-table DML protection | LIVE / REMEDIATED | 14f/14g + regression | Token replay defect fixed | Retain statement-scoped reset |
| RLS/grants/read models | LIVE | 14d | None found | Retain |
| FK performance coverage | REMEDIATED / VERIFIED | 14h + advisor rerun | Eight audit findings fixed | Retain indexes |
| Type generation | VERIFIED | Live project type generation | Full app wiring pending | Wire only when full source is restored |
| Full frontend/UI | NOT VERIFIED | Complete Admin source unavailable | Cannot truthfully test browser flows | Verify after source restoration |
| Production provider/model | DISABLED / UNCONFIGURED | Hosted runtime state and no audit provider call | Intentional | Separate explicit go-live decision required |

## 14. Sign-off decision

**Database implementation:** PASS  
**RLS / tenant security:** PASS  
**Controlled release workflow:** PASS  
**Pilot → production promotion controls:** PASS  
**Protected-data release gate:** PASS  
**Emergency stop / circuit breakers:** PASS  
**Gateway start-time enforcement:** PASS  
**Direct-DML protection:** PASS after Stage 14g remediation  
**Performance advisor:** PASS after Stage 14h remediation  
**Type generation:** PASS  
**Rollback regression:** PASS — **14/14**  
**Zero-residue verification:** PASS  
**Full frontend/UI regression:** NOT TESTABLE from current repository  
**Production provider go-live:** NOT AUTHORISED / REMAINS DISABLED

### Overall Stage 14 status

**SIGNED OFF — GOVERNED RELEASE / RUNTIME CONTROL FOUNDATION COMPLETE; PRODUCTION PROVIDER REMAINS DISABLED.**

Stage 14 closes the release/runtime control-plane gate without authorising live provider execution. The programme may proceed to the next controlled implementation stage while preserving the same implementation discipline and the established Finance/Freight/Auth protection boundaries.
