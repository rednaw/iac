# Proposed Traefik Architecture

[**<---**](README.md)

## Overview

This document describes how Traefik would replace Nginx + Certbot in our infrastructure, including architecture, configuration approach, and integration points.

## Architecture Diagram

```
Internet
   │
   ├─ HTTP (80) ──────────────────────┐
   │                                    │
   └─ HTTPS (443) ──────────────────────┤
                                        │
                            ┌───────────▼──────────┐
                            │      Traefik         │
                            │  - Entrypoint :80    │
                            │  - Entrypoint :443   │
                            │  - ACME (Let's Enc)  │
                            │  - Docker Provider   │
                            │  - File Provider     │
                            └───────────┬──────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
            ┌───────▼──────┐   ┌────────▼────────┐  ┌──────▼──────┐
            │  App         │   │  Registry       │  │  OpenObserve│
            │  :5000       │   │  :5001          │  │  :5080      │
            │  (Docker)    │   │  (Docker)       │  │  (Docker)   │
            └──────────────┘   └─────────────────┘  └─────────────┘
            
            ┌──────────────────────────────────────────────┐
            │  Docker Labels                               │
            │  - traefik.enable=true                       │
            │  - traefik.http.routers.app.rule=...         │
            │  - traefik.http.services.app.loadbalancer... │
            └──────────────────────────────────────────────┘
```

## Configuration Approach

### Option 1: Docker Labels (Recommended)

**How it works**:
- Traefik watches Docker containers
- Containers expose themselves via labels
- No static config files needed
- Automatic service discovery

**Pros**:
- ✅ Fully dynamic
- ✅ No Ansible templating
- ✅ Configuration lives with containers
- ✅ Best for containerized services

**Cons**:
- ❌ Requires Docker labels on all containers
- ❌ Less visible (labels vs files)
- ❌ Harder to version control labels

### Option 2: File Provider

**How it works**:
- Traefik reads YAML/TOML config files
- Similar to Nginx config files
- Can be managed by Ansible
- More explicit and version-controlled

**Pros**:
- ✅ Explicit configuration
- ✅ Easy to version control
- ✅ Can use Ansible templates
- ✅ Works for non-containerized services

**Cons**:
- ❌ Less dynamic
- ❌ Still need Ansible templating
- ❌ File watching overhead

### Option 3: Hybrid Approach

**How it works**:
- Docker labels for containerized services (app, registry)
- File provider for static configs (redirects, non-containerized)
- Best of both worlds

**Recommendation**: **Hybrid Approach**
- Use Docker labels for app containers
- Use file provider for redirects and static configs
- Simplifies most common case (app deployment) while keeping flexibility

## Component Breakdown

### 1. Traefik Installation

**Location**: `ansible/roles/server/tasks/traefik.yml` (new)

**What it does**:
- Installs Traefik (Docker container or binary)
- Creates Traefik config directory
- Sets up Docker network for Traefik
- Configures systemd service or Docker Compose
- Enables and starts Traefik

**Installation Options**:

#### Option A: Docker Container (Recommended)
```yaml
# Run Traefik as Docker container
# Pros: Easy updates, isolated, consistent
# Cons: Requires Docker socket access
```

#### Option B: Binary Installation
```yaml
# Install Traefik binary via apt/package manager
# Pros: No Docker dependency, simpler
# Cons: Manual updates, less isolated
```

**Recommendation**: Docker container for consistency with rest of stack.

### 2. Traefik Configuration

**Location**: `/etc/traefik/traefik.yml` or `/etc/traefik/dynamic/`

**Static Configuration** (`traefik.yml`):
```yaml
api:
  dashboard: true
  insecure: false  # Or use auth middleware

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@rednaw.nl
      storage: /etc/traefik/certs/acme.json
      httpChallenge:
        entryPoint: web

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik
  file:
    directory: /etc/traefik/dynamic
    watch: true
```

**Dynamic Configuration** (`/etc/traefik/dynamic/`):
- Redirect rules (www → app)
- Middleware definitions
- TLS options

### 3. SSL Certificate Management

**ACME Configuration**:
- **Challenge Type**: HTTP-01 (simpler) or DNS-01 (more flexible)
- **Storage**: `/etc/traefik/certs/acme.json` (encrypted)
- **Email**: For Let's Encrypt notifications
- **Automatic Renewal**: Built into Traefik

**HTTP-01 Challenge** (Recommended):
- Traefik handles challenge automatically
- Requires port 80 to be accessible
- Simpler setup
- Works with current infrastructure

**DNS-01 Challenge** (Alternative):
- Requires DNS API credentials
- More complex setup
- Works even if port 80 blocked
- Not needed for our use case

**Certificate Storage**:
- Traefik stores certificates in `acme.json`
- Encrypted JSON file
- Automatic renewal before expiry
- No separate Certbot process

### 4. Service Configuration via Docker Labels

#### Application Container Labels

```yaml
# docker-compose.yml or container labels
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.app.rule=Host(`dev.rednaw.nl`) || Host(`prod.rednaw.nl`)"
  - "traefik.http.routers.app.entrypoints=websecure"
  - "traefik.http.routers.app.tls.certresolver=letsencrypt"
  - "traefik.http.services.app.loadbalancer.server.port=3000"
  - "traefik.http.routers.app.middlewares=app-headers"
  - "traefik.http.middlewares.app-headers.headers.customrequestheaders.X-Forwarded-Proto=https"
```

#### Registry Container Labels

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.registry.rule=Host(`registry.rednaw.nl`)"
  - "traefik.http.routers.registry.entrypoints=websecure"
  - "traefik.http.routers.registry.tls.certresolver=letsencrypt"
  - "traefik.http.routers.registry.middlewares=registry-auth"
  - "traefik.http.middlewares.registry-auth.basicauth.usersfile=/etc/traefik/auth/htpasswd"
  - "traefik.http.services.registry.loadbalancer.server.port=5001"
```

#### OpenObserve Container Labels

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.openobserve.rule=Host(`monitoring.rednaw.nl`)"
  - "traefik.http.routers.openobserve.entrypoints=websecure"
  - "traefik.http.routers.openobserve.tls.certresolver=letsencrypt"
  - "traefik.http.services.openobserve.loadbalancer.server.port=5080"
```

### 5. File Provider Configuration

**Redirect Rules** (`/etc/traefik/dynamic/redirects.yml`):

```yaml
http:
  routers:
    www-redirect:
      rule: "Host(`www.rednaw.nl`)"
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt
      service: redirect-service
      middlewares:
        - redirect-to-app
    
    apex-redirect:
      rule: "Host(`rednaw.nl`)"
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt
      service: redirect-service
      middlewares:
        - redirect-to-app
  
  middlewares:
    redirect-to-app:
      redirectRegex:
        regex: "^https://(www\\.)?rednaw\\.nl(.*)"
        replacement: "https://dev.rednaw.nl${2}"
        permanent: true
  
  services:
    redirect-service:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1"
```

### 6. Basic Authentication Middleware

**Registry Authentication**:

**Option A: Traefik Basic Auth Middleware**
```yaml
# In registry container labels or file provider
traefik.http.middlewares.registry-auth.basicauth.usersfile=/etc/traefik/auth/htpasswd
```

**Option B: Keep Registry Auth**
- Let registry handle authentication
- Traefik just proxies (like current `/v2/` behavior)

**Recommendation**: Use Traefik middleware for consistency, but can fall back to registry auth if needed.

### 7. Integration Points

#### Fail2ban Integration

**Current**: Fail2ban monitors Nginx logs

**With Traefik**:
- Traefik logs to `/var/log/traefik/access.log`
- Configure fail2ban to monitor Traefik logs
- Update fail2ban filters for Traefik log format

**Traefik Log Format**:
```yaml
accessLog:
  filePath: /var/log/traefik/access.log
  format: json  # Or common log format
```

#### Docker Network

**Setup**:
- Create `traefik` network: `docker network create traefik`
- Connect Traefik container to network
- Connect app containers to same network
- Use container names for service discovery

#### Health Checks

**Traefik Built-in**:
- Health check endpoints
- Circuit breakers
- Retry logic

**Configuration**:
```yaml
traefik.http.services.app.loadbalancer.healthcheck.path=/health
traefik.http.services.app.loadbalancer.healthcheck.interval=10s
```

## Deployment Workflow

### Initial Setup
1. Ansible installs Traefik (Docker container)
2. Traefik starts, watches Docker socket
3. Traefik obtains certificates via ACME HTTP-01
4. Containers start with labels
5. Traefik automatically discovers routes
6. SSL certificates provision automatically

### Application Deployment
1. Container starts with Traefik labels
2. Traefik detects new container
3. Routes appear automatically
4. Certificate obtained if needed
5. No manual configuration needed

### Adding New Domain
1. Add domain to container labels
2. Traefik detects change
3. Certificate obtained automatically
4. Route active immediately
5. No Ansible changes needed (if using labels)

## Advantages Over Current Setup

### 1. **Simplified Deployment**
- No Ansible templates for app routing
- Labels live with container definition
- Less Ansible code to maintain

### 2. **Automatic SSL**
- No separate Certbot process
- Certificates managed by Traefik
- Automatic renewal built-in

### 3. **Dynamic Updates**
- No reloads needed
- Changes take effect immediately
- Better for containerized environments

### 4. **Better Observability**
- Built-in dashboard
- Metrics endpoint
- Better logging options

### 5. **Modern Features**
- Health checks
- Circuit breakers
- Rate limiting
- Load balancing

## Migration Challenges

### 1. **Basic Auth Migration**
- Need to migrate htpasswd file
- Configure Traefik middleware
- Test authentication flow

### 2. **Fail2ban Integration**
- Update log paths
- Adjust filters for Traefik format
- Test ban rules

### 3. **Certificate Migration**
- Let Traefik obtain new certificates (simplest approach)
- No need to import existing certificates - Traefik will provision fresh ones
- DNS propagation timing (usually instant)

### 4. **Docker Network Setup**
- Ensure all containers on Traefik network
- Update deployment scripts
- Test connectivity

### 5. **Learning Curve**
- Need to learn Traefik concepts and label syntax
- Different debugging approach (dashboard vs log parsing)
- Label syntax vs config files

**Note**: As a solo project, learning curve is manageable and investment pays off as project grows.

## Next Steps

See [Configuration Examples](configuration-examples.md) for detailed Traefik configurations for each service.
