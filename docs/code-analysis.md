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

Checks also run in GitHub Actions. The CI needs two secrets: `SOPS_AGE_KEY` (see [Secrets](secrets.md)) and registry credentials (see [Registry](registry.md#authentication)).

| Event | What happens |
|-------|--------------|
| PR from Renovate | Build image → run checks |
| PR from you | Use `latest` → run checks |
| Merge to main | Tested image becomes `latest` |

If a check fails locally, fix the issue and re-run `task test:run` before pushing.
