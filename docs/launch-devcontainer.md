[**<---**](README.md)

# Launch the IaC devcontainer

The IaC devcontainer provides a standardized environment with all tools pre-installed (Task, Terraform, Ansible, SOPS, crane, Docker CLI, jq, and more via [mise](https://mise.jdx.dev/)). It automatically configures registry, Terraform Cloud, and hcloud from your secrets file so you don't need to log in manually.

**Before this:** You need Docker, VS Code or Cursor, and the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension. If you're creating a new project, complete [New project](new-project.md) through creating and encrypting the secrets file first. If you're joining, complete [Joining](joining.md) through getting added to the SOPS keyring (and SSH if you need server access).

## 1. Set your app path (if you have an app to deploy)

On the **host**, run:

```bash
./scripts/setup-app-path.sh /path/to/your/app
```

**App requirements:**

- `docker-compose.yml`
- `.iac/` directory
- `.github/workflows/build-and-push.yml` 

The devcontainer bind-mounts these files and directory; if they are missing, the container may not start. For a new app, create it first ([New project → step 5](new-project.md#5-complete-the-iac-contract-in-the-app-repo)).

The app is mounted at `/workspaces/iac/app`. See [Application deployment → App mount](application-deployment.md#app-mount) for details.

## 2. Open the workspace in the devcontainer

1. **File → Open Workspace from File...** → select `iac.code-workspace` in the repo root.
2. When prompted, choose **Reopen in Container** (or **Cmd+Shift+P** → **Dev Containers: Reopen in Container**). Wait for the image to build.

## 3. What happens on startup

When the devcontainer starts (operational mode), it decrypts `app/.iac/iac.yml` using your mounted `~/.config/sops/age/keys.txt` and writes:

- **`~/.docker/config.json`** — Registry auth (for application deployment).
- **`~/.terraform.d/credentials.tfrc.json`** — Terraform Cloud token (shared state).
- **`~/.config/hcloud/cli.toml`** — Hetzner Cloud API token.

You don't need to run `task terraform:login` or `hcloud context create`; they are populated from the secrets file. You now have access to the registry, Terraform Cloud, and Hetzner from inside the devcontainer.

The devcontainer also includes VS Code extensions (SOPS, dotenv) and `files.associations` so encrypted `.env` files are edited as dotenv.

**If you don't have decrypt access yet:** The devcontainer will still start, but it won't write these credentials until you're part of the SOPS keyring and the secrets file is present. Complete [New project](new-project.md) (create and encrypt the file) or [Joining](joining.md) (get added to the keyring), then close and reopen the container.

## 4. Overview

```mermaid
flowchart TB
    subgraph HOST["Laptop"]
        SECRETS@{ shape: lin-doc, label: "private keys<br/>~/.config/sops/age/keys.txt<br/>~/.ssh/id_rsa" }
        APP@{ shape: lin-doc, label: "Encrypted<br/>Infrastructure secrets<br/>Application secretss" }
    end

    subgraph DEVCONTAINER["IaC Devcontainer"]
        TOOLS(Task, SOPS, Terraform, Ansible)
        SETUP(Devcontainer init)
        DOCKER_CONFIG@{ shape: lin-doc, label: "~/.docker/config.json" }
        TF_CRED@{ shape: lin-doc, label: "~/.terraform.d/credentials.tfrc.json" }
        HCLOUD_CONFIG@{ shape: lin-doc, label: "~/.config/hcloud/cli.toml" }
    end

    subgraph EXTERNAL["External services"]
        TF_CLOUD(Terraform Cloud)
        HCLOUD(Hetzner Cloud)
    end

    subgraph SERVER[Hetzner Server]
      subgraph DOCKER[Docker]
        APP_SERVICE(Application)
        REGISTRY(Registry)
      end
    end


    SECRETS --->|mounted| DEVCONTAINER
    APP --->|mounted| DEVCONTAINER

    SETUP -->|create| DOCKER_CONFIG
    SETUP -->|create| TF_CRED
    SETUP -->|create| HCLOUD_CONFIG

    TOOLS -->|manage| SERVER

    DOCKER_CONFIG -->|authorize| REGISTRY
    TF_CRED -->|authorize| TF_CLOUD
    HCLOUD_CONFIG -->|authorize| HCLOUD
```
