# Traefik Configuration Examples

[**<---**](README.md)

This document provides detailed Traefik configuration examples for each service in our infrastructure.

**Note**: These examples are designed for the current setup (tientje-ketama, hello-world, registry, OpenObserve) but will scale well as you add more apps and move to multi-server architecture.

## Traefik Static Configuration

**File**: `/etc/traefik/traefik.yml`

```yaml
# API and Dashboard
api:
  dashboard: true
  insecure: false  # Set to true for testing, use auth middleware in production
  debug: false

# Global settings
global:
  checkNewVersion: false
  sendAnonymousUsage: false

# Entrypoints
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    address: ":443"

# Certificate resolvers (Let's Encrypt)
certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@rednaw.nl  # Change to your email
      storage: /etc/traefik/certs/acme.json
      httpChallenge:
        entryPoint: web
      # Optional: DNS challenge (if HTTP-01 doesn't work)
      # dnsChallenge:
      #   provider: cloudflare
      #   delayBeforeCheck: 0

# Providers
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false  # Only containers with traefik.enable=true
    network: traefik
    watch: true
  file:
    directory: /etc/traefik/dynamic
    watch: true

# Logging
log:
  level: INFO
  format: json
  filePath: /var/log/traefik/traefik.log

accessLog:
  filePath: /var/log/traefik/access.log
  format: json
  bufferingSize: 100

# Metrics (optional)
metrics:
  prometheus:
    entryPoint: websecure
    path: /metrics
```

## Application Service (Docker Labels)

**Location**: Container labels in `docker-compose.yml` or deployment

```yaml
services:
  app:
    image: registry.rednaw.nl/rednaw/tientje-ketama:${SHA}
    networks:
      - traefik
    labels:
      # Enable Traefik
      - "traefik.enable=true"
      
      # Router configuration
      - "traefik.http.routers.app-dev.rule=Host(`dev.rednaw.nl`)"
      - "traefik.http.routers.app-dev.entrypoints=websecure"
      - "traefik.http.routers.app-dev.tls.certresolver=letsencrypt"
      - "traefik.http.routers.app-dev.tls.domains[0].main=dev.rednaw.nl"
      
      - "traefik.http.routers.app-prod.rule=Host(`prod.rednaw.nl`)"
      - "traefik.http.routers.app-prod.entrypoints=websecure"
      - "traefik.http.routers.app-prod.tls.certresolver=letsencrypt"
      - "traefik.http.routers.app-prod.tls.domains[0].main=prod.rednaw.nl"
      
      # Service configuration
      - "traefik.http.services.app.loadbalancer.server.port=3000"
      - "traefik.http.services.app.loadbalancer.healthcheck.path=/health"
      - "traefik.http.services.app.loadbalancer.healthcheck.interval=10s"
      
      # Middleware (headers, etc.)
      - "traefik.http.routers.app-dev.middlewares=app-headers"
      - "traefik.http.routers.app-prod.middlewares=app-headers"
      - "traefik.http.middlewares.app-headers.headers.customrequestheaders.X-Forwarded-Proto=https"
      - "traefik.http.middlewares.app-headers.headers.customrequestheaders.X-Forwarded-For=${remote_addr}"
      
      # Security headers (optional, can also be in middleware)
      - "traefik.http.middlewares.app-headers.headers.sslRedirect=true"
      - "traefik.http.middlewares.app-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.app-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.app-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.app-headers.headers.frameDeny=true"
      - "traefik.http.middlewares.app-headers.headers.contentTypeNosniff=true"
      - "traefik.http.middlewares.app-headers.headers.browserXssFilter=true"

networks:
  traefik:
    external: true
```

**Alternative**: Environment-based routing (single router with multiple hosts)

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.app.rule=Host(`dev.rednaw.nl`) || Host(`prod.rednaw.nl`)"
  - "traefik.http.routers.app.entrypoints=websecure"
  - "traefik.http.routers.app.tls.certresolver=letsencrypt"
  - "traefik.http.services.app.loadbalancer.server.port=3000"
```

## Registry Service (Docker Labels)

**Location**: Registry container labels

```yaml
services:
  registry:
    image: registry:2
    networks:
      - traefik
    volumes:
      - registry-data:/var/lib/registry
      - /etc/docker-registry/auth:/auth
    environment:
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: "Registry Realm"
    labels:
      # Enable Traefik
      - "traefik.enable=true"
      
      # Router configuration
      - "traefik.http.routers.registry.rule=Host(`registry.rednaw.nl`)"
      - "traefik.http.routers.registry.entrypoints=websecure"
      - "traefik.http.routers.registry.tls.certresolver=letsencrypt"
      
      # Basic authentication middleware
      - "traefik.http.routers.registry.middlewares=registry-auth"
      - "traefik.http.middlewares.registry-auth.basicauth.usersfile=/etc/traefik/auth/htpasswd"
      
      # Service configuration
      - "traefik.http.services.registry.loadbalancer.server.port=5000"
      
      # Large file upload support
      - "traefik.http.services.registry.loadbalancer.server.port=5000"
      - "traefik.http.middlewares.registry-buffering.buffering.maxRequestBodyBytes=0"
      - "traefik.http.middlewares.registry-buffering.buffering.maxResponseBodyBytes=0"
      - "traefik.http.routers.registry.middlewares=registry-auth,registry-buffering"
      
      # Timeouts for large uploads
      - "traefik.http.services.registry.loadbalancer.server.port=5000"
      # Note: Timeouts configured in static config or via middleware

networks:
  traefik:
    external: true

volumes:
  registry-data:
```

**Note**: For `/v2/` endpoint without auth (like current setup), you might need:
- Separate router for `/v2/` path
- Or configure registry to handle auth itself (remove Traefik auth middleware)

## OpenObserve Service (Docker Labels)

**Location**: OpenObserve container labels

```yaml
services:
  openobserve:
    image: public.ecr.aws/zinclabs/openobserve:latest
    networks:
      - traefik
    labels:
      # Enable Traefik
      - "traefik.enable=true"
      
      # Router configuration
      - "traefik.http.routers.openobserve.rule=Host(`monitoring.rednaw.nl`)"
      - "traefik.http.routers.openobserve.entrypoints=websecure"
      - "traefik.http.routers.openobserve.tls.certresolver=letsencrypt"
      
      # WebSocket support
      - "traefik.http.routers.openobserve.middlewares=openobserve-ws"
      - "traefik.http.middlewares.openobserve-ws.headers.customrequestheaders.Upgrade=websocket"
      - "traefik.http.middlewares.openobserve-ws.headers.customrequestheaders.Connection=Upgrade"
      
      # Service configuration
      - "traefik.http.services.openobserve.loadbalancer.server.port=5080"

networks:
  traefik:
    external: true
```

## Redirect Rules (File Provider)

**File**: `/etc/traefik/dynamic/redirects.yml`

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
        replacement: "https://dev.rednaw.nl${2}"  # Or use environment variable
        permanent: true
  
  services:
    redirect-service:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1"
```

**Environment-specific redirects** (if needed):

```yaml
# For dev environment
redirect-to-app-dev:
  redirectRegex:
    regex: "^https://(www\\.)?rednaw\\.nl(.*)"
    replacement: "https://dev.rednaw.nl${2}"
    permanent: true

# For prod environment  
redirect-to-app-prod:
  redirectRegex:
    regex: "^https://(www\\.)?rednaw\\.nl(.*)"
    replacement: "https://prod.rednaw.nl${2}"
    permanent: true
```

## Middleware Definitions (File Provider)

**File**: `/etc/traefik/dynamic/middlewares.yml`

```yaml
http:
  middlewares:
    # Security headers middleware
    security-headers:
      headers:
        sslRedirect: true
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true
        frameDeny: true
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: "same-origin"
        customRequestHeaders:
          X-Forwarded-Proto: "https"
    
    # Basic auth for registry
    registry-auth:
      basicauth:
        usersFile: /etc/traefik/auth/htpasswd
    
    # Large file upload support
    registry-buffering:
      buffering:
        maxRequestBodyBytes: 0
        maxResponseBodyBytes: 0
        memRequestBodyBytes: 10485760  # 10MB
    
    # Rate limiting (optional)
    rate-limit:
      rateLimit:
        average: 100
        period: 1m
        burst: 50
```

## TLS Options (File Provider)

**File**: `/etc/traefik/dynamic/tls.yml`

```yaml
tls:
  options:
    default:
      minVersion: "VersionTLS12"
      cipherSuites:
        - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
        - "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
        - "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
      sslProtocols:
        - "TLSv1.2"
        - "TLSv1.3"
      curvePreferences:
        - "CurveP521"
        - "CurveP384"
      sniStrict: true
```

## Docker Compose for Traefik

**File**: `/etc/traefik/docker-compose.yml` (or managed by Ansible)

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    networks:
      - traefik
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /etc/traefik:/etc/traefik:ro
      - /etc/traefik/certs:/etc/traefik/certs
      - /var/log/traefik:/var/log/traefik
      - /etc/traefik/auth:/etc/traefik/auth:ro
    command:
      - --configfile=/etc/traefik/traefik.yml
    labels:
      - "traefik.enable=false"  # Don't expose Traefik itself
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/ping"]
      interval: 10s
      timeout: 3s
      retries: 3

networks:
  traefik:
    external: true
```

## Ansible Task Example

**File**: `ansible/roles/server/tasks/traefik.yml` (conceptual)

```yaml
---
# Traefik installation and configuration

- name: Create Traefik directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: '0755'
  loop:
    - /etc/traefik
    - /etc/traefik/dynamic
    - /etc/traefik/certs
    - /etc/traefik/auth
    - /var/log/traefik

- name: Copy Traefik static configuration
  ansible.builtin.template:
    src: traefik.yml.j2
    dest: /etc/traefik/traefik.yml
    mode: '0644'

- name: Copy dynamic configuration files
  ansible.builtin.template:
    src: "{{ item.src }}"
    dest: "{{ item.dest }}"
    mode: '0644'
  loop:
    - { src: redirects.yml.j2, dest: /etc/traefik/dynamic/redirects.yml }
    - { src: middlewares.yml.j2, dest: /etc/traefik/dynamic/middlewares.yml }
    - { src: tls.yml.j2, dest: /etc/traefik/dynamic/tls.yml }

- name: Copy htpasswd file (if exists)
  ansible.builtin.copy:
    src: /etc/docker-registry/auth/htpasswd
    dest: /etc/traefik/auth/htpasswd
    mode: '0644'
  when: ansible_facts.stat.exists.stat.exists | default(false)

- name: Create Traefik Docker network
  community.docker.docker_network:
    name: traefik
    state: present

- name: Ensure Traefik container is running
  community.docker.docker_container:
    name: traefik
    image: traefik:v3.0
    state: started
    restart_policy: unless-stopped
    networks:
      - name: traefik
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /etc/traefik:/etc/traefik:ro
      - /etc/traefik/certs:/etc/traefik/certs
      - /var/log/traefik:/var/log/traefik
      - /etc/traefik/auth:/etc/traefik/auth:ro
    command:
      - --configfile=/etc/traefik/traefik.yml
    labels:
      traefik.enable: "false"
```

## Testing Configuration

### Validate Traefik Config

```bash
# Check Traefik logs
docker logs traefik

# Test configuration (if running as binary)
traefik --configfile=/etc/traefik/traefik.yml --check

# Check dashboard (if enabled)
curl http://localhost:8080/api/rawdata
```

### Test Routes

```bash
# Test HTTP redirect
curl -I http://dev.rednaw.nl

# Test HTTPS
curl -I https://dev.rednaw.nl

# Test registry auth
curl -I https://registry.rednaw.nl/v2/
curl -u user:pass https://registry.rednaw.nl/v2/
```

## Next Steps

See [Migration Guide](migration-guide.md) for step-by-step migration instructions.
