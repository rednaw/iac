# Image Lifecycle & Deployment Tracking

## 1. Purpose

This document defines **how container images are built, tagged, identified, deployed, and tracked over time**.

The goals are:
- Deterministic and reproducible deployments
- Clear separation between *build-time* and *deploy-time* metadata
- Simple operational workflows (Taskfile + Ansible)
- Strong auditability: *who deployed what, when, and what was running at a given time*

---

## 2. What We Are Building

We are building a **lightweight image lifecycle capability** consisting of:

- CI pipelines that build and push images to a registry
- A deployment flow that deploys **immutable image digests**
- Host-side records of:
  - what is currently deployed
  - what has been deployed historically
- CLI tooling (Taskfile tasks) to:
  - inspect registry contents
  - see what is currently deployed
  - correlate deployments with registry images

This is **not** a full deployment platform.
It is a pragmatic, inspectable, filesystem-based approach that integrates with existing tooling.

---

## 3. Image Identity Strategy

### 3.1 Tags vs Digests

- **Tags** are used for *human interaction* and *CI output*.
- **Digests** are used for *actual deployment*.

**Decision:**
- CI **always** publishes images with a tag (short Git SHA)
- Deployments **always** resolve tag → digest
- The digest is what is actually deployed and recorded

Tags are optional for rollback; digests are first-class.

---

## 4. CI Metadata (Build-Time)

CI enriches images with metadata at build time.

### 4.1 Required Tag

- Exactly **one tag** per build
- Format: short Git SHA (e.g. `1f3a9c2`)

### 4.2 Image Labels

CI sets OCI-compliant labels, for example:

- `org.opencontainers.image.title`
- `org.opencontainers.image.description`
- `org.opencontainers.image.created`
- `org.opencontainers.image.revision`
- `org.opencontainers.image.source`

The **description** is especially important and should be meaningful.

Example source:
- Git commit subject
- Manually curated workflow description

---

## 5. Deployment Metadata (Deploy-Time)

Deployment adds metadata that **cannot exist at build time**.

Examples:
- when the image was deployed
- who deployed it
- where it was deployed
- which digest was actually used

---

## 6. Deployment Records (On Host)

Two files are used.

### 6.1 `deploy-info.yml` — Current State

**Purpose:**
- Authoritative record of what is running *right now*

**Path:**
```
/opt/giftfinder/<app>/deploy-info.yml
```

**Characteristics:**
- Exactly one deployment
- Overwritten on each successful deploy

Example:

```yaml
app: hello
workspace: prod

image:
  repo: registry.rednaw.nl/rednaw/hello-world
  tag: 1f3a9c2
  digest: sha256:aaa
  description: "add healthcheck + fix nginx proxy header"
  built_at: "2026-01-24T22:41:03Z"

deployment:
  deployed_at: "2026-01-25T01:10:00Z"
  deployed_by: "alice"
```

---

### 6.2 `deploy-history.yml` — Audit Trail

**Purpose:**
- Answer historical questions
- Provide a durable deployment log

**Path:**
```
/opt/giftfinder/<app>/deploy-history.yml
```

**Characteristics:**
- Append-only
- Never rewritten

Example:

```yaml
- image:
    tag: 9c8e712
    digest: sha256:bbb
    description: "initial release"
    built_at: "2026-01-20T18:12:55Z"

  deployment:
    deployed_at: "2026-01-22T09:03:11Z"
    deployed_by: "bob"
    workspace: prod

- image:
    tag: 1f3a9c2
    digest: sha256:aaa
    description: "add healthcheck + fix nginx proxy header"
    built_at: "2026-01-24T22:41:03Z"

  deployment:
    deployed_at: "2026-01-25T01:10:00Z"
    deployed_by: "alice"
    workspace: prod
```

This enables queries like:
> "What was running yesterday at 05:00, when was it built, and who deployed it?"

---

## 7. Tag → Digest Resolution

**Decision:** resolve tag → digest **before deployment**.

Resolution happens:
- in Taskfile or a small helper script
- using registry APIs (e.g. `crane digest`)

Ansible receives:
- digest (required)
- tag (optional, informational)
- description and build metadata (optional but recommended)

---

## 8. Taskfile Capabilities

### 8.1 `registry:overview`

Renamed from `registry:tags`.

Purpose:
- List images in the registry
- Show tag, created time, description

Scope:
- Registry-wide

---

### 8.2 `images:overview`

Purpose:
- Inspect a **single image repository**
- Correlate registry images with deployed state

Behavior:
- Reads registry metadata
- Reads `deploy-info.yml` from target host
- Marks currently deployed digest (e.g. `→` or `*`)

Runs per workspace (e.g. dev, prod).

---

## 9. Cleanup Considerations

### 9.1 Tags

- Tags are mutable and may be pruned
- Old SHA tags can be removed freely

### 9.2 Digests

- Digests are immutable
- **Never delete a digest referenced in:**
  - any `deploy-info.yml`
  - any `deploy-history.yml`

Future cleanup automation must respect this rule.

---

## 10. Open Questions (Resolved)

- Tag vs digest → **digest wins**
- Where to record deployments → **on host**
- Single vs multiple tags → **single SHA tag**
- Registry vs deploy metadata → **both, clearly separated**

---

## 11. Design Principles

- Boring over clever
- Filesystem over databases
- Explicit over implicit
- Humans must be able to SSH in and understand the state

This document is intended to be directly implementable.

