# Application Deployment

This document describes how we deploy containerized applications: from building and storing images in a private registry to promoting and running them on our servers.

---

## TL;DR

**Deploy an app:**
```bash
cd ~/projects/iac
task application:deploy -- dev ../hello-world abc1234 1.0.0
```

**What happens:**
1. CI builds images tagged with short SHA (7 chars) → pushed to registry
2. You run `task application:deploy` → promotes SHA to semver, deploys via Ansible
3. App's `deploy.yml` handles app-specific infrastructure setup
4. IAC's `deploy-app` role handles the common deployment logic

**App structure:**
```
hello-world/
  deploy.yml          # App-specific infra + calls IAC deploy-app role
  docker-compose.yml  # Plain file, uses ${IMAGE}
  dev.yml            # Deployment descriptor
  prod.yml
  env.enc            # Optional app secrets
```

---

## What We're Building

A small, transparent workflow for a team of two or three people:

* **Images** are built in CI, tagged with short commit SHA (7 characters), and pushed to our private registry. CI does not deploy.
* **Deployments** are manual. One command promotes an image (adds a semantic version tag), pushes it to the registry, and deploys it via Ansible.
* **Secrets** stay in SOPS-encrypted files. Ansible decrypts what's needed during deploy.
* **Insight** into the registry: when needed, use Crane and Docker directly; see the [Registry and containers cheat sheet](registry-containers-cheatsheet.md).

No automatic production deploys, no heavy automation—just clear steps and full control.

---

## Project Layout

**Layout convention (not configurable):** the app and IAC projects are **side-by-side**. IAC is always at `../iac` relative to the app.

Example: `~/projects/iac` and `~/projects/hello-world`

**Infrastructure** (servers, Docker, Nginx, etc.) is managed by playbooks in the IAC project. You `cd` to the IAC project to run terraform/ansible.

**Application deployment** is run from the **IAC** project. Each app has its own `deploy.yml` playbook that handles app-specific infrastructure requirements.

---

## The Deploy Command

**Always promote + deploy** (no deploy-only). Single entry point:

### From IAC

Run from the IAC project:

```bash
cd ~/projects/iac
task application:deploy -- <WORKSPACE> <APP_ROOT> <SHA> <SEMVER>
```

**Example:**
```bash
task application:deploy -- dev ../hello-world abc1234 1.0.0
task application:deploy -- prod ../hello-world f2f8d1d 2.0.0
```

**Arguments:**
* **WORKSPACE** → `dev` or `prod`
* **APP_ROOT** → path to the app root directory (e.g. `../hello-world`)
* **SHA** → short commit SHA (7 characters) of the image to promote
* **SEMVER** → semantic version to tag and deploy (e.g. `1.2.3`, no `v` prefix)

**What it does:**
1. Runs `scripts/registry-promote.py` to pull the SHA image, tag with semver, and push
2. Changes directory to the app root
3. Runs `ansible-playbook` for `deploy.yml` with inventory from IAC

---

## App Deployment Playbook (`deploy.yml`)

The app's `deploy.yml` is where you configure **app-specific infrastructure requirements**. This includes:

* Creating application directories (beyond the base deploy target)
* Setting up app-specific volumes or data directories
* Configuring app-specific permissions
* Any other infrastructure needs unique to your application

**Structure:**
```yaml
---
- name: Deploy My Application
  hosts: all
  become: yes

  pre_tasks:
    - name: Load infrastructure secrets
      ansible.builtin.import_tasks: "{{ iac_repo_root }}/ansible/tasks/secrets.yml"
      vars:
        secrets_file: "{{ iac_repo_root }}/secrets/infrastructure-secrets.yml.enc"

  tasks:
    # App-specific infrastructure setup goes here
    # Example: create data directories, set permissions, etc.
    - name: Ensure app data directory exists
      ansible.builtin.file:
        path: "{{ deploy_target }}/data"
        state: directory
        owner: giftfinder
        group: giftfinder
        mode: '0755'

  roles:
    - name: Deploy application
      role: "{{ iac_repo_root }}/ansible/roles/deploy-app"
```

The IAC `deploy-app` role handles the common deployment logic:
* Decrypts `env.enc` → `.env` (if present)
* Copies `docker-compose.yml`
* Configures registry authentication
* Creates the base deploy target directory
* Runs Docker Compose

---

## App Structure

Every app needs these files in its root:

```
app/
  deploy.yml            # App-specific infra + calls IAC deploy-app role
  docker-compose.yml    # Plain file; service uses image: ${IMAGE}
  dev.yml               # Deployment descriptor
  prod.yml              # Deployment descriptor
  env.enc               # Optional; SOPS-encrypted app secrets
```

**Deployment descriptor** (`dev.yml`, `prod.yml`):
```yaml
registry_name: registry.rednaw.nl
image_name: rednaw/hello-world
service_name: hello-world
```

**Docker Compose** (`docker-compose.yml`):
```yaml
services:
  hello-world:
    image: ${IMAGE}  # Set by deploy-app role
    # ... rest of config
```

---

## App Secrets (env.enc)

If an app needs secrets at runtime, it keeps them in **`env.enc`** in the app root. Ansible decrypts it with the same SOPS key we use for infrastructure secrets and writes **`.env`** at the deploy target on the server (e.g. `/opt/giftfinder/hello-world/.env`). The app's Compose setup or code can then load `.env` as usual.

---

## CI: Build and Push Only

CI builds the container image and pushes it to the private registry with:

* A **short commit SHA** tag (7 characters, for traceability and deployment).

CI does **not** assign final semantic versions and does **not** trigger deployments. That stays manual.

---

## Registry and Pruning

The registry is a self-hosted Docker (OCI) registry with authentication.

* **SHA-only** tags can be pruned manually after a retention period (e.g. 7–14 days), once we're sure they're not deployed.
* **Semantic** tags are never pruned.

For listing tags, inspecting digests, and pruning, use **Crane** and **Docker** directly; see the [Registry and containers cheat sheet](registry-containers-cheatsheet.md). Pruning and garbage collection are manual and explicit.

---

## Conventions

* **App and IAC side-by-side:** IAC is at `../iac` from the app. **Not configurable.** Only side-by-side apps are supported.
* **Inventory path:** `$IAC_REPO/ansible/inventory/<WORKSPACE>.ini`, where `$IAC_REPO` is the IAC project root.
* **Deploy target on the server:** `/opt/giftfinder/<app_slug>`, where `app_slug` is the basename of the app root (e.g. `hello-world`). No overrides.
* **Convention over configuration:** paths and targets derived from layout; no overrides.

---

## Quick Reference

**Deploy:**
```bash
task application:deploy -- dev ../hello-world abc1234 1.0.0
```

**List registry tags:**
```bash
task registry:tags -- registry.rednaw.nl/rednaw/hello-world
```

**View SHA-semver mapping:**
```bash
task registry:map -- registry.rednaw.nl/rednaw/hello-world
```
