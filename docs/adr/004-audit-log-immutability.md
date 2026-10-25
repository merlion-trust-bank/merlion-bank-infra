# ADR-004: Audit log immutability – S3 Object Lock (governance mode, bypass denied), 365 days

- **Status:** Accepted
- **Date:** 2026-10-25
- **Deciders:** Solutions Architect (on instructor advice)
- **Related:** HC-2 Auditability, HC-3 Audit log retention (docs/requirements.md); INF-10 (`modules/audit`)

## Context
HC-3 requires pipeline and infrastructure audit logs to be retained for at least one year and
protected from tampering **by the engineering team itself**. HC-2 requires every production change
to be traceable (who, what, when, through which pipeline).

S3 Object Lock offers two modes:
- **Compliance:** no one, including the root user, can delete or shorten retention until it
  expires. Irreversible once objects are written; the bucket cannot be removed for a year.
- **Governance:** objects are protected, but principals with `s3:BypassGovernanceRetention` can
  remove them early.

Our instructor advised governance mode to avoid irreversible commitments in the course account.

## Decision
- CloudTrail trail `kean-merlion-trail` (multi-region, write management events, log file
  validation) delivers to the bucket `kean-merlion-audit-<account>` in us-east-1.
- The bucket has **Object Lock enabled**, default retention **GOVERNANCE, 365 days**, versioning on,
  SSE-KMS with a dedicated key (`alias/kean-audit`), public access blocked, TLS-only.
- The bucket policy **denies `s3:DeleteObject`, `s3:DeleteObjectVersion` and
  `s3:BypassGovernanceRetention` to every principal**, so governance retention cannot be bypassed
  without first changing the bucket policy.
- Changing the bucket policy is itself recorded by CloudTrail, so any weakening is visible.
- After 30 days, objects transition to S3 Glacier Instant Retrieval (lower cost, still instantly readable).
- The same bucket holds pipeline deploy records (APP-11) and EKS audit logs.

## Alternatives considered
| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Governance mode + bypass denied** | Tamper-resistant in practice; reversible by an auditable policy change; same cost as compliance | An administrator could first remove the Deny statement (visible in CloudTrail) | **Chosen** (instructor advice) |
| Compliance mode | Strongest guarantee: not even root can delete | Irreversible; locks the bucket for a year | Rejected |
| Versioning + MFA delete only | Simple | MFA delete needs root credentials; deletes still possible | Rejected |
| CloudWatch Logs only | Easy querying | Retention can be shortened by anyone with logs permissions | Rejected |

## Consequences
**Positive**
- Meets HC-3: logs are retained for 365 days and cannot be deleted or overwritten in normal operation.
- Meets HC-2: every API call, including `AssumeRoleWithWebIdentity` by the CI roles, is recorded with identity and time.
- Log file validation (signed digest files) detects altered log files.
- Storage cost is low (small JSON files, Glacier IR after 30 days).

**Negative / risks**
- Weaker than compliance mode: someone with permission to edit the bucket policy could remove the
  Deny and then bypass retention. Mitigation: that change is logged by CloudTrail; restrict
  `s3:PutBucketPolicy` on this bucket to the bootstrap administrator.
- WriteOnly events: read-only API calls are not recorded (acceptable for change traceability; lowers volume and cost).

## Evidence (2026-10-25)
- `get-object-lock-configuration` → `ObjectLockEnabled: Enabled`, `Mode: GOVERNANCE`, `Days: 365`
- `get-trail-status` → `Logging: true`; digest files delivered for every region, stored in us-east-1
- `get-object-retention` on a delivered log → `Mode: GOVERNANCE`, `RetainUntilDate: 2027-10-25`
- `delete-object` by the account engineer → **AccessDenied** ("explicit deny in a resource-based policy")
- Code: `modules/audit/main.tf`, bucket policy statement `DenyDeleteAndBypass`
