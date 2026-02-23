[**<---**](README.md)

# New project (bootstrapping from scratch)

Create the platform. Use this when you are creating new infrastructure and there is no `infrastructure-secrets.yml` yet. You will create the secrets file once, encrypt it with SOPS, and from then on the devcontainer will use it to configure registry, Terraform Cloud, and hcloud automatically.

## 1. Development environment

1. Install [Docker](https://docs.docker.com/get-docker/), [VS Code](https://code.visualstudio.com/) or [Cursor](https://cursor.com/), and the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension.
2. Clone the repo.
3. On the host, run **`./scripts/setup-app-path.sh /path/to/your/app`** (the app must have `iac.yml`, `docker-compose.yml`, `.env`, `.sops.yaml`). You'll open the devcontainer after creating secrets in the steps below.

Until you have created and encrypted `infrastructure-secrets.yml`, the devcontainer cannot configure Terraform Cloud, hcloud, or registry auth. Create the secrets file (steps 2–4), then open the workspace and launch the devcontainer—see [Launch the IaC devcontainer](launch-devcontainer.md).

## 2. SOPS key and config

Generate your age key pair and prepare SOPS to encrypt a single key-holder (you) initially:

```bash
task secrets:keygen
task secrets:generate-sops-config
```

This creates `~/.config/sops/age/keys.txt` (private key, keep secret) and `secrets/sops-key-<username>.pub` (commit this), and generates `.sops.yaml` so that files matching `secrets/infrastructure-secrets.yml` are encrypted with your public key. Commit the public key and `.sops.yaml`:

```bash
git add secrets/sops-key-*.pub .sops.yaml
git commit -m "Add SOPS key and config for bootstrap"
git push
```

## 3. External accounts and tokens

Create the following; you will put the relevant values into `infrastructure-secrets.yml` in the next step.

| What | Where to get it |
|------|------------------|
| **Hetzner Cloud API token** | Hetzner Cloud Console → Security → API tokens. Create a token with Read & Write. |
| **Terraform Cloud token** | Terraform Cloud → User Settings → Tokens. Create an API token. You need an organization (e.g. create one) and workspaces `platform-dev` and `platform-prod` (see step 6 below). |
| **Registry credentials** | If you use the self-hosted registry: choose a username and password and the registry domain; the registry will be configured later by Ansible. If you use a third-party registry, use its credentials. |
| **Your SSH public key** | Ensure you have `~/.ssh/id_rsa.pub` (or generate with `ssh-keygen`). You will add this key to Hetzner and put the Hetzner key ID in secrets. SSH is used to log in to the server for maintenance and troubleshooting. |
| **Your IP for SSH** | Your current IP (e.g. from [whatismyipaddress.com](https://whatismyipaddress.com/)); use CIDR form e.g. `203.0.113.50/32`. The firewall only allows SSH from IPs listed in `allowed_ssh_ips`. |

Add your SSH public key to Hetzner Cloud: Console → Project → Security → SSH keys → Add. Note the key **ID** (numeric) for the next step. You can also get the ID later with `task server:list-hetzner-keys` (after hcloud is configured).

## 4. Create and encrypt infrastructure-secrets.yml

Create `secrets/infrastructure-secrets.yml` (plain YAML) with at least:

- `hcloud_token` — Hetzner Cloud API token
- `ssh_keys` — list of Hetzner SSH key IDs, e.g. `["12345678"]`
- `allowed_ssh_ips` — list of CIDRs allowed to SSH, e.g. `["203.0.113.50/32"]`
- `registry_username`, `registry_password`, `base_domain`, `registry_http_secret` — registry auth and config (registry hostname is `registry.<base_domain>`)
- `terraform_cloud_token` — Terraform Cloud API token (used by the devcontainer to write `~/.terraform.d/credentials.tfrc.json`)

The devcontainer reads `hcloud_token` and `terraform_cloud_token` from this file at startup and writes hcloud and Terraform credentials so you do not need to run `hcloud context create` or `task terraform:login` manually.

Encrypt the file with SOPS (in VS Code with the SOPS extension: open the file, save; or via CLI):

```bash
sops --encrypt --in-place secrets/infrastructure-secrets.yml
# Or: edit in VS Code and save; the SOPS extension encrypts on save.
```

Commit the encrypted file (never commit the plain file):

```bash
git add secrets/infrastructure-secrets.yml
git commit -m "Add encrypted infrastructure secrets (bootstrap)"
git push
```

## 5. Launch the devcontainer

Open the workspace and start the devcontainer so it can decrypt secrets and configure your credentials. Close and reopen the container if you already had it open.

See [Launch the IaC devcontainer](launch-devcontainer.md) for the steps (open workspace, Reopen in Container) and what happens on startup (decrypt, write registry/Terraform/hcloud config).

## 6. Terraform Cloud (one-time)

We use Terraform Cloud for shared state, automatic locking, and state history. No local state files; each team member uses the same state.

- Create a Terraform Cloud account and organization (e.g. `rednaw`). Set execution mode to **Local** at organization level.
- Backend in `terraform/versions.tf` expects organization name and workspaces `platform-dev`, `platform-prod`. Create those workspaces in Terraform Cloud:
  1. Go to Terraform Cloud → your organization
  2. Create workspace with name `platform-dev`
  3. Create workspace with name `platform-prod`
- The environment is derived from the workspace name (`platform-dev` → `dev`). Variables like `server_type`, `server_location` can be set via `-var` or `.tfvars` per environment. Workspaces must exist before `task terraform:init -- dev` or `-- prod`.
- Terraform runs locally; state is stored in Terraform Cloud (one state per workspace, automatic locking). Each environment has its own workspace and state. If Terraform Cloud is unreachable, you can recover state using [terraform import](https://developer.hashicorp.com/terraform/tutorials/state/state-import).

## 7. Terraform and Ansible

Initialize Terraform, provision the dev server, and configure it:

```bash
task terraform:init -- dev
task terraform:apply -- dev
task ansible:install
task ansible:bootstrap -- dev
task ansible:run -- dev
```

Get the server IP with `task terraform:output -- dev`. Use `prod` instead of `dev` for production.

**Notes:** Use the `--` separator when passing the workspace (e.g. `task terraform:apply -- dev`). If your IP address changes (e.g. different network or VPN), update `allowed_ssh_ips` in secrets and run `task terraform:apply -- <workspace>` again.

## 8. Adding more people later

When someone joins, they follow [Joining](joining.md). You add their SOPS public key to `.sops.yaml` and re-encrypt `secrets/infrastructure-secrets.yml` so they can decrypt it; after that, their devcontainer will also configure registry, Terraform, and hcloud from the same file. See [secrets.md](secrets.md) for the exact steps.
