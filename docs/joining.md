[**<---**](onboarding.md)

# Joining an existing project

The infrastructure already exists. You need access to **secrets** (same age recipients for **`secrets/infra.yml`** and **`apps/<app>/.iac/.env`**), SSH, and the devcontainer — then you can deploy and operate.

**What you need before starting:**

- Editor and extensions: see [Onboarding: Before you start](onboarding.md#before-you-start)
- Access to the **IaC fork** and the **app repo(s)** you work on (often Git **submodules** under **`iac/apps/`**)
- An SSH key pair (`~/.ssh/id_ed25519` or `id_rsa`)

---

## 1. Clone the IaC repo and add apps

Clone your fork of the IaC repo. Application repos usually live under **`apps/<name>/`** inside it ([`apps/README.md`](../apps/README.md)). Example using submodules:

```bash
git clone <iac-fork-url> iac
cd iac
git submodule update --init --recursive
```

Use your real app folder name — it becomes **`<app>`** in **`task app:deploy -- dev <app> <sha>`**.

---

## 2. Open the devcontainer

Open **`iac/iac.code-workspace`** in VS Code/Cursor → **Reopen in Container**.

Until **`secrets/infra.yml`** decrypts for you, registry / Terraform Cloud / **hcloud** are usually **not** configured inside the container — expected until you are added as a recipient.

---

## 3. Generate your SOPS key

Inside the container, from the IaC repo:

```bash
cd /workspaces/iac
task secrets:keygen
```

| Output | Purpose |
|--------|---------|
| `~/.config/sops/age/keys.txt` | Private key (never commit) |
| `secrets/sops-key-<username>.pub` | Public key — commit to **IaC fork** |

```bash
cd /workspaces/iac
git add -f secrets/sops-key-*.pub
git commit -m "Add SOPS public key for <yourname>"
git push
```

> Back up **`~/.config/sops/age/keys.txt`** securely — it cannot be recovered if lost.

---

## 4. Ask a teammate to add you

**Same recipients everywhere:** **`secrets/sops-key-*.pub`** drives **`secrets/.sops.yaml`** (for **`infra.yml`**) and **`apps/<app>/.iac/.sops.yaml`** (for **`.env`**).

They **`git pull`**, regenerate rules, re-encrypt files:

```bash
cd /workspaces/iac
git pull
task secrets:generate-sops-config
task secrets:sync-all-app-env-sops-configs
# Open secrets/infra.yml in VS Code, Save (re-encrypt)
# Open each apps/<app>/.iac/.env, Save (re-encrypt)
git add -f secrets/ apps/
git commit -m "Add <yourname> to SOPS recipients"
git push
```

If only one app changed, they can run **`task secrets:generate-app-env-sops-config -- <app>`** instead of **`sync-all`**.

---

## 5. Pull and verify decryption

```bash
cd /workspaces/iac && git pull
git submodule update --init --recursive
```

Open **`secrets/infra.yml`** in VS Code — you should see decrypted YAML. If you still see ciphertext, see [Troubleshooting](troubleshooting.md).

For app work, pull inside **`apps/<app>/`** if it is a submodule (`git pull` / **`git submodule update`**) and verify **`.iac/.env`** decrypts when you need it.

---

## 6. Reopen the devcontainer

Close and reopen the devcontainer. When **`secrets/infra.yml`** decrypts, **`devcontainer-setup.sh`** writes Docker registry auth, Terraform Cloud token, and **hcloud** config. You should see messages such as:

```
Registry auth configured for registry.<base_domain>.
hcloud CLI configured (context "default").
Terraform Cloud token configured.
```

See [Launch the IaC devcontainer](launch-devcontainer.md).

---

## 7. Configure SSH access (firewall)

1. Add your public key in **Hetzner Cloud Console** → Security → SSH keys. Note the numeric key **ID** (or **`task server:list-hetzner-keys`**).
2. Note your public IP in CIDR form, e.g. `203.0.113.50/32`.
3. Open **`secrets/infra.yml`**, add your key ID to **`ssh_keys`** and your IP to **`allowed_ssh_ips`**. Save (re-encrypt).
4. Commit and apply:

   ```bash
   cd /workspaces/iac
   git add -f secrets/infra.yml
   git commit -m "Add SSH key and IP for <yourname>"
   git push
   ```

   ```bash
   task platform:provision:apply -- dev
   ```

If your IP changes later, update **`allowed_ssh_ips`** in **`secrets/infra.yml`** and run **`task platform:provision:apply -- dev`** again.

---

## 8. Verify everything works

Replace **`my-app`** with your app directory name under **`apps/`**:

```bash
task registry:overview
task app:versions -- dev my-app
task platform:provision:plan -- dev
task server:list-hetzner-keys
```

If anything fails, see [Troubleshooting](troubleshooting.md).

---

## What's next

- **Deploy:** [Application deployment](application-deployment.md)
- **Server access:** [Remote-SSH](remote-ssh.md)
- **Terraform Cloud:** Ask a teammate to add you to the organization if you need the web UI.
