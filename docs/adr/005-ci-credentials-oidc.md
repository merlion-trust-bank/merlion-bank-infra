# ADR-005: CI/CD credentials – GitHub OIDC, short-lived, per environment

- **Status:** Accepted
- **Date:** 2026-10-25
- **Deciders:** DevSecOps (DO1), reviewed by Solutions Architect
- **Related:** Brief Phase 2.5 credential hygiene, ADR-002 (environments), INF-03 (`modules/iam-ci`)

## Context
Pipelines need AWS access to run Terraform and deploy to EKS. The brief prohibits long-lived cloud
keys in the CI platform where short-lived credentials are supported, requires different
credentials per environment, and requires that staging credentials cannot touch production.

## Decision
- GitHub Actions authenticates with **OIDC**: the workflow presents a signed token to AWS STS and
  receives **temporary credentials (≤ 1 hour)**. No AWS access keys are stored in GitHub.
- One IAM role per environment: **`kean-gha-staging`** and **`kean-gha-prod`**
  (team build: `gha-staging` / `gha-prod` in separate accounts).
- **Trust policy** (who): `aud = sts.amazonaws.com` and `sub` restricted to our repos *and* the
  matching GitHub environment, e.g. `repo:merlion-trust-bank/merlion-bank-infra:environment:production`.
  The `production` environment requires a manual approval, so the prod role is only reachable after approval.
- **Permissions** (what):
  - `PowerUserAccess` for infrastructure services (no IAM / Organizations).
  - IAM only on resources named `kean-<env>-*` (EKS, node and IRSA roles).
  - Terraform state only under `envs/<env>/`.
  - **Explicit Deny** on any resource tagged `Environment=<other env>`, and on the other env's / bootstrap state.
- Roles and the OIDC provider are created by `bootstrap/` (applied once from a laptop).

## Alternatives considered
| Option | Why not chosen |
|---|---|
| IAM user access keys stored as GitHub secrets | Long-lived, leakable, hard to rotate; prohibited by the brief where OIDC is available |
| One CI role for all environments | Staging pipeline could change production; fails credential separation |
| Fully least-privilege hand-written policies | Ideal, but slow to get right for EKS/RDS/VPC; planned hardening after the platform stabilises |

## Consequences
**Positive**
- Nothing secret to leak from GitHub: the role ARN is not a secret.
- Every assumption is logged in CloudTrail (`AssumeRoleWithWebIdentity`) with the repo and environment, which feeds auditability (HC-2).
- A compromised staging workflow cannot assume the prod role and is denied on prod-tagged resources.

**Negative / risks**
- `PowerUserAccess` is broad. In the single shared account, separation relies on the Deny
  statements and consistent `Environment` tags. Mitigation: tagging via provider `default_tags`,
  checkov in CI, and an `AccessDenied` test. In the team build, separate accounts are the boundary.
- Resources that don't support tags aren't covered by the tag-based Deny. Mitigation: name
  prefixes, and IAM limited to `kean-<env>-*`.

## Evidence
- `modules/iam-ci/main.tf`: trust and permission policies
- `aws iam get-role --role-name kean-gha-prod` → trust condition lists only `environment:production`
- (INF-13) GitHub repo Settings → Secrets: no AWS keys; workflow uses `aws-actions/configure-aws-credentials` with `role-to-assume`
