# bootstrap (us-east-1)

Applied once from a laptop, because the pipeline depends on it:
- S3 bucket for Terraform remote state: versioned, KMS-encrypted, TLS-only, public access blocked.
  Locking via S3 lockfiles (`use_lockfile = true`, Terraform >= 1.10), so no DynamoDB table.
- GitHub Actions OIDC provider: already exists in the shared account, so it is looked up and reused.

Bootstrap state is local and git-ignored. All other stacks use the remote state bucket.

    terraform init
    terraform plan -out=bootstrap.tfplan
    terraform apply bootstrap.tfplan
