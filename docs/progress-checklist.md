# Merlion Trust Bank – Solo Build Checklist

Individual run of every ticket in [task-breakdown.md](task-breakdown.md), in **execution order** (dependencies first).
Repos: `merlion-trust-bank/merlion-bank-infra` · `merlion-trust-bank/merlion-bank-app` · AWS: course account (`students/ce13/kealeee`), `us-east-1`

**Progress: 1 / 46 · Current ticket → INF-02 (bootstrap)**

---

## Solo adaptations

| Team plan | Solo version |
|---|---|
| 4 roles | You play every role |
| 3 AWS accounts | 1 shared course account; environments separated by **state key + `kean-` name prefix + per-env IAM role** |
| Staging environment | Optional: build `dev` and `prod` first, add `staging` only if budget and time allow |
| DynamoDB state lock | S3 native lockfile (`use_lockfile = true`, Terraform ≥ 1.10) |
| Teammate approval | Self-merge (required approvals = 0 in the individual repo only) |
| Org-wide CloudTrail | If the student role can't create trails, use a `kean-` trail on the account, or document the instructor's trail as the evidence |
| All infra | **Terraform only, checked in.** CLI for read-only checks |

## Every ticket's check-in routine

- [ ] `git checkout main && git pull && git checkout -b <ticket-id>-<desc>`
- [ ] Write code / docs
- [ ] `terraform fmt -recursive && terraform validate` (infra tickets)
- [ ] `terraform plan` → read it → `apply` (only where the ticket says)
- [ ] Commit (pre-commit + gitleaks pass) → push → PR using the template, with evidence (plan summary / screenshot)
- [ ] Merge → delete branch → `git checkout main && git pull`
- [ ] Tick the ticket below

**End of every session:** destroy anything billable that you don't need tomorrow (EKS, NAT, RDS). The state bucket and ECR can stay.

---

## Phase 1 – Foundations (no hourly cost yet)

| ✓ | Ticket | Repo | What you do (essence) | Done when |
|---|---|---|---|---|
| [x] | **INF-01** Repo setup | infra | `.gitignore`, CODEOWNERS, PR template, pre-commit + gitleaks, folder skeleton, README | PR merged; gitleaks blocks a fake secret · ✅ PR #2 merged (`f47666a`) |
| [ ] | **INF-02** Bootstrap | infra | Terraform: S3 state bucket (versioned, KMS, TLS-only), GitHub OIDC provider (create or reuse) | `apply` succeeds; bucket + OIDC ARN in outputs |
| [ ] | **DOC-01** Requirements | infra | Functional / non-functional requirements, constraints, assumptions (incl. region directive, solo adaptations) | `docs/requirements.md` merged |
| [ ] | **DOC-11** ADR-006 Region | infra | Why `us-east-1` instead of Singapore; region is a single variable | `docs/adr/006-region.md` merged |
| [ ] | **DOC-06** ADR-001 Runtime | infra | EKS vs ECS: decision + consequences | ADR merged |
| [ ] | **DOC-07** ADR-002 Accounts | infra | Team: 3 accounts. Solo: 1 account, separation by state / role / prefix; trade-offs | ADR merged |
| [ ] | **INF-03** OIDC roles | infra | Terraform `modules/iam-ci`: `gha-dev`, `gha-prod` roles trusting only your repo + GitHub environment; least-privilege policies | Roles exist; trust policy shows `repo:` and `environment:` conditions |
| [ ] | **DOC-10** ADR-005 OIDC | infra | Short-lived creds, no static keys | ADR merged |
| [ ] | **INF-04** KMS | infra | Terraform `modules/kms`: CMKs for RDS, S3, logs, secrets, rotation on | Keys + aliases `alias/kean-*` |
| [ ] | **INF-05** Network | infra | Terraform `modules/network`: VPC, 2 AZs, public / private / isolated-DB subnets, NAT, VPC endpoints | `plan` clean; `apply` only when EKS is next (NAT costs hourly) |

## Phase 2 – Platform

| ✓ | Ticket | Repo | What you do (essence) | Done when |
|---|---|---|---|---|
| [ ] | **INF-10** Audit | infra | Terraform `modules/audit`: S3 Object Lock bucket (compliance, 365 d) + CloudTrail | Bucket shows Object Lock; trail logging |
| [ ] | **DOC-09** ADR-004 Audit | infra | Why compliance mode; cost note (same as governance) | ADR merged |
| [ ] | **INF-11** Region guardrail | infra | `var.region` everywhere; deny-other-regions policy on CI roles | Policy attached; `plan` shows it |
| [ ] | **INF-06** EKS | infra | Terraform `modules/eks`: cluster, managed node group (small), IRSA, control-plane audit logs | `kubectl get nodes` Ready |
| [ ] | **INF-07** RDS | infra | Terraform `modules/rds`: `accounts-db`, `ledger-db` in isolated subnets, KMS, backups, `force_ssl`; single-AZ in dev | Both DBs available, not publicly accessible |
| [ ] | **INF-08** ECR | infra | Terraform `modules/ecr`: one repo per service, immutable, scan on push | 7 repos `kean-*` |
| [ ] | **DOC-12** ADR-007 Promotion | infra | Build once, promote the same digest | ADR merged |
| [ ] | **INF-09** Secrets | infra | Terraform `modules/secrets`: DB creds (RDS-managed) + JWT key pair in Secrets Manager | Secrets exist, KMS-encrypted |
| [ ] | **INF-12** Env roots | infra | `envs/dev` (+ `envs/prod`) wiring modules, S3 backend with `use_lockfile` | `terraform plan` per env from the remote backend |
| [ ] | **INF-13** Infra pipeline | infra | GitHub Actions: PR → fmt / validate / tflint / checkov / plan comment; main → apply dev → approval → prod (OIDC) | A PR shows a plan comment; a failing checkov blocks it |

## Phase 3 – Application delivery

| ✓ | Ticket | Repo | What you do (essence) | Done when |
|---|---|---|---|---|
| [ ] | **APP-01** Repo setup | app | Same guardrails as INF-01 + GitHub Environments `dev`, `production` (reviewer = you) | Environments visible in Settings |
| [ ] | **APP-02** Import source | app | Vendor Bank of Anthos at a pinned tag into `src/` | Upstream tag recorded in README |
| [ ] | **APP-03** Image builds | app | Actions: build 6 services (+ loadgenerator), tag = git SHA | Images built in CI |
| [ ] | **APP-04** SCA gate | app | Trivy fs / dependency scan, fail on HIGH/CRITICAL | A vulnerable dependency fails the job |
| [ ] | **APP-05** Image scan gate | app | Trivy image scan before push to ECR | A vulnerable base image blocks the push |
| [ ] | **APP-06** gitleaks in CI | app | Secret scan job | Job green; a fake secret fails it |
| [ ] | **INF-14** LB Controller + ESO | infra | Terraform Helm releases: AWS Load Balancer Controller, ACM cert, External Secrets (IRSA) | Controllers running |
| [ ] | **APP-07** Helm chart | app | Your own chart: 6 Deployments/Services, probes, limits, PDB, HPA, ALB ingress | `helm template` renders; lint passes |
| [ ] | **APP-08** ExternalSecrets | app | DB creds + JWT keys from Secrets Manager → pods | Pods start with no secrets in values |
| [ ] | **APP-09** Env values | app | `values-dev.yaml`, `values-prod.yaml` | Diff between envs is only sizing / hosts |
| [ ] | **APP-10** CD pipeline | app | main → ECR → deploy dev → smoke test → **approval** → prod (OIDC per env) | App reachable via ALB HTTPS |
| [ ] | **APP-11** Deploy audit record | app | Pipeline writes who / what / when / digest to the Object Lock bucket | A JSON record exists per prod deploy |
| [ ] | **APP-12** Pipeline README | app | Flow, approvals, failed-gate handling, CI-log hygiene | README merged |
| [ ] | **DOC-03** Service selection | infra | Chosen vs alternative vs why, for each major component | Doc merged |

## Phase 4 – Operate (SRE)

| ✓ | Ticket | Repo | What you do (essence) | Done when |
|---|---|---|---|---|
| [ ] | **INF-15** Monitoring stack | infra | Terraform Helm: kube-prometheus-stack, Loki (S3, 365 d), Promtail, YACE; Grafana with login | Grafana shows Loki + Prometheus data |
| [ ] | **DOC-08** ADR-003 Observability | infra | Self-hosted vs CloudWatch vs Grafana Cloud | ADR merged |
| [ ] | **INF-16** Alert routing | infra | Alertmanager → email + Telegram; Watchdog alert | Test alert arrives |
| [ ] | **APP-13** Log queries | app | All 6 services visible in Loki; saved LogQL queries | Queries in `ops/queries/` |
| [ ] | **APP-14** SLIs / SLOs | app | Availability 99.9%, p95 < 500 ms, error budget | `ops/slo/slo.md` merged |
| [ ] | **INF-17** Dashboard + SLO rules | infra | Grafana dashboard JSON + PrometheusRules | Dashboard answers "healthy right now?" |
| [ ] | **APP-15** Runbook | app | Ledger-db failure: detect → diagnose → mitigate → escalate | Runbook merged |
| [ ] | **INF-18** Cost controls | infra | Tags, AWS Budget, dev scale-down, teardown workflow | Teardown workflow destroys dev |
| [ ] | **APP-16** Demo scripts | app | Failing-gate PR, alert trigger, audit-trail walkthrough | Rehearsed once end-to-end |

## Phase 5 – Close-out

| ✓ | Ticket | Repo | What you do (essence) | Done when |
|---|---|---|---|---|
| [ ] | **DOC-02** Diagram final | infra | Make the diagram match what's actually deployed | PNG + SVG updated |
| [ ] | **DOC-04** Compliance mapping | infra | Constraint → decision → evidence (links, screenshots) | Doc merged |
| [ ] | **DOC-05** Cost estimate | infra | `us-east-1` monthly prod cost + what you actually spent | Doc merged |
| [ ] | Final README | both | Architecture, setup, pipeline, operations | READMEs merged |
| [ ] | **Teardown** | infra | `terraform destroy` all envs (keep the bootstrap bucket if needed) | Billing shows no running EKS / NAT / RDS |

---

**Totals:** 18 INF + 16 APP + 12 DOC = **46 tickets**
