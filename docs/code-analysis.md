[**<---**](README.md)

# Static code analysis

Static checks run linters for Terraform, Ansible, and embedded scripts in Taskfiles. They also scan Terraform for security issues.

Run all checks locally:

```bash
task test:run
```

The test suite runs five checks:

1. **Terraform validation** — Validates Terraform syntax and configuration
2. **Terraform security** — Scans for security issues with tfsec
3. **Ansible lint** — Lints Ansible playbooks for issues and best practices
4. **Ansible syntax** — Validates Ansible playbook syntax
5. **Taskfiles** — Validates embedded scripts in Taskfiles with shellcheck

Checks also run in GitHub Actions.

**On a PR:** All checks run. On a Renovate PR we build the image first, then run them. On any other PR we use the existing image (`iac-dev:latest`) and run the checks (no build).

**On merge to main:** The image that was tested for that commit is saved as `latest` for the next PRs. If there was no image for that commit, we build from main, run the checks, and then save it as `latest`.

| Event | What happens |
|-------|--------------|
| PR from Renovate | Build image → run checks |
| PR from you | Use `latest` → run checks |
| Merge to main | Tested image becomes `latest` |

**Secrets:** `SOPS_AGE_KEY` (see [Secrets](secrets.md)). Registry auth: see [Registry](registry.md).
