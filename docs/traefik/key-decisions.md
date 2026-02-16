# Key Decisions & Answers

[**<---**](README.md)

This document provides explicit answers to the key questions that need to be resolved before implementing Traefik.

## 1. Service Discovery: Docker Labels vs File Provider?

### Question
How will Traefik discover services? Docker labels (automatic) or file-based configuration (explicit)?

### Answer: **Hybrid Approach**

**Docker Labels** for containerized services:
- Application containers (tientje-ketama, hello-world, future apps)
- Registry container
- OpenObserve container

**File Provider** for static/routing configs:
- Redirect rules (www.rednaw.nl → app)
- Apex domain redirects
- Middleware definitions (if shared across services)
- TLS options

### Rationale
- **Docker labels**: Simplifies app deployment - other developers just add labels to their docker-compose.yml
- **File provider**: Better for routing rules that aren't tied to containers (redirects)
- **Best of both**: Dynamic discovery for apps, explicit config for infrastructure-level routing

### Implementation
- Configure Docker provider in `traefik.yml`
- Configure file provider in `traefik.yml` pointing to `/etc/traefik/dynamic/`
- Use labels on all app containers
- Use file provider for redirects and shared middleware

**See**: [Traefik Architecture](traefik-architecture.md#configuration-approach) for details

---

## 2. Certificate Management: HTTP-01 vs DNS-01 Challenge?

### Question
Which ACME challenge method should be used? HTTP-01 (simpler) or DNS-01 (more flexible)?

### Answer: **HTTP-01 Challenge**

### Rationale
- **Simpler setup**: No DNS API credentials needed
- **Works with current infrastructure**: Port 80 is already accessible
- **Automatic**: Traefik handles challenge automatically
- **Sufficient**: No need for DNS-01 complexity

### When to Use DNS-01
- If port 80 is blocked (not our case)
- If you need wildcard certificates (not needed currently)
- If you have complex DNS requirements (not our case)

### Implementation
```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      httpChallenge:
        entryPoint: web
```

**See**: [Traefik Architecture](traefik-architecture.md#ssl-certificate-management) for details

---

## 3. Basic Auth: Traefik Middleware vs App-Level?

### Question
How should registry authentication be handled? Traefik basic auth middleware or let the registry handle it?

### Answer: **Traefik Basic Auth Middleware**

### Rationale
- **Consistency**: All authentication handled at reverse proxy level
- **Simpler registry config**: Registry doesn't need auth setup
- **Centralized**: Easier to manage credentials in one place
- **Matches current pattern**: Similar to current Nginx auth_basic approach

### Alternative Considered
- **Registry-level auth**: Let registry handle authentication (like current `/v2/` behavior)
  - **Rejected**: Less consistent, harder to manage

### Implementation
```yaml
# In registry container labels or middleware file
traefik.http.middlewares.registry-auth.basicauth.usersfile=/etc/traefik/auth/htpasswd
```

**Note**: Migrate existing htpasswd file from `/etc/docker-registry/auth/htpasswd` to `/etc/traefik/auth/htpasswd`

**See**: [Configuration Examples](configuration-examples.md#registry-service-docker-labels) for details

---

## 4. Fail2ban Integration

### Question
How to integrate Traefik with existing fail2ban setup?

### Answer: **Update Fail2ban to Monitor Traefik Logs**

### Approach
1. Configure Traefik to log in a format fail2ban can parse
2. Update fail2ban filters for Traefik log format
3. Update fail2ban jail configuration to monitor Traefik logs

### Traefik Log Configuration
```yaml
# Option A: JSON format (more structured)
accessLog:
  filePath: /var/log/traefik/access.log
  format: json

# Option B: Common log format (easier for fail2ban)
accessLog:
  filePath: /var/log/traefik/access.log
  format: common
```

**Recommendation**: Use **common log format** for easier fail2ban integration (matches Nginx log format)

### Fail2ban Configuration
```ini
# /etc/fail2ban/jail.local
[traefik-auth]
enabled = true
port = http,https
logpath = /var/log/traefik/access.log
maxretry = 3
bantime = 3600
findtime = 600
```

### Filter Updates
- Update or create filter for Traefik log format
- Can reuse Nginx filters if using common log format
- Test ban rules after migration

**See**: [Migration Guide](migration-guide.md#54-update-fail2ban) for implementation steps

---

## 5. Deployment Impact: Changes Needed?

### Question
What changes are needed to the application deployment process?

### Answer: **Minimal Changes - Add Traefik Labels**

### Current Deployment Process
1. Ansible resolves image from registry
2. Ansible decrypts app secrets
3. Ansible prepares server
4. Ansible runs docker-compose with image
5. Container starts on port 5000
6. Nginx proxies to port 5000 (already configured)

### New Deployment Process
1. Ansible resolves image from registry
2. Ansible decrypts app secrets
3. Ansible prepares server
4. Ansible runs docker-compose with image **+ Traefik labels**
5. Container starts on port 3000 (or whatever app uses)
6. Traefik automatically discovers container via labels
7. Route appears automatically, SSL certificate provisions automatically

### Changes Required

#### 1. Docker Compose Files
Add Traefik labels to app `docker-compose.yml`:
```yaml
services:
  app:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`dev.rednaw.nl`) || Host(`prod.rednaw.nl`)"
      - "traefik.http.routers.app.entrypoints=websecure"
      - "traefik.http.routers.app.tls.certresolver=letsencrypt"
      - "traefik.http.services.app.loadbalancer.server.port=3000"
```

#### 2. Ansible Deployment Role
- **No changes needed** - labels are in docker-compose.yml
- Ansible just runs docker-compose as before
- Traefik discovers containers automatically

#### 3. Application Deployment Documentation
- Document Traefik label requirements for other developers
- Provide label template/examples
- Explain that labels handle routing automatically

### Benefits
- **Other developers**: Just add labels to their docker-compose.yml, no Ansible changes
- **No Ansible changes**: Labels live with application code
- **Automatic**: Routes and SSL certificates provision automatically
- **Simpler**: Less coordination needed

### Migration Impact
- **Existing apps**: Add labels to docker-compose.yml, redeploy
- **New apps**: Use Traefik labels from start
- **Registry/OpenObserve**: Add labels, update containers

**See**: [Configuration Examples](configuration-examples.md) for label examples

---

## Summary of Decisions

| Question | Decision | Rationale |
|----------|----------|-----------|
| **Service Discovery** | Hybrid (Docker labels + File provider) | Labels for apps, files for routing |
| **Certificate Challenge** | HTTP-01 | Simpler, works with current setup |
| **Basic Auth** | Traefik middleware | Consistent, centralized |
| **Fail2ban** | Update to monitor Traefik logs | Common log format for compatibility |
| **Deployment Impact** | Add Traefik labels to docker-compose | Minimal changes, automatic discovery |

## Next Steps

With these decisions made:

1. ✅ Service discovery approach: Hybrid
2. ✅ Certificate challenge: HTTP-01
3. ✅ Basic auth: Traefik middleware
4. ✅ Fail2ban: Update log monitoring
5. ✅ Deployment: Add labels to docker-compose files

**Ready to implement**: All key questions answered.

**Remaining open decisions** (choose before coding): dashboard exposure, registry auth (Traefik-only vs both), and a few wiring details are spelled out in [Implementation Plan – Open Decisions](implementation-plan.md#open-decisions-resolve-before-starting). Then follow the [Implementation Plan](implementation-plan.md) checklist.
