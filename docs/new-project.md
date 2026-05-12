[**<---**](onboarding.md)

# New project (from scratch)

Create the full platform from zero: fork-local infra secrets, server, Traefik, registry, monitoring. When done you have a running server ready for app deployment.

- **Infrastructure secrets** live in your **IaC fork** under **`secrets/infra.yml`** (SOPS). Upstream keeps **`secrets/`** gitignored; you **`git add -f secrets/`** in the fork.
- **Per-app contract** lives in each **application repo** under **`.iac/`** — plain **`iac.yml`** (`image_name`, `app_domains`), SOPS **`.env`**, and a single **`.iac/docker-compose.yml`** for deploy.

Use **[tientje-ketama](https://github.com/rednaw/tientje-ketama)** as a reference for **`.iac/`** layout and Traefik labels.

**What you need before starting:**

- Editor and extensions: see [Onboarding: Before you start](onboarding.md#before-you-start)
- A [Hetzner Cloud](https://console.hetzner.cloud/) account
- A domain name you control (for DNS records)
- An application repo (Docker-based); optional repo-root **`docker-compose.yml`** for **local** dev only — deploy uses **`.iac/docker-compose.yml`** only

---

## 1. Directory layout on your machine

The devcontainer bind-mounts **the parent directory of the IaC repo** to **`/workspaces/iac/apps/`** ([`.devcontainer/devcontainer.json`](../.devcontainer/devcontainer.json)). Put the IaC clone and each app repo as **siblings** under one folder:

```
~/projects/
├── my-app/          # your application repo — folder name = `<app>` in task CLI
└── iac/             # IaC fork (clone here)
```

```bash
mkdir -p ~/projects && cd ~/projects
git clone <your-iac-fork-url> iac
git clone <your-app-repo-url> my-app
```

Inside the container, **`my-app`** is **`/workspaces/iac/apps/my-app/`**. Deploy commands use that basename: **`task app:deploy -- dev my-app <sha>`**.

---

## 2. Prepare your app repo

In **`my-app`** (paths relative to the app repo):

```bash
mkdir -p .iac .github/workflows
touch .github/workflows/build-and-push.yml   # replace with real workflow in §7
```

Example tree:

```
my-app/
├── docker-compose.yml          # optional — local dev only; not used by platform deploy
├── .iac/                       # filled in §7
└── .github/workflows/
    └── build-and-push.yml
```

---

## 3. Open the devcontainer

Open **`iac/iac.code-workspace`** in VS Code/Cursor, then **Reopen in Container** (Cmd+Shift+P → Dev Containers: Reopen in Container).

Until **`secrets/infra.yml`** exists and decrypts, Task/SOPS/Terraform/Ansible are available but registry auth, Terraform Cloud, and **hcloud** are typically **not** wired yet.

---

## 4. Initialise infra secrets (IaC repo)

From the IaC repo root inside the container:

```bash
cd /workspaces/iac
task secrets:init
```

This ensures **`~/.config/sops/age/keys.txt`**, writes **`secrets/sops-key-<username>.pub`**, **`secrets/.sops.yaml`**, and an encrypted template **`secrets/infra.yml`**.

Commit **`secrets/`** in your **fork** (force-add because **`secrets/`** is gitignored upstream):

```bash
cd /workspaces/iac
git add -f secrets/
git commit -m "Add fork-local infra secrets"
git push
```

---

## 5. Create external accounts

Create the following accounts and tokens. You will paste values into **`secrets/infra.yml`** next.

| What | Where to get it |
|------|-----------------|
| **Hetzner Cloud API token** | [Hetzner Console](https://console.hetzner.cloud/) → Security → API tokens → Create (Read & Write) |
| **Hetzner SSH key** | Upload `~/.ssh/id_ed25519.pub` (or `id_rsa.pub`) in Hetzner Console → Project → Security → SSH keys. Note the numeric key **ID**. |
| **Your IP** | Current public IP in CIDR form, e.g. `203.0.113.50/32` ([whatismyipaddress.com](https://whatismyipaddress.com/)) |
| **Terraform Cloud** | [app.terraform.io](https://app.terraform.io) — organization + API token (User Settings → Tokens) |
| **Registry credentials** | Choose username and password for the self-hosted Docker registry |
| **OpenObserve credentials** | Username (email-style, e.g. `admin@observe.local`) and password |
| **TransIP** (if DNS there) | API key pair from [TransIP API](https://www.transip.eu/cp/account/api/) |

---

## 6. Edit `secrets/infra.yml`

Open **`secrets/infra.yml`** in VS Code (SOPS extension decrypts on open). Fill fields from the template (`base_domain`, `hcloud_token`, `ssh_keys`, `allowed_ssh_ips`, registry, Terraform Cloud, OpenObserve, TransIP, etc.). Generate **`registry_http_secret`** with `openssl rand -hex 32`.

**Save** to re-encrypt. Commit and push (**`git add -f secrets/`** when needed).

Reload the window or run **`bash .devcontainer/devcontainer-setup.sh`** so **`~/.docker/config.json`**, Terraform Cloud credentials, and **hcloud** are written.

---

## 7. App contract under `.iac/`

All paths below are under **`/workspaces/iac/apps/<app>/`** (e.g. **`.../apps/my-app/`**).

### `.iac/iac.yml` (plain YAML — **not** SOPS)

Only app-facing keys; **`task app:deploy`** rejects infrastructure keys (they must stay in **`secrets/infra.yml`**).

```yaml
image_name: myorg/myapp
app_domains:
  - dev.example.com
  - example.com
```

### `.iac/.env` (SOPS dotenv)

Runtime secrets for Compose (database passwords, etc.). Add **`.iac/.sops.yaml`** with **`creation_rules`** that encrypt **`.env`** only (not **`iac.yml`**). Point **`age:`** at your recipients — often the same public key material as in **`secrets/`** (see [tientje-ketama `.iac/.sops.yaml`](https://github.com/rednaw/tientje-ketama/blob/main/.iac/.sops.yaml)).

```bash
cd /workspaces/iac/apps/my-app
# Create .iac/.env and .iac/.sops.yaml, then:
sops --encrypt --in-place .iac/.env
```

### `.iac/docker-compose.yml` (single deploy file)

One Compose file that Ansible copies to the server: services, **`image: ${IMAGE}`** for the routed app service, Traefik **labels**, external **`traefik`** network, **`restart: unless-stopped`**. See [Traefik](traefik.md#adding-an-application).

### `.iac/backup.yml` (optional)

Restic contract — see [Backups](backups.md#backupyml).

### `.github/workflows/build-and-push.yml`

Use the reusable workflow from your IaC repo, for example:

```yaml
on:
  push:
    branches: [main]
jobs:
  build-and-push:
    uses: rednaw/iac/.github/workflows/_build-and-push.yml@main
    secrets:
      REGISTRY_USERNAME: ${{ secrets.REGISTRY_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.REGISTRY_PASSWORD }}
```

In the app repo (GitHub → Settings → Secrets and variables → Actions):

- **Variables:** `REGISTRY_URL` = `registry.<base_domain>`, `IMAGE_NAME` = same as **`image_name`** in **`iac.yml`**
- **Secrets:** `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` — same values as in **`secrets/infra.yml`**

### Commit the app repo

```bash
cd /workspaces/iac/apps/my-app
git add .iac .github
git commit -m "Add .iac contract and build workflow"
git push
```

---

## 8. Reload devcontainer after infra secrets

After **`secrets/infra.yml`** decrypts successfully, reopen the devcontainer (or reload the window) so registry / Terraform Cloud / **hcloud** are configured. See [Launch the IaC devcontainer](launch-devcontainer.md).

---

## 9. Terraform Cloud workspaces

In [Terraform Cloud](https://app.terraform.io):

1. Create workspaces **`platform-dev`** and **`platform-prod`** in your organization.
2. Set **Execution Mode** to **Local** on each (Settings → General).

Workspace names must match — the platform derives the environment from the name (`platform-dev` → **`dev`**).

---

## 10. Provision the server

```bash
task platform:provision:apply -- dev
```

Server IP:

```bash
task platform:provision:output -- dev
```

---

## 11. Set up DNS

Point your domain at the server IP. Typical records:

| Type | Name | Value |
|------|------|-------|
| A | `dev.<base_domain>` | Server IP |
| A | `registry.<base_domain>` | Same IP |
| A | `<base_domain>` (prod) | Same IP if used |

DNS must resolve before Ansible configures Traefik (Let's Encrypt).

---

## 12. Bootstrap and configure the server

```bash
task platform:configure:bootstrap -- dev
task platform:configure:apply -- dev
```

---

## 13. Deploy your app

Push to **`main`** so CI builds and pushes the image. Then:

```bash
task app:versions -- dev my-app
task app:deploy -- dev my-app <sha>
```

Replace **`my-app`** with your repo folder name under **`apps/`**.

---

## What's next

- **Production:** Repeat with **`prod`** instead of **`dev`**.
- **Adding people:** [Joining](joining.md) · infra keyring in **`secrets/`**, app **`.env`** keyring in the app repo — [Secrets](secrets.md).
- **Operations:** [Application deployment](application-deployment.md), [Troubleshooting](troubleshooting.md), [Monitoring](monitoring.md).
- **IP changes:** Update **`allowed_ssh_ips`** in **`secrets/infra.yml`**, commit, then **`task platform:provision:apply -- dev`**.
