[**<---**](README.md)
# Self-Hosted Docker Registry

This document describes the private Docker registry used to store container images for deployment. **To interact with the registry (list images, run crane, deploy), use the devcontainer** — registry auth and tools (crane, Docker, jq) are configured automatically there. It covers infrastructure, authentication in each environment, commands, and troubleshooting.

---

## Overview

- **Hostname:** `registry.rednaw.nl` (value comes from SOPS secret `registry_domain`)
- **Software:** [Docker Registry](https://distribution.github.io/distribution/) (image `registry:3`)
- **Protocol:** Docker Registry API v2, served over HTTPS with HTTP Basic Auth
- **Purpose:** Store application images (e.g. `rednaw/hello-world`) and the IAC dev image (`iac/iac-dev`); used by GitHub Actions, the devcontainer, and on the server by the ubuntu and deploy users

---

## Infrastructure

The registry runs on the same Ubuntu server(s) as the applications, configured by Ansible.

| Component | Details |
|-----------|--------|
| **Ansible role** | `ansible/roles/server/tasks/registry.yml` |
| **Container** | `registry:3`, name `registry`, port `127.0.0.1:5001→5000` |
| **Storage** | `/var/lib/docker-registry` on the host (bind-mounted) |
| **Config** | `/etc/docker-registry/config.yml` (from `registry-config.yml.j2`) |
| **Auth** | htpasswd file at `/etc/docker-registry/auth/htpasswd` (generated from SOPS credentials) |
| **Nginx** | Proxies HTTPS `registry.rednaw.nl` → `http://127.0.0.1:5001`; Basic Auth at Nginx, then `auth_basic off` for `/v2/` so the registry receives the request and can validate with the same credentials |

Credentials and domain are taken from SOPS-decrypted `secrets/infrastructure-secrets.yml`:

- `registry_username` / `registry_password` — used for htpasswd and for Docker client auth
- `registry_domain` — e.g. `registry.rednaw.nl`
- `registry_http_secret` — registry config HTTP secret

---

## Authentication (How to Log In)

All environments use the **same credential source**: SOPS-decrypted `secrets/infrastructure-secrets.yml` (`registry_username`, `registry_password`). No manual `docker login` is required.

### DevContainer

- **Trigger:** `postStartCommand` runs `scripts/devcontainer-secrets-setup.sh` on container start.
- **Effect:** The script writes to `~/.docker/config.json` inside the devcontainer so `docker`, `crane`, and `trivy` can access the private registry without manual `docker login`.
- **When:** Automatic; no manual steps. No `DOCKER_CONFIG` env var needed.
- **Tools:** Registry-related tools (e.g. **crane**, Docker CLI, jq) are automatically installed in the devcontainer via [mise](https://mise.jdx.dev/) and the image build; you can run `task registry:overview`, `crane ls`, etc. from inside the devcontainer.

### GitHub Actions

- **Method:** Workflows install SOPS and yq, decrypt `secrets/infrastructure-secrets.yml`, extract `registry_username` and `registry_password`, and pass them to `docker/login-action@v3`.
- **When:** Automatic in `static-code-analysis.yml` and `promote-image.yml`. Only `SOPS_AGE_KEY` is required as a repository secret.

### Server – ubuntu user

- **Method:** Ansible writes `~/.docker/config.json` during server setup (`ansible/roles/server/tasks/registry.yml`).
- **When:** Automatic when the server role runs.

### Server – deploy user

- **Method:** Ansible writes `/opt/deploy/.docker/config.json` during server setup (`ansible/roles/server/tasks/deploy-user.yml`).
- **When:** Automatic when the server role runs. Used to pull images during application deployment.

---

## Commands and Tasks

### `task registry:overview`

Lists all repositories and their tags (TAG, CREATED, DESCRIPTION) in the registry.

```bash
task registry:overview
```

If you see "No repositories found (or access denied)", see [Troubleshooting](#troubleshooting).

---

## Crane and Docker Reference

### Crane (registry API)

| Task | Command |
|------|--------|
| List repos | `crane catalog registry.rednaw.nl` |
| List tags for an image | `crane ls registry.rednaw.nl/<image>` e.g. `crane ls registry.rednaw.nl/rednaw/hello-world` |
| Get digest of a tag | `crane digest registry.rednaw.nl/<image>:<tag>` |
| Inspect manifest | `crane manifest registry.rednaw.nl/<image>:<tag>` |
| Delete a tag | `crane delete registry.rednaw.nl/<image>:<tag>` |

Filter SHA-like tags (e.g. for pruning):  
`crane ls registry.rednaw.nl/<image> | grep -E '^[0-9a-f]{7}$'`

### Docker (server / local)

| Task | Command |
|------|--------|
| Image a container uses | `docker inspect <container> --format '{{.Config.Image}}'` |
| Disk usage | `docker system df` |
| List running containers | `docker ps` |

### Registry host (on server)

| Task | Command |
|------|--------|
| Registry data size | `du -sh /var/lib/docker-registry` (or the registry’s `rootdirectory`) |

### Example: list SHA-only tags for pruning

```bash
crane ls registry.rednaw.nl/rednaw/hello-world | grep -E '^[0-9a-f]{7}$'
# Then delete if safe, e.g.:
# crane delete registry.rednaw.nl/rednaw/hello-world:<sha>
```

---

## Troubleshooting

| Problem | What to do |
|--------|------------|
| "No repositories found (or access denied)" | Use the devcontainer. |
| "Could not resolve digest" / image not found | Check image exists: `crane ls registry.rednaw.nl/<repo>`. Ensure tag is correct and auth is configured. |
| Deploy fails to pull image | On the server, deploy user’s auth is in `/opt/deploy/.docker/config.json`; ensure Ansible has run and `infrastructure_secrets` contains correct `registry_domain`, `registry_username`, `registry_password`. |
| Registry unreachable from laptop | Check DNS and HTTPS for `registry.rednaw.nl`; ensure Nginx and the registry container are running on the server. |

---

## Related Documentation

- [Application deployment](application-deployment.md) — How apps are deployed and how they use the registry
- [Secrets](secrets.md) — Where registry credentials are stored (SOPS)
- [Private](private.md) — Local config files and auth
