[**<---**](README.md)

## Tools used

The IAC setup uses the following tools. Versions are pinned in `aqua.yaml` (CLI tools) and the root `Dockerfile` (Dev Container and CI); both use the same image.

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
- [Renovate](https://docs.renovatebot.com/) – Automated dependency update PRs (GitHub Actions, Docker, Terraform, aqua, Ansible, etc.). See below.

---

### Renovate (run in CI)

Renovate runs **in your CI** (no separate server, no Mend app): the workflow runs on a schedule and Renovate opens PRs to update dependencies.

**What gets updated**

- GitHub Actions (workflow files)
- Dockerfile base image
- Terraform providers and lock file
- aqua (aquaproj) tools in `aqua.yaml`
- Ansible Galaxy collections in `ansible/requirements.yml`

**How it runs**

Workflow [`.github/workflows/renovate.yml`](../.github/workflows/renovate.yml) runs weekly (Monday before 6am). Add repository secret `RENOVATE_TOKEN` (PAT with `repo` and `workflow` scope). Config: [`renovate.json`](../renovate.json).

