
# Image Lifecycle & Deployment Metadata — Implementation Spec

## Terminology Update
- `registry:tags` is renamed to **`registry:overview`**
- Purpose: global registry inspection without deployment context

---

## CI-time Metadata (Image Metadata)

These values are **baked into the image** by CI and are immutable once pushed.

Source: OCI image labels and tags.

Included fields:
- **tag**: short SHA (single human-facing tag)
- **description**: commit subject
- **built_at**: commit timestamp
- **revision**: full git SHA
- **source**: repository URL

CI assigns:
- exactly **one tag**: short SHA
- OCI labels for all metadata above

---

## Deploy-time Metadata (Runtime State)

These values describe **what is running** and are written only after a successful deploy.

Source: deployment process (Ansible).

Written to:  
`/opt/<org>/<app>/deploy-info.yml`

### Canonical schema

```yaml
app: hello-world
workspace: dev
image: registry.rednaw.nl/rednaw/hello-world

tag: eb53023
digest: sha256:abc123...

description: "add healthcheck + fix nginx proxy header"

deployed_at: "2026-01-25T01:10:00Z"
deployed_by: "wander@casa"
```

### Responsibilities
- **Task layer**
  - resolves tag → digest
  - inspects image metadata (description, built_at)
  - passes immutable facts into Ansible
- **Ansible**
  - performs deployment
  - writes `deploy-info.yml` only on success

---

## Tag → Digest Resolution

- Always resolved **before deployment**
- Happens in **Task**, using `crane`
- Ansible never performs registry lookups

### Rollback
- Default: rollback by **tag**
- Supported: deploy by **digest** (first-class, advanced path)

---

## images:overview

Purpose: per-image, per-workspace view with deploy state.

Invocation:
```bash
task images:overview -- dev rednaw/hello-world
```

Behavior:
1. List tags and metadata via registry
2. Read `deploy-info.yml` from target workspace
3. Mark currently deployed digest

Output:
```
→ eb53023   2026-01-25 01:01:33  simple deploy
  6350192   2026-01-25 01:10:00  version 0.0.2
```

`→` indicates the digest deployed on that workspace.

---

## registry:overview

Purpose: global registry inspection (no deploy context).

Scope:
- all repositories
- tags, creation time, descriptions

Does **not**:
- show deployed state
- access servers

---

## Cleanup Semantics

Primary unit: **digest**

Rules:
1. Never delete a digest referenced in any `deploy-info.yml`
2. Tags may be pruned independently
3. Storage reclamation happens via digest deletion only

A digest is safe to delete iff:
- not referenced by any deploy-info.yml
- meets retention policy (TBD)

---

## Design Principles

- Tags for humans, digests for machines
- Deploy state is historical truth, never recomputed
- CI metadata ≠ runtime state
- Ansible receives facts, not questions
