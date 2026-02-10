[**<---**](README.md)

# Getting started

## Requirements

- **[Docker](https://docs.docker.com/get-docker/)**
- **[VS Code](https://code.visualstudio.com/)** or **[Cursor](https://cursor.com/)** with the following extensions:
  - **[Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)** (`ms-vscode-remote.remote-containers`).
  - **[SOPS](https://marketplace.visualstudio.com/items?itemName=signageos.signageos-vscode-sops)** by SignageOS (`signageos.signageos-vscode-sops`). Configure the key path in settings; see [Secrets](secrets.md#vs-code-integration).
  - **[Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh)** (`ms-vscode-remote.remote-ssh`) for [running VSCode or Cursor on the server](CURSOR.md).

## Summary

Clone the repo, open the `iac` folder, and choose **Reopen in Container**.

Follow one of these install paths.

| Situation | Guide |
|-----------|--------|
| **New project** — you are creating infrastructure and there is no `infrastructure-secrets.yml` yet | [Install: new project](new-project.md) |
| **Joining** — the repo already has encrypted secrets and you need access | [Install: joining an existing project](joining.md) |


## Provision server

After completing your install path, use:

```bash
task terraform:init -- dev              # Initialize Terraform for dev
task terraform:apply -- dev             # Create dev server
task ansible:install                    # Install Ansible collections (once)
task ansible:bootstrap -- dev           # Setup ubuntu user (one-time, requires server IP)
task ansible:run -- dev                 # Configure dev server
```

**Server IP:** `task terraform:output -- dev` or `task terraform:output -- prod`

Use `prod` instead of `dev` for production.
