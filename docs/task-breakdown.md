# Merlion Trust Bank – Task Breakdown

Capstone: Cloud Infrastructure Engineering · Use Case A (Merlion Trust Bank) · Reference app: Google Bank of Anthos
Region: **`us-east-1`** (2 AZs: `us-east-1a`, `us-east-1b`) · Environments: **staging / prod** in one shared AWS account (prefix `kean-`) · Work tracking: **GitHub pull requests**

> **Region note.** The brief's data-residency constraint names `ap-southeast-1`. Our instructor has directed us to deploy in **`us-east-1`**, so we treat the constraint as *"all customer data, backups and logs stay in one approved region"*.
> - Region is a single Terraform variable (`var.region`). Moving to Singapore is a variable change plus a redeploy.
> - This deviation is recorded in **ADR-006** together with the instructor's approval.
> - In the architecture diagram, rename the red boundary label from "ap-southeast-1 (Singapore)" to **"us-east-1"** (DOC-02).

---

## 1. Roles

One engineer delivers the project and wears each role in turn; every ticket names the role it belongs to.

| Role | Primary ownership |
|---|---|
| **SA** – Solutions Architect | Requirements, architecture diagram, service selection, constraint mapping, cost, ADRs, audit controls |
| **DO1** – DevSecOps (foundations) | Terraform foundations: state, OIDC roles, VPC, EKS; Helm chart & secrets wiring |
| **DO2** – DevSecOps (data + delivery) | RDS, ECR, KMS, Secrets Manager, cluster add-ons, both CI/CD pipelines, security gates |
| **SRE** – Site Reliability Engineer | Self-hosted Prometheus, Loki, Grafana, Alertmanager; dashboards, SLO rules, alert routing, runbook, cost |

---

## 2. Target architecture (summary of the diagram)

| Layer | What we build |
|---|---|
| Delivery (outside AWS) | GitHub org `merlion-trust-bank` · branches `<ticket-id>-*` · PR to `main` (template + self-review) · Actions: build → SCA → image scan · staging auto on merge → smoke tests → **production manual approval** · Terraform plan shown on PR |
| Identity | GitHub OIDC → AWS STS. `kean-gha-staging` can only touch staging-tagged resources and state. `kean-gha-prod` is usable only from the `production` environment, after approval. No stored keys |
| Environments | One shared AWS account; staging and prod separated by `Environment` tag, state key and CI role. **Staging** (prod-like but smaller, same Terraform modules, auto-deploy on merge, loadgenerator, scaled down when idle) · **Prod** (same image digest promoted after approval). No dev environment: PR checks give fast feedback (ADR-002) |
| Network (prod) | VPC across 2 AZs. **Public subnets:** ALB (AWS Load Balancer Controller + ACM cert), NAT gateway. **Private subnets:** EKS. **Isolated DB subnets:** no internet route |
| Workload | 6 Bank of Anthos services built into our own images: `frontend` (2+ replicas), `userservice` (signs JWTs), `contacts`, `ledgerwriter`, `balancereader`, `transactionhistory` |
| Data | RDS PostgreSQL `accounts-db` and `ledger-db`: Multi-AZ, KMS-encrypted, automated backups, SQL over TLS |
| Platform services | ECR (immutable tags, scan on push) · Secrets Manager (DB creds, JWT key pair → pods via External Secrets/IRSA) · KMS CMKs (RDS, S3, logs, secrets) · Terraform state in S3 (versioned, encrypted) |
| Observability | **Self-hosted on EKS** in `us-east-1`, no third-party SaaS (namespace `monitoring`, `kube-prometheus-stack` + Loki Helm charts): **Loki + Promtail** (logs from all pods, chunks in S3 `us-east-1` + KMS, 365-day retention) · **Prometheus** (node, pod, app metrics on EBS; ALB metrics via **YACE** CloudWatch exporter) · **Grafana** (health, SLOs, logs for anyone outside engineering) · **Alertmanager** (SLO rules → email / Telegram) |
| Audit | CloudTrail (multi-region trail `kean-merlion-trail`) → **S3 Object Lock, governance mode, 1-year retention** (bypass + deletes denied by bucket policy). Also stores EKS audit logs and pipeline deploy records (who, what, when) |

---

## 3. Repositories

### 3.1 `merlion-bank-infra` – Terraform + architecture docs

```
merlion-bank-infra/
├── .github/
│   ├── workflows/
│   │   ├── tf-plan.yml            # PR: fmt, validate, tflint, checkov, plan per env -> PR comment
│   │   └── tf-apply.yml           # main: apply staging -> (approval) -> prod
│   ├── CODEOWNERS
│   └── pull_request_template.md
├── bootstrap/                     # per account: state bucket, lock, GitHub OIDC provider
├── modules/
│   ├── kms/                       # CMKs: rds, s3, logs, secrets
│   ├── network/                   # VPC, 2 AZ public / private / isolated-db subnets, NAT, endpoints
│   ├── eks/                       # cluster, managed node group, IRSA, control-plane + audit logs
│   ├── rds/                       # accounts-db, ledger-db
│   ├── ecr/                       # one repo per service
│   ├── secrets/                   # Secrets Manager entries (DB creds, JWT key pair)
│   ├── iam-ci/                    # kean-gha-staging, kean-gha-prod OIDC roles
│   ├── audit/                     # CloudTrail + Object Lock bucket
│   ├── addons/                    # LB Controller, External Secrets
│   └── observability/             # Loki S3 bucket + IRSA, Helm releases (kube-prometheus-stack,
│                                  #   Loki, Promtail, YACE), Grafana dashboards JSON,
│                                  #   PrometheusRules (SLOs), Alertmanager routes
├── envs/
│   ├── staging/                   # root module, staging account
│   └── prod/                      # root module, prod account
├── docs/
│   ├── architecture/              # diagram source + PNG
│   ├── adr/
│   ├── requirements.md
│   ├── service-selection.md
│   ├── constraint-compliance.md
│   ├── cost-estimate.md
│   └── task-breakdown.md          # this file
└── README.md
```

### 3.2 `merlion-bank-app` – application, deployment, operations

```
merlion-bank-app/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                 # PR: SCA, build, image scan (fail on HIGH/CRITICAL), gitleaks
│   │   └── cd.yml                 # main: push ECR -> staging -> smoke tests -> approval -> prod
│   ├── CODEOWNERS
│   └── pull_request_template.md
├── src/                           # Bank of Anthos upstream source, pinned release tag
├── deploy/
│   └── helm/bank-of-anthos/       # OUR chart (upstream manifests = reference only)
│       ├── templates/
│       ├── values-staging.yaml
│       └── values-prod.yaml
├── ops/
│   ├── slo/slo.md                 # SLIs, SLO targets, error budget
│   ├── runbooks/                  # incident runbook(s)
│   ├── queries/                   # saved LogQL / PromQL queries
│   └── demo/                      # failing-gate PR + alert trigger scripts
├── security/.trivyignore          # justified exceptions only, each with expiry
└── README.md                      # pipeline doc: branch -> PR -> staging -> prod
```

---

## 4. Check-in rules (apply to both repos)

| Rule | Setting |
|---|---|
| Branch naming | `<ticket-id>-<short-desc>`, e.g. `inf-05-network` |
| Branch protection on `main` | No direct pushes (including admins), PR required, required status checks pass, PR template completed |
| CODEOWNERS | `* @kealeee` |
| Review | Self-review against the PR template before merging; the "Reviewer" columns name the role whose view to check |
| Commit messages | `<type>(<scope>): <TICKET> <summary>`, e.g. `feat(network): INF-05 VPC module` |
| PR template | What changed · Why · Task ID · `terraform plan` / test evidence · Constraint impact (region / audit / retention / credentials) |
| GitHub Environments | `staging` (no gate, auto on merge to `main`) · `production` (**required reviewers**, only `main`) |
| Never commit | Secrets, kubeconfigs, `.terraform/`, state files, `*.tfvars` with secrets. gitleaks runs as a pre-commit hook and in CI |
| CI output hygiene | CI run logs are stored by GitHub, outside our AWS region. **No customer data and no app logs in CI output.** Smoke tests assert on status codes only |

---

## 5. Task breakdown

Branch names below use the ticket ID, e.g. `inf-05-network`.

### 5.1 `merlion-bank-infra`

| ID | Task | Owner | Branch | Key files | Depends on | Reviewer |
|---|---|---|---|---|---|---|
| INF-01 | Repo setup: branch protection, CODEOWNERS, PR template, `.gitignore`, gitleaks pre-commit, README skeleton | DO1 | `<id>-repo-setup` | `.github/*`, `README.md` | – | SA |
| INF-02 | Bootstrap: S3 state bucket (versioned, KMS, S3 lockfile), GitHub OIDC provider (reused if it exists) | DO1 | `<id>-bootstrap` | `bootstrap/` | INF-01 | SRE |
| INF-03 | OIDC roles `kean-gha-staging`, `kean-gha-prod`. Trust is pinned to `repo:merlion-trust-bank/<repo>` + environment; `kean-gha-prod` trusts only `environment:production`; each role is scoped to its own `Environment` tag and state key | DO1 | `<id>-oidc-roles` | `modules/iam-ci/` | INF-02 | SA |
| INF-04 | KMS module: CMKs for RDS, S3 (state + audit), CloudWatch Logs, Secrets Manager; key policies, rotation on | DO2 | `<id>-kms` | `modules/kms/` | INF-02 | DO1 |
| INF-05 | Network: VPC across **2 AZs (`us-east-1a`, `us-east-1b`)**. Public subnets (ALB, NAT), private subnets (EKS), **isolated DB subnets with no internet route**, VPC endpoints (ECR, S3, Secrets Manager, Logs, STS). 1 NAT in staging, 1 per AZ in prod | DO1 | `<id>-network` | `modules/network/` | INF-02 | SA |
| INF-06 | EKS: cluster in private subnets, managed node group, IRSA, control-plane logs **including `audit`** → CloudWatch | DO1 | `<id>-eks` | `modules/eks/` | INF-05 | SRE |
| INF-07 | RDS: `accounts-db` and `ledger-db` PostgreSQL in isolated DB subnets. Multi-AZ in prod, single-AZ in staging (cost). KMS encryption, automated backups, `rds.force_ssl = 1`, SG allows only EKS nodes | DO2 | `<id>-rds` | `modules/rds/` | INF-04, INF-05 | DO1 |
| INF-08 | ECR: one repo per service, **immutable tags**, scan on push, lifecycle policy. Same digest promoted staging → prod (ADR-007) | DO2 | `<id>-ecr` | `modules/ecr/` | INF-02 | DO1 |
| INF-09 | Secrets Manager: DB credentials (RDS-managed master secret) and JWT key pair, KMS-encrypted. Read access only for the External Secrets IRSA role | DO2 | `<id>-secrets` | `modules/secrets/` | INF-04, INF-07 | SRE |
| INF-10 | Audit: CloudTrail **multi-region trail** (write management events) → S3 bucket with **Object Lock governance mode, 365 days** (instructor advice), log file validation, bucket policy denying `DeleteObject*` and `s3:BypassGovernanceRetention` to everyone; prefixes for EKS audit logs and pipeline deploy records | SA | `<id>-audit-trail` | `modules/audit/` | INF-04 | DO1 |
| INF-11 | Region guardrail: `var.region = "us-east-1"` in every env root; deny-other-regions policy on CI roles; CloudTrail alarm on console write events in prod | SA | `<id>-region-guardrail` | `modules/iam-ci/`, `envs/*/providers.tf` | INF-03, INF-10 | DO1 |
| INF-12 | Env roots `envs/staging`, `envs/prod` wiring all modules. Separate state key per env; staging smaller sizes | DO1 | `<id>-env-roots` | `envs/` | INF-04…10 | DO2 |
| INF-13 | Infra pipeline. **PR:** fmt / validate / tflint / **checkov (fail on HIGH)** / `plan` per env posted as PR comment. **main:** apply staging (`kean-gha-staging`) → **manual approval** → prod (`kean-gha-prod`) | DO2 | `<id>-tf-pipeline` | `.github/workflows/tf-*.yml` | INF-03, INF-12 | DO1 |
| INF-14 | Cluster add-ons part 1: **AWS Load Balancer Controller** (IRSA), **ACM certificate** for the ALB, **External Secrets Operator** (IRSA → Secrets Manager) | DO2 | `<id>-addons-lb-eso` | `modules/addons/` | INF-06, INF-09 | SRE |
| INF-15 | Monitoring stack in namespace `monitoring` via Helm (Terraform `helm_release`, pinned chart versions): **kube-prometheus-stack** (Prometheus on EBS PV, node-exporter, kube-state-metrics, Grafana, Alertmanager), **Loki** with chunks in an **S3 bucket in `us-east-1`** (KMS, IRSA, compactor retention **365 days**), **Promtail** DaemonSet (or Grafana Alloy, Promtail's successor), **YACE** exporter (IRSA, read-only CloudWatch) for ALB 5xx / `TargetResponseTime`. Grafana exposed via ALB ingress with login, admin password from Secrets Manager | SRE | `<id>-monitoring-stack` | `modules/observability/` | INF-06, INF-04, INF-14 | DO2 |
| INF-16 | Alert routing: **Alertmanager** receivers for **email** (SMTP) and **Telegram** (native `telegram_configs`). Bot token + SMTP creds via External Secrets, never in values files. Alert templates carry metric names and thresholds only, **no customer data**. Include a `Watchdog` / dead-man's-switch alert so a down Prometheus is noticed | SRE | `<id>-alertmanager-routing` | `modules/observability/` | INF-15 | DO2 |
| INF-17 | **Grafana dashboard** ("is the system healthy right now?"): SLO status + error budget, ALB requests / 5xx / p95, pod and node CPU and memory, Loki log panel per service. Provisioned as JSON (dashboards-as-code). **PrometheusRules** for SLOs: availability burn rate, p95 > 500 ms, plus pod CrashLoop / DB unreachable | SRE | `<id>-grafana-slo-rules` | `modules/observability/` | INF-15, INF-16, APP-13 | SA |
| INF-18 | Cost controls: tagging standard, AWS Budgets alert, **staging scale-to-0 when idle** (scheduled node group scaling, RDS stop), teardown workflow | SRE | `<id>-cost-controls` | `envs/staging/`, `.github/workflows/teardown.yml` | INF-12 | SA |

### 5.2 Docs and ADRs (`merlion-bank-infra/docs`)

| ID | Task | Owner | Branch | Reviewer |
|---|---|---|---|---|
| DOC-01 | Business requirements summary: functional, non-functional, constraints, assumptions (including the region directive) | SA | `<id>-requirements` | SRE |
| DOC-02 | Architecture diagram: update the region label to `us-east-1` and keep it matching what's deployed | SA | `<id>-architecture-diagram` | DO1 |
| DOC-03 | Service selection: chosen vs alternative vs why (EKS, RDS, GitHub Actions, Prometheus/Loki/Grafana, Secrets Manager) | SA | `<id>-service-selection` | DO2 |
| DOC-04 | Constraint compliance mapping: constraint → decision → evidence (see [section 7](#7-hard-constraint-traceability)) | SA | `<id>-compliance-map` | SRE |
| DOC-05 | Monthly prod cost estimate with `us-east-1` pricing (EKS, nodes incl. monitoring stack, 2× Multi-AZ RDS, NAT, ALB, EBS for Prometheus, S3 for Loki + audit, CloudTrail, YACE CloudWatch API calls) plus staging run cost | SA | `<id>-cost-estimate` | SRE |
| DOC-06 | ADR-001 Runtime: EKS vs ECS | SA | `<id>-adr-001-runtime` | DO1 |
| DOC-07 | ADR-002 Environments: staging + production in one shared account, isolated by tag / state / role | DO1 | `<id>-adr-002-accounts` | SA |
| DOC-08 | ADR-003 Observability: **self-hosted Prometheus + Loki + Grafana + Alertmanager on EKS** (chosen) vs CloudWatch (alternative) vs Grafana Cloud (rejected: SaaS, data outside our region). Consequences: data stays in `us-east-1`, open-source skills from the labs, no per-GB ingest fees; but we operate it ourselves (single replicas, so a Watchdog alert is needed), and ALB metrics still come from CloudWatch via YACE | SRE | `<id>-adr-003-observability` | SA |
| DOC-09 | ADR-004 Audit log immutability: S3 Object Lock governance mode + denied bypass, 1 year (vs compliance mode) | SA | `<id>-adr-004-audit` | DO1 |
| DOC-10 | ADR-005 Credentials: GitHub OIDC per environment (`kean-gha-*`), no static keys | DO1 | `<id>-adr-005-oidc` | DO2 |
| DOC-11 | ADR-006 Region: `us-east-1` per instructor directive (deviation from the brief, approval recorded, region parameterised) | SA | `<id>-adr-006-region` | SRE |
| DOC-12 | ADR-007 Image promotion: build once, promote the same digest staging → prod | DO2 | `<id>-adr-007-promotion` | DO1 |

### 5.3 `merlion-bank-app`

| ID | Task | Owner | Branch | Key files | Depends on | Reviewer |
|---|---|---|---|---|---|---|
| APP-01 | Repo setup: branch protection, CODEOWNERS, PR template, GitHub Environments `staging`, `production` (prod requires reviewers) | DO2 | `<id>-repo-setup` | `.github/*` | – | DO1 |
| APP-02 | Vendor Bank of Anthos source at a pinned release tag into `src/`, recording the upstream commit in README | DO2 | `<id>-import-source` | `src/`, `README.md` | APP-01 | SA |
| APP-03 | Build images for the **6 services** (+ `loadgenerator` for staging), tagged with git SHA, pushed by digest | DO2 | `<id>-image-builds` | `ci.yml` | APP-02, INF-08 | DO1 |
| APP-04 | **Security gate 1 – SCA:** Trivy `fs` / OWASP dependency-check on Python + Java deps, **fail on HIGH/CRITICAL**, exit code not suppressed | DO2 | `<id>-sca-gate` | `ci.yml` | APP-03 | SRE |
| APP-05 | **Security gate 2 – image scan:** Trivy image `--exit-code 1 --severity HIGH,CRITICAL`, blocks push to ECR | DO2 | `<id>-image-scan-gate` | `ci.yml`, `security/.trivyignore` | APP-03 | SRE |
| APP-06 | Secret scanning: gitleaks in CI | DO1 | `<id>-gitleaks` | `ci.yml` | APP-01 | DO2 |
| APP-07 | Helm chart (our own): 6 Deployments + Services, **`frontend` ≥ 2 replicas**, probes, requests/limits, PDBs, HPA on `frontend`. Ingress `ingressClassName: alb` with ACM cert and HTTPS 443. DB endpoints → RDS over TLS | DO1 | `<id>-helm-chart` | `deploy/helm/` | APP-03, INF-07, INF-14 | DO2 |
| APP-08 | Secrets wiring: `ExternalSecret` objects for DB creds + JWT key pair → Kubernetes Secrets → pods. Nothing in values files or images | DO1 | `<id>-external-secrets` | `deploy/helm/templates/externalsecret.yaml` | APP-07, INF-09, INF-14 | SRE |
| APP-09 | Env values: `values-staging` (smaller, `loadgenerator` on), `values-prod` | DO1 | `<id>-env-values` | `deploy/helm/values-*.yaml` | APP-07 | SA |
| APP-10 | CD pipeline: merge to `main` → build + gates → push → **staging** (`kean-gha-staging`) auto → smoke tests → **manual approval** → **prod** (`kean-gha-prod`), same image digest | DO2 | `<id>-cd-pipeline` | `cd.yml` | APP-05, APP-09, INF-03 | DO1 |
| APP-11 | Deploy audit record: on every prod deploy, the pipeline writes `{actor, approver, PR, commit SHA, image digest, env, timestamp}` to the Object Lock bucket | SA | `<id>-deploy-audit` | `cd.yml` | APP-10, INF-10 | DO2 |
| APP-12 | Pipeline README: branch → PR → staging → prod; approvals; **what happens when a security gate fails**; CI-log hygiene note | DO2 | `<id>-pipeline-readme` | `README.md` | APP-10 | SA |
| APP-13 | Logging check: all 6 services log to stdout, visible in Loki per service (`{namespace="bank", app="<service>"}`). Save LogQL queries (errors per service, failed logins, ledger write failures) | SRE | `<id>-log-queries` | `ops/queries/` | APP-10, INF-15 | DO1 |
| APP-14 | SLIs and SLOs: **availability** = 1 − ALB 5xx ratio (target 99.9%); **p95 latency** = ALB `TargetResponseTime` p95 (target < 500 ms). Justification + error budget | SRE | `<id>-slo` | `ops/slo/slo.md` | APP-13 | SA |
| APP-15 | Incident runbook, e.g. "ledger-db failover / connection errors": detection (Alertmanager alert), diagnosis (Grafana dashboard, LogQL in Loki, RDS events), mitigation, escalation | SRE | `<id>-runbook` | `ops/runbooks/` | INF-17 | DO1 |
| APP-16 | Demo prep: failing-gate PR (vulnerable base image), alert trigger (scale `frontend` to 0 or break a DB secret in staging), audit trail walkthrough for the last prod deploy | SRE + DO2 | `<id>-demo-scripts` | `ops/demo/` | APP-05, INF-17, APP-11 | SA |

---

## 6. Check-in sequence (suggested 4 weeks)

| Week | `merlion-bank-infra` | `merlion-bank-app` | Docs |
|---|---|---|---|
| **1 – Foundations** | INF-01, INF-02, INF-03, INF-04, INF-05 | APP-01, APP-02 | DOC-01, DOC-06, DOC-07, DOC-11 |
| **2 – Platform** | INF-06, INF-07, INF-08, INF-09, INF-10, INF-11, INF-12, INF-13 | APP-03, APP-04, APP-05, APP-06 | DOC-03, DOC-10, DOC-12 |
| **3 – Deploy + observe** | INF-14, INF-15, INF-16 | APP-07, APP-08, APP-09, APP-10, APP-11, APP-13 | DOC-08, DOC-09 |
| **4 – Operate + harden** | INF-17, INF-18 | APP-12, APP-14, APP-15, APP-16 | DOC-02 final (matches deployed), DOC-04, DOC-05, final README |

**Critical path:** INF-02 → INF-03 → INF-05 → INF-06 → INF-14 → APP-07 → APP-10 (prod running) → INF-15 → INF-17 → live alert demo.

---

## 7. Hard-constraint traceability

| Constraint | Check-in that satisfies it | Evidence to show |
|---|---|---|
| **Data residency** (one approved region: `us-east-1` per instructor) | INF-05/07 (VPC, RDS, backups in-region, no cross-region copy), INF-11 (region pin + deny), INF-15 (self-hosted Loki/Prometheus, Loki chunks in S3 `us-east-1`, no SaaS), CI-log hygiene rule | `terraform state show` region, RDS backup config, Loki bucket region, ADR-003, ADR-006 |
| **Auditability** (every prod change traceable) | Branch protection + PR template (INF-01/APP-01), plan on PR (INF-13), prod approval (APP-10), deploy record (APP-11), CloudTrail incl. OIDC role sessions (INF-10) | Ticket → PR → Actions run → approver → deploy record → CloudTrail `AssumeRoleWithWebIdentity` event |
| **Audit log retention 1 yr, tamper-proof** | INF-10 Object Lock **governance mode** 365 days; deletes and `BypassGovernanceRetention` denied to everyone in the bucket policy | Bucket Object Lock config, a failed `DeleteObject` attempt, ADR-004 |
| No console changes to prod | INF-03 (`kean-gha-prod` only from `production` environment), INF-11 (console-write alarm) | IAM trust policy, CloudTrail query |
| Credential separation | INF-03 per-environment roles, APP-10 assumes a different role per stage | `kean-gha-staging` trying a prod action → `AccessDenied` |
| Security gates block | APP-04, APP-05, INF-13 checkov | Demo PR with a failing scan (APP-16) |

---

## 8. Definition of done for every PR

- [ ] Branch named `<ticket-id>-*`; Task ID in the PR
- [ ] Self-reviewed against the PR template (constraint boxes ticked)
- [ ] CI green (fmt/lint/checkov/plan, or build/SCA/image scan/gitleaks)
- [ ] No secrets; region only via `var.region` (`us-east-1`)
- [ ] Docs, ADRs or diagram updated if the design changed
- [ ] Infra: `terraform plan` attached to the PR, nothing applied manually
