[**<---**](README.md)

## Tools used

The IAC setup uses the following tools. Versions are pinned in `mise.toml` (CLI tools) and the root `Dockerfile` (Ansible venv); Dev Container and CI use the same image.

#### production
- [Terraform](https://developer.hashicorp.com/terraform) - Infrastructure as Code tool for provisioning cloud resources
- [Ansible](https://docs.ansible.com/) - Configuration management tool for server setup and automation
- [Docker](https://www.docker.com/) - Containerization platform for application deployment
- [Sops](https://getsops.io/) - Secrets management tool for encrypting sensitive files in Git
- [Task](https://taskfile.dev/) - Task runner for defining and executing build commands
- [Certbot](https://eff-certbot.readthedocs.io/en/stable/intro.html) fetches certificates from Let’s Encrypt—an open certificate authority,

#### testing
- [TFsec](https://aquasecurity.github.io/tfsec/v1.20.0/) - A static analysis security scanner for Terraform code.
- [Ansible Lint](https://docs.ansible.com/projects/lint/) - Promotes best practices for Ansible
- [ShellCheck](https://www.shellcheck.net/) - Finds bugs in shell scripts.

#### dependency updates
- [Renovate](https://docs.renovatebot.com/) – Automated dependency update PRs. What is upgraded and what is manual is documented in [Upgrading dependencies](upgrading.md). Workflow [`.github/workflows/renovate.yml`](../.github/workflows/renovate.yml) runs weekly (Monday 05:00 Amsterdam); requires repository secret `RENOVATE_TOKEN` (PAT with `repo` and `workflow` scope).

