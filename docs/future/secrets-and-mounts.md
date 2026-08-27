[**<---**](../README.md)

# Secrets and mounts

How the IaC repo supports **multiple application repos**, **fork-local infrastructure secrets**, and a single **`/workspaces/<name>/.iac/`** deploy contract. Builds on [repo layout](restructuring.md).

---

## Fork model

Operators **fork** the IaC repo and commit **`secrets/infra.yml`** in the fork. Upstream lists **`secrets/`** in **`.gitignore`** — use **`git add -f secrets/`** when committing that tree.

- Renovate and CI run in the fork as usual.
- Org-specific values live next to the automation that consumes them.

---

## Two layers of secrets (same age recipients)

**`secrets/sops-key-*.pub`** is the single source of recipients for both **`secrets/infra.yml`** and **`/workspaces/<app>/.iac/.env`**. **`task secrets:generate-sops-config`** writes **`secrets/.sops.yaml`**; **`task secrets:generate-app-env-sops-config`** / **`task secrets:sync-all-app-env-sops-configs`** refresh **`/workspaces/<app>/.iac/.sops.yaml`**.

### `secrets/infra.yml` (IaC fork, SOPS)

Shared infrastructure for Terraform, the Ansible platform role, and devcontainer bootstrap:

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
# Additional server types (VPN, honeypot, …) add keys here when implemented.
```

[`ansible/tasks/secrets.yml`](../../ansible/tasks/secrets.yml) decrypts this into **`infrastructure_secrets`** for playbooks (override with **`secrets_file`** when needed).

### Per-app `.iac/` (application repo)

| Path | Purpose |
|------|---------|
| **`iac.yml`** | Plain YAML: **`image_name`**, **`app_domains`**, optional **`backup:`** block. **`task app:deploy`** rejects infra-only keys. |
| **`docker-compose.yml`** | Full Compose file deployed to the server (Traefik labels, **`traefik`** external network, **`image: ${IMAGE}`**, **`restart: unless-stopped`**). |
| **`.env`** | SOPS-encrypted runtime secrets for Compose. |
| **`.sops.yaml`** | Encrypt **`.env`** only (`path_regex: \.env$`). **`age:`** matches **`secrets/sops-key-*.pub`** (regenerate via **`task secrets:generate-app-env-sops-config`**). |

Repo-root **`docker-compose.yml`** is optional and **only** for local developer workflows — deploy reads **`.iac/docker-compose.yml`** only.

The GitHub Actions caller workflow is small and reusable; registry URL and image name come from repository variables/secrets aligned with **`secrets/infra.yml`**.

---

## Mounting application repos

The devcontainer mounts **`${localWorkspaceFolder}/..`** at **`/workspaces`** ([`.devcontainer/devcontainer.json`](../../.devcontainer/devcontainer.json)).

Convention: clone **`iac`** and each app as **siblings** on the host. Inside the container they appear as **`/workspaces/iac`** and **`/workspaces/<name>/`** — **`<name>`** is the second argument to **`task app:deploy`** and **`task app:versions`**.

---

## Workspace UI

Use **`iac.code-workspace`** to add sibling app clones to the sidebar:

```json
{
  "folders": [
    { "path": "." },
    { "path": "../app1", "name": "app1" },
    { "path": "../app2", "name": "app2" }
  ],
  "settings": {}
}
```

---

## Tasks

```bash
# SOPS (same recipients for infra + app .env)
task secrets:generate-sops-config
task secrets:generate-app-env-sops-config -- app1
task secrets:sync-all-app-env-sops-configs

# Platform (no app argument)
task platform:provision:plan -- dev
task platform:configure:apply -- dev

# Applications
task app:deploy -- dev app1 abc123f
task app:versions -- dev app1

# Other server types when implemented
task vpn:apply -- dev
task honeypot:run -- prod
```

Tasks resolve **`/workspaces/<name>/.iac/`** for **`iac.yml`**, **`docker-compose.yml`**, and **`.env`**. Infra facts come from **`secrets/infra.yml`**.

---

## Devcontainer startup

[`devcontainer-setup.sh`](../../.devcontainer/devcontainer-setup.sh) decrypts **`secrets/infra.yml`** when present and configures registry auth, Terraform Cloud, **hcloud**, and Docker contexts **`host`** / **`dev`** / **`prod`** for platform servers.

---

## Deploy path

Playbooks load infra secrets first. **`deploy_app`** copies **`/workspaces/<name>/.iac/docker-compose.yml`** and decrypted **`.env`** to the server. **`image_name`** is read from **`iac.yml`** via **`task app:deploy`**.

---

## Repository layout (reference)

```
/workspaces/
├── iac/
│   ├── secrets/                 # gitignored upstream; committed in fork
│   │   ├── infra.yml
│   │   └── .sops.yaml
│   ├── ansible/
│   ├── terraform/
│   ├── tasks/
│   ├── prefect/
│   ├── docs/
│   ├── .devcontainer/
│   └── ...
├── app1/
│   └── .iac/
└── app2/
    └── .iac/
```

---

## Application `.iac/` contract

Per application repo (see also [Traefik](../traefik.md), [New project](../new-project.md), [tientje-ketama](https://github.com/rednaw/tientje-ketama)):

1. Infrastructure keys exist **only** in the IaC fork **`secrets/infra.yml`**, not in the app repo.
2. **`.iac/iac.yml`** — plaintext **`image_name`**, **`app_domains`**; no cloud/registry/SSH secrets.
3. **`.iac/docker-compose.yml`** — single deploy manifest (Traefik + services).
4. **`.iac/.env`** — SOPS runtime secrets; **`.iac/.sops.yaml`** targets **`.env`** only and shares **`secrets/sops-key-*.pub`** recipients.
5. Optional **`.iac/backup.yml`** — Restic contract when backups are enabled (**`tasks/Taskfile.backup.yml`** expects this path).

---

## Remaining work

| Priority | Item |
|----------|------|
| **P1** | **Backup shape** — standardize on **`backup:`** in **`iac.yml`** vs **`backup.yml`** only; align **`tasks/Taskfile.backup.yml`** and Prefect. |
| **P2** | **Platform UX** — optional Docker context naming, **`registry`** hostname on dev vs prod, multi-environment clarity for future server types. |

---

## Risks

| Risk | Mitigation |
|------|------------|
| Fork vs upstream merges | **`secrets/`** absent upstream keeps merges simple; structural conflicts are rare. |
| Thin **`iac.yml`** | App-facing config stays in the app repo; plain YAML is easy to edit and **`task app:deploy`** validates forbidden keys. |
| Parent **`/workspaces`** bind exposes sibling clones | Same trust boundary as Docker socket access in the devcontainer — intended for operators of those repos. |
