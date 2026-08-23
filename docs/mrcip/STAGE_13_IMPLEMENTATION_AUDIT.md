# MRCIP Stage 13 Implementation Audit

**Stage:** 13 — AI Evaluation, Safety Calibration, Provider Commercial Controls & Production Onboarding  
**Audit date:** 23 August 2026  
**Status:** **SIGNED OFF — DATABASE / SECURITY / SOURCE-CONTROL PROVENANCE COMPLETE; PRODUCTION PROVIDER REMAINS DISABLED**

## 1. Scope

This audit verifies the actual Stage 13 implementation in the hosted Supabase project and the corresponding source-controlled artifacts on branch `mrcip/phase-0-audit`. It incorporates the programme-wide retrospective ACL remediation and the completed recovery of the two Stage 13 migration sources that were previously absent from GitHub.

Stage 13 is fully reconciled at the database, security and migration-provenance boundaries. This does **not** activate a production AI provider and does **not** claim browser/Admin UI regression because the connected repository still does not contain the complete frontend application source.

## 2. Authoritative hosted migration chain

| Version | Migration | Hosted Git blob SHA | GitHub source status |
| --- | --- | --- | --- |
| 20260821060725 | `mrcip_stage_13a_ai_evaluation_foundation` | `a826b4214fe3af0c7c467d36e226cb055c2ea13f` | Present; exact match verified |
| 20260821060752 | `mrcip_stage_13b_provider_commercial_and_onboarding_foundation` | `43c931898a842065361bb6b549966e6d1624b9e0` | Present; exact match verified |
| 20260821060927 | `mrcip_stage_13c_evaluation_workflow_engine` | `4bafdf0acbee619e4949bd21ab7b6eb5a49f3635` | Present; exact match verified |
| 20260821061049 | `mrcip_stage_13d_provider_onboarding_budget_and_activation_gates` | `3e986530652939cd381d1c337e548c14f50bb9eb` | Present; exact match verified |
| 20260821061129 | `mrcip_stage_13e_rls_grants_and_read_models` | `0d7e9f9dac1bf241a0ad2f0a24fc8a83bc569e4f` | Present; exact match verified |
| 20260821061339 | `mrcip_stage_13e_rls_read_models_and_drift_reconciliation` | `b7ac746901402e86face5c14070e46de190c5958` | Present; exact match verified |
| 20260821061513 | `mrcip_stage_13f_onboarding_revocation_and_refusal_hardening` | `d69f4c436a16c1c8d55b68333c48b66bee33f4e8` | Present; exact match verified |
| 20260821061623 | `mrcip_stage_13g_evaluation_gateway_payload_hardening` | `0eed99b877945d44cdfc830b9401a770e763f7f8` | Present; exact match verified |
| 20260821061636 | `mrcip_stage_13h_eval_gateway_service_rpc_grants` | `7c5bc53b9bd685eb6a6bceacebec6494856e3572` | Present; exact match verified |

### Provenance close-out

The authoritative 13c and 13d bodies were recovered directly from hosted `supabase_migrations.schema_migrations` through a short-lived authenticated export path. A one-time GitHub Actions workflow fetched the authoritative SQL and required `git hash-object` to match the hosted hashes before committing either file.

Recovery commit:

`c8395610b35a59fab1dbd23c2ac9e1d19afb5bec`

Verified recovered files:

- `supabase/migrations/20260821060927_mrcip_stage_13c_evaluation_workflow_engine.sql` → `4bafdf0acbee619e4949bd21ab7b6eb5a49f3635`
- `supabase/migrations/20260821061049_mrcip_stage_13d_provider_onboarding_budget_and_activation_gates.sql` → `3e986530652939cd381d1c337e548c14f50bb9eb`

The one-time workflow removed itself after success. The temporary privileged export RPC was dropped. The temporary Edge exporter `mrcip-stage13-export` was redeployed as a JWT-verified HTTP 410 decommissioned stub. No production database records were changed by the source-recovery process.

## 3. Implemented Stage 13 data model

Live Stage 13 objects include:

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

TypeScript database type generation succeeds after provenance cleanup and includes the Stage 13 evaluation, commercial-control, onboarding and workflow RPC surface. The temporary export RPC is absent from the live public type surface.

## 4. Controlled workflow / RPC verification

Verified Stage 13 workflow functions include evaluation-suite approval, evaluation run/attempt preparation, service-role gateway attempt lifecycle, human evaluation review/finalisation, provider-rate approval, budget-policy approval and provider-onboarding approval/revocation controls.

Security boundaries remain:

- no audited MRCIP public RPC is exposed to `anon`;
- external/gateway lifecycle mutation remains service-role controlled;
- public MRCIP workflow RPCs use invoker semantics and explicit role checks;
- the temporary provenance export RPC has been removed.

## 5. Provider/runtime state

The main `mrcip-ai-gateway` remains the controlled Stage 12/13 execution surface. The superseded `mrcip-ai-eval-gateway` remains a JWT-verified HTTP 410 decommissioned stub.

The temporary `mrcip-stage13-export` provenance exporter is also a JWT-verified HTTP 410 decommissioned stub and can no longer return migration content.

No production AI provider is activated or credentialed. No production evaluation, rate-card, budget-policy or provider-onboarding record is being represented as live merely because the control-plane schema exists.

## 6. RLS, ACL and tenant-security verification

The programme-wide retrospective audit identified a legacy default-ACL defect on 19 early Stage 1–2 MRCIP tables. That defect was remediated by:

`20260823081757_mrcip_retrospective_acl_hardening_stages_1_13`

Hosted/source Git blob SHA:

`41b1d561798ca48b1cee68db22692bce934b860e`

Authoritative post-remediation result:

- MRCIP public tables audited: **86**
- tables with `anon` privileges: **0**
- tables where `authenticated` retains `TRUNCATE`, `REFERENCES` or `TRIGGER`: **0**
- unvalidated public constraints: **0**

A final post-export cleanup sanity check again found no anonymous MRCIP table exposure and no dangerous authenticated table grants. The earlier comprehensive 86-table audit remains the programme-wide ACL source of truth.

## 7. Advisor status

The final security-advisor rerun reports only the same pre-existing platform/Auth findings:

1. `public.can_access_portal(...)` — authenticated-callable `SECURITY DEFINER`;
2. `public.complete_organisation_onboarding(...)` — authenticated-callable `SECURITY DEFINER`;
3. `public.get_my_access()` — authenticated-callable `SECURITY DEFINER`;
4. Supabase leaked-password protection disabled.

These findings pre-date Stage 13 and remain separated from MRCIP feature work because Auth changes require dedicated login/protected-route regression.

The performance advisor reports mainly unused-index informational findings on the low/empty-data implementation plus the pre-existing duplicate `organisation_memberships` index warning. No new Stage 13 provenance-related missing-FK-index defect was introduced.

## 8. Regression / residue boundary

Verified boundaries include:

- all nine Stage 13 migration source files are byte-identical to hosted migration bodies;
- no temporary provenance RPC remains;
- the temporary exporter is decommissioned;
- no Stage 11–13 AI/provider/evaluation/rate/budget/onboarding test residue was introduced by reconciliation;
- no accidental production-provider activation occurred;
- Stage 3 matching, Stage 4 disclosure protection, Stage 5–6 commission controls, Stage 7 evidence lineage, Stage 8 CRM/DNC, Stage 9 scoring, Stage 10 retrieval/reporting and Stage 11–12 AI governance remain unchanged;
- quotation/invoice/VAT, Finance, Payments, Freight, Negotiation, logistics and Auth calculation/access logic were not modified.

The repository still lacks the complete Admin frontend source, so browser/UI regression and full end-to-end Admin-page sign-off remain outside this audit.

## 9. Requirement status matrix

| Requirement | Status | Evidence / location | Issue | Action |
| --- | --- | --- | --- | --- |
| Evaluation suite/case foundation | LIVE | Hosted schema; 13a | None found | Retain |
| Evaluation run/attempt/result workflow | LIVE | 13c + hosted functions | None | Retain exact source |
| Provider commercial rates | LIVE FOUNDATION | 13b/13d | Production rates unconfigured | Configure only after approval |
| Budget controls | LIVE FOUNDATION | 13b/13d | Production budgets unconfigured | Configure only after approval |
| Production provider onboarding | LIVE GATE / PROVIDER DISABLED | 13b/13d/13f | No active provider; intentional | Preserve fail-closed activation gate |
| RLS/read models | LIVE | 13e migrations | None found | Retain |
| Refusal/revocation hardening | LIVE | 13f | None found | Retain |
| Evaluation gateway payload hardening | LIVE | 13g | None found | Retain |
| Gateway RPC service grants | LIVE | 13h | None found | Retain |
| Programme ACL least privilege | REMEDIATED / VERIFIED | 20260823081757 | Legacy defect fixed | Keep regression rule |
| Type generation | VERIFIED | Live project type generation | Full frontend type integration pending | Wire when complete app source is restored |
| Full frontend/UI | NOT VERIFIED | Complete Admin source unavailable | Cannot truthfully test browser flows | Verify when source is connected |
| Migration provenance | **VERIFIED** | Hosted history ↔ GitHub | None | Preserve exact-hash reconciliation rule |

## 10. Sign-off decision

**Database implementation:** PASS  
**RLS/ACL/security boundary:** PASS  
**Gateway service boundary:** PASS  
**Provider activation safety:** PASS — disabled/unconfigured  
**Type generation:** PASS  
**Source-control migration provenance:** PASS — **9/9 Stage 13 migrations exact**  
**Full frontend/UI regression:** NOT TESTABLE from current repository

### Overall Stage 13 status

**SIGNED OFF — DATABASE / SECURITY / SOURCE-CONTROL PROVENANCE COMPLETE; PRODUCTION PROVIDER REMAINS DISABLED.**

The Stage 13 provenance gate is closed. The programme may proceed to the next controlled implementation stage while retaining the established sequence:

**IMPLEMENT → TEST → AUDIT → REMEDIATE → SIGN OFF → PROCEED**.
