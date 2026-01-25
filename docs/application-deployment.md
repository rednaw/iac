# Application Deployment Guide

A quick guide for deploying your containerized application to the iac infrastructure.

---

## Overview

### The Flow

```
┌─────────────────┐
│  Your Code      │
│  (GitHub)       │
└────────┬────────┘
         │
         │ Push to main
         ▼
┌─────────────────┐
│  GitHub Actions │  ← Builds Docker image
│  (CI)           │     Tags with short SHA (7 chars)
└────────┬────────┘     Pushes to registry
         │
         │ Image: registry.rednaw.nl/rednaw/app:abc1234
         ▼
┌─────────────────┐
│  Private        │  ← Stores images by SHA tag
│  Registry       │
└────────┬────────┘
         │
         │ You run: task application:deploy -- <WORKSPACE> <APP_ROOT> <SHA>
         ▼
┌─────────────────┐
│  Taskfile       │  ← Resolves tag → digest
│                 │     Extracts metadata (description, built_at)
└────────┬────────┘     Passes digest to Ansible
         │
         │ Image digest: registry/app@sha256:...
         ▼
┌─────────────────┐
│  Ansible        │  ← Deploys digest-pinned image
│  (deploy.yml)   │     Writes deploy-info.yml, deploy-history.yml
└────────┬────────┘     Copies docker-compose.yml, runs Docker Compose
         │
         ▼
┌─────────────────┐
│  Server         │  ← Your app runs here (pinned to digest)
│  (Docker)       │     deploy-info.yml records current deployment
└─────────────────┘
```

### Key Concepts

**1. GitHub Actions (CI)**

- Builds your Docker image on every push to main
- Tags images with **short commit SHA** (7 characters, e.g. `abc1234`)
- Pushes to the private registry
- Does **not** deploy; deployments are manual

**2. Deployment**

- Run `task application:deploy -- <WORKSPACE> <APP_ROOT> <SHA>` from the IAC project
- The deploy command resolves the SHA tag → immutable digest
- Ansible deploys the **digest-pinned** image (e.g. `registry/app@sha256:...`)
- Deployment records are written to `/opt/giftfinder/<app>/deploy-info.yml` and `deploy-history.yml`

**3. Manual Control**

- No automatic deployments; you choose when and what to deploy
- Deploy any built image by its commit SHA

---

## Quick Start

**Deploy your app:**

```bash
cd ~/projects/iac
task application:deploy -- dev ../your-app abc1234
```

Use the short SHA (7 characters) of the commit whose image you want to deploy. The deploy command resolves the tag to an immutable digest and deploys that.

**Optional:** Override the deployer attribution:

```bash
task application:deploy -- dev ../your-app abc1234 "CI Pipeline"
```

---

## What You Need

Your app needs these files in its root directory:

```
your-app/
  deploy.yml                              # Deployment config + app-specific setup
  docker-compose.yml                      # Docker Compose config
  .github/workflows/build-and-push.yml    # GitHub Actions workflow
  env.enc                                 # Optional: encrypted app secrets
```

---

## Setting Up Your App

### 1. Create Deployment Playbook

Create `deploy.yml` in your app root:

```yaml
---
- name: Deploy Your Application
  hosts: all
  become: yes
  vars:
    registry_name: registry.rednaw.nl
    image_name: rednaw/your-app
    service_name: your-app
    # Image digest is resolved from tag and passed by Taskfile

  pre_tasks:
    - name: Load infrastructure secrets
      ansible.builtin.import_tasks: "{{ iac_repo_root }}/ansible/tasks/secrets.yml"
      vars:
        secrets_file: "{{ iac_repo_root }}/secrets/infrastructure-secrets.yml.enc"

  tasks:
    # App-specific setup: directories, permissions, etc.

  roles:
    - name: Deploy application
      role: "{{ iac_repo_root }}/ansible/roles/deploy-app"
```

**Configuration:**

- `registry_name`: Registry domain (usually `registry.rednaw.nl`) — used by Taskfile to resolve image
- `image_name`: Image name in the registry (e.g. `rednaw/your-app`) — used by Taskfile to resolve image
- `service_name`: Service name in `docker-compose.yml`
- Image digest is resolved from the SHA tag by the Taskfile and passed to Ansible

**What the deploy-app role does:**

- Decrypts `env.enc` → `.env` (if present)
- Copies `docker-compose.yml` to the server
- Configures Docker registry auth
- Creates the deploy directory and runs Docker Compose

### 2. Docker Compose

Use `${IMAGE}` for the image; it is set to a digest-pinned reference during deploy (e.g. `registry.rednaw.nl/rednaw/app@sha256:...`):

```yaml
services:
  your-app:
    image: ${IMAGE}
    ports:
      - "127.0.0.1:5000:5000"
    restart: unless-stopped
```

### 3. Optional: App Secrets

If your app needs secrets at runtime, create `env.enc` in your app root. The deploy process decrypts it to `.env` on the server at `/opt/giftfinder/your-app/.env`.

### 4. GitHub Workflow

Create `.github/workflows/build-and-push.yml` in your app root. It should:

- Build the Docker image on push to main (and optionally on pull requests)
- Tag the image with the short commit SHA (`${GITHUB_SHA:0:7}`)
- Push to your private registry
- Use `vars.REGISTRY_USERNAME` and `secrets.REGISTRY_PASSWORD` for registry auth

CI does **not** deploy; you run `task application:deploy` manually.

---

## Deploying

### Deploy Command

Run from the IAC project:

```bash
cd ~/projects/iac
task application:deploy -- <WORKSPACE> <APP_ROOT> <SHA>
```

**Arguments:**

- `WORKSPACE`: `dev` or `prod`
- `APP_ROOT`: Path to your app root (e.g. `../your-app`)
- `SHA`: Short commit SHA (7 characters) of the image to deploy

**Examples:**

```bash
task application:deploy -- dev ../your-app abc1234
task application:deploy -- prod ../your-app f2f8d1d
```

**What happens:**

1. Prepares `known_hosts` for the workspace hostname
2. Resolves SHA tag → immutable digest using `crane digest`
3. Extracts image metadata (description, built_at) from image labels
4. Runs Ansible with digest-pinned image (e.g. `registry/app@sha256:...`)
5. Ansible writes deployment records (`deploy-info.yml`, `deploy-history.yml`)
6. App runs via Docker Compose on the server, pinned to the digest

---

## Project Layout

Your app and the IAC project must be **side by side**:

```
~/projects/
  iac/           # Infrastructure project
  your-app/      # Your application
```

---

## Common Tasks

### Deploy an image

```bash
cd ~/projects/iac
task application:deploy -- dev ../your-app abc1234
```

### List registry tags

```bash
task registry:overview
```

Shows TAG, CREATED, and DESCRIPTION for all repos in the registry.

### Inspect image with deployment status

```bash
task images:overview -- dev rednaw/hello-world
```

Shows tags for a specific image repository, with the currently deployed digest marked (→). Reads deployment state from the server.

---

## Deployment Tracking

Each deployment creates two files on the server:

### `deploy-info.yml` (Current State)

Located at `/opt/giftfinder/<app>/deploy-info.yml`. Records what is **currently running**:

- Image digest, tag, description, build time
- Deployment timestamp and deployer attribution
- Overwritten on each successful deploy

### `deploy-history.yml` (Audit Trail)

Located at `/opt/giftfinder/<app>/deploy-history.yml`. Append-only log of all deployments:

- Historical deployments with full metadata
- Enables queries like "what was running yesterday at 05:00?"
- Never rewritten; only appended

You can inspect these files directly on the server or use `images:overview` to see deployment status.

---

## Troubleshooting


**"Failed to list tags"**

- Log in to the registry: `docker login registry.rednaw.nl`

**"Failed to read deployment configuration from deploy.yml"**

- Ensure `deploy.yml` exists in your app root and has a `vars` section with `registry_name`, `image_name`, and `service_name`.

**"Could not resolve digest for ..."**

- Make sure the image exists in the registry and you're logged in: `docker login registry.rednaw.nl`
- Verify the SHA tag is correct (7 hexadecimal characters)

**"crane command not found"**

- Install crane: `brew install crane`

---

## See Also

- [Registry and containers cheat sheet](future/registry-containers-cheatsheet.md)
- [SSH host keys](SSH-host-keys.md)
- IAC docs: INSTALL, SECURITY, TROUBLESHOOTING
