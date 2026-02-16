# Traefik Implementation Plan

[**<---**](README.md)

Step-by-step plan for implementing Traefik. Complete in order.

---

## Configuration summary

**Dashboard:** Exposed on a public hostname (`traefik.{{ base_domain }}` or `dashboard.{{ base_domain }}`) with basic-auth middleware. Enable `api.dashboard: true`, expose API on port 8080, add a router for that hostname with auth.

---

**Registry auth:** Traefik basic-auth for `registry.*`; `usersfile=/etc/traefik/auth/htpasswd`. Registry container: `REGISTRY_AUTH=none`, no auth volume.

---

**htpasswd:** Single file at `/etc/traefik/auth/htpasswd`. Traefik role creates `/etc/traefik/auth`; registry role (which has `infrastructure_secrets`) creates/updates the file. Registry role stops writing to `/etc/docker-registry/auth/htpasswd`; registry container does not mount any auth path.

---

**Redirect target:** Per-server. Set `app_environment` from `inventory_hostname`, `base_domain` (default `rednaw.nl`), `traefik_redirect_target: "{{ app_environment }}.{{ base_domain }}"`. In the redirect template use `replacement: "https://{{ traefik_redirect_target }}$2"`. Each server then redirects www/apex to its own app hostname.

---

**Traefik container:** Managed by Ansible in the server role (`community.docker.docker_network` + `community.docker.docker_container`), same pattern as registry and OpenObserve. No separate docker-compose for Traefik.

---

**Multi-domain:** Use `base_domain` as a variable everywhere (default `rednaw.nl` in role defaults or group_vars). Derive all hostnames from it: app `{{ app_environment }}.{{ base_domain }}`, registry `registry.{{ base_domain }}`, monitoring `monitoring.{{ base_domain }}`, redirects `www.{{ base_domain }}` / `{{ base_domain }}`, dashboard `traefik.{{ base_domain }}`. For app labels to work with any TLD, have deploy set `APP_DOMAIN={{ app_environment }}.{{ base_domain }}` (e.g. in `.env`) and use `Host(\`${APP_DOMAIN}\`)` in the app compose.

---

## Prerequisites

- [ ] Dev environment reachable (e.g. `task ansible:run -- dev`).
- [ ] Ready to apply the Ansible changes below.

---

## Phase 1: Ansible – Traefik Role and Server Wiring

### Step 1.1 – Create Traefik task file

**File:** `ansible/roles/server/tasks/traefik.yml`

**Contents (conceptual):**

1. **Facts (same pattern as nginx.yml)**  
   Set `base_domain` (default `"rednaw.nl"` e.g. in role defaults or group_vars so it can be overridden per group/host), `app_environment` from `inventory_hostname`, then `traefik_redirect_target: "{{ app_environment }}.{{ base_domain }}"`. Derive all hostnames from `base_domain`.

2. **Directories**  
   Create with `ansible.builtin.file`:
   - `/etc/traefik`
   - `/etc/traefik/dynamic`
   - `/etc/traefik/certs`
   - `/etc/traefik/auth`
   - `/var/log/traefik`

3. **Static config**  
   Deploy from template `traefik.yml.j2` → `/etc/traefik/traefik.yml` (see Step 1.2).

4. **Dynamic config**  
   Deploy from templates:
   - `traefik-dynamic-redirects.yml.j2` → `/etc/traefik/dynamic/redirects.yml`
   - Optionally `traefik-dynamic-middlewares.yml.j2` → `/etc/traefik/dynamic/middlewares.yml`
   - Optionally `traefik-dynamic-tls.yml.j2` → `/etc/traefik/dynamic/tls.yml`  
   Use `traefik_redirect_target` (or `cert_domain`) in redirect template.

5. **Docker network**  
   `community.docker.docker_network`: name `traefik`, state present.

6. **Traefik container**  
   `community.docker.docker_container`:
   - Image: e.g. `traefik:v3.0` (pin exact version in production).
   - Ports: `80:80`, `443:443`, and `8080:8080` (for dashboard; dashboard router will expose it on a hostname with auth).
   - Volumes:  
     - `/var/run/docker.sock:/var/run/docker.sock:ro`  
     - `/etc/traefik:/etc/traefik:ro`  
     - `/etc/traefik/certs:/etc/traefik/certs` (read-write for ACME)  
     - `/var/log/traefik:/var/log/traefik`  
     - `/etc/traefik/auth:/etc/traefik/auth:ro`
   - Network: `traefik`.
   - Command: e.g. `--configfile=/etc/traefik/traefik.yml`.
   - Restart: `unless-stopped`.
   - Do **not** add Traefik labels (so Traefik is not exposed via itself).

**Order:** Ensure Traefik runs after Docker and before registry (so `/etc/traefik/auth` exists for htpasswd).

---

### Step 1.2 – Static config template

**File:** `ansible/roles/server/templates/traefik.yml.j2`

**Must include:**

- **Entrypoints:** `web` (80), `websecure` (443).  
  HTTP→HTTPS redirect from `web` to `websecure`.
- **ACME:** `certificatesResolvers.letsencrypt` with `httpChallenge` and `entryPoint: web`.  
  `storage: /etc/traefik/certs/acme.json`.
- **Providers:**  
  - `docker`: `endpoint: unix:///var/run/docker.sock`, `exposedByDefault: false`, `network: traefik`.  
  - `file`: `directory: /etc/traefik/dynamic`, `watch: true`.
- **Logging:**  
  - `accessLog`: `filePath: /var/log/traefik/access.log`, `format: common` (for fail2ban).
  - Optional: `log.level`, `log.filePath`.
- **API/Dashboard:**  
  Enable `api.dashboard: true`, expose API (e.g. port 8080), add a router on `traefik.{{ base_domain }}` (or `dashboard.{{ base_domain }}`) with basic-auth middleware.

Reference: [Configuration Examples](configuration-examples.md#traefik-static-configuration).

---

### Step 1.3 – Dynamic redirect template

**File:** `ansible/roles/server/templates/traefik-dynamic-redirects.yml.j2`

**Content:** File-provider YAML (Jinja2) that:

- Defines routers for `Host(\`www.{{ base_domain }}\`)` and `Host(\`{{ base_domain }}\`)` (apex).
- Uses `certResolver: letsencrypt` and entrypoint `websecure`.
- Uses a redirect middleware that sends to `https://{{ traefik_redirect_target }}$2`, permanent.
- Defines a dummy service for the redirect router (e.g. `loadBalancer.servers: [url: "http://127.0.0.1"]`).

Use variables `base_domain` and `traefik_redirect_target` so dev/prod and future TLDs work without hardcoding a domain.

---

### Step 1.4 – Optional: middlewares and TLS

- **Middlewares:** If you use shared middlewares (e.g. security headers), add `traefik-dynamic-middlewares.yml.j2` and deploy to `/etc/traefik/dynamic/`.
- **TLS options:** Optional `traefik-dynamic-tls.yml.j2` for TLS options (min version, ciphers, etc.).

---

### Step 1.5 – Integrate Traefik into server role

**File:** `ansible/roles/server/tasks/main.yml`

**Changes:**

1. **Remove** (in this order to avoid broken state):
   - `Install nginx` (and any “Configure nginx” that only generates Nginx config).
   - `Configure SSL certificates` (certbot).
   - `Configure nginx sites`.

2. **Add** (after Docker, before deploy-user and registry):
   - `Install and configure Traefik` → `import_tasks: traefik.yml`.

3. **Keep:** base, unattended-upgrades, ssh, fail2ban, docker, deploy-user, registry, openobserve.

**New order (conceptual):**

```text
base → unattended-upgrades → ssh → fail2ban → docker → traefik → deploy-user → registry → openobserve
```

---

### Step 1.6 – Registry role: htpasswd and auth

**File:** `ansible/roles/server/tasks/registry.yml`

**Changes:**

1. **htpasswd path:**  
   Write htpasswd to `/etc/traefik/auth/htpasswd` (Traefik role creates `/etc/traefik/auth`; registry role creates/updates the file). Stop writing to `/etc/docker-registry/auth/htpasswd`.

2. **Registry container:**  
   Set `REGISTRY_AUTH=none`. Do not mount `/etc/traefik/auth` (or any auth path) into the registry container. Remove the volume that mounted `/etc/docker-registry/auth:/auth` and any registry auth config that referenced it.

---

### Step 1.7 – Registry container: Traefik network and labels

**File:** `ansible/roles/server/tasks/registry.yml` (same `docker_container` that runs the registry)

**Add:**

- **Networks:** Include `traefik` (in addition to existing registry network if needed).
- **Labels** (Docker labels for Traefik; use variable so domain is not hardcoded):
  - `traefik.enable=true`
  - Router: `Host(\`registry.{{ base_domain }}\`)`, entrypoints `websecure`, `tls.certresolver=letsencrypt`.
  - Middleware: `registry-auth` (basic auth, `usersfile=/etc/traefik/auth/htpasswd`).
  - Service: `loadbalancer.server.port=5000` (container port; registry image exposes 5000).
  - Optional: buffering/timeouts for large uploads.

Reference: [Configuration Examples](configuration-examples.md#registry-service-docker-labels).

---

### Step 1.8 – OpenObserve: Traefik network and labels

**File:** `ansible/roles/server/tasks/openobserve.yml`

**Add:**

- **Networks:** Include `traefik`.
- **Labels** (use `base_domain` variable):
  - `traefik.enable=true`
  - Router: `Host(\`monitoring.{{ base_domain }}\`)`, `websecure`, `tls.certresolver=letsencrypt`.
  - Service: `loadbalancer.server.port=5080`.
  - WebSocket: set appropriate headers (e.g. `Upgrade`, `Connection`) if required.

Reference: [Configuration Examples](configuration-examples.md#openobserve-service-docker-labels).

---

### Step 1.9 – Handlers

**File:** `ansible/roles/server/handlers/main.yml`

**Changes:**

- Remove handler “Restart nginx” (if nothing else notifies it).
- If you need “Restart Traefik”: add a handler that restarts the Traefik container (e.g. `community.docker.docker_container` with `state: started` and `restart: true` or equivalent). Only use if any task notifies it (e.g. after changing static/dynamic config that is not hot-reloaded).

---

### Step 1.10 – Fail2ban

**File:** e.g. `ansible/roles/server/templates/fail2ban.conf.j2` (or wherever fail2ban jail/filters are defined)

**Changes:**

- Add a jail (e.g. `[traefik-auth]`) that uses `logpath = /var/log/traefik/access.log`, with the same `maxretry` / `bantime` / `findtime` as your Nginx jail.
- Ensure the filter matches the **common** log format (same as Nginx if you kept it). If the format differs, add or adjust a filter for Traefik’s common format.
- Remove or disable Nginx-related jails that reference Nginx log paths.

Use common log format for access log so existing fail2ban filters can be adapted.

---

## Phase 2: Application Docker Compose (Traefik Labels)

App containers are started by the deploy role from the app’s `docker-compose.yml` (copied from `app_root` to `deploy_target`). Traefik discovery and routing require:

- App service on the **traefik** network.
- Traefik labels on the app service.

**Important:** The file that is deployed is the **app’s** `docker-compose.yml` (in each app repo). The IAC repo’s `app/` directory is the mount for the app you are deploying; that app’s compose file must be updated.

### Step 2.1 – Per-app docker-compose changes

**Where:** In **each** application repo (e.g. tientje-ketama, hello-world), in the repo’s `docker-compose.yml`.

**Add:**

1. **Networks:**
   ```yaml
   networks:
     default:  # keep existing
       name: <app-network>
     traefik:
       external: true
   ```

2. **App service:**
   - `networks: [ default, traefik ]`.
   - `labels` (adjust router name and port to your app):
     - `traefik.enable=true`
     - `traefik.http.routers.<app>.rule=Host(\`dev.rednaw.nl\`) || Host(\`prod.rednaw.nl\`)`
     - `traefik.http.routers.<app>.entrypoints=websecure`
     - `traefik.http.routers.<app>.tls.certresolver=letsencrypt`
     - `traefik.http.services.<app>.loadbalancer.server.port=3000` (or the port the app listens on inside the container)

**Note:** Same labels work on both dev and prod; routing is by Host header.

**Multi-domain (other TLD):** To avoid hardcoding the domain in the app repo, have the deploy role set `APP_DOMAIN={{ app_environment }}.{{ base_domain }}` in the app’s `.env` (or equivalent), and in the app’s compose use a single-host rule, e.g. `Host(\`${APP_DOMAIN}\`)`. Then the same app repo works for any base domain; see §6 Multi-domain.

**Reference:** [Configuration Examples](configuration-examples.md#application-service-docker-labels).

### Step 2.2 – Document for other developers

**Where:** e.g. `docs/application-deployment.md` or a short “Adding a new app” doc in the IAC repo.

**Content:**

- New apps must add the **traefik** external network and the above labels to their `docker-compose.yml`.
- Point to [Configuration Examples](configuration-examples.md#application-service-docker-labels) for the exact snippet and port/host rules.

---

## Phase 3: Deploy and Verify (Dev)

### Step 3.1 – Run server playbook (dev)

```bash
task ansible:run -- dev
```

- No Nginx/Certbot; Traefik and updated registry/OpenObserve run.
- If anything fails, fix Ansible (tasks, templates, variable names) and re-run.

### Step 3.2 – Verify Traefik and routing

- **Traefik:** `docker ps | grep traefik`; `docker logs traefik` (no errors).
- **Network:** `docker network inspect traefik` shows Traefik and (after deploy) app containers.
- **HTTP → HTTPS:** `curl -I http://dev.rednaw.nl` → 301/302 to `https://dev.rednaw.nl`.
- **HTTPS:** `curl -I https://dev.rednaw.nl` (after app is deployed).
- **Redirects:** `curl -I https://www.rednaw.nl` → redirect to `https://dev.rednaw.nl` (or prod on prod).
- **Registry:** `curl -I https://registry.rednaw.nl/v2/` (401 without auth); `curl -u user:pass -I https://registry.rednaw.nl/v2/` (200 or 401 as expected).
- **OpenObserve:** `curl -I https://monitoring.rednaw.nl`.

### Step 3.3 – Deploy an app (dev)

- Ensure the app’s `docker-compose.yml` has Traefik network and labels (Step 2.1).
- Run: `task app:deploy -- dev <sha>`.
- Check Traefik sees the app: dashboard (if enabled) or `docker ps` and Traefik logs.
- Open `https://dev.rednaw.nl` in a browser and test the app.

### Step 3.4 – Fail2ban

- Trigger a few failed auth attempts (e.g. wrong password on registry or app).
- Check `fail2ban-client status traefik-auth` (or your jail name) and that IPs get banned per your config.

---

## Phase 4: Production and Cleanup

### Step 4.1 – Run server playbook (prod)

```bash
task ansible:run -- prod
```

### Step 4.2 – Verify production

Same as Step 3.2, but for prod hostnames and `prod.rednaw.nl`.

### Step 4.3 – Remove Nginx/Certbot remnants

- Remove Nginx and Certbot packages from server role (e.g. base or a dedicated “cleanup” task): `apt remove nginx nginx-common certbot python3-certbot-nginx` (and `apt autoremove` if desired).
- Remove any remaining Nginx/Certbot tasks, templates, and handlers from the Ansible repo.
- Remove `/etc/nginx`, `/var/www/html`, `/etc/letsencrypt` (optional; Traefik uses its own certs).

Do this in Ansible so the next full run leaves no Nginx/Certbot on the server.

### Step 4.4 – Documentation

- Update main architecture/deployment docs to describe Traefik instead of Nginx/Certbot.
- Update troubleshooting and “how to add an app” to match Traefik (labels, network, dashboard if used).

---

## Checklist Summary

| # | Step | Done |
|---|------|------|
| 1.1 | Create `ansible/roles/server/tasks/traefik.yml` | [ ] |
| 1.2 | Create `traefik.yml.j2` | [ ] |
| 1.3 | Create `traefik-dynamic-redirects.yml.j2` | [ ] |
| 1.4 | Optional middlewares/TLS templates | [ ] |
| 1.5 | Edit `main.yml`: remove nginx/certbot, add traefik | [ ] |
| 1.6 | Registry: htpasswd to /etc/traefik/auth, REGISTRY_AUTH=none, no auth volume | [ ] |
| 1.7 | Registry container: traefik network + labels | [ ] |
| 1.8 | OpenObserve: traefik network + labels | [ ] |
| 1.9 | Handlers: remove nginx, add Traefik restart if needed | [ ] |
| 1.10 | Fail2ban: traefik jail + filter, remove nginx | [ ] |
| 2.1 | Each app repo: docker-compose traefik network + labels | [ ] |
| 2.2 | Document Traefik label requirements for new apps | [ ] |
| 3.1 | Run `task ansible:run -- dev` | [ ] |
| 3.2 | Verify Traefik and all routes (dev) | [ ] |
| 3.3 | Deploy one app and test (dev) | [ ] |
| 3.4 | Verify fail2ban (dev) | [ ] |
| 4.1 | Run `task ansible:run -- prod` | [ ] |
| 4.2 | Verify production | [ ] |
| 4.3 | Remove Nginx/Certbot from role and server | [ ] |
| 4.4 | Update architecture/deployment docs | [ ] |

---

## If Something Fails

- Fix the relevant Ansible task or template.
- Re-run: `task ansible:run -- <workspace>`.
- If the server is in a bad state, fix via Ansible or rebuild from Terraform and re-run the playbook (greenfield, no backup/rollback).
