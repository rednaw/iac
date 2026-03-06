[**<---**](README.md)

# Joining an existing project

The infrastructure exists. A teammate has already set up the server, registry, and platform. You need access to the secrets, SSH, and devcontainer — then you can deploy and operate.

**What you need before starting:**

- [Docker](https://docs.docker.com/get-docker/), [VS Code](https://code.visualstudio.com/) or [Cursor](https://cursor.com/), and the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
- Access to **two repos**: the IaC repo and the app repo
- An SSH key pair (`~/.ssh/id_rsa`), if you don't have one run `ssh-keygen`

---

## 1. Clone both repos

```bash
git clone <iac-repo-url> iac
git clone <app-repo-url> your-app
```

---

## 2. Set the app path and open the devcontainer

On your **host** (not inside the devcontainer):

```bash
cd iac
./scripts/setup-app-path.sh /path/to/your-app
```

- **macOS:** Takes effect immediately.
- **Linux:** Log out and back in, or run `source ~/.profile`.

Then open `iac.code-workspace` in VS Code/Cursor and **Reopen in Container** (Cmd+Shift+P → Dev Containers: Reopen in Container). The devcontainer starts in bootstrap mode since you can't decrypt secrets yet — that's expected.

---

## 3. Generate your SOPS key

Inside the devcontainer:

```bash
task secrets:keygen
```

This creates:

| File | What it is |
|------|-----------|
| `~/.config/sops/age/keys.txt` | Your private key (never share, never commit) |
| `app/.iac/sops-key-<username>.pub` | Your public key (commit to app repo) |

> **Important:** Back up your private key (`~/.config/sops/age/keys.txt`) to a secure location (password manager, encrypted drive). It cannot be recovered if lost.

Commit your public key in the **app repo**:

```bash
cd /workspaces/iac/app
git add .iac/sops-key-*.pub
git commit -m "Add SOPS public key for <yourname>"
git push
```

---

## 4. Ask your teammate to add you

Send your teammate a message — they need to run these commands (with the app mounted in their devcontainer):

```bash
git pull                               # in the app repo
task secrets:generate-sops-config      # adds your key to .sops.yaml
# Open app/.iac/iac.yml in VS Code, save (re-encrypts with your key included)
# Open app/.iac/.env in VS Code, save (re-encrypts)
git add .iac/
git commit -m "Add <yourname> to secrets"
git push
```

**Wait for them to push**, then pull in your app repo:

```bash
cd /workspaces/iac/app
git pull
```

---

## 5. Verify decryption works

Open `app/.iac/iac.yml` in VS Code. If the SOPS extension is working, you should see decrypted YAML with actual values — tokens, passwords, domain names. If it shows garbled encrypted text, check [Secrets: Troubleshooting](secrets.md#troubleshooting).

---

## 6. Reopen the devcontainer (operational mode)

Close the devcontainer and reopen it. Now that you can decrypt `iac.yml`, it starts in **operational mode**: registry auth, Terraform Cloud, and hcloud are configured automatically. You should see messages like:

```
Registry auth configured for registry.<base_domain>.
hcloud CLI configured (context "default").
Terraform Cloud token configured.
```

See [Launch the IaC devcontainer](launch-devcontainer.md) for details.

---

## 7. Configure your SSH access

To run Ansible, deploy, and troubleshoot on the server, you need your SSH key registered with Hetzner and your IP in the firewall:

1. Add your public key (`~/.ssh/id_rsa.pub` or `~/.ssh/id_ed25519.pub`) in **Hetzner Cloud Console** → Project → Security → SSH keys. Note the key **ID** (or run `task server:list-hetzner-keys` to list IDs).

2. Get your current public IP (e.g. [whatismyipaddress.com](https://whatismyipaddress.com/)). Write it in CIDR form: `203.0.113.50/32`.

3. Open `app/.iac/iac.yml` in VS Code (the SOPS extension decrypts it). Add your Hetzner key ID to the `ssh_keys` list and your IP to `allowed_ssh_ips`. Save.

4. Commit, push, and apply:

   ```bash
   cd /workspaces/iac/app
   git add .iac/iac.yml
   git commit -m "Add SSH key and IP for <yourname>"
   git push
   ```

   ```bash
   task terraform:apply -- dev
   ```

If your IP changes later (e.g. different network, VPN), update `allowed_ssh_ips` in `iac.yml` and run `task terraform:apply -- dev` again.

---

## 8. Verify everything works

Run these from the devcontainer and check the expected output:

```bash
task registry:overview
# Expected: lists image repositories and tags (e.g. rednaw/tientje-ketama)

task app:versions -- dev
# Expected: table of available image tags with dates and descriptions
# The → arrow shows which version is currently deployed

task terraform:plan -- dev
# Expected: runs without login prompts, shows "No changes" or planned changes

task server:list-hetzner-keys
# Expected: lists SSH key IDs and names from your Hetzner project
```

If any command fails, see [Troubleshooting](troubleshooting.md).

---

## What's next

- **Deploy:** [Application deployment](application-deployment.md) — deploy flow, commands, app configuration.
- **Server access:** [Remote-SSH](remote-ssh.md) — SSH tunnels for Traefik dashboard and OpenObserve.
- **Terraform Cloud:** The project uses TFC as a backend for shared Terraform state. To see the management console, ask a teammate to add you to the organization.
