# Application Deployment

This document describes how we deploy containerized applications: from building and storing images in a private registry to promoting and running them on our servers.  

For the implementation spec used by tooling and automation, see **application-deployment-implementation.md**.

---

## What We're Building

We want a small, transparent workflow for a team of two or three people:

* **Images** are built in CI, tagged with the commit SHA, and pushed to our private registry. CI does not deploy.
* **Deployments** are manual. One command promotes an image (adds a semantic version tag), pushes it to the registry, and deploys it via Ansible.
* **Secrets** stay in SOPS-encrypted files. Ansible decrypts what’s needed during deploy.
* **Insight** into the registry (tags, SHAs, what’s safe to prune) comes from read-only Crane tasks.

No automatic production deploys, no heavy automation—just clear steps and full control.

---

## Where Apps and Deploy Logic Live

Deploy logic lives in the app. Layout:

```
app/
  iac/
    docker-compose.yml    # plain; image: ${IMAGE} for the deployable service
    deploy.yml            # Ansible: ensure host dirs for volume mounts exist, run docker_compose_v2
    env.enc               # optional; SOPS-encrypted app secrets
    dev.yml               # deployment descriptors (any name, .yml or .yaml)
    prod.yml
```

IAC passes `image`, `service_name`, `deploy_target` into `deploy.yml`. The playbook creates any server paths required by volume mounts (e.g. `deploy_target/data`) before running Compose.

Apps can sit in the IAC repo (`apps/hello/`) or outside it (`../MilledonAI/`); the layout is the same.

---

## The Deploy Command

You run:

```bash
task registry:deploy -- <WORKSPACE> <DESCRIPTOR_PATH>
```

For example:

```bash
task registry:deploy -- dev apps/hello/iac/dev.yml
task registry:deploy -- prod ../MilledonAI/iac/prod.yml
```

* **WORKSPACE** is `dev` or `prod` (which server and inventory).
* **DESCRIPTOR_PATH** is the path to a deployment descriptor in an app’s `iac/` directory.

The task will: check the descriptor, pull the SHA-tagged image from the registry, ensure the semantic tag doesn’t already exist, tag and push the semantic version, then run Ansible to deploy. Ansible passes the SHA-pinned image into your app’s `iac/deploy.yml` playbook and, if present, decrypts `iac/env.enc` to `.env` on the server. At the end, Crane runs a quick read-only check so we know the promotion worked.

---

## App Secrets (env.enc)

If an app needs secrets at runtime, it keeps them in **`iac/env.enc`**. Ansible decrypts it with the same SOPS key we use for infrastructure secrets and writes **`.env`** at the deploy target on the server (e.g. `/opt/giftfinder/hello/.env`). The app’s Compose setup or code can then load `.env` as usual.

---

## CI: Build and Push Only

CI builds the container image and pushes it to the private registry with:

* A **full 40-character commit SHA** tag (for traceability and deployment).
* Optionally a **provisional tag** (e.g. `1.2.3-rc`) for QA.

CI does **not** assign final semantic versions and does **not** trigger deployments. That stays manual.

---

## Registry and Pruning

The registry is a self-hosted Docker (OCI) registry with authentication. We use **Crane** for read-only inspection: listing images and tags, inspecting a digest, or finding SHA-only images that might be pruned.

* **SHA-only** tags can be pruned manually after a retention period (e.g. 7–14 days), once we’re sure they’re not deployed.
* **Semantic** tags are never pruned.

Pruning and garbage collection are manual and explicit.

---

## Conventions

* **Deploy target on the server:** `/opt/giftfinder/<app_slug>`, where `app_slug` is the last part of the app root (e.g. `hello` from `apps/hello`, `MilledonAI` from `../MilledonAI`). There is no configuration to override this.
* **App root** is the parent of the `iac` directory that contains the descriptor.
* **Convention over configuration:** we derive paths and targets from the descriptor path and app layout; no overrides.

---

## How the Two Docs Relate

* **application-deployment.md** (this file) explains the system for humans: what we’re building, how it works, and how to use it.
* **application-deployment-implementation.md** is the structured spec for implementers and tooling: fields, formats, validation rules, and step-by-step behaviour. It stays in sync with this document.
