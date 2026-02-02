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

The IAC test suite is automatically executed via GitHub Actions. The workflow (`.github/workflows/static-code-analysis.yml`) builds the same Docker image used by the Dev Container, pushes it to GitHub Container Registry, then runs all five checks sequentially (each as its own step for clear feedback). The workflow fails early if the `SOPS_AGE_KEY` secret is not configured, which is required for decrypting SOPS-encrypted files. 

