# Infrastructure as Code

**TL;DR** Bring me to the [documentation](docs/README.md).

## Introduction

You want to self-host. Maybe you left Heroku after the pricing changes. Maybe you care about data sovereignty. Maybe you just want a €4/month server instead of a $25/month platform.

Your options:
1. **PaaS-in-a-box** ([Coolify](https://coolify.io/docs/), [CapRover](https://caprover.com/)) — Click buttons, don't look under the hood, accept that what you get is as good as it gets.
2. **[Kubernetes](https://kubernetes.io/)** — Spend months learning, over-engineer everything, feel clever
3. **Wing it** — SSH in, edit some configuration files, run docker-compose up, forget how you set it up, dread the next server

None of these feel right.

## This Project

A fourth option: proper infrastructure-as-code, but approachable.

- **[Terraform](https://www.terraform.io/)** provisions your server (Hetzner, cheap and European)
- **[Ansible](https://www.ansible.com/)** configures it (Docker, security hardening, Traefik and more)
- **[SOPS](https://getsops.io/)** encrypts your secrets (committed to Git, no need for a secrets manager service)
- **[docker compose](https://docs.docker.com/compose/)** runs your apps (the format you already know)

Everything is code. Everything is versioned. Nothing is magic.

![Architecture Diagram](docs/architecture.svg)

## Batteries included

Build your own server and deploy you app by running a few commands.
- **Hardened server** — SSH keys only, [fail2ban](https://linuxsecurity.com/features/what-is-fail2ban) intrusion prevention, automatic security updates.
- **Deploy your apps** — Be in full control of what version is running.
- **[Private Docker registry](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-registry/)** — Push your application image from GitHub Actions. 
- **[Traefik](https://doc.traefik.io/traefik/) reverse proxy** — HTTPS with [Let's Encrypt](https://letsencrypt.org/), automatic routing via Docker labels.
- **[OpenObserve](https://openobserve.ai/)** — Logs and metrics, no SaaS dependencies.
- **[Prefect](https://www.prefect.io/)** — Schedule tasks and workflows on the server.
- **[Restic](https://restic.net/)** — App backups (local repo and optional Storage Box). See `docs/backups.md`.
- **Secrets in Git** — [SOPS](https://getsops.io/)-encrypted, no need for an external secrets manager.

Work from a [DevContainer](https://containers.dev/) — All tools like [Task](https://taskfile.dev/), [Ansible](https://www.ansible.com/), [Terraform](https://www.terraform.io/), [SOPS](https://getsops.io/) and more come pre-installed and configured to work together.

All configuration and encrypted secrets live in your application repository under `.iac/`.

## Who This Is For

- **Learners** — Understand IaC properly, not through a GUI
- **Small teams** — Deploy 2-5 apps without a platform team
- **Indie hackers** — Ship your side project on a €4/month VPS
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


