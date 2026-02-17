[**<---**](README.md)

# Getting started

## Requirements

- **[Docker](https://docs.docker.com/get-docker/)**
- **[VS Code](https://code.visualstudio.com/)** or **[Cursor](https://cursor.com/)** with the following extensions:
  - **[Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)** (`ms-vscode-remote.remote-containers`).
  - **[SOPS](https://marketplace.visualstudio.com/items?itemName=signageos.signageos-vscode-sops)** by SignageOS (`signageos.signageos-vscode-sops`). Configure the key path in settings; see [Secrets](secrets.md#vs-code-integration).
  - **[Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh)** (`ms-vscode-remote.remote-ssh`) for [running VS Code or Cursor on the server](remote-vscode.md).

## Summary

1. Clone the repo, open the `iac` folder, VSCode/Cursor will offer to reopen in devcontainer, **do not do that yet**.
2. Set which app the devcontainer will mount: run **`./scripts/setup-app-path.sh /path/to/your/app`** (the app must have `iac.yml`, `docker-compose.yml`, `.env`, and `.sops.yaml`). See [Application deployment](application-deployment.md#app-mount).
3. For setting up a **new project** follow the [Install: new project](new-project.md) guide, if you want to join an **existing project** follow the [Install: joining an existing project](joining.md) guide.

## Result
When done you will be in full control of your application infrastructure using the IaC Devcontainer

```mermaid
graph TB
    subgraph IAC[IaC Devcontainer]
        TASK(Taskfile<br/>Automation)
        SOPS(SOPS<br/>Secrets Management)
        TF(Terraform)
        ANS(Ansible)
        INFRA_SECRETS@{ shape: lin-doc, label: "infrastructure-secrets.yml" }
    end

    subgraph SERVER[Ubuntu Server]
      TRAEFIK(Traefik<br/>Reverse Proxy + TLS)
      subgraph DOCKER[App Docker Compose]
        SUPPORTING_SERVICES@{ shape: cyl, label: "Supporting Services<br/>Postgres, Redis, ..." }
        APP_SERVICE(Application Service)
      end
      OBSERVE(OpenObserve<br/>Monitors system health)
      REGISTRY(Docker Registry)
      SEC(Security hardening<br/>Fail2ban, SSH, AbuseIPDB)
    end

    subgraph APP[Application Devcontainer]
      COMPOSE@{ shape: lin-doc, label: "docker-compose.yml<br/>Application services" }
      IAC_YML@{ shape: lin-doc, label: "iac.yml<br/>IaC configuration" }
      PUSH@{ shape: subproc, label: "Github workflow<br/>Build and push" }
      APP_SECRETS@{ shape: lin-doc, label: ".env<br/>Application secrets" }
      SOPS_CONFIG@{ shape: lin-doc, label: ".sops.yml<br/>SOPS configuration" }
    end

    IAC -->|mount 4 files| APP
    
    TASK -->|orchestrate| TF
    TASK -->|orchestrate| ANS

    SOPS -->|read| INFRA_SECRETS
        
    TF -->|provision| SERVER
    TF -->|read| SOPS
    
    ANS -->|provision| SERVER
    ANS -->|read| SOPS

    APP_SERVICE -->|pull application image| REGISTRY
    PUSH --->|push application image| REGISTRY 
    
    APP_SERVICE -->|proxy| TRAEFIK
```