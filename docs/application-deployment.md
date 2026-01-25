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
│  Ansible        │  ← Deploys to server
│  (deploy.yml)   │     Image = registry/app:<SHA>
└────────┬────────┘     Copies docker-compose.yml, runs Docker Compose
         │
         ▼
┌─────────────────┐
│  Server         │  ← Your app runs here
│  (Docker)       │
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
- SHA is the unique identifier; CI sets image description from the git commit message
- Ansible deploys the image `registry/rednaw/app:<SHA>` via Docker Compose

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

Use the short SHA (7 characters) of the commit whose image you want to deploy.

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
    # Image tag = short commit SHA (passed from deploy command)
    image: "{{ registry_name }}/{{ image_name }}:{{ sha }}"

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

- `registry_name`: Registry domain (usually `registry.rednaw.nl`)
- `image_name`: Image name in the registry (e.g. `rednaw/your-app`)
- `service_name`: Service name in `docker-compose.yml`
- `image`: Built from `registry_name`, `image_name`, and `sha`; `sha` is passed by the deploy command

**What the deploy-app role does:**

- Decrypts `env.enc` → `.env` (if present)
- Copies `docker-compose.yml` to the server
- Configures Docker registry auth
- Creates the deploy directory and runs Docker Compose

### 2. Docker Compose

Use `${IMAGE}` for the image; it is set during deploy:

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
2. Runs Ansible with `deploy.yml`; image = `registry/rednaw/app:<SHA>`
3. App runs via Docker Compose on the server

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
task registry:map
```

Shows TAG, CREATED, and DESCRIPTION (from git commit message) for each tag in the registry.

---

## Troubleshooting


**"Failed to list tags"**

- Log in to the registry: `docker login registry.rednaw.nl`

**"Failed to read deployment configuration from deploy.yml"**

- Ensure `deploy.yml` exists in your app root and has a `vars` section with `registry_name`, `image_name`, and `service_name`, and that `image` is set from `sha`.

---

## See Also

- [Registry and containers cheat sheet](future/registry-containers-cheatsheet.md)
- [SSH host keys](SSH-host-keys.md)
- IAC docs: INSTALL, SECURITY, TROUBLESHOOTING
