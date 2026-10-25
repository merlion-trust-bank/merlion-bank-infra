# ADR-002: Environments – staging and production in one AWS account, isolated per environment

- **Status:** Accepted
- **Date:** 2026-10-25
- **Deciders:** DevSecOps (DO1), reviewed by Solutions Architect
- **Related:** Credential hygiene (brief Phase 2.5), HC-2 Auditability, ADR-005 (OIDC)

## Context
The brief requires CI/CD to at least two environments, with production gated by approval, and
different credentials per environment so that **staging credentials cannot touch production**.
Production changes must be traceable and made only through the pipeline (HC-2).

To control cost we run **two environments: staging and production**. There is no separate dev
environment: fast feedback comes from PR checks (terraform plan, security scans, image builds).

The platform runs in a shared course AWS account (`255945442255`); creating additional AWS
accounts is not possible.

## Decision
**Environments:** `staging` (smaller sizing, synthetic data, load generator) and `production`.
**Flow:** PR checks -> merge to `main` -> auto-deploy **staging** -> smoke tests -> **manual
approval** -> deploy **production** (same image digest / same Terraform modules).

**Isolation inside the single account:**
- Every resource is prefixed `kean-` and tagged `Environment = staging | prod` (provider `default_tags`).
- Separate Terraform state key per environment (`envs/<env>/terraform.tfstate`).
- One OIDC role per environment: `kean-gha-staging`, `kean-gha-prod`. Each role may only act on
  resources tagged with its own `Environment` and its own state key; an explicit Deny blocks the
  other environment. `kean-gha-prod` is trusted only from the `production` GitHub environment,
  which requires manual approval.
- Separate VPCs per environment (`10.20.0.0/16` staging, `10.30.0.0/16` prod).

## Alternatives considered
| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Single account + tag/state/role isolation** | Works within the course account; per-environment credentials still enforced | Boundary depends on IAM policy correctness and consistent tagging; shared quotas | **Chosen** |
| Separate AWS account per environment | Strongest boundary; separate billing, quotas, CloudTrail | Not available in the course account | Rejected (not available) |
| Three environments (dev, staging, prod) | Extra sandbox | Higher cost (another EKS + RDS); PR checks already give fast feedback | Rejected |
| Single environment | Cheapest | Fails the brief (≥ 2 environments, gated prod) | Rejected |

## Consequences
**Positive**
- Meets the brief with the minimum running cost (two stacks, not three).
- Every production change is pre-tested in staging with the same artefacts.
- A compromised staging workflow cannot assume the prod role and is denied on prod-tagged resources.

**Negative / risks**
- Isolation relies on IAM conditions and naming; a policy or tagging mistake could cross
  environments. Mitigation: policies reviewed in PRs, `default_tags` on every provider,
  an `AccessDenied` test from `kean-gha-staging` against a `prod`-tagged resource, checkov (INF-13).
- No dev sandbox: experiments happen in staging, so staging may be briefly unstable.
- Shared account: quotas are shared with other users of the account.

## Evidence (to be completed)
- INF-03: trust policies for `kean-gha-staging` / `kean-gha-prod` with `repo:` and `environment:` conditions
- `AccessDenied` when `kean-gha-staging` attempts to modify a `prod`-tagged resource
