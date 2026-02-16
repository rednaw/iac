# Current Architecture: Nginx + Certbot

[**<---**](README.md)

## Overview

This document provides a detailed analysis of the current Nginx + Certbot implementation to understand what needs to be replicated or replaced in a Traefik migration.

## Architecture Diagram

```
Internet
   │
   ├─ HTTP (80) ──────────────────────┐
   │                                    │
   └─ HTTPS (443) ──────────────────────┤
                                        │
                                   ┌────▼────┐
                                   │  Nginx  │
                                   │  :80    │
                                   │  :443   │
                                   └────┬────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
            ┌───────▼──────┐   ┌────────▼────────┐  ┌──────▼──────┐
            │  App         │   │  Registry       │  │  OpenObserve│
            │  :5000       │   │  :5001          │  │  :5080      │
            └──────────────┘   └─────────────────┘  └─────────────┘
            
            ┌──────────────────────────────────────────────┐
            │  Certbot                                     │
            │  - Obtains/renews certificates               │
            │  - Stores in /etc/letsencrypt/live/         │
            │  - Uses webroot challenge                   │
            └──────────────────────────────────────────────┘
```

## Components Breakdown

### 1. Nginx Installation & Configuration

**Location**: `ansible/roles/server/tasks/nginx.yml`

**What it does**:
- Installs Nginx via apt
- Removes default site
- Creates webroot directory for ACME challenges (`/var/www/html/.well-known/acme-challenge`)
- Generates config files from Jinja2 templates
- Validates configuration before restart
- Enables and starts Nginx service

**Key Facts**:
- Uses sites-available/sites-enabled pattern
- Each domain gets its own config file
- Config files are Jinja2 templates with conditional SSL blocks
- Restart required after config changes

### 2. Certbot Certificate Management

**Location**: `ansible/roles/server/tasks/certbot.yml`

**What it does**:
- Installs Certbot and python3-certbot-nginx plugin
- Enables certbot.timer for automatic renewal
- Obtains/expands SAN certificate for all domains:
  - `dev.rednaw.nl` or `prod.rednaw.nl` (based on environment)
  - `registry.rednaw.nl`
  - `monitoring.rednaw.nl`
  - `www.rednaw.nl`
  - `rednaw.nl`
- Uses webroot challenge method
- Stores certificates in `/etc/letsencrypt/live/{cert_domain}/`

**Key Facts**:
- Single SAN certificate covers all domains
- Certificate name matches environment domain (`dev.rednaw.nl` or `prod.rednaw.nl`)
- Uses `--expand` flag to add domains to existing certificate
- `--keep-until-expiring` prevents unnecessary renewals
- Certbot timer handles automatic renewal

### 3. Nginx Configuration Templates

#### Template: `nginx-application.j2`
**Purpose**: Main application proxy

**Features**:
- HTTP → HTTPS redirect (if certs exist)
- ACME challenge endpoint on HTTP
- SSL termination with modern TLS settings
- Security headers (HSTS, X-Frame-Options, etc.)
- Proxies to `http://127.0.0.1:5000`
- Serves default page on 502 errors (when app not deployed)

**Key Configuration**:
```nginx
proxy_pass http://127.0.0.1:5000;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

#### Template: `nginx-registry.j2`
**Purpose**: Docker registry proxy

**Features**:
- Same SSL/HTTP redirect as application
- **Basic Authentication** at Nginx level (`auth_basic`)
- Auth file: `/etc/docker-registry/auth/htpasswd`
- Large file upload support:
  - `client_max_body_size 0` (unlimited)
  - `proxy_request_buffering off`
  - Extended timeouts (900s)
- Special handling for `/v2/` endpoint:
  - `auth_basic off` (registry handles auth)
  - Proxies to `http://127.0.0.1:5001`

**Key Configuration**:
```nginx
auth_basic "Registry Realm";
auth_basic_user_file /etc/docker-registry/auth/htpasswd;

location /v2/ {
    auth_basic off;  # Registry validates credentials
    proxy_pass http://127.0.0.1:5001;
}
```

#### Template: `nginx-openobserve.j2`
**Purpose**: OpenObserve monitoring proxy

**Features**:
- Standard SSL/HTTP redirect
- WebSocket support (`Upgrade` and `Connection` headers)
- Proxies to `http://127.0.0.1:5080`
- No authentication (OpenObserve handles it)

**Key Configuration**:
```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_pass http://127.0.0.1:5080;
```

#### Template: `nginx-redirect-to-app.j2`
**Purpose**: Apex/www domain redirects

**Features**:
- Redirects `www.rednaw.nl` and `rednaw.nl` to app domain
- ACME challenge support
- Simple 301 redirect

**Key Configuration**:
```nginx
location / {
    return 301 https://{{ redirect_target }}$request_uri;
}
```

### 4. SSL Configuration

**Certificate Path**: `/etc/letsencrypt/live/{cert_domain}/`
- `fullchain.pem` - Certificate + chain
- `privkey.pem` - Private key

**TLS Settings**:
- Protocols: TLSv1.2, TLSv1.3
- Modern cipher suites
- SSL session caching
- OCSP stapling enabled
- HSTS header with preload

### 5. Service Management

**Handlers**: `ansible/roles/server/handlers/main.yml`
- Restarts Nginx after config changes
- Uses systemd for service management

**Integration Points**:
- Fail2ban monitors Nginx logs
- Certbot timer renews certificates automatically
- Ansible manages all configuration

## Current Workflow

### Initial Setup
1. Ansible installs Nginx
2. Ansible creates webroot directory
3. Ansible generates Nginx configs (without SSL initially)
4. Nginx starts, serves HTTP only
5. Certbot obtains certificates via webroot challenge
6. Ansible regenerates Nginx configs with SSL blocks
7. Nginx restarts with SSL enabled

### Certificate Renewal
1. Certbot timer runs periodically
2. Certbot renews certificates if needed
3. Certbot reloads Nginx (via systemd hook)
4. No Ansible involvement needed

### Application Deployment
1. Application container starts on port 5000
2. Nginx already configured to proxy to 5000
3. No Nginx changes needed
4. If app not running, Nginx serves default page (502 → index.html)

### Adding New Domain
1. Add domain to `domains_to_configure` in `nginx.yml`
2. Create new Jinja2 template
3. Add domain to Certbot SAN list
4. Run Ansible playbook
5. Certbot expands certificate
6. Nginx restarts

## Key Dependencies

### External Services
- **Let's Encrypt**: Certificate authority
- **DNS**: Must resolve domains to server IP

### File System
- `/etc/nginx/sites-available/` - Config files
- `/etc/nginx/sites-enabled/` - Symlinks
- `/var/www/html/` - Webroot for ACME
- `/etc/letsencrypt/live/` - Certificates
- `/etc/docker-registry/auth/htpasswd` - Registry auth

### System Services
- `nginx.service` - Web server
- `certbot.timer` - Certificate renewal

### Ports
- `80` - HTTP (ACME challenges + redirects)
- `443` - HTTPS (main traffic)

## Limitations & Pain Points

### Current Limitations
1. **Manual Configuration**: Each domain requires template + Ansible changes
2. **Restart Required**: Nginx must reload after config changes
3. **No Health Checks**: Nginx doesn't check if backend is healthy
4. **Static Routing**: Routes are fixed, not dynamic
5. **No Dashboard**: Hard to debug routing issues
6. **Template Complexity**: Jinja2 conditionals for SSL existence
7. **Adding New Apps**: Requires Ansible changes, coordination
8. **Multi-Server**: Would need more complex Nginx setup

### What Works Well
1. **Certbot Integration**: Automatic renewal works reliably
2. **Basic Auth**: Simple and effective for registry
3. **Fail2ban Integration**: Works seamlessly
4. **Performance**: Fast and efficient
5. **Current Use Case**: Works fine for current simple setup

## Migration Considerations

### What Must Be Preserved
1. **SSL Certificates**: Same Let's Encrypt certificates (or migrate)
2. **Domain Routing**: All domains must continue working
3. **Basic Auth**: Registry authentication must work
4. **WebSocket**: OpenObserve WebSocket support
5. **Large Uploads**: Registry must handle large images
6. **Fail2ban**: Security monitoring must continue

### What Can Be Improved
1. **Dynamic Discovery**: Automatic service registration
2. **No Reloads**: Hot configuration updates
3. **Health Checks**: Better backend monitoring
4. **Dashboard**: Visual route debugging
5. **Simpler Config**: Less templating complexity
6. **Adding Apps**: Other developers can add apps without Ansible changes
7. **Multi-Server**: Better support for future multi-server architecture

### What Might Be Lost
1. **Static File Serving**: Nginx excels at this (Traefik can do it but less optimized)
2. **Fine-grained Control**: Nginx config is more flexible
3. **Performance**: Traefik has slightly higher overhead (minimal impact)
4. **Familiarity**: Need to learn Traefik (but early stage = good time)

## Next Steps

See [Traefik Architecture](traefik-architecture.md) for how Traefik would replace these components.
