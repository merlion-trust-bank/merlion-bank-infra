# ADR-002: Environments – staging and production, isolated per environment

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

The individual build runs in a shared course AWS account (`255945442255`) where we cannot create
new accounts; the team build can use separate accounts.

## Decision
**Environments:** `staging` (prod-like sizing, synthetic data, load generator) and `production`.
**Flow:** PR checks -> merge to `main` -> auto-deploy **staging** -> smoke tests -> **manual
approval** -> deploy **production** (same image digest / same Terraform modules).

**Team build (target design): one AWS account per environment** – staging and prod.
- OIDC roles `gha-staging` (staging account) and `gha-prod` (prod account).
- `gha-prod` is trusted only from the GitHub `production` environment, after manual approval.
- Separate Terraform state per account; CloudTrail in both accounts to one Object Lock bucket.

**Individual build (this repo): one shared account, isolation by convention + IAM**
- Every resource is prefixed `kean-` and tagged `Environment = staging | prod`.
- Separate Terraform state key per environment (`envs/<env>/terraform.tfstate`).
- One OIDC role per environment; each role may only act on resources tagged with its own
  `Environment` and its own state key. `gha-prod` is trusted only from the `production`
  GitHub environment.

## Alternatives considered
| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Separate accounts (staging, prod)** | Hard boundary: a compromised staging role cannot reach prod; separate billing, quotas, CloudTrail | Needs multiple accounts; more bootstrap | **Chosen for team** |
| **Single account + tag-based IAM** | Works without new accounts | Boundary depends on IAM policy correctness; shared quotas | **Individual build only** (account constraint) |
| Three environments (dev, staging, prod) | Extra isolated sandbox | Higher cost (another EKS + RDS); PR checks already give fast feedback | Rejected |
| Single environment | Cheapest | Fails the brief (≥ 2 environments, gated prod) | Rejected |

## Consequences
**Positive**
- Meets the brief with the minimum running cost (two stacks, not three).
- Every production change is pre-tested in staging with the same artefacts.
- Team design: compromise of the staging pipeline cannot modify production (`AccessDenied` test).

**Negative / risks**
- No dev sandbox: experiments happen in staging, so staging may be briefly unstable.
  Mitigation: PR checks (plan, scans) before merge; staging is not customer-facing.
- Individual build: isolation relies on IAM conditions and naming. Mitigation: policies reviewed
  in PRs, `AccessDenied` test from `gha-staging` against a `prod`-tagged resource, checkov (INF-13).

## Evidence (to be completed)
- INF-03: trust policies for `gha-staging` / `gha-prod` with `repo:` and `environment:` conditions
- `AccessDenied` when `gha-staging` attempts to modify a `prod`-tagged resource
