# Container Image Lifecycle & Deployment Capability

## Purpose

This document describes the design of the container image lifecycle and deployment capability within the Infrastructure as Code (IAC) project.

The goal is to support **safe, inspectable, and reversible application deployments** on a self‑hosted Docker registry, operated by a small trusted team, with minimal automation upfront and a clear path toward automation later.

This capability spans:

- Image build & tagging in CI  
- Image storage and inspection in a private registry  
- Human‑driven deployments via Task ➔ Ansible ➔ Docker  
- Rollback, cleanup, and auditability  

---

## Non‑Goals

This capability explicitly does **not** attempt to:

- Provide full CI/CD automation or GitOps  
- Replace Docker Registry v3  
- Solve monitoring, alerting, or observability  
- Implement advanced policy enforcement  
- Optimize cloud cost or FinOps metrics  

Those concerns are intentionally out of scope.

---

## Current Context

- Registry: self‑hosted Docker Registry v3  
- CI: GitHub Actions  
- Deployment: manual Task invocation ➔ Ansible ➔ Docker Compose  
- Users: 2–3 trusted humans  
- Secrets: SOPS  
- Storage: constrained, cleanup matters  

The system is **real‑world driven**: insight first, automation later.

---

## High-Level Design

### Core Principle

> **Tags are for humans. Digests are for machines. Descriptions are for context.**  

- Humans select versions using readable tags  
- Deployments resolve tags to immutable digests  
- Running containers are pinned to digests  
- Human-readable descriptions aid inspection, rollback, and cleanup  

This provides:

- Good UX  
- Strong safety guarantees  
- Clear rollback semantics  
- Predictable cleanup  

---

## Image Lifecycle (Conceptual)

1. CI builds image  
2. CI assigns multiple tags  
3. Image is pushed once; tags reference the same digest  
4. Humans inspect registry state via `application:overview`  
5. Deployment selects a tag  
6. Tag is resolved to digest  
7. Digest is deployed  
8. Deployment metadata is recorded (`/opt/giftfinder/<app>/deploy-info.yml`)  
9. Tags may later be pruned; digest remains valid until explicitly removed  

---

## Image Metadata

Each image carries **first-class metadata**, automatically populated from Git history:

| Field | Source | Purpose |
|-------|--------|---------|
| `org.opencontainers.image.description` | Commit subject | Human-readable explanation of changes |
| `org.opencontainers.image.created` | Commit timestamp | When image was built |
| `org.opencontainers.image.revision` | Full git SHA | Traceability to exact source |
| `org.opencontainers.image.source` | Repository URL | Optional reference to repo |

This metadata is surfaced via the **`application:overview`** task:

```text
IMAGE: rednaw/hello-world

TAG        CREATED              DESCRIPTION
---        -------              -----------
→ 6350192  2026-01-25 01:10     add healthcheck + fix nginx proxy header
  eb53023  2026-01-25 01:01     initial deploy
```

Key points:

- Arrow (`→`) marks the currently deployed image  
- Short SHA is the primary human-facing tag  
- Description gives immediate insight into what changed and why  

---

## Tooling

- **Docker Registry v3**: image storage  
- **GitHub Actions**: CI build & push  
- **Crane (go-containerregistry)**: registry inspection, tag → digest resolution, metadata access  
- **Task**: UX layer (`application:overview`)  
- **Ansible**: execution layer  

---

## Deployment & Rollback Behavior

- By default, deployments use **tag → digest resolution**  
- Digests are **recorded** in `/opt/giftfinder/<app>/deploy-info.yml`  
- Rollback is a **deploy of an earlier digest**  
- Tags are optional for rollback; description and SHA make selection easier  

---

## Cleanup & Retention

- Only images that are **not currently deployed** are safe to delete  
- Tags may be pruned manually until automated cleanup is introduced  
- Descriptions and digests provide auditability for cleanup decisions  

---

## Open Questions (Partially Resolved)

| Decision | Status | Notes |
|----------|--------|-------|
| Versioning strategy | ✅ | Use short SHA for tag; description for context |
| PR / branch tags | ✅ | Only build on main branch push |
| Deployment recording | ✅ | File `/opt/giftfinder/<app>/deploy-info.yml` contains digest, tag, description |
| Image retention | ⬜ | Automated cleanup rules TBD |
| Tag vs digest display | ✅ | Tag shown for humans; digest recorded internally |
| Multiple tags per image | ⬜ | Should we add semantic version or other descriptors? |
| Registry inspection task | ✅ | `application:overview` shows tag, digest, created, description; currently deployed marked |
| Automation / CI integration | ⬜ | Should registry inspection run in CI? Local-only for now |

---

## Next Steps

1. Decide on **automated cleanup rules**  
2. Decide if **semantic versioning** or additional tags should be applied  
3. Optionally integrate **registry inspection into CI**  
4. Refine `application:overview` formatting if needed  
5. Document the **tagging and rollback convention** for contributors  

---

This is now a **full, self-contained reference** for the container image lifecycle, image metadata, deployment, and inspection within the IAC project.

