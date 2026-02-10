# Infrastructure as Code

**TL;DR** Bring me to the [documentation](docs/README.md)

![Architecture Diagram](docs/architecture.svg)

You want to self-host. Maybe you left Heroku after the pricing changes. Maybe you care about data sovereignty. Maybe you just want a €4/month server instead of a $25/month platform.

Your options:
1. **PaaS-in-a-box** (Coolify, CapRover) — Click buttons, hope it works, don't look under the hood
2. **Kubernetes** — Spend months learning, over-engineer everything, feel clever
3. **Wing it** — SSH in, docker-compose up, forget how you set it up, dread the next server

None of these feel right.

## This Project

A fourth option: proper infrastructure-as-code, but approachable.

- **Terraform** provisions your server (Hetzner, cheap and European)
- **Ansible** configures it (Docker, security hardening, Nginx)
- **SOPS** encrypts your secrets (committed to Git, decrypted transparently in VS Code)
- **docker-compose** runs your apps (the format you already know)

Everything is code. Everything is versioned. Nothing is magic.

## Who This Is For

- **Indie hackers** — Ship your side project on a €4/month VPS
- **Small teams** — Deploy 2-5 apps without a platform team
- **Learners** — Understand IaC properly, not through a GUI
- **Privacy-conscious developers** — Your data, your servers, your jurisdiction

## Who This Is Not For

- Teams that need auto-scaling (use Kubernetes)
- People who don't want to touch a terminal (use Coolify)
- Enterprises with compliance requirements (hire a platform team)

## Philosophy

**Teach, don't hide.** Every decision is documented. When you outgrow this, you'll understand what you're moving to.

**Opinionated defaults.** Hetzner. Ubuntu. Docker. Nginx. SOPS. You can change them, but you don't have to decide.

**Single server, done well.** Most projects don't need a cluster. They need one reliable server, properly configured.

**Developer experience matters.** Open the repo in a Dev Container and get a consistent environment; edit encrypted secrets in VS Code; run commands through Taskfile. No context-switching to web consoles.

## Automate everything

```mermaid
graph TB
    subgraph "Laptop"
        DEV((dev))
        TASK[Taskfile<br/>Automation]
        SOPS[SOPS<br/>Secrets Management]
    end

    subgraph "Layer 2: Configuration Management"
        ANS[Ansible]
        TASKS[Ansible Tasks<br/>base, nginx, docker, etc.]
        TEMP[Jinja2 Templates]
    end
    
    subgraph "Layer 1: Infrastructure Provisioning"
        TF[Terraform]
        TFC[Terraform Cloud<br/>State Management]
        HETZ[Hetzner Cloud<br/>VPS, Firewall]
    end
        
    subgraph "Layer 3: Application Deployment"
        DC[Docker Compose]
        APP[Application Services]
    end
    
    subgraph "Hetzner"
        SERVER[Ubuntu Server<br/>Hetzner VPS]
        NGINX[Nginx<br/>Reverse Proxy]
        DOCKER[Docker Engine]
        SEC[Security Tools<br/>fail2ban, SSH hardening]
    end
    
    DEV -->|task commands| TASK
    TASK -->|orchestrates| TF
    TASK -->|orchestrates| ANS
    TASK -->|manages| SOPS
    
    SOPS -->|decrypts| TF
    SOPS -->|decrypts| ANS
    
    TF -->|provisions| HETZ
    TF -->|stores state| TFC
    HETZ -->|creates| SERVER
    
    ANS -->|uses| TASKS
    ANS -->|uses| TEMP
    ANS -->|configures| SERVER
    ANS -->|triggers| DC
    
    SERVER -->|runs| NGINX
    SERVER -->|runs| DOCKER
    SERVER -->|runs| SEC
    
    DC -->|deploys| APP
    DOCKER -->|runs| APP
    NGINX -->|proxies| APP
    
    style TF fill:#7c3aed,color:#fff
    style ANS fill:#ee0000,color:#fff
    style DC fill:#2496ed,color:#fff
    style TFC fill:#623ce4,color:#fff
    style HETZ fill:#d50c2d,color:#fff
    style SERVER fill:#e95420,color:#fff
```
