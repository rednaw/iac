[**<---**](README.md)

# Install: joining an existing project

Use this path when the repo already has `infrastructure-secrets.yml` (encrypted) and a SOPS key ring. Your only one-time setup is getting the SOPS private key. After that, the devcontainer configures registry, Terraform Cloud, and hcloud for you from the existing secrets file.

## 1. Get the SOPS key

You need the private key that can decrypt `secrets/infrastructure-secrets.yml`.

**You generate a new key and get added:**

1. Generate your key and commit your public key:
   ```bash
   git clone <repo-url> iac && cd iac
   task secrets:keygen
   git add secrets/sops-key-*.pub
   git commit -m "Add SOPS public key for <yourname>"
   git push
   ```
2. Ask a teammate to add you to the secrets and re-encrypt:
   ```bash
   # Teammate runs:
   git pull
   task secrets:generate-sops-config   # Updates .sops.yaml with your key
   # Open secrets/infrastructure-secrets.yml in VS Code, save (re-encrypt)
   git add .sops.yaml secrets/infrastructure-secrets.yml
   git commit -m "Add <yourname> to secrets"
   git push
   ```
3. Pull and put your private key in place:
   ```bash
   git pull
   ```
   Your private key is in `~/.config/sops/age/keys.txt` (created by `task secrets:keygen`). If you use another machine, you must copy this file there securely; it is not in the repo.

## 2. Development environment

1. Open the `iac` folder in VS Code or Cursor.
2. Choose **Reopen in Container**. Wait for the image to build or pull (first time only).

On startup, the devcontainer decrypts `secrets/infrastructure-secrets.yml` (using your mounted `~/.config/sops/age/keys.txt`) and writes:

- `~/.docker/config.json` — registry auth for Docker, crane, Trivy
- `~/.terraform.d/credentials.tfrc.json` — Terraform Cloud token
- `~/.config/hcloud/cli.toml` — Hetzner Cloud API token

You do not need to run `task terraform:login` or `hcloud context create`; they are configured from the secrets file.

**Terraform Cloud:** Credentials are configured from secrets by the devcontainer. Ask an existing member to add you to the Terraform Cloud organization. If you will run Terraform (e.g. to apply firewall changes), initialize the workspace once: `task terraform:init -- dev` or `task terraform:init -- prod` (use the `--` separator). State is stored in Terraform Cloud, one workspace per environment. For how the org and workspaces are set up, see [Install: new project](new-project.md) (Terraform Cloud section).

## 3. Add your SSH access

To log in to servers for maintenance, troubleshooting, and running Ansible you need your SSH key on Hetzner and your IP allowed by the firewall:

1. Add your public key (`~/.ssh/id_rsa.pub`) in Hetzner Cloud Console → Project → Security → SSH keys. Note the key **ID** (or run `task server:list-hetzner-keys` to list IDs).
2. Get your current IP (e.g. [whatismyipaddress.com](https://whatismyipaddress.com/)); use CIDR form e.g. `203.0.113.50/32`.
3. Open `secrets/infrastructure-secrets.yml` in VS Code (SOPS extension decrypts it). Add your Hetzner key ID to the `ssh_keys` list and your IP to `allowed_ssh_ips`. Save (the extension re-encrypts).
4. Commit and push, then update the firewall:
   ```bash
   git add secrets/infrastructure-secrets.yml
   git commit -m "Add SSH key and IP for <yourname>"
   git push
   task terraform:apply -- dev   # or prod, if you have both
   ```

If your IP changes later (e.g. new network or VPN), update `allowed_ssh_ips` and run `task terraform:apply -- <workspace>` again. Remember the `--` separator (e.g. `task terraform:apply -- dev`).

## 4. Optional: SSH config for Cursor Remote-SSH

To use Cursor Remote-SSH with the server, run once (from inside the devcontainer):

```bash
task server:setup-remote-cursor
```

This updates `~/.ssh/config` with the server host and settings. The task uses Terraform output or inventory to get the server IP.

## 5. Verify

- **Registry:** `task registry:overview` (should list repos/tags).
- **Terraform:** `task terraform:plan -- dev` (should run without asking for login).
- **hcloud:** `task server:list-hetzner-keys` (should list keys).
- **Secrets:** Open `secrets/infrastructure-secrets.yml` in VS Code; it should decrypt without errors.

For Terraform Cloud setup details (workspaces, state, recovery) and full provisioning (Ansible bootstrap and run), see [Getting started](getting-started.md) and [Application deployment](application-deployment.md).
