[**<---**](../README.md)

# Secrets and mounts: multi-app, multi-server DX

The current model assumes one app and one server type. This document redesigns secrets, mounts, and the devcontainer contract to support multiple apps and multiple server types in parallel — without switching or rebuilding.

**Prerequisite:** The [repo restructuring](restructuring.md) should happen first or in parallel.

---

## Problems with the current model

### 1. One app at a time

The devcontainer mounts a single app via `APP_HOST_PATH` — three separate file-level mounts for `.iac/`, `docker-compose.yml`, and the CI workflow:

```json
"source=${localEnv:APP_HOST_PATH}/.iac,target=/workspaces/iac/app/.iac,type=bind",
"source=${localEnv:APP_HOST_PATH}/docker-compose.yml,target=/workspaces/iac/app/docker-compose.yml,type=bind",
"source=${localEnv:APP_HOST_PATH}/.github/workflows/...,target=/workspaces/iac/app/.github/...,type=bind"
```

With two apps on the platform, you'd need to change `APP_HOST_PATH` and rebuild the devcontainer to switch. No way to work on both simultaneously.

### 2. `iac.yml` conflates infra and app config

`app/.iac/iac.yml` contains both:

| Key | Concern | Scope |
|-----|---------|-------|
| `base_domain` | Infrastructure | All servers |
| `hcloud_token` | Infrastructure | All servers |
| `terraform_cloud_*` | Infrastructure | All servers |
| `transip_*` | Infrastructure | All servers |
| `ssh_keys`, `allowed_ssh_ips` | Infrastructure | All servers |
| `registry_*` | Infrastructure | Platform (prod) |
| `openobserve_*` | Infrastructure | Platform |
| `abuseipdb_api_key` | Infrastructure | Platform |
| `image_name` | App | One specific app |
| `app_domains` | App | One specific app |

Infrastructure secrets live in the app repo. VPN/honeypot secrets would need to go there too. The app repo accumulates config unrelated to the app.

### 3. dev/prod for non-platform servers

dev/prod exists for app acceptance testing (v1 on prod, v2 on dev). VPN and honeypot servers don't serve app developers — they have different environment semantics or may only need one environment. But the entire toolchain (`_check:workspace`, `hostkeys:hostname`, Docker contexts) is hardcoded to dev/prod.

### 4. Registry on dev is an orphan

Ansible installs the registry on both servers, but DNS only points `registry.<base_domain>` at prod. Dev's registry exists but has no DNS and no purpose.

---

## Design

### Fork model

The IaC repo moves from "clone and use" to "fork and use." Users fork the repo, commit their infra secrets directly. The IaC repo becomes their deployment repo.

Why this works:
- **Upstream merges are clean.** The only forked file (`secrets/infra.yml`) doesn't exist upstream, so merges never conflict. Add `secrets/` to `.gitignore` in the upstream repo to make this explicit.
- **Renovate still works.** Runs in the fork against the fork's branch. No change.
- **The audience customizes anyway.** Different domains, servers, apps — a fork is the natural model.
- **One fewer thing to manage.** No config repo, no extra `INFRA_HOST_PATH` env var. Secrets live next to the code that reads them.

### Split secrets into two layers

**`secrets/infra.yml`** — org-level infrastructure config, committed to the fork. SOPS-encrypted. Shared across all server types:

```yaml
base_domain: "example.com"
hcloud_token: "..."
transip_account_name: "..."
transip_private_key: "..."
terraform_cloud_organization: "..."
terraform_cloud_token: "..."
ssh_keys: [...]
allowed_ssh_ips: [...]
registry_username: "..."
registry_password: "..."
registry_http_secret: "..."
openobserve_username: "..."
openobserve_password: "..."
abuseipdb_api_key: "..."
# Future server types add their secrets here
# vpn_xray_uuid: "..."
# honeypot_openobserve_token: "..."
```

**Per-app `.iac/iac.yml`** — app-specific config, stays in each app repo. Plain YAML, no encryption:

```yaml
image_name: "myorg/myapp"
app_domains:
  - "dev.example.com"
  - "prod.example.com"
backup:
  retention:
    keep_daily: 7
    keep_weekly: 4
    keep_monthly: 12
  postgres:
    - service: db
      user_env: POSTGRES_USER
      db_env: POSTGRES_DB
  volumes:
    - service: app
      path: /app/uploads
```

All fields are already plaintext today (`unencrypted_regex` for image/domains, `backup.yml` was never encrypted). Dropping SOPS for this file means app developers don't need age keys to edit app config. The `backup` key is optional — apps without backups omit it.

The app's `.iac/.env` (database passwords, API keys, etc.) **remains SOPS-encrypted**. The app's `.iac/.sops.yaml` stays, but only covers `.env`:

```yaml
creation_rules:
  - path_regex: \.env$
    age: <age public keys>
```

### Mount all apps at once

Replace the per-file app mounts with a single directory mount:

```json
"mounts": [
  "source=${localEnv:APPS_HOST_PATH},target=/workspaces/iac/apps,type=bind",
  "source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind",
  "source=${localEnv:HOME}/.config/sops,target=/home/vscode/.config/sops,type=bind",
  "source=iac-cursor-state,target=/home/vscode/.cursor,type=volume"
]
```

One env var (`APPS_HOST_PATH`) instead of `APP_HOST_PATH`. Points to a directory containing all app repos:

```
$APPS_HOST_PATH/                →  /workspaces/iac/apps/
├── app1/
│   └── .iac/                   # the entire contract
│       ├── iac.yml             # plain YAML: image_name, app_domains, backup
│       ├── docker-compose.yml  # complete compose for platform deployment
│       ├── .env                # SOPS-encrypted app secrets
│       └── .sops.yaml          # SOPS config for .env
└── app2/
    └── .iac/
        └── ...
```

The `.iac/` directory **is** the contract — three files:

| File | Purpose |
|------|---------|
| `iac.yml` | Plain YAML: image name, app domains, backup config |
| `docker-compose.yml` | Complete compose for platform deployment (all services, no override chain) |
| `.env` | SOPS-encrypted app secrets (database passwords, API keys) |

Nothing outside `.iac/` matters to the IaC workspace. The app's root `docker-compose.yml` (for local dev) is separate and not part of the platform contract.

The CI workflow (`.github/workflows/build-and-push.yml`) is **identical for every app** — it's a 14-line caller that references the reusable workflow in the IaC repo. App-specific values (registry URL, image name) come from GitHub repository variables, not the file. It's a one-time setup step (like "set these GitHub secrets"), not per-app config.

No per-app mount entries. Any number of apps. No rebuild to add or remove one.

### Workspace UI

The `apps/` mount contains full app source trees, but you don't edit source code from the IaC workspace — only deployment config. Use `iac.code-workspace` to surface just each app's `.iac/` as a named folder and hide the rest:

```json
{
  "folders": [
    { "path": "." },
    { "path": "apps/app1/.iac", "name": "app1 (.iac)" },
    { "path": "apps/app2/.iac", "name": "app2 (.iac)" }
  ],
  "settings": {
    "files.exclude": {
      "apps": true
    }
  }
}
```

The sidebar shows:

```
📁 iac                 ← main workspace (ansible, terraform, tasks, docs, ...)
📁 app1 (.iac)         ← iac.yml, docker-compose.yml, .env
📁 app2 (.iac)         ← same
```

Deployment config is directly editable. No source code clutter. The workspace file lists your apps, but that's expected in a fork.

### Tasks take an app name

```bash
# Platform infra (no app needed)
task platform:plan -- dev
task platform:run -- dev

# App deployment (specify which app)
task app:deploy -- dev app1 abc123f
task app:deploy -- dev app2 def456a
task app:versions -- dev app1

# Non-platform servers (no app needed)
task vpn:apply -- dev
task honeypot:run -- prod
```

The task resolves app name → `apps/<name>/.iac/` for everything: `iac.yml` (plain YAML, read with `yq`), `docker-compose.yml`, `.env`. Infra secrets come from `secrets/infra.yml` (in the repo, SOPS-decrypted).

### Devcontainer setup

`devcontainer-setup.sh` changes:

| Today | After |
|-------|-------|
| Reads `app/.iac/iac.yml` for everything | Reads `secrets/infra.yml` for infra config |
| Bootstrap mode if `app/.iac/iac.yml` missing | Bootstrap mode if `secrets/infra.yml` missing |
| Sets `BASE_DOMAIN`, `REGISTRY` from iac.yml | Same, from `infra.yml` |
| Configures Docker auth from iac.yml | Same, from `infra.yml` |
| Creates Docker contexts `dev`, `prod` | Creates contexts for all purposes: `platform-dev`, `platform-prod`, `vpn-dev`, etc. |
| One decryption | One decryption (`infra.yml` only; app `iac.yml` is plain YAML, `.env` decrypted at deploy time) |

### Ansible secrets path

Today, [`ansible/tasks/secrets.yml`](../../ansible/tasks/secrets.yml) defaults to `app/.iac/iac.yml`. After the split:

- Infra secrets: `secrets/infra.yml` (in the repo, loaded by all playbooks)
- App config: `apps/<name>/.iac/iac.yml` (plain YAML, read directly)
- App secrets: `apps/<name>/.iac/.env` (SOPS-encrypted, decrypted at deploy time)

The deploy playbook receives all three: infrastructure secrets from `infra.yml`, app config from `iac.yml` (plain), and app secrets from `.env` (decrypted).

---

## What the repo looks like after

```
/workspaces/iac/
├── secrets/                        # gitignored upstream, committed in fork
│   ├── infra.yml                   # SOPS-encrypted infra secrets
│   └── .sops.yaml                  # SOPS config + age public keys
├── apps/                           # mounted: all app repos
│   ├── app1/
│   │   └── .iac/                   # the entire contract
│   │       ├── iac.yml             # plain YAML (config + backup)
│   │       ├── docker-compose.yml  # all services
│   │       └── .env                # SOPS-encrypted
│   └── app2/
│       └── .iac/...
├── ansible/
├── terraform/
├── tasks/
├── prefect/
├── docs/
├── .devcontainer/
└── ...
```

Upstream repo: generic framework, `secrets/` gitignored. Fork: committed `secrets/infra.yml` with org-specific config. Apps: mounted from host. Only `.iac/` matters to the platform — everything else in the app repo is invisible to IaC.

---

## Migration

For existing users:

1. Fork the IaC repo (if not already)
2. Create `secrets/infra.yml` by extracting infra keys from `app/.iac/iac.yml`
3. Create `secrets/.sops.yaml` (copy SOPS config from `app/.iac/.sops.yaml`)
4. Reduce each app's `.iac/iac.yml` to just `image_name` and `app_domains` (plain YAML, remove SOPS encryption)
5. Merge `docker-compose.yml` (app root) and `.iac/docker-compose.override.yml` into a single `.iac/docker-compose.yml`
6. Merge `.iac/backup.yml` into `iac.yml` under a `backup` key
7. Remove `.iac/docker-compose.override.yml` and `.iac/backup.yml`
8. Update `.iac/.sops.yaml` to only cover `.env`
8. Move the app directory into a parent (e.g. `~/projects/app1/`)
10. Replace `APP_HOST_PATH` with `APPS_HOST_PATH` (pointing to `~/projects/`)
11. Add app workspace folders to `iac.code-workspace`
12. Rebuild devcontainer

A `task secrets:migrate` could automate steps 2-8.

---

## Risks

| Risk | Mitigation |
|------|-----------|
| Fork model = merging upstream updates | `secrets/` is gitignored upstream, so merges are clean. Only conflicting changes are structural (rare, reviewable). |
| App `iac.yml` is now very thin — is a separate file worth it? | Yes: it keeps app config in the app repo (where app developers manage it), and it's the contract the deploy task expects. Plain YAML makes it trivial to edit. |
| Ansible needs to load two secret files | Small change: load `infra.yml` as pre-task (already done), pass app path as variable to deploy role. |
| `APPS_HOST_PATH` mount exposes all app repos | Acceptable — you're the operator of all these apps. The devcontainer already has full Docker socket access. |
| Breaking change for existing users | Provide migration task and update onboarding docs. |
