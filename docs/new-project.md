[**<---**](onboarding.md)

# New project (bootstrapping from scratch)

Create the full platform from zero: secrets, server, Traefik, registry, monitoring. When done you have a running server ready for app deployment.

All platform config lives in your **app repo** under **`.iac/`** (not in the IaC repo). The [tientje-ketama](https://github.com/rednaw/tientje-ketama) app is a working reference — use its `.iac/` directory as an example throughout this guide.

**What you need before starting:**

- Editor and extensions: see [Onboarding: Before you start](onboarding.md#before-you-start)
- A [Hetzner Cloud](https://console.hetzner.cloud/) account
- A domain name you control (for DNS records)
- An app repo with at least a `docker-compose.yml`

---

## 1. Prepare your app repo

In your **app repo**, create the initial structure:

```bash
mkdir -p .iac
mkdir -p .github/workflows
```

> **Important:** Create `.github/workflows/build-and-push.yml` now (even as a stub). The devcontainer bind-mounts this path; if the file is missing, the container will fail to start.

Create a minimal stub for now (you will fill it in at step 5):

```bash
touch .github/workflows/build-and-push.yml
```

Your app repo should now look like:

```
your-app/
├── docker-compose.yml          # Your app stack
├── .iac/                       # Empty for now
└── .github/workflows/
    └── build-and-push.yml      # Stub (will fill in step 5)
```

---

## 2. Clone the IaC repo and set the app path

```bash
git clone <iac-repo-url> iac
cd iac
./scripts/setup-app-path.sh /path/to/your/app
```

The script writes `APP_HOST_PATH` to your shell profile so the devcontainer knows where your app lives.

- **macOS:** Takes effect immediately (via `launchctl`).
- **Linux:** Log out and back in, or run `source ~/.profile`.

---

## 3. Open the devcontainer (bootstrap mode)

Open `iac.code-workspace` in VS Code/Cursor, then **Reopen in Container** (Cmd+Shift+P → Dev Containers: Reopen in Container).

Since `.iac/iac.yml` doesn't exist yet, the devcontainer starts in **bootstrap mode**: all tools work (Task, SOPS, Terraform, Ansible) but it won't configure registry, Terraform Cloud, or hcloud credentials. That's fine — you need the tools to create the secrets file.

---

## 4. Generate SOPS keys

Inside the devcontainer:

```bash
task secrets:keygen
task secrets:generate-sops-config
```

This creates:

| File | What it is |
|------|-----------|
| `~/.config/sops/age/keys.txt` | Your private key (never share, never commit) |
| `app/.iac/sops-key-<username>.pub` | Your public key (commit to app repo) |
| `app/.iac/.sops.yaml` | SOPS config for encrypting `iac.yml` and `.env` |

> **Important:** Back up your private key (`~/.config/sops/age/keys.txt`) to a secure location (password manager, encrypted drive). It cannot be recovered if lost.

Commit in the **app repo**:

```bash
cd /workspaces/iac/app
git add .iac/sops-key-*.pub .iac/.sops.yaml
git commit -m "Add SOPS key and config"
git push
```

---

## 5. Create external accounts

Create the following accounts and tokens. You'll put all values into `iac.yml` in the next step.

| What | Where to get it |
|------|-----------------|
| **Hetzner Cloud API token** | [Hetzner Console](https://console.hetzner.cloud/) → Security → API tokens → Create (Read & Write) |
| **Hetzner SSH key** | Upload `~/.ssh/id_rsa.pub` in Hetzner Console → Project → Security → SSH keys. Note the key **ID** (numeric). If you don't have a key yet: `ssh-keygen -t ed25519` |
| **Your IP** | Your current public IP in CIDR form, e.g. `203.0.113.50/32`. Find it at [whatismyipaddress.com](https://whatismyipaddress.com/) |
| **Terraform Cloud** | Create an account at [app.terraform.io](https://app.terraform.io). Create an organization. Create an API token under User Settings → Tokens |
| **Registry credentials** | Choose a username and password for your self-hosted Docker registry |
| **OpenObserve credentials** | Choose a username (email format, e.g. `admin@observe.local`) and password for monitoring |

---

## 6. Create and encrypt `app/.iac/iac.yml`

Inside the devcontainer, create `.iac/iac.yml` in the **app repo** with your values.

Here's a complete template (tientje-ketama uses this structure):

```yaml
base_domain: example.com
image_name: myorg/myapp
app_domains:
  - dev.example.com
  - example.com

hcloud_token: hcloud_XXXXXXXXXXXXX
ssh_keys:
  - "12345678"
allowed_ssh_ips:
  - "203.0.113.50/32"

registry_username: myreguser
registry_password: my-strong-password
registry_http_secret: "$(openssl rand -hex 32)"

terraform_cloud_token: XXXXXXX.atlasv1.XXXXXXXXXX
terraform_cloud_organization: my-org

openobserve_username: admin@observe.local
openobserve_password: my-observe-password

abuseipdb_api_key: ""
```

`registry_http_secret` is used internally by the Docker registry to sign tokens — generate a random string with `openssl rand -hex 32`.

`base_domain` drives all hostnames: `dev.<base_domain>`, `prod.<base_domain>`, `registry.<base_domain>`.

Encrypt the file:

```bash
cd /workspaces/iac/app
sops --encrypt --in-place .iac/iac.yml
```

Commit the **encrypted** file (never commit the plain text version):

```bash
git add .iac/iac.yml
git commit -m "Add encrypted platform config"
git push
```

---

## 7. Create the remaining `.iac/` files

Still in the app repo, create:

### `.iac/.env` (app runtime secrets)

SOPS-encrypted dotenv for your app. Start with a minimal file:

```bash
# In VS Code: create app/.iac/.env, add your vars, save (SOPS extension encrypts)
# Or from the CLI:
echo "# App secrets" > /workspaces/iac/app/.iac/.env
cd /workspaces/iac/app && sops --encrypt --in-place .iac/.env
```

### `.iac/docker-compose.override.yml` (Traefik routing)

This adds Traefik labels, the `traefik` network, and restart policies. It's applied on the server during deploy alongside your main `docker-compose.yml`.

Example (tientje-ketama pattern):

```yaml
services:
  app:
    image: ${IMAGE}
    labels:
      traefik.enable: "true"
      traefik.http.routers.app.rule: "Host(`dev.example.com`) || Host(`example.com`)"
      traefik.http.routers.app.entrypoints: "websecure"
      traefik.http.routers.app.tls.certresolver: "letsencrypt"
      traefik.http.routers.app.middlewares: "app-headers,app-buffering"
      traefik.http.services.app.loadbalancer.server.port: "3000"
    networks:
      - default
      - traefik
    restart: unless-stopped

  # Add restart to every other service too (db, redis, etc.)
  db:
    restart: unless-stopped

networks:
  traefik:
    external: true
```

Key points:
- Replace `example.com` with your actual domain and `3000` with your app's port.
- `image: ${IMAGE}` is required — the deploy task sets this to the resolved image digest.
- `restart: unless-stopped` on every service ensures your app survives reboots. See [Backups](backups.md#after-an-in-place-restore).
- See [Traefik](traefik.md#adding-an-application) for middleware configuration.

### `.github/workflows/build-and-push.yml` (CI)

Replace the stub from step 1 with the actual workflow:

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

Then set up GitHub Actions in your app repo (Settings → Secrets and variables → Actions):

- **Variables:** `REGISTRY_URL` = `registry.<base_domain>`, `IMAGE_NAME` = your `image_name` value
- **Secrets:** `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` (same values as in `iac.yml`)

### Commit everything

```bash
cd /workspaces/iac/app
git add .iac/ .github/
git commit -m "Add .iac contract and build workflow"
git push
```

---

## 8. Reopen the devcontainer (operational mode)

Close the devcontainer and reopen it. Now that `.iac/iac.yml` exists and is decryptable, it starts in **operational mode**: it decrypts secrets and configures registry auth, Terraform Cloud, and hcloud automatically.

See [Launch the IaC devcontainer](launch-devcontainer.md) for details.

---

## 9. Terraform Cloud workspaces

In [Terraform Cloud](https://app.terraform.io):

1. Create workspaces **`platform-dev`** and **`platform-prod`** in your organization.
2. In each workspace, set **Execution Mode** to **Local** (Settings → General → Execution Mode).

The workspace names must match — the platform derives the environment from the name (`platform-dev` → `dev`).

---

## 10. Provision the server

From the IaC devcontainer:

```bash
task terraform:init -- dev
task terraform:apply -- dev
```

This creates the Hetzner server, firewall, and network. Get the server IP:

```bash
task terraform:output -- dev
```

---

## 11. Set up DNS

Point your domain at the server IP. Create these DNS records at your DNS provider:

| Type | Name | Value |
|------|------|-------|
| A | `dev.<base_domain>` | Server IP from step 10 |
| A | `registry.<base_domain>` | Same IP |
| A | `<base_domain>` (if used for prod) | Same IP |

For example, if your `base_domain` is `example.com` and the server IP is `203.0.113.10`:

```
dev.example.com       A  203.0.113.10
registry.example.com  A  203.0.113.10
```

DNS must resolve before Ansible runs — Traefik needs it for Let's Encrypt certificates.

---

## 12. Bootstrap and configure the server

```bash
task ansible:bootstrap -- dev
task ansible:run -- dev
```

`ansible:bootstrap` does first-time setup (users, Docker, firewall). `ansible:run` installs everything else (Traefik, registry, OpenObserve, monitoring).

When Ansible finishes, you have:
- Traefik serving HTTPS with Let's Encrypt
- A private Docker registry at `registry.<base_domain>`
- OpenObserve for monitoring (via SSH tunnel — see [Remote-SSH](remote-ssh.md))

---

## 13. Deploy your app

Push a commit to your app's `main` branch. The CI workflow builds and pushes the image to the registry. Then:

```bash
task app:versions -- dev     # List available versions
task app:deploy -- dev <sha> # Deploy (e.g. task app:deploy -- dev 706c88c)
```

Your app should be live at `https://dev.<base_domain>`.

---

## What's next

- **Production:** Repeat steps 10–13 with `prod` instead of `dev`.
- **Adding people:** When someone joins, they follow [Joining](joining.md). You add their SOPS key and re-encrypt — see [Secrets: Adding a new person](secrets.md#adding-a-new-person).
- **Operations:** [Application deployment](application-deployment.md), [Troubleshooting](troubleshooting.md), [Monitoring](monitoring.md).
- **IP changes:** If your IP changes, update `allowed_ssh_ips` in `iac.yml` and run `task terraform:apply -- dev`.
