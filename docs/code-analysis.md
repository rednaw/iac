[**<---**](README.md)

## Static code analysis

The test suite runs linters for terraform, ansible and embedded scripts in tasks, it also scans for security issues in terraform
```bash
# Run all tests
task test:run
```

The test suite runs five checks:
1. **Terraform Validation** - Validates Terraform syntax and configuration
2. **Terraform Security** - Scans for security issues with tfsec
3. **Ansible Lint** - Lints Ansible playbooks for best practices and issues
4. **Ansible Syntax** - Validates Ansible playbook syntax
5. **Taskfiles** - Validates embedded scripts in Taskfiles with shellcheck

The test suite runs in GitHub Actions.

**On a PR:** We always run the checks. On a Renovate PR we build the image first, then run them. On any other PR we use the existing image (`iac-dev:latest`) and run the checks—no build.

**On merge to main:** The image that was tested (from that commit) is saved as `latest` for the next PRs. If there was no image for that commit, we build from main, run the checks, and then save as `latest`.

| Event | What happens |
|-------|----------------|
| PR from Renovate | Build image → run checks |
| PR from you | Use `latest` → run checks |
| Merge to main | Tested image becomes `latest` |

**Secrets:** `SOPS_AGE_KEY` (see [secrets.md](secrets.md)). Registry auth: see [Registry](registry.md). 
