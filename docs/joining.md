[**<---**](README.md)

# Install: joining an existing project

Use this path when the repo already has an encrypted `infrastructure-secrets.yml` file and a SOPS key ring. Your only one-time setup is creating a SOPS key and asking a teammate to add it to the keyring. After that, the devcontainer automatically configures connections to Hetzner Cloud, Docker Registry, and Terraform Cloud from the secrets file.

## 1. The SOPS keyring

You need to be part of the SOPS keyring to be able to decrypt `secrets/infrastructure-secrets.yml`.

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
   Your private key is in `~/.config/sops/age/keys.txt` (created by `task secrets:keygen`). It is not in the repo, keep it somewhere safe.

4. Verify that it works:
   Open `secrets/infrastructure-secrets.yml`, you should be able to view and edit the secrets.

## 2. Launch the IaC Devcontainer

1. Run **`./scripts/setup-app-path.sh /path/to/your/app`** on the host (the app must have `iac.yml`, `docker-compose.yml`, and `secrets.yml`).
2. Open the workspace: **File → Open Workspace from File...** → select `iac.code-workspace` in the repo root.
3. Run **Cmd+Shift+P** → **Dev Containers: Reopen in Container**.

On startup, the devcontainer decrypts `secrets/infrastructure-secrets.yml` (using your mounted `~/.config/sops/age/keys.txt`) and writes:

- `~/.docker/config.json` — Credentials for the built in Docker Registry used for application deployment.
- `~/.terraform.d/credentials.tfrc.json` — Terraform Cloud token used for shared terraform state.
- `~/.config/hcloud/cli.toml` — Hetzner Cloud API token used for creating the server and firewall.

This means that you now have access to the Hetzner cloud, Terraform cloud and Docker registry without needing to login.

**Terraform Cloud:** This project uses TFC solely as a free backend for storing shared terraform state even though it offers lots of other functionality. That functionality is explicitly avoided to stay clear of vendor lockin. TFC comes with an extensive management console, if you are interested ask an existing team member to add you to the Terraform Cloud organization so you can have a look. See [Install: new project](new-project.md) (Terraform Cloud section) for more info.

## 3. Configure your SSH access

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

## 4. Optional: Run VScode/Cursor on the server

See the [Run VScode/Cursor on the server] documentation

## 5. Verify

- **Registry:** `task registry:overview` (should list repos/tags).
- **Deployment status:** `task app:versions -- dev` (should show the deployment status of the app)
- **Terraform:** `task terraform:plan -- dev` (should run without asking for login).
- **hcloud:** `task server:list-hetzner-keys` (should list keys).

For Terraform Cloud setup details (workspaces, state, recovery) and full provisioning (Ansible bootstrap and run), see [Getting started](getting-started.md) and [Application deployment](application-deployment.md).
