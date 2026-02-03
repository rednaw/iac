[**<---**](README.md)

## Building on the shoulders of giants

These are the main tools and technologies used by Rednaw IaC

#### Server provisioning
- [Ansible](https://docs.ansible.com/) - Configuration management tool for server setup and automation
- [hcloud](https://github.com/hetznercloud/cli/blob/main/README.md) - Hetzner Cloud CLI
- [Terraform](https://developer.hashicorp.com/terraform) - Infrastructure as Code tool for provisioning cloud resources

#### Secrets management
- [Age](https://github.com/FiloSottile/age/blob/main/README.md) - A simple, modern, and secure file encryption tool, using the age format
- [Sops](https://getsops.io/) - Secrets management tool for encrypting sensitive files in Git

#### Task runner
- [Task](https://taskfile.dev/) - Task runner for defining and executing build commands

#### Version management
- [Mise](https://mise.jdx.dev/) - Version manager for CLI tools
- [Renovate](https://docs.renovatebot.com/) – Automated dependency update PRs, see [Upgrading dependencies](upgrading.md).

#### Application deployment
- [Crane](https://github.com/google/go-containerregistry/blob/main/cmd/crane/README.md) - Container registry CLI (digest, config, catalog)
- [Docker](https://www.docker.com/) - Containerization platform for application deployment
- [Docker Registry](https://distribution.github.io/distribution/) - a stateless, server side application that lets you store and distribute docker images.

#### Web server and TLS
- [Certbot](https://eff-certbot.readthedocs.io/en/stable/intro.html) - Fetches and renews certificates from Let’s Encrypt
- [Nginx](https://nginx.org/) - Reverse proxy and static file serving on the server

#### Server security
- [Fail2ban](https://github.com/fail2ban/fail2ban/blob/master/README.md) - Intrusion prevention by banning IPs that show malicious behaviour (e.g. repeated failed SSH logins)

#### Testing
- [Ansible Lint](https://docs.ansible.com/projects/lint/) - Promotes best practices for Ansible
- [ShellCheck](https://www.shellcheck.net/) - Finds bugs in shell scripts.
- [TFsec](https://aquasecurity.github.io/tfsec/v1.20.0/) - A static analysis security scanner for Terraform code.

