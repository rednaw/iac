[**<---**](README.md)

# New project (bootstrapping from scratch)

Create the platform. Use this when you are creating new infrastructure and do not yet have platform config in the app repo. All platform-specific configuration and secrets live in the app repo under **`.iac/`** (not in the IaC repo).

## 1. Development environment

1. Install [Docker](https://docs.docker.com/get-docker/), [VS Code](https://code.visualstudio.com/) or [Cursor](https://cursor.com/), and the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension.
2. Clone the IaC repo.
3. Have an **app repo** (or directory) with:
   - **`docker-compose.yml`** — your app stack (generic; no domain or Traefik labels here).
   - **`.iac/`** — empty directory (create with `mkdir .iac`). You will fill this in the steps below.
4. On the host, run **`./scripts/setup-app-path.sh /path/to/your/app`**. You will open the devcontainer after creating secrets (steps below).

Until `.iac/iac.yml` exists and is encrypted, the devcontainer runs in **bootstrap mode**: tools work, but it will not configure Terraform Cloud, hcloud, or registry auth. Complete steps 2–5, then reopen the devcontainer for **operational mode**. See [Launch the IaC devcontainer](launch-devcontainer.md).

## 2. SOPS key and config (in the app repo)

From the IaC repo (or inside the devcontainer with the app mounted), generate your age key and SOPS config for the app’s `.iac/` directory:

```bash
task secrets:keygen
task secrets:generate-sops-config
```

This creates:

- `~/.config/sops/age/keys.txt` (private key; keep secret)
- **`app/.iac/sops-key-<username>.pub`** (commit this to the **app** repo)
- **`app/.iac/.sops.yaml`** (commit to the app repo; covers `iac.yml` and `.env`)

Commit in the **app** repo:

```bash
cd /path/to/your/app
git add .iac/sops-key-*.pub .iac/.sops.yaml
git commit -m "Add SOPS key and config for bootstrap"
git push
```

## 3. External accounts and tokens

Create the following; you will put values into **`app/.iac/iac.yml`** in the next step.

| What | Where to get it |
|------|------------------|
| **Hetzner Cloud API token** | Hetzner Cloud Console → Security → API tokens. Create a token with Read & Write. |
| **Terraform Cloud token** | Terraform Cloud → User Settings → Tokens. Create an API token. You need an organization and workspaces `platform-dev` and `platform-prod` (see step 6). |
| **Registry credentials** | Choose a username and password for the self-hosted registry (hostname will be `registry.<base_domain>`). |
| **Your SSH public key** | Ensure you have `~/.ssh/id_rsa.pub` (or generate with `ssh-keygen`). Add this key to Hetzner and put the Hetzner key ID in secrets. |
| **Your IP for SSH** | Your current IP (e.g. [whatismyipaddress.com](https://whatismyipaddress.com/)); use CIDR e.g. `203.0.113.50/32`. The firewall only allows SSH from IPs in `allowed_ssh_ips`. |

Add your SSH public key in Hetzner Cloud: Console → Project → Security → SSH keys → Add. Note the key **ID** (numeric) for the next step.

## 4. Create and encrypt `app/.iac/iac.yml`

In the **app** repo, create **`.iac/iac.yml`** (plain YAML) with at least:

**Unencrypted** (required):

- `base_domain` — your domain (e.g. `example.com`). Drives platform name, registry URL, and hostnames.
- `image_name` — Docker image name (e.g. `myorg/myapp`).
- `app_domains` — list of domains for Traefik TLS (e.g. `["dev.example.com", "example.com"]`).

**Encrypted** (credentials):

- `hcloud_token` — Hetzner Cloud API token
- `ssh_keys` — list of Hetzner SSH key IDs, e.g. `["12345678"]`
- `allowed_ssh_ips` — list of CIDRs for SSH, e.g. `["203.0.113.50/32"]`
- `registry_username`, `registry_password`, `registry_http_secret`
- `terraform_cloud_token`, `terraform_cloud_organization`
- `openobserve_username`, `openobserve_password` (for monitoring)
- `abuseipdb_api_key` (optional; for Fail2ban)

The `.sops.yaml` in `.iac/` is set up so that `image_name` and `app_domains` stay unencrypted; everything else is encrypted. Encrypt the file (in VS Code: open and save with the SOPS extension; or via CLI):

```bash
cd /path/to/your/app
sops --encrypt --in-place .iac/iac.yml
```

Commit the encrypted file (never commit the plain file):

```bash
git add .iac/iac.yml
git commit -m "Add encrypted platform config (bootstrap)"
git push
```

## 5. Complete the `.iac/` contract in the app repo

Create these in the **app** repo:

- **`.iac/.env`** — SOPS-encrypted dotenv for app runtime secrets (can be a stub: empty or a comment). Same SOPS keyring as `iac.yml`.
- **`.iac/docker-compose.override.yml`** — Production overrides: Traefik labels (e.g. `Host(\`example.com\`)`), `networks: [default, traefik]`, `restart: unless-stopped`. See [Traefik](traefik.md) and [Application deployment](application-deployment.md).
- **`.github/workflows/build-and-push.yml`** — Thin caller to the IaC reusable workflow. Example:

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

  Set **Variables** in the app repo (Settings → Secrets and variables → Actions): `REGISTRY_URL` = `registry.<base_domain>`, `IMAGE_NAME` = value of `image_name` from `iac.yml`. Set **Secrets**: `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` (from `iac.yml`).

Commit and push:

```bash
git add .iac/ .github/
git commit -m "Add .iac contract and build workflow"
git push
```

## 6. Launch the devcontainer

Open the IaC workspace and start the devcontainer. With `app/.iac/iac.yml` present and decryptable, it will run in **operational mode**: decrypt, write registry/Terraform/hcloud config. If you had the container open before, close and reopen it.

See [Launch the IaC devcontainer](launch-devcontainer.md).

## 7. Terraform Cloud (one-time)

- Create a Terraform Cloud account and organization. Set execution mode to **Local**.
- Create workspaces **`platform-dev`** and **`platform-prod`**. The organization name is read from `terraform_cloud_organization` in `app/.iac/iac.yml`.
- The environment is derived from the workspace name (`platform-dev` → `dev`). Workspaces must exist before `task terraform:init` or `task terraform:apply`.

## 8. Terraform and Ansible

From the IaC devcontainer:

```bash
task terraform:apply -- dev
task ansible:bootstrap -- dev
task ansible:run -- dev
```

Get the server IP with `task terraform:output -- dev`. Use `prod` instead of `dev` for production.

If your IP changes, update `allowed_ssh_ips` in `app/.iac/iac.yml` and run `task terraform:apply -- <workspace>` again.

## 9. Adding more people later

When someone joins, they follow [Joining](joining.md). You add their SOPS public key to `app/.iac/` and run `task secrets:generate-sops-config`, then re-encrypt `app/.iac/iac.yml` so they can decrypt it. See [Secrets](secrets.md).
