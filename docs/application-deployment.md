# Application Deployment Guide

A quick guide for deploying your containerized application to the iac infrastructure.

---

## Overview

This guide explains how to deploy containerized applications using our infrastructure. Here's how it works:

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
│  Private        │  ← Stores images
│  Registry       │     SHA tags (abc1234)
└────────┬────────┘     Semver tags (1.2.3)
         │
         │ You run: task application:deploy
         ▼
┌─────────────────┐
│  Promotion      │  ← Promotes SHA → Semver
│  (registry-     │     Adds annotation (SHA mapping)
│   promote.py)   │     Pushes semver tag
└────────┬────────┘
         │
         │ Image: registry.rednaw.nl/rednaw/app:1.2.3
         ▼
┌─────────────────┐
│  Ansible        │  ← Deploys to server
│  (deploy.yml)   │     Copies docker-compose.yml
└────────┬────────┘     Runs Docker Compose
         │
         ▼
┌─────────────────┐
│  Server         │  ← Your app runs here
│  (Docker)       │     Managed via Docker Compose
└─────────────────┘
```

### Key Concepts

**1. GitHub Actions (CI)**
- Builds your Docker image on every push
- Tags images with **short commit SHA** (7 characters, e.g. `abc1234`)
- Pushes to the private registry
- **Does NOT deploy** - deployments are manual

**2. Image Promotion**
- You manually promote a SHA-tagged image to a semantic version
- Example: `abc1234` → `1.2.3`
- The promotion process adds an annotation linking semver back to SHA
- This creates a traceable deployment history

**3. Deployment**
- Run `task application:deploy` from the IAC project
- Promotes the image (SHA → semver) and deploys in one command
- Uses Ansible to configure the server and run Docker Compose
- Your app's `deploy.yml` handles app-specific infrastructure needs

**4. Manual Control**
- No automatic deployments - you decide when and what to deploy
- Full control over semantic versions
- Clear audit trail (SHA → semver mapping)

---

## Quick Start

**Deploy your app:**
```bash
cd ~/projects/iac
task application:deploy -- dev ../your-app abc1234 1.0.0
```

That's it! The command promotes your image (adds a version tag) and deploys it.

---

## What You Need

Your app needs these files in its root directory:

```
your-app/
  deploy.yml                              # Deployment config + app-specific infrastructure setup
  docker-compose.yml                      # Your app's Docker Compose config
  .github/workflows/build-and-push.yml   # GitHub Actions workflow
  env.enc                                 # Optional: encrypted app secrets
```

---

## Setting Up Your App

### 1. Create Deployment Playbook

Create `deploy.yml` in your app root. Start with the deployment configuration at the top:

```yaml
---
# Deployment configuration
- vars:
    registry_name: registry.rednaw.nl
    image_name: rednaw/your-app
    service_name: your-app

# Application deployment playbook
- name: Deploy Your Application
  hosts: all
  become: yes

  pre_tasks:
    - name: Load infrastructure secrets
      ansible.builtin.import_tasks: "{{ iac_repo_root }}/ansible/tasks/secrets.yml"
      vars:
        secrets_file: "{{ iac_repo_root }}/secrets/infrastructure-secrets.yml.enc"

  tasks:
    # Add app-specific infrastructure setup here
    # Examples: create data directories, set permissions, etc.

  roles:
    - name: Deploy application
      role: "{{ iac_repo_root }}/ansible/roles/deploy-app"
```

**Configuration values:**
- `registry_name`: The registry domain (usually `registry.rednaw.nl`)
- `image_name`: Your image name in the registry (e.g. `rednaw/your-app`)
- `service_name`: The service name in your `docker-compose.yml`

**What the IAC role handles automatically:**
- Decrypts `env.enc` → `.env` (if present)
- Copies `docker-compose.yml` to the server
- Configures Docker registry authentication
- Creates the base deploy directory
- Runs Docker Compose

**What you handle in `deploy.yml`:**
- App-specific directories, volumes, or permissions
- Any other infrastructure needs unique to your app

### 2. Create Docker Compose File

Your `docker-compose.yml` should use `${IMAGE}` for the image:

```yaml
services:
  your-app:
    image: ${IMAGE}  # This gets set automatically during deploy
    ports:
      - "127.0.0.1:5000:5000"
    restart: unless-stopped
    # ... rest of your config
```

### 3. Optional: App Secrets

If your app needs secrets at runtime, create `env.enc` in your app root:

```bash
# Encrypt your secrets
sops -e -i env.yml  # Creates env.enc
```

The deployment process will decrypt it to `.env` on the server at `/opt/giftfinder/your-app/.env`.

### 4. Create GitHub Workflow

Create `.github/workflows/build-and-push.yml` in your app root:

```yaml
name: Build and Push

on:
  workflow_dispatch:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  IMAGE_NAME: rednaw/your-app
  REGISTRY: registry.rednaw.nl

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ vars.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Extract short SHA
        id: sha
        run: echo "short_sha=${GITHUB_SHA:0:7}" >> $GITHUB_OUTPUT

      - name: Build and push image
        uses: docker/build-push-action@v6
        with:
          context: .
          file: ./Dockerfile
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.sha.outputs.short_sha }}
```

**What to customize:**
- `IMAGE_NAME`: Your image name (must match `image_name` in `dev.yml`/`prod.yml`)
- `REGISTRY`: Your registry domain (usually `registry.rednaw.nl`)

**GitHub configuration needed:**
- **Repository variable:** `REGISTRY_USERNAME` (set in repository settings → Variables)
- **Repository secret:** `REGISTRY_PASSWORD` (set in repository settings → Secrets)

**What it does:**
- Builds your Docker image on every push to `main` and on pull requests
- Tags the image with the short commit SHA (7 characters)
- Pushes to the registry (skips push on pull requests)
- Does **not** deploy—deployments are manual

---

## Deploying

### The Deploy Command

Always run from the IAC project:

```bash
cd ~/projects/iac
task application:deploy -- <WORKSPACE> <APP_ROOT> <SHA> <SEMVER>
```

**Arguments:**
- `WORKSPACE`: `dev` or `prod`
- `APP_ROOT`: Path to your app root (e.g. `../your-app`)
- `SHA`: Short commit SHA (7 characters) of the image to deploy
- `SEMVER`: Semantic version (e.g. `1.2.3`, no `v` prefix)

**Examples:**
```bash
# Deploy to dev
task application:deploy -- dev ../your-app abc1234 1.0.0

# Deploy to prod
task application:deploy -- prod ../your-app f2f8d1d 2.0.0
```

**What happens:**
1. Promotes the SHA-tagged image to a semantic version tag
2. Pushes the tagged image to the registry
3. Deploys the app using Ansible
4. Your app runs via Docker Compose on the server

---

## CI Setup

See [step 5 above](#5-create-github-workflow) for the complete GitHub Actions workflow.

**Key points:**
- CI builds and pushes images tagged with **short commit SHA** (7 characters)
- CI only builds and pushes—it does **not** deploy
- Deployments are manual using `task application:deploy`

---

## Project Layout

**Important:** Your app and the IAC project must be **side-by-side**:

```
~/projects/
  iac/           # Infrastructure project
  your-app/      # Your application
```

The IAC project is always at `../iac` relative to your app. This is not configurable.

---

## Common Tasks

### Deploy a New Version
```bash
cd ~/projects/iac
task application:deploy -- dev ../your-app abc1234 1.0.1
```

### Check What's Deployed
```bash
task registry:map -- registry.rednaw.nl/rednaw/your-app
```

### View Registry Tags
```bash
task registry:tags -- registry.rednaw.nl/rednaw/your-app
```

---

## Troubleshooting

**"Host key verification failed"**
- This happens after server recreation. The deploy command handles this automatically.

**"Failed to list tags"**
- Make sure you're logged into the registry: `docker login registry.rednaw.nl`

**"Failed to read deployment configuration from deploy.yml"**
- Make sure `deploy.yml` exists in your app root and has a `vars` section with `registry_name`, `image_name`, and `service_name`.

**"No matching SHA found" in registry:map**
- Older images (promoted before annotations were added) won't show SHA mappings. New promotions will.

---

## Need More Details?

- **Registry commands:** See [Registry and containers cheat sheet](registry-containers-cheatsheet.md)
- **Infrastructure setup:** See the IAC project documentation
- **Secrets management:** See SOPS documentation
