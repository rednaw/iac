[**<---**](../README.md)

# Documentation

This diagram shows the main pieces: the IaC devcontainer, your app repo, and the server. 

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

    subgraph APP[Your application repo]
      COMPOSE@{ shape: lin-doc, label: "docker-compose.yml<br/>Application services" }
      IAC_YML@{ shape: lin-doc, label: "iac.yml<br/>IaC configuration" }
      PUSH@{ shape: subproc, label: "Github workflow<br/>Build and push" }
      APP_SECRETS@{ shape: lin-doc, label: ".env<br/>Encrypted secrets" }
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

The IaC devcontainer mounts four files in your local application clone so you can deploy without installing tools like Task, Ansible or Terraform on your local machine or application Devcontainer.

---

## Onboarding

[**Onboarding**](onboarding.md) — Choose your path: create a new project or join an existing one.

---

## Reference

**Infrastructure**

- [Traefik](traefik.md) — Reverse proxy, TLS, operations, adding apps
- [Registry](registry.md) — Auth, commands, operations
- [Monitoring](monitoring.md) — OpenObserve, dashboards, logs

**Application**

- [Application deployment](application-deployment.md) — Commands, app mount, records, implementation details
- [Secrets](secrets.md) — File locations, editing, SOPS, app secrets

**Operations**

- [Troubleshooting](troubleshooting.md) — Common issues and fixes
- [Upgrading dependencies](upgrading.md) — Renovate, PRs
- [Remote-SSH](remote-ssh.md) — Connect to the server via Remote-SSH (tunnel, dashboards)

**Meta**

- [Private (local config)](private.md) — Local config files
- [Code analysis](code-analysis.md) — What runs, when (CI), how to run locally
- [Tools and technologies](technologies.md) — Link list

---

**Other**

- [Contributing](../CONTRIBUTING.md) · [Documentation strategy](documentation-strategy.md)
