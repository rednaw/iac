[**<---**](README.md)

# Troubleshooting

**Secrets / SOPS / iac.yml**

| Problem | What to do |
|--------|------------|
| "app/.iac/iac.yml not found" or "cannot decrypt" | Create the file and encrypt it. See [Secrets](secrets.md). |
| "Cannot decrypt: no matching keys" | Your public key isn't in the file. Teammate opens file in VS Code, saves, commits and pushes. |
| "SOPS key not found" | `task secrets:keygen` (in IaC repo). Key must be at `~/.config/sops/age/keys.txt` on host (mounted). |
| VS Code doesn't decrypt | SOPS extension installed? Key path set? `.sops.yaml` exists? `ls ~/.config/sops/age/keys.txt` |
| File shows binary | Encrypted. Install SOPS extension. |

**Terraform**

| Problem | What to do |
|--------|------------|
| "Error: authentication required" | In devcontainer: SOPS key in place, `app/.iac/iac.yml` has `terraform_cloud_token`. Startup script sets `TF_TOKEN_app_terraform_io` in shell profile. Outside devcontainer: `terraform login` or create `~/.terraform.d/credentials.tfrc.json`. |

**Connection / SSH**

| Problem | What to do |
|--------|------------|
| Connection timeout | `task server:check-status`. Ensure `dev.<base_domain>` / `prod.<base_domain>` resolve and point at the server. Server may need 30–60 s after `terraform apply`. |
| "Host key verification failed" | `task hostkeys:prepare -- <workspace>` then retry. We use `StrictHostKeyChecking=accept-new`; after a server recreate, prepare again. |

**Registry**

| Problem | What to do |
|--------|------------|
| "No repositories found" or "access denied" | Use the devcontainer (registry auth is written on first open). |
| "Could not resolve digest" / image not found | `crane ls registry.<base_domain>/<repo>`. Check tag and auth. Tag for deploy is 7 hex chars? |
| Deploy fails to pull | Server auth in `/opt/iac/.docker/config.json`. Ansible ran? Secrets have `base_domain`, `registry_username`, `registry_password`. |
| Registry unreachable | DNS/HTTPS for `registry.<base_domain>`; Traefik and registry container running. |

**Application deployment**

| Problem | What to do |
|--------|------------|
| No app at `/workspaces/iac/app` | Editor had no `APP_HOST_PATH`. Run `./scripts/setup-app-path.sh /path/to/app` on host, Reopen in Container. |
| "missing required vars" / "iac.yml not found" | App mount has `docker-compose.yml` and `.iac/` (iac.yml, .env, .sops.yaml). Run setup-app-path, Reopen in Container. |
| Ansible playbook failures | Playbook logs; secrets decrypted? `task server:check-status`. |
| "Could not read deploy-info.yml" | App may not be deployed yet; SSH and app name correct? |

**Prefect / Workflows**

| Problem | What to do |
|--------|------------|
| Deployment not in UI | [`prefect/prefect.yaml`](../prefect/prefect.yaml) has your flow under `deployments:`? Run `task workflow:deploy -- dev`. Check playbook for "Register Prefect deployments". |
| Flow run fails immediately | Flow run logs in UI. Often: import error (add module to [`prefect/Dockerfile.worker`](../prefect/Dockerfile.worker)), wrong entrypoint in prefect.yaml, or auth (worker has socket + DOCKER_CONFIG). |
| Worker not picking up runs | `docker ps` and `docker logs prefect-worker`. UI → Work Pools → host-pool → 1 worker online. |
| Can't reach UI | `task tunnel:start -- dev`, then http://localhost:57802/. |

**Traefik**

| Problem | What to do |
|--------|------------|
| Certificates not provisioning | `docker logs traefik`. HTTP→HTTPS redirect must exclude `/.well-known/acme-challenge`; router exists. |
| HTTP→HTTPS not working | [`traefik-dynamic-redirects-http.yml.j2`](../ansible/roles/server/templates/traefik-dynamic-redirects-http.yml.j2) priority 10000 and excludes ACME path. |
| Container not discovered | Container on `traefik` network (`docker network inspect traefik`), has `traefik.enable=true` label. |
| IPv6 not working | DNS AAAA records. Port bindings: `docker inspect traefik \| grep -A 10 Ports`. |
