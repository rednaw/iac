[**<---**](README.md)

# Joining

This page is for **joining an existing project**. You get access (SOPS key, SSH), then operate. One-time setup: create a SOPS key, get added to the keyring, add your SSH key and IP to secrets. After that, the devcontainer configures Hetzner Cloud, Docker Registry, and Terraform Cloud from the secrets file.

## 1. The SOPS keyring

You need to be part of the SOPS keyring to be able to decrypt `app/.iac/iac.yml`.

**You generate a new key and get added:**


1. Generate your key and commit your public key:
   ```bash
   git clone <repo-url> iac && cd iac
   # Mount the app (setup-app-path.sh) and open devcontainer, then:
   task secrets:keygen
   cd /path/to/app && git add .iac/sops-key-*.pub && git commit -m "Add SOPS public key for <yourname>" && git push
   ```
2. Ask a teammate to add you to the secrets and re-encrypt (they run, with app mounted):
   ```bash
   git pull   # in the app repo
   task secrets:generate-sops-config   # Updates app/.iac/.sops.yaml
   # Open app/.iac/iac.yml in VS Code, save (re-encrypt)
   git add .iac/ && git commit -m "Add <yourname> to secrets" && git push
   ```
3. Pull and put your private key in place:
   ```bash
   git pull   # in the app repo
   ```

   > **Important:** Your private key is in `~/.config/sops/age/keys.txt`. It is not in the repo and cannot be recovered if lost. Back it up to a secure location (password manager, encrypted drive) before continuing.

4. Verify that it works:
   Open `app/.iac/iac.yml`, you should be able to view and edit the secrets.

## 2. Launch the IaC devcontainer

Open the workspace and start the devcontainer so it decrypts secrets and configures your credentials (registry, Terraform Cloud, hcloud).

See [Launch the IaC devcontainer](launch-devcontainer.md) for the steps (setup-app-path, open workspace, Reopen in Container) and what happens on startup.

**Terraform Cloud:** This project uses TFC as a free backend for shared Terraform state. If you want to see the management console, ask a teammate to add you to the Terraform Cloud organization. See [New project](new-project.md) (Terraform Cloud section) for how it's set up.

## 3. Configure your SSH access

To log in to servers for maintenance, troubleshooting, and running Ansible you need your SSH key on Hetzner and your IP allowed by the firewall:

1. Add your public key (`~/.ssh/id_rsa.pub`) in Hetzner Cloud Console → Project → Security → SSH keys. Note the key **ID** (or run `task server:list-hetzner-keys` to list IDs).
2. Get your current IP (e.g. [whatismyipaddress.com](https://whatismyipaddress.com/)); use CIDR form e.g. `203.0.113.50/32`.
3. Open `app/.iac/iac.yml` in VS Code (SOPS extension decrypts it). Add your Hetzner key ID to the `ssh_keys` list and your IP to `allowed_ssh_ips`. Save (the extension re-encrypts).
4. Commit and push (in the app repo), then update the firewall:
   ```bash
   git add .iac/iac.yml
   git commit -m "Add SSH key and IP for <yourname>"
   git push
   task terraform:apply -- dev   # or prod, if you have both
   ```

If your IP changes later (e.g. new network or VPN), update `allowed_ssh_ips` and run `task terraform:apply -- <workspace>` again. Remember the `--` separator (e.g. `task terraform:apply -- dev`).

## 4. Optional: Connect via Remote-SSH (work on the server)

See [Remote-SSH](remote-ssh.md).

## 5. Verify

- **Registry:** `task registry:overview` (should list repos/tags).
- **Deployment status:** `task app:versions -- dev` (should show the deployment status of the app)
- **Terraform:** `task terraform:plan -- dev` (should run without asking for login).
- **hcloud:** `task server:list-hetzner-keys` (should list keys).

Next: [Application deployment](application-deployment.md) (deploy flow, commands), [Troubleshooting](troubleshooting.md). For Terraform Cloud details (workspaces, state) and full provisioning, see [New project](new-project.md).
