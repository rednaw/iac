# Infrastructure as Code

**TL;DR** Bring me to the [documentation](docs/README.md).

## Introduction

You want to self-host. Maybe you left Heroku after the pricing changes. Maybe you care about data sovereignty. Maybe you just want a €4/month server instead of a $25/month platform.

Your options:
1. **PaaS-in-a-box** (Coolify, CapRover) — Click buttons, hope it works, don't look under the hood
2. **Kubernetes** — Spend months learning, over-engineer everything, feel clever
3. **Wing it** — SSH in, docker-compose up, forget how you set it up, dread the next server

None of these feel right.

## This Project

A fourth option: proper infrastructure-as-code, but approachable.

- **Terraform** provisions your server (Hetzner, cheap and European)
- **Ansible** configures it (Docker, security hardening, Traefik and more)
- **SOPS** encrypts your secrets (committed to Git, decrypted transparently in VS Code)
- **docker-compose** runs your apps (the format you already know)

Everything is code. Everything is versioned. Nothing is magic.

![Architecture Diagram](docs/architecture.svg)

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

**Opinionated defaults.** Hetzner. DevContainers. Docker Registry. Traefik. SOPS. OpenObserve. You can change them, but you don't have to decide.

**Single server, done well.** Many projects don't need a cluster. They need one reliable server, properly configured.

**One place to work.** Open the workspace, Reopen in Container, all tooling and services are wired to work together, ready when you are.


