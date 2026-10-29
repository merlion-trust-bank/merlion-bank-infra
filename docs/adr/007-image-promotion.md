# ADR-007: Image promotion – build once, promote the same digest from staging to production

- **Status:** Accepted
- **Date:** 2026-10-29
- **Deciders:** DevSecOps (DO2), reviewed by DevSecOps (DO1)
- **Related:** ADR-002 (environments), ADR-005 (OIDC), INF-08 (ECR), APP-03/04/05 (build + gates), APP-10 (CD), APP-11 (deploy audit record), HC-2 Auditability

## Context
The pipeline deploys to **staging** first and, after a **manual approval**, to **production**
(ADR-002). The approval is only meaningful if production runs exactly what was tested and
approved in staging. If each environment built its own image, a dependency update, a moved
base-image tag or a different build cache could put untested code into production, and the
security gates (SCA, image scan) would no longer describe what is running.

Production changes must also be traceable (HC-2): for any running pod we must be able to say
which commit, which pipeline run and which approver put it there.

Container images live in Amazon ECR (INF-08): one repository per service
(`kean-merlion/<service>`), created in `bootstrap/` and shared by both environments, with
**immutable tags**, scan on push and a lifecycle policy keeping the last 20 images. EKS nodes
in both environments pull with `AmazonEC2ContainerRegistryReadOnly`.

## Decision
**Build once, promote by digest.**

1. **Build once.** On merge to `main`, CI builds each service image **once**, tagged with the
   full git commit SHA. No environment-specific build arguments; environment differences live
   only in Helm values (`values-staging.yaml`, `values-prod.yaml`).
2. **Gate before push.** SCA (APP-04) and the Trivy image scan (APP-05) run on that image and
   fail on HIGH/CRITICAL. Only an image that passes is pushed to ECR.
3. **Record the digest.** The push returns the image digest (`sha256:…`). The pipeline passes
   this digest to every later job as a job output; nothing downstream rebuilds or re-resolves a tag.
4. **Deploy by digest.** Helm sets `image: <repo>@sha256:<digest>` in both environments.
   Staging deploys automatically and smoke tests run against it.
5. **Promote, do not rebuild.** After manual approval in the `production` GitHub environment,
   the production job deploys **the same digest**. The production job never builds or pushes
   images.
6. **Audit.** The production deploy record (APP-11) stores the digest together with actor,
   approver, PR, commit SHA, environment and timestamp in the Object Lock audit bucket.

Immutable tags guarantee that a SHA tag can never be pointed at a different image; deploying by
digest guarantees it even if a tag were somehow reused.

## Alternatives considered
| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Build once, promote the same digest** | Prod runs exactly what was tested and scanned; one build per change; clear audit trail | Pipeline must pass the digest between jobs; environment config must stay out of the image | **Chosen** |
| Rebuild per environment | Simple pipeline; env settings could be baked in | Prod image never tested or scanned as built; non-reproducible builds | Rejected |
| Promote by mutable tag (`:staging` → `:prod`) | Easy to read | Tag can move after approval; not possible with immutable tags; weak traceability | Rejected |
| Separate ECR repositories per environment, copy image on promotion | Clear per-environment registry permissions | Extra copy step and storage; same digest anyway, so little added safety in one account | Rejected |

## Consequences
**Positive**
- The manual approval approves a specific, already-tested artefact.
- Security scan results apply to the exact image running in production.
- Rollback is a redeploy of an earlier digest still kept in ECR (last 20 images).
- Every production pod can be traced back to a commit and an approver.

**Negative / risks**
- Configuration that differs between environments must come from Helm values, environment
  variables or External Secrets, never from the image. Mitigation: review in PRs (APP-07, APP-09).
- The lifecycle policy expires old images, so a digest older than the last 20 builds cannot be
  rolled back to. Mitigation: 20 builds is enough for the release rate here; raise
  `keep_last_images` if needed.
- A vulnerability published after promotion is not caught by the push-time gate. Mitigation:
  rebuild with the fix and promote the new digest through the same pipeline.

## Evidence (to be completed)
- INF-08: ECR repositories `kean-merlion/<service>` with `IMMUTABLE` tags and scan on push
- APP-10: staging and production deploy jobs log the same `sha256:` digest for one pipeline run
- APP-11: production deploy record in the audit bucket contains the image digest
