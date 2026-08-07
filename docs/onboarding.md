[**<---**](README.md)

# Onboarding

## Before you start

Install on your machine:

- **[Docker](https://docs.docker.com/get-docker/)** — to run the IaC devcontainer
- **[VS Code](https://code.visualstudio.com/) or [Cursor](https://cursor.com/)** — to open the workspace and run extensions

**Extensions** (install in VS Code or Cursor via **Cmd+Shift+X** → search by name):

| Extension | Purpose |
|-----------|---------|
| [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) | Open the IaC repo in the devcontainer (required) |
| [SOPS](https://marketplace.visualstudio.com/items?itemName=signageos.signageos-vscode-sops) (SignageOS) | View and edit encrypted secrets (**`secrets/infra.yml`**, **`.iac/.env`**) (required) |
| [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh) | Connect to the server and use port forwarding for Traefik/OpenObserve dashboards (optional) |

The devcontainer installs additional extensions inside the container (YAML, Ansible, dotenv, Mermaid); you don’t need to install those on the host.

---

Pick your path:

## New project

You have an app and want to deploy it on your own Hetzner server. You will create the infrastructure from scratch, then deploy.

| Step | What you do | Time |
|------|-------------|------|
| 1. **[New project](new-project.md)** | Create SOPS keys, secrets file, external accounts (Hetzner, Terraform Cloud), provision the server with Terraform + Ansible, set up DNS. | ~60 min |
| 2. **[Launch devcontainer](launch-devcontainer.md)** | Open the IaC workspace; **`iac/apps/`** is mounted at **`/workspaces/iac/apps/`**. **`secrets/infra.yml`** decrypt drives credentials. | ~5 min |
| 3. **[Application deployment](application-deployment.md)** | **`apps/<app>/.iac/`** contract: plain **`iac.yml`**, SOPS **`.env`**, **`docker-compose.yml`** with Traefik; **`task app:deploy -- dev <app> <sha>`**. | ~30 min |
| 4. **[App secrets](secrets.md#creating-app-secrets)** | Create `.iac/.env` with app runtime secrets (database URL, API keys). | ~10 min |

When done: your app is live at `https://<your-domain>` with TLS, a private registry, and monitoring.

**Reference implementation:** [tientje-ketama](https://github.com/rednaw/tientje-ketama) is a working app that uses this platform. Use its `.iac/` directory as a reference for file structure and Traefik labels.

---

## Join an existing project

The infrastructure exists. You need **secrets** access (**`secrets/infra.yml`** and **`apps/<app>/.iac/.env`** share recipients — see [Secrets](secrets.md)), then you can operate and deploy.

| Step | What you do | Time |
|------|-------------|------|
| 1. **[Joining](joining.md)** | **`apps/`** under IaC (often submodules), devcontainer, **`task secrets:keygen`**, teammate runs **`generate-sops-config`** + **`sync-all-app-env-sops-configs`** and re-saves **`infra.yml`** / **`.iac/.env`**, SSH firewall in **`secrets/infra.yml`**. | ~20 min (includes waiting for teammate) |
| 2. **[Launch devcontainer](launch-devcontainer.md)** | **`apps/`** bind mount and how **`secrets/infra.yml`** drives credential setup (same container as step 1). | skim |

When done: **`task app:versions -- dev <app>`** with your app folder name under **`apps/`**.

---

## Explore

After onboarding, use the [Reference](README.md#reference) for operations, troubleshooting, and details.
