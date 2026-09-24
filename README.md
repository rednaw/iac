# Infrastructure as Code

Opinionated IaC for a **single Hetzner VPS**: Terraform provisions, Ansible configures, SOPS encrypts secrets, Docker Compose runs apps.

Public repo **`rednaw/iac`** has no infra secrets. Encrypted infra lives in the **private sibling** [`rednaw/secrets`](https://github.com/rednaw/secrets) (`../secrets` beside this clone).

## Included

- Hardened Ubuntu (SSH keys, fail2ban, unattended upgrades)
- SOPS encrypted infrastructure (private sibling) and application secrets (per-app `.iac/.env`)
- Traefik (HTTPS / Let’s Encrypt) + private Docker registry
- OpenObserve (logs/metrics) + Prefect (scheduled jobs) + Restic backups
- Optional CMS OAuth proxy at `auth.<base_domain>` (Sveltia / GitHub Pages)
- Devcontainer with Task, Ansible, Terraform, SOPS, Docker CLI

## Work here

1. Clone this repo as **`iac`**, and each app as a **sibling** (same parent directory).
2. Clone the private **`secrets`** repo as a sibling too (`…/rednaw/iac` + `…/rednaw/secrets`).
3. Mount your age private key (`~/.config/sops/age/keys.txt`) — the Dev Container bind-mounts it.
4. **File → Open Folder** on **`iac`** → **Reopen in Container**.

Tasks resolve apps at `/workspaces/<app>/` (parent mount). Infra secrets resolve to `../secrets` (override with `SECRETS_DIR`). The editor sidebar is IaC-only — open `../secrets/infra.yml` to edit (SOPS extension decrypts).

```bash
# First machine / new age key only:
task secrets:init                          # writes encrypted template into ../secrets

task platform:provision:plan               # Terraform
task platform:configure:apply              # Ansible
task app:versions -- <app>
task app:deploy -- <app> <7-char-sha>
task tunnel:start                          # OpenObserve / Traefik / Prefect UI (portal.html)
```

Run `task` for the full list.

## Where things live

| What | Path |
|------|------|
| OS + Docker baseline | `ansible/roles/base/` |
| Traefik, registry, OpenObserve, CMS OAuth, Prefect | `ansible/roles/platform/` |
| App deploy | `ansible/roles/deploy_app/`, `tasks/Taskfile.app.yml` |
| Server provisioning | `terraform/platform/` (+ `terraform/modules/server/`) |
| Scheduled flows | `prefect/` |
| Automation | `Taskfile.yml`, `tasks/` |
| Dev environment | `.devcontainer/` |
| Infra secrets (SOPS) | private sibling `../secrets` (`infra.yml`, `.sops.yaml`, age pubs) |
| App contract | `/workspaces/<app>/.iac/` (`iac.yml`, `docker-compose.yml`, `.env`) |

## Roadmap

Planned work (VPN, honeypot, …): [`docs/future/`](docs/future/).
