# Deployment Strategy Evaluation

## Context

**Goal:** Deploy the application from GitHub Actions to Hetzner server(s)

**Constraints:**
- ⚠️ **Budget: Cost-conscious** €4/month may be acceptable (?), but need to be careful with costs.
- ✅ **2-person team**
- ✅ **Early stage / MVP**
- ✅ **Private GitHub repository**
- ✅ **Large Docker images:** ~11.4GB total (4 images × 2.85GB each)
  - Images contain PyTorch (~1-2GB) + SentenceTransformer model (~500MB-1GB) + dependencies

**Application Stack:**
- Flask backend (Python)
- Celery workers (4 services)
- PostgreSQL, Redis, OpenSearch (infrastructure)
- Docker Compose for orchestration

---

## Deployment Strategies Overview

### Strategy 1: Container Registry

**How it works:**
1. GitHub Actions builds Docker images
2. Push images to container registry
3. Server pulls images from registry
4. Deploy with `docker compose up`

**Variants:**
- **1a. Self-hosted registry (separate server)** - Dedicated server for registry
- **1b. Self-hosted registry (same server)** - Registry on existing app server
- **1c. GitHub Container Registry** (ghcr.io)
- **1d. Docker Hub**

**Pros:**
- ✅ **Mature, industry-standard approach** (widely used in production)
- ✅ **Sets a standard** (follows containerization best practices)
- ✅ Images cached in registry (fast pulls)
- ✅ Can deploy to multiple servers (scalable)
- ✅ Version control (tagged images)
- ✅ Separation of build and deploy
- ✅ **Same-server option:** No extra cost, simpler setup

**Cons:**
- ⚠️ Requires registry infrastructure (cost or limits)
- ⚠️ Network dependency (registry must be accessible)
- ⚠️ **Separate server:** Extra cost (€3-4/month)
- ⚠️ **Same server:** Disk space management, all services on one server

**Cost Analysis:**
- **Self-hosted (separate server):** €3-4/month (dedicated server) ⚠️ **Requires budget approval**
- **Self-hosted (same server):** €0/month (uses existing server) ✅ **No additional cost**
- **GitHub Container Registry:** ~€5.81/month ⚠️ **Higher cost**
- **Docker Hub Pro:** €8.20/month ⚠️ **Higher cost**

**Verdict:** ✅ **Viable with self-hosted registry (separate or same server)**

---

### Strategy 2: Build on Server

**How it works:**
1. GitHub Actions triggers deployment (or manual)
2. Server clones/updates code repository
3. Server builds Docker images locally
4. Deploy with `docker compose up`

**Implementation:**
- **Code access:** Server needs access to private GitHub repository
  - Option A: SSH keys on server (for `git clone` from private repo)
  - Option B: GitHub Actions triggers build via SSH (requires SSH key in GitHub Secrets)
- Ansible ensures code is checked out (or manual `git pull`)
- Server runs `docker compose build`
- Server runs `docker compose up -d`

**Pros:**
- ✅ **No registry needed** (no extra cost)
- ✅ **No storage limits** (uses server disk)
- ✅ **No transfer limits** (no network transfer of images)
- ✅ **Simple workflow** (standard docker compose)
- ✅ **Full control** (build exactly what you need)

**Cons:**
- ⚠️ **SSH setup required** (for private repo access or GitHub Actions trigger)
  - Server needs SSH key for GitHub (if cloning private repo)
  - OR GitHub Actions needs SSH key for server (if automating)
- ⚠️ **Uses server resources** (CPU, disk, RAM during build)
- ⚠️ **Slower deployments** (build takes time)
- ⚠️ **Build dependencies on server** (Docker, build tools)
- ⚠️ **No image caching** (rebuilds every time, unless using cache)
- ⚠️ **Single point of failure** (if server is down, can't build)

**Cost Analysis:**
- **Cost:** €0/month (uses existing server) ✅ **No additional cost**

**Resource Impact:**
- Build time: ~10-30 minutes (depending on cache)
- CPU usage: High during build
- Disk usage: ~11.4GB for images + build cache
- RAM usage: ~2-4GB during build

**Verdict:** ✅ **Viable, simplest option**

---

### Strategy 3: GitHub Artifacts

**How it works:**
1. GitHub Actions builds Docker images
2. Save images as artifacts (tar files)
3. Server downloads artifacts via GitHub API
4. Load images into Docker (`docker load`)
5. Deploy with `docker compose up`

**Implementation:**
- GitHub Actions: `docker save` → upload as artifact
- Server: Download artifact → `docker load` → deploy

**Pros:**
- ✅ **No registry needed** (uses GitHub Artifacts)
- ✅ **No extra cost** (GitHub Artifacts included)
- ✅ **Versioned** (tied to GitHub releases/commits)
- ✅ **Secure** (GitHub authentication)

**Cons:**
- ⚠️ **GitHub Artifacts limits:**
  - 10GB storage per repository
  - 1GB per artifact file
  - 90-day retention (free tier)
- ⚠️ **Large images (11.4GB)** (exceeds 10GB limit)
- ⚠️ **Artifact size limit** (1GB per file, need to split)
- ⚠️ **Network transfer** (download 11.4GB on each deploy)
- ⚠️ **Slower deployments** (download + load time)

**Cost Analysis:**
- **Cost:** €0/month (free tier) ✅ **No additional cost**
- **But:** Storage limit (10GB) is close to the 11.4GB image size requirement

**Verdict:** ⚠️ **Risky - storage limits are tight**

---

### Strategy 4: Direct Image Transfer (SCP/RSYNC)

**How it works:**
1. GitHub Actions builds Docker images
2. Save images as tar files (`docker save`)
3. Transfer directly to server (SCP, RSYNC, or similar)
4. Load images on server (`docker load`)
5. Deploy with `docker compose up`

**Implementation:**
- GitHub Actions: Build → `docker save` → compress → SCP to server
- Server: Receive → decompress → `docker load` → deploy

**Pros:**
- ✅ **No registry needed** (direct transfer)
- ✅ **No extra cost** (uses existing server)
- ✅ **No storage limits** (server disk)
- ✅ **Full control** (direct transfer)

**Cons:**
- ⚠️ **Network transfer** (11.4GB on each deploy)
- ⚠️ **Slower deployments** (transfer + load time)
- ⚠️ **SSH key management** (GitHub Actions needs server access)
- ⚠️ **No image caching** (full transfer each time)
- ⚠️ **Bandwidth usage** (11.4GB per deployment)

**Cost Analysis:**
- **Cost:** €0/month (uses existing server) ✅ **No additional cost**
- **Bandwidth:** Included in Hetzner server (usually 20TB/month)

**Transfer Time Estimate:**
- 11.4GB over typical connection: ~5-15 minutes
- Plus load time: ~2-5 minutes
- **Total: ~7-20 minutes per deployment**

**Verdict:** ✅ **Viable, but slow**

---

### Strategy 5: Hybrid: Build on Server with CI Trigger

**How it works:**
1. GitHub Actions triggers build on server (via webhook/SSH)
2. Server clones/updates code
3. Server builds images
4. Server deploys

**Implementation:**
- GitHub Actions: SSH to server → trigger build script
- Server: Build script handles everything

**Pros:**
- ✅ **No registry needed**
- ✅ **No extra cost**
- ✅ **Automated** (CI/CD triggered)
- ✅ **Uses server resources** (no external dependencies)

**Cons:**
- ⚠️ **Same as Strategy 2** (build on server)
- ⚠️ **SSH key management** (GitHub Actions needs server access)
- ⚠️ **Server must be accessible** (for SSH from GitHub Actions)

**Cost Analysis:**
- **Cost:** €0/month ✅ **No additional cost**

**Verdict:** ✅ **Viable, automated version of Strategy 2**

---

### Strategy 6: GitOps (ArgoCD, Flux, etc.)

**How it works:**
1. Git repository contains deployment manifests
2. GitOps tool watches repository
3. Automatically syncs and deploys changes
4. Can pull from registry or build on cluster

**Pros:**
- ✅ **Declarative** (infrastructure as code)
- ✅ **Automated** (continuous sync)
- ✅ **Audit trail** (Git history)

**Cons:**
- ❌ **Overkill** for single server
- ❌ **Complex setup** (requires Kubernetes or similar)
- ❌ **Learning curve** (new tools to learn)
- ❌ **Not suitable** for small teams and early-stage projects

**Verdict:** ❌ **Not recommended** (too complex for small teams and early-stage projects)

---

## Comparison Matrix

| Strategy | Cost | Speed | Complexity | Storage Limits | Transfer Limits | Cost Consideration | Viable |
|----------|------|-------|------------|----------------|-----------------|---------------------|--------|
| **1. Container Registry (Self-hosted, separate)** | €3-4/month | Fast (cached) | Medium | ✅ Unlimited | ✅ Unlimited | ⚠️ Requires approval | ✅ **Yes** |
| **1. Container Registry (Self-hosted, same server)** | €0/month | Fast (cached) | Medium | ✅ Unlimited | ✅ Unlimited | ✅ No additional cost | ✅ **Yes** |
| **1. Container Registry (GitHub)** | ~€5.81/month | Fast (cached) | Low | ❌ 2GB (need 11.4GB) | ⚠️ 10GB/month | ⚠️ Higher cost | ❌ **No** |
| **1. Container Registry (Docker Hub)** | €8.20/month | Fast (cached) | Low | ✅ Unlimited | ⚠️ Rate limits | ⚠️ Highest cost | ❌ **No** |
| **2. Build on Server** | €0/month | Slow (10-30 min) | Medium | ✅ Unlimited | ✅ None | ✅ No additional cost | ✅ **Yes** |
| **3. GitHub Artifacts** | €0/month | Medium (download) | Medium | ⚠️ 10GB (close to 11.4GB) | ⚠️ Network | ✅ No additional cost | ⚠️ **Risky** |
| **4. Direct Transfer (SCP)** | €0/month | Slow (7-20 min) | Medium | ✅ Unlimited | ⚠️ 11.4GB per deploy | ✅ No additional cost | ✅ **Yes** |
| **5. Hybrid (CI Trigger)** | €0/month | Slow (10-30 min) | Medium | ✅ Unlimited | ✅ None | ✅ No additional cost | ✅ **Yes** |
| **6. GitOps** | €0/month | Medium | High | ✅ Unlimited | ✅ None | ✅ No additional cost | ❌ **No** (overkill) |

---

## Detailed Analysis

### Strategy 1: Container Registry (Self-hosted) ⭐

**Best for:**
- ✅ **Mature, industry-standard approach** (widely used in production)
- ✅ **Sets a standard** (follows containerization best practices)
- ✅ Fast deployments (images cached)
- ✅ Multiple servers (scalable)
- ✅ Version control (tagged images)
- ✅ Standard practice

**Deployment Options:**

#### **Option A: Registry on Separate Server**

**Pros:**
- ✅ Proper separation of concerns
- ✅ No resource contention with app
- ✅ Can scale independently
- ✅ Standard architecture pattern

**Cons:**
- ⚠️ Extra cost (€3-4/month)
- ⚠️ Two servers to manage

**Best for:** When you want proper separation, have budget, or plan to scale

---

#### **Option B: Registry on Same Server**

**Pros:**
- ✅ **No extra cost** (€0/month)
- ✅ **Simpler** (one server to manage)
- ✅ Registry is lightweight (~100-200MB RAM)
- ✅ Push/pull is infrequent (only during deployments)

**Cons:**
- ⚠️ **Disk space management:** Registry images (~11.4GB) + app data + database + OpenSearch
- ⚠️ All services on one server (single point of failure). Separating services over multiple servers is another independent effort, currently all services run on the same server anyway.
- ⚠️ Need to monitor total disk usage

**Best for:** Small teams, early stage, cost-conscious, when disk space is sufficient

**Resource Impact (Same Server):**
- **Disk space:** Registry images (~11.4GB) + app data + database + OpenSearch
- **RAM:** Registry adds ~100-200MB (minimal)
- **CPU:** Registry is lightweight, push/pull is infrequent
- **Network:** Push/pull traffic during deployments (usually fine)

**Recommendation:** For 2-person team, early stage, **same server is a viable option** if you have sufficient disk space (~50GB+ recommended for headroom).

---

**Trade-offs (Both Options):**
- ⚠️ **Registry setup/maintenance:**
  - **Initial setup:**
    - Install Docker Registry container
    - Configure Nginx reverse proxy
    - Set up authentication (htpasswd)
    - Configure Docker networking
    - Set up firewall rules
  - **Ongoing maintenance:**
    - Monitor registry disk usage (images accumulate over time)
    - Clean up old/unused images periodically
    - Update Docker Registry container (security patches)
    - Update Nginx configuration if needed
    - Backup registry data (if you want image history)
    - Monitor registry health/uptime

**Effort:**
- Setup: Medium (2-3 hours)
- Maintenance: Low (Ansible handles it)

**Recommendation:** ✅ **Best option if you want fast, standard deployments**

---

### Strategy 2: Build on Server ⭐

**Best for:**
- ✅ Zero extra cost
- ✅ Simple workflow
- ✅ No external dependencies
- ✅ Full control

**Trade-offs:**
- ⚠️ Slower deployments (10-30 minutes)
- ⚠️ Uses server resources during build
- ⚠️ No image caching (unless using Docker cache)

**Effort:**
- Setup: Medium (2-3 hours)
  - SSH key setup for GitHub (deploy key or personal access token)
  - OR SSH key setup for GitHub Actions → Server
  - Ansible playbook for code checkout
  - Docker Compose configuration
- Maintenance: Low (standard docker compose, occasional SSH key rotation)

**Recommendation:** ✅ **Best option if you want simplicity and zero cost**

---

### Strategy 3: GitHub Artifacts

**Best for:**
- ✅ No extra cost
- ✅ Integrated with GitHub
- ✅ Versioned artifacts

**Trade-offs:**
- ⚠️ **Storage limit (10GB) is close to the 11.4GB image size requirement**
- ⚠️ Artifact size limit (1GB per file)
- ⚠️ 90-day retention (free tier)
- ⚠️ Network transfer (11.4GB download)

**Effort:**
- Setup: Medium (2 hours)
- Maintenance: Low

**Recommendation:** ⚠️ **Risky - storage limits are tight, not recommended**

---

### Strategy 4: Direct Transfer (SCP)

**Best for:**
- ✅ No extra cost
- ✅ No storage limits
- ✅ Direct control

**Trade-offs:**
- ⚠️ Slow deployments (7-20 minutes)
- ⚠️ Network transfer (11.4GB per deploy)
- ⚠️ SSH key management
- ⚠️ No image caching

**Effort:**
- Setup: Medium (2 hours)
- Maintenance: Low

**Recommendation:** ✅ **Viable but slow, consider if you deploy infrequently**

---

### Strategy 5: Hybrid (CI Trigger)

**Best for:**
- ✅ Automated (CI/CD triggered)
- ✅ No extra cost
- ✅ No storage limits

**Trade-offs:**
- ⚠️ Same as Strategy 2 (build on server)
- ⚠️ SSH key management
- ⚠️ Server must be accessible

**Effort:**
- Setup: Medium (2-3 hours)
- Maintenance: Low

**Recommendation:** ✅ **Good if you want automation with Strategy 2**

---

## Recommendation

### **Option A: Build on Server** ⭐ **RECOMMENDED FOR SIMPLICITY**

**Why:**
1. ✅ **Zero additional cost** (uses existing server)
2. ✅ **Simplest** (standard docker compose workflow)
3. ✅ **No external dependencies** (no registry, no artifacts)
4. ✅ **Full control** (build exactly what you need)
5. ✅ **No storage/transfer limits** (uses server disk)

**When to use:**
- You deploy infrequently (< 5 times/week)
- You're okay with 10-30 minute deployments
- You want the simplest possible setup
- You want to minimize costs

**Implementation:**
- **SSH Setup Required:**
  - **Option A (Manual):** Server has SSH key/deploy key for GitHub → can clone private repo
  - **Option B (Automated):** GitHub Actions has SSH key for server → triggers build remotely
- Ansible ensures code is checked out (or manual `git pull`)
- Server runs `docker compose build && docker compose up -d`

---

### **Option B: Container Registry (Self-hosted)** ⭐ **RECOMMENDED: MATURE STANDARD**

**Why:**
1. ✅ **Mature, industry-standard approach** (widely used in production)
2. ✅ **Sets a standard** (follows containerization best practices)
3. ✅ **Fast deployments** (images cached, ~2-5 minutes)
4. ✅ **Scalable** (can deploy to multiple servers)
5. ✅ **Version control** (tagged images)
6. ✅ **Same-server option:** No additional cost (€0/month)
7. ⚠️ **Separate-server option:** Additional cost (€3-4/month, requires budget approval)

**When to use:**
- When you want a **mature, industry-standard approach**
- When you want to **set a standard** for your deployment process
- You deploy frequently (> 5 times/week)
- You want fast deployments
- You want standard, professional setup
- **Same-server:** Budget is tight, disk space is sufficient
- **Separate-server:** Budget allows for €3-4/month, want proper separation

**Implementation Options:**
- **Option A (Separate server):**
  - Provision second Hetzner server (registry)
  - Deploy registry with Ansible
  - GitHub Actions builds and pushes to registry
  - App server pulls and deploys
- **Option B (Same server):**
  - Deploy registry on existing app server (alongside app/database/Redis/OpenSearch)
  - GitHub Actions builds and pushes to registry
  - Same server pulls and deploys
  - **Pros:** No extra cost, simpler (one server)
  - **Cons:** Disk space management, all services on one server

---

## Final Recommendation

**For the given constraints (cost-conscious, 2-person team, early stage, 11.4GB images):**

### **Recommended: Container Registry on Same Server (Strategy 1, Option B)**

**Reasons:**
1. ✅ **Mature, industry-standard approach** (sets a standard from the start)
2. ✅ **Zero additional cost** (uses existing server, same as Strategy 2)
3. ✅ **Fast deployments** (images cached, ~2-5 minutes vs 10-30 minutes)
4. ✅ **Foundation for scaling** (can easily move to separate server later)
5. ✅ **Version control** (tagged images, better than building from source)
6. ✅ **Separation of concerns** (build once, deploy anywhere)

**When to consider Strategy 2 (Build on Server) instead:**
- When you want the absolute simplest setup (no registry to configure)
- When deployments are very infrequent (< 1/week)
- When you're not concerned about deployment speed
- When you prefer building from source on each deploy

**Migration path:**
- Strategy 1 (same server) → Strategy 1 (separate server) is straightforward
- Just move registry container to new server, update URLs
- Strategy 2 → Strategy 1 is also possible if you want to migrate later

---

## Summary

| Strategy | Cost | Speed | Complexity | Recommendation |
|----------|------|-------|------------|----------------|
| **Build on Server** | €0/month | Slow | Medium | ✅ **Recommended for early stage** |
| **Container Registry (Self-hosted, same server)** | €0/month | Fast | Medium | ✅ **Recommended: mature standard, no extra cost** |
| **Container Registry (Self-hosted, separate)** | €3-4/month | Fast | Medium | ✅ **Recommended for proper separation** |
| **GitHub Artifacts** | €0/month | Medium | Medium | ⚠️ **Risky (storage limits)** |
| **Direct Transfer** | €0/month | Slow | Medium | ✅ **Viable but slow** |
| **Hybrid (CI Trigger)** | €0/month | Slow | Medium | ✅ **Automated build on server** |

**Conclusion:** 

For early-stage projects that are cost-conscious:
- **Build on Server** (Strategy 2) is the simplest option (zero additional cost, but slower deployments)
- **Container Registry on same server** (Strategy 1, Option B) is a **mature, industry-standard approach** that sets a standard for your deployment process, with zero additional cost if you have sufficient disk space

**Container Registry is more mature** because it:
- Follows containerization best practices (build once, deploy anywhere)
- Separates build and deploy concerns
- Enables version control of images (tagged releases)
- Is the standard approach used by most production systems
- Sets a foundation for future scaling (can easily move to separate server later)

**Recommendation:** If you want to establish a **standard, mature deployment process** from the start, consider **Container Registry on the same server** (Strategy 1, Option B) - it's the industry standard approach with zero additional cost. Migrate to a separate server (Strategy 1, Option A) when you need proper separation or have budget for it.
