# merlion-bank-infra

Infrastructure as Code (Terraform) for the Merlion Trust Bank capstone: Bank of Anthos on AWS EKS.

- Region: `us-east-1` (2 AZs)
- Tooling: Terraform, GitHub Actions (OIDC), Helm
- Docs: [task breakdown](docs/task-breakdown.md) · [architecture](docs/architecture/)

## Layout
| Path | Purpose |
|---|---|
| `bootstrap/` | Remote state bucket + GitHub OIDC provider (applied once) |
| `modules/` | Reusable Terraform modules |
| `envs/{dev,staging,prod}` | One root module per environment |
| `docs/` | Requirements, ADRs, diagrams |

## Contributing
Branch -> PR (template) -> checks -> merge. Secret scanning runs locally via pre-commit (gitleaks).
