# AI context guide

**Project:** IaC for a single server (Terraform + Ansible + SOPS + Docker). Indie hackers and small teams. See [README](README.md) and [docs/README](docs/README.md).

**Philosophy:** Teach, don't hide. Opinionated defaults. Single server, done well.

**Context limit:** Be concise. Read only what you need. Say "see docs/X" instead of pasting long doc blocks. When you must summarize, keep it short.

**Develop mode has two phases.** (1) **Design:** Iterative discussion until there is an unambiguous design document (in `docs/` or agreed in chat). Propose options and trade-offs; resolve ambiguity before any code or config. (2) **Implementation:** Only when the user gives an explicit go (e.g. "go", "implement it", "you can implement"). Do not start implementing on your own; if in doubt, ask.

---

## Two modes

**Develop** — Add or change platform code: Ansible roles/tasks, Prefect flows, Terraform, CI/workflows, docs. Workflow: first iterative discussion → unambiguous design doc; then implementation only after explicit go. Edit in this repo, apply via `task`.

**Observe** — Handle issues on the server or in the devcontainer: something's broken/slow/wrong. Inspect state via SSH or Docker context, diagnose, and advise. **Do not change the system in observe mode.** Fixes go in this repo and get applied (Ansible, Terraform, task). Observe = observe and advise; develop = implement and apply.

Infer which mode the user is in. Then emphasize either "run this to inspect, then we'll fix via the repo" (observe) or "edit this and apply" (develop).

---

## Execution environment

**Devcontainer** — You're in it. Task, Ansible, Terraform, SOPS, Docker CLI, crane, and other tools preinstalled (mise). Secrets decrypted via SOPS on startup; registry auth, Terraform Cloud, and optional cloud credentials configured. Assume commands run here unless stated otherwise.

**Application mount** — The devcontainer bind-mounts the user's local app into `app/`: `.iac/` (secrets), `docker-compose.yml`, and `.github/workflows/build-and-push.yml`. Edits here = edits in the app repo. So app deploy and config happen from this workspace.

**Server access** — The managed server is reachable for diagnostics:
- **SSH:** `ssh` to server (see [docs/remote-ssh](docs/remote-ssh.md)) for ad‑hoc commands, logs, files.
- **Docker context:** `docker context use dev` (or `prod`), then `docker ps`, `docker exec`, `docker logs` run against the server's Docker daemon. Use this to inspect/debug containers without SSH.

When suggesting diagnostics, say where the command runs: "in the devcontainer" or "on the server (SSH or Docker context)."

---

## Repository structure

| Area | Path | Doc |
|------|------|-----|
| **Server config** | `ansible/roles/server/tasks/*.yml` | [docs/](docs/) (Traefik, registry, monitoring, workflows) |
| **App deployment** | `ansible/roles/deploy_app/tasks/*.yml` | [docs/application-deployment](docs/application-deployment.md) |
| **Provisioning** | `terraform/*.tf` | docs/new-project, backups |
| **Workflows** | `prefect/<name>/flow.py`, `prefect/prefect.yaml` | [docs/workflows](docs/workflows.md) |
| **Automation** | `Taskfile.yml`, `tasks/Taskfile.*.yml` | Inline comments + docs |
| **CI** | `.github/workflows/*.yml` | docs/code-analysis, registry |
| **Dev environment** | `.devcontainer/`, `Dockerfile`, `mise.toml` | docs/launch-devcontainer |
| **Secrets** | `app/.iac/iac.yml` (SOPS), `.iac/.env` (app) | [docs/secrets](docs/secrets.md) |

---

## Server components (Ansible roles/tasks order)

Server role (`ansible/roles/server/tasks/main.yml`) imports in order:
1. **base** — users, packages, firewall  
2. **unattended-upgrades** — auto security updates  
3. **ssh** — hardening (key-only, fail2ban)  
4. **fail2ban** — ssh brute-force protection  
5. **docker** — Docker + compose  
6. **traefik** — reverse proxy, TLS, labels  
7. **iac-user** — iac user (no home) + /opt/iac tree + shared registry auth  
8. **registry** — self-hosted Docker registry (GHCR hosts IaC dev image only)  
9. **openobserve** — logs + metrics (OTEL collector)  
10. **prefect** — Postgres DB, server, worker (Docker socket + flows)

See `ansible/roles/server/tasks/<component>.yml` for each. Templates in `roles/server/templates/`.

---

## Common tasks (entrypoints)

Root `Taskfile.yml` includes `tasks/Taskfile.*.yml`. Common namespaces:

- **terraform** — `task terraform:plan -- <env>`, `task terraform:apply -- <env>`  
- **ansible** — `task ansible:run -- <env>` (apply server config)  
- **app** — `task app:deploy -- <env> <sha>`, `task app:versions -- <env>`  
- **secrets** — `task secrets:init-keys`, `task secrets:decrypt`  
- **server** — `task server:check-status -- <env>`, `task server:ssh -- <env>`  
- **tunnel** — `task tunnel:start -- <env>` (SSH forward for dashboards: OpenObserve, Traefik, Prefect)  
- **registry** — `task registry:overview` (list repos/tags via crane)  
- **test** — `task test:run` (Terraform/Ansible lint + tfsec)

See `task` (or `task <namespace>`) for full list.

---

## Before you edit (conventions)

**Ansible**  
- Roles: `ansible/roles/<role>/tasks/main.yml` (imports subtasks), templates in `roles/<role>/templates/`.  
- Playbooks: `ansible/playbooks/<name>.yml` (apply roles).  
- Secrets: referenced from `infrastructure_secrets` (decrypted from `app/.iac/iac.yml`).

**Terraform**  
- Workspaces: `dev` / `prod`. State in Terraform Cloud.  
- Variables: `terraform/variables.tf`, locals in `locals.tf`, outputs in `outputs.tf`.

**Taskfiles**  
- Root `Taskfile.yml` includes `tasks/Taskfile.*.yml`.  
- Add new namespaces in the correct Taskfile (e.g. app → `Taskfile.app.yml`).

**Prefect**  
- Flows: `prefect/<name>/flow.py` (e.g. `registry_prune/flow.py`).  
- Deployment: `prefect/prefect.yaml` (schedules, work pool).  
- Server + worker: deployed by Ansible (`ansible/roles/server/tasks/prefect.yml`).

**GitHub Actions**  
- IaC dev image: build/cache on GHCR (`:latest`, `:buildcache`, `:sha` tags).  
- App images: build/push to self-hosted registry (`registry.<base_domain>`).  
- See `.github/workflows/` and [docs/registry](docs/registry.md).

---

## Docs organization

Docs live in `docs/`. Index: [docs/README](docs/README.md). Key docs:

- **Onboarding:** new-project, joining, launch-devcontainer  
- **Infra:** traefik, registry, monitoring (OpenObserve), workflows (Prefect), backups  
- **App:** application-deployment, secrets  
- **Ops:** troubleshooting, upgrading, remote-ssh  
- **Dev:** code-analysis, documentation-strategy

Breadcrumb at top of every doc: `[**<---**](README.md)`. Style: plain language, short sentences, "you" for reader, imperative for instructions. See [docs/documentation-strategy](docs/documentation-strategy.md).

---

## When answering

- **Be brief.** Link to `docs/<topic>.md` for procedures and details instead of pasting.  
- **If unsure where a setting lives,** search (role name, env var, keyword) then read only the relevant file(s).  
- **Develop mode:** First design (discuss until unambiguous; design doc in docs/ or agreed). Only implement after explicit go. When implementing, show "edit this file, run this task" and explain conventions.  
- **Observe mode:** Show "run this to inspect" and advise on next steps; remind that fixes go via the repo.
