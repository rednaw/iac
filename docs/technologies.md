[**<---**](README.md)

# Tools and technologies

Main tools and technologies used in this project:

## Server provisioning

- [Ansible](https://docs.ansible.com/) — Configuration management for server setup and automation
- [hcloud](https://github.com/hetznercloud/cli/blob/main/README.md) — Hetzner Cloud CLI
- [Terraform](https://developer.hashicorp.com/terraform) — Infrastructure as Code for provisioning cloud resources

## Secrets management

- [Age](https://github.com/FiloSottile/age/blob/main/README.md) — File encryption tool using the age format
- [Sops](https://getsops.io/) — Secrets management for encrypting sensitive files in Git

## Task runner

- [Task](https://taskfile.dev/) — Task runner for defining and executing build commands

## Version management

- [Mise](https://mise.jdx.dev/) — Version manager for CLI tools
- [Renovate](https://docs.renovatebot.com/) — Automated dependency update PRs; see [Upgrading](upgrading.md)

## Application deployment

- [Crane](https://github.com/google/go-containerregistry/blob/main/cmd/crane/README.md) — Container registry CLI (digest, config, catalog)
- [Docker](https://www.docker.com/) — Containerization platform for application deployment
- [Docker Registry](https://distribution.github.io/distribution/) — Stateless server application for storing and distributing Docker images

## Web server and TLS

- [Traefik](https://doc.traefik.io/traefik/) — Reverse proxy with built-in Let's Encrypt (ACME) for TLS

## Server security

- [Fail2ban](https://github.com/fail2ban/fail2ban/blob/master/README.md) — Intrusion prevention by banning IPs that show malicious behavior (e.g. repeated failed SSH logins)

## Testing

- [Ansible Lint](https://docs.ansible.com/projects/lint/) — Promotes best practices for Ansible
- [ShellCheck](https://www.shellcheck.net/) — Finds bugs in shell scripts
- [TFsec](https://aquasecurity.github.io/tfsec/v1.20.0/) — Static analysis security scanner for Terraform code
