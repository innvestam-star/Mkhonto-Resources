# MRCIP Stage 13 Implementation Audit

**Stage:** 13 — AI Evaluation, Safety Calibration, Provider Commercial Controls & Production Onboarding  
**Audit date:** 23 August 2026  
**Status:** **CONDITIONAL SIGN-OFF — LIVE DATABASE/RUNTIME COMPLETE; SOURCE-CONTROL PROVENANCE REMEDIATION OPEN**

## 1. Scope

This audit verifies the actual Stage 13 implementation in the hosted Supabase project and the corresponding source-controlled artifacts on branch `mrcip/phase-0-audit`. It also incorporates the programme-wide retrospective ACL audit completed after Stage 13.

Stage 13 is not treated as fully signed off until every hosted migration has an exact source-controlled counterpart. The live implementation may be operationally complete while governance/provenance remains incomplete.

## 2. Authoritative hosted migration chain

The hosted migration history contains the following Stage 13 migrations:

| Version | Migration | Hosted Git blob SHA | GitHub source status |
| --- | --- | --- | --- |
| 20260821060725 | `mrcip_stage_13a_ai_evaluation_foundation` | `a826b4214fe3af0c7c467d36e226cb055c2ea13f` | Present; exact match verified |
| 20260821060752 | `mrcip_stage_13b_provider_commercial_and_onboarding_foundation` | `43c931898a842065361bb6b549966e6d1624b9e0` | Present; exact match verified |
| 20260821060927 | `mrcip_stage_13c_evaluation_workflow_engine` | `4bafdf0acbee619e4949bd21ab7b6eb5a49f3635` | **Missing from GitHub; hosted body retained as authority** |
| 20260821061049 | `mrcip_stage_13d_provider_onboarding_budget_and_activation_gates` | `3e986530652939cd381d1c337e548c14f50bb9eb` | **Missing from GitHub; hosted body retained as authority** |
| 20260821061129 | `mrcip_stage_13e_rls_grants_and_read_models` | `0d7e9f9dac1bf241a0ad2f0a24fc8a83bc569e4f` | Present; exact match verified |
| 20260821061339 | `mrcip_stage_13e_rls_read_models_and_drift_reconciliation` | `b7ac746901402e86face5c14070e46de190c5958` | Present; exact match verified |
| 20260821061513 | `mrcip_stage_13f_onboarding_revocation_and_refusal_hardening` | `d69f4c436a16c1c8d55b68333c48b66bee33f4e8` | Present; exact match verified |
| 20260821061623 | `mrcip_stage_13g_evaluation_gateway_payload_hardening` | `0eed99b877945d44cdfc830b9401a770e763f7f8` | Present; exact match verified |
| 20260821061636 | `mrcip_stage_13h_eval_gateway_service_rpc_grants` | `7c5bc53b9bd685eb6a6bceacebec6494856e3572` | Present; exact match verified |

### Provenance exception

The exact hosted SQL bodies for 13c and 13d remain available in `supabase_migrations.schema_migrations`, but the corresponding SQL files were never committed to the feature branch. A reconstruction attempt for 13c produced a non-matching Git blob and was rejected; it was not attached to the branch. This is the correct control outcome: migration history must not be represented as exact when it is not byte-identical to the hosted authority.

**Required close-out action:** restore 13c and 13d only from an exact authoritative export whose Git blob hashes equal the values above.

## 3. Implemented Stage 13 data model

Live schema/type generation confirms Stage 13 objects including:

- `mrcip_ai_eval_suites`
- `mrcip_ai_eval_cases`
- `mrcip_ai_eval_runs`
- `mrcip_ai_eval_attempts`
- `mrcip_ai_eval_results`
- `mrcip_ai_provider_rates`
- `mrcip_ai_budget_policies`
- `mrcip_ai_provider_onboarding`

Read models include:

- `mrcip_ai_eval_run_summary`
- `mrcip_ai_eval_suite_summary`
- `mrcip_ai_budget_usage_summary`
- `mrcip_ai_provider_production_readiness`

TypeScript type generation succeeded against the live project after the retrospective remediation.

## 4. Controlled workflow / RPC verification

Live function inspection confirms Stage 13 workflow functions including:

- `approve_mrcip_ai_eval_suite`
- `prepare_mrcip_ai_eval_run`
- `start_mrcip_ai_eval_run`
- `prepare_mrcip_ai_eval_attempt`
- `mrcip_ai_eval_gateway_start_attempt`
- `mrcip_ai_eval_gateway_complete_attempt`
- `mrcip_ai_eval_gateway_fail_attempt`
- `review_mrcip_ai_eval_attempt`
- `finalize_mrcip_ai_eval_run`
- provider-rate approval controls
- budget-policy approval controls
- provider-onboarding preparation, approval and revocation controls

Security verification shows:

- no MRCIP public RPC is `SECURITY DEFINER`;
- no audited MRCIP RPC is executable by `anon`;
- evaluation and execution gateway service RPCs are restricted to `service_role`;
- public MRCIP workflow RPCs use invoker semantics and role checks rather than an exposed definer bypass.

## 5. Provider/runtime state

The main `mrcip-ai-gateway` remains the Stage 12/13 execution surface. Evaluation execution is consolidated through the main gateway.

The superseded `mrcip-ai-eval-gateway` is deployed as an HTTP 410 decommissioned stub with JWT verification enabled.

A temporary reconciliation helper, `mrcip-stage13-reconcile-export`, was used only during provenance investigation and has been redeployed as an HTTP 410 decommissioned stub with JWT verification enabled. It does not expose migration content.

No production AI provider has been activated. Current live counts for provider configurations, prompt/execution/evaluation/rate/budget/onboarding records were verified at zero during the retrospective audit; there is no synthetic Stage 13 test residue or accidental provider activation.

## 6. RLS, ACL and tenant-security verification

All 86 MRCIP public tables are RLS-enabled.

The retrospective audit discovered a legacy default-ACL defect on 19 early Stage 1–2 tables: `anon` still held direct privileges and `authenticated` retained dangerous privileges including `TRUNCATE`, `REFERENCES` and `TRIGGER`. Because RLS does not protect `TRUNCATE`, this was a material programme-wide security defect.

It was remediated by hosted migration:

`20260823081757_mrcip_retrospective_acl_hardening_stages_1_13`

Hosted/source Git blob SHA:

`41b1d561798ca48b1cee68db22692bce934b860e`

Post-remediation verification:

- MRCIP tables audited: **86**
- tables with `anon` privileges: **0**
- tables where `authenticated` retains `TRUNCATE`, `REFERENCES` or `TRIGGER`: **0**
- unvalidated public constraints: **0**

This remediation applies to the whole MRCIP programme, including Stage 13.

## 7. Security advisor status

The post-remediation security advisor shows no new MRCIP Stage 13 warning. The remaining warnings are pre-existing platform/Auth items and are intentionally tracked separately:

1. `public.can_access_portal(...)` is an authenticated-callable `SECURITY DEFINER` function.
2. `public.complete_organisation_onboarding(...)` is an authenticated-callable `SECURITY DEFINER` function.
3. `public.get_my_access()` is an authenticated-callable `SECURITY DEFINER` function.
4. Supabase leaked-password protection is disabled.

The Auth RPCs are not altered during unrelated MRCIP stages because they require dedicated login/protected-route regression testing.

## 8. Performance advisor status

No missing-FK-index regression was identified for Stage 13. The performance advisor currently reports mainly unused-index informational findings, expected on a low/empty-data implementation, plus the pre-existing duplicate `organisation_memberships` index warning.

No index is removed merely because it is currently unused; production workload evidence is required before pruning.

## 9. Regression / residue boundary

The current retrospective audit verified:

- no Stage 11–13 AI provider, request, execution, evaluation, rate, budget or onboarding fixture residue;
- no accidental production-provider activation;
- all public constraints validated;
- MRCIP anonymous table exposure eliminated;
- service-only gateway RPC boundaries intact;
- generated database types include the Stage 13 schema/RPC surface.

The repository does not contain the complete Admin frontend application, so this audit does **not** claim browser/UI regression or end-to-end Admin-page sign-off.

## 10. Requirement status matrix

| Requirement | Status | Evidence / location | Issue | Action |
| --- | --- | --- | --- | --- |
| Evaluation suite/case foundation | LIVE | Hosted schema; 13a | None found | Retain |
| Evaluation run/attempt/result workflow | LIVE | Hosted functions; 13c authority | GitHub 13c SQL absent | Restore exact hosted source only |
| Provider commercial rates | LIVE FOUNDATION | Hosted schema; 13b/13d | No active production rows | Configure only after approval |
| Budget controls | LIVE FOUNDATION | Hosted schema; 13b/13d | No active production rows | Configure only after approval |
| Production provider onboarding | LIVE FOUNDATION | Hosted schema/RPCs | No active provider; intentional | Preserve gated activation |
| RLS/read models | LIVE | 13e migrations | None found | Retain |
| Refusal/revocation hardening | LIVE | 13f | None found | Retain |
| Evaluation gateway payload hardening | LIVE | 13g | None found | Retain |
| Gateway RPC service grants | LIVE | 13h | None found | Retain |
| Programme ACL least privilege | REMEDIATED / VERIFIED | 20260823081757 | 19-table legacy ACL defect found | Fixed; regression rule added |
| Type generation | VERIFIED | Live project type generation | App type file not present in partial frontend source | Do not invent missing app source |
| Full frontend/UI | NOT VERIFIED | Full Admin source unavailable | Cannot truthfully test browser flows | Verify when complete frontend is connected |
| Migration provenance | **PARTIAL** | Hosted history + GitHub | 13c/13d files absent | Exact source recovery required |

## 11. Sign-off decision

**Database implementation:** PASS  
**RLS/ACL/security boundary:** PASS after remediation  
**Gateway service boundary:** PASS  
**Provider activation safety:** PASS — disabled/unconfigured  
**Type generation:** PASS  
**Source-control migration provenance:** **OPEN — 13c/13d missing**  
**Full frontend/UI regression:** NOT TESTABLE from current repository

### Overall Stage 13 status

**CONDITIONAL SIGN-OFF — LIVE DATABASE/RUNTIME COMPLETE; SOURCE-CONTROL PROVENANCE REMEDIATION OPEN.**

Stage 14 must not be treated as formally started until the Stage 13 migration provenance exception is closed or explicitly accepted as a documented governance exception by an authorised maintainer. The preferred outcome remains exact recovery of the two missing migration files.