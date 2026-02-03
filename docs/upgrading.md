[**<---**](README.md)

## How upgrading works

The Rednaw IaC toolkit leverages many tools and techologies, see [Tools and technologies used](TOOLS.md). These technologies are in constant development so to keep up to date  upgrades are automated by **[Renovate](https://docs.renovatebot.com/)** as much as possible. 

Renovate runs in CI: the workflow [`.github/workflows/renovate.yml`](../.github/workflows/renovate.yml) runs on a daily schedule and can be triggered manually. It is configured by [`renovate.json`](../renovate.json) and a repository secret `RENOVATE_TOKEN` (GitHub PAT with `repo` and `workflow` scope).

Renovate opens upgrade PRs; testing tools and workflow actions are upgraded automatically when CI passes; everything else (ansible, terraform, sops, image, etc.) is one PR per dependency and needs to be merged manually.


## Package files

These files declare versioned dependencies and are monitored by Renovate

| File | What |
|--------|------|
| **requirements.txt** | Python dependencies: ansible, ansible-lint, PyYAML |
| **mise.toml** | CLI tools: terraform, sops, yq, tfsec, shellcheck, age, task, crane, hcloud |
| **ansible/requirements.yml** | Ansible collections |
| **GitHub Actions** | Marketplace actions in workflow files |
| **Dockerfile** | Base image (`FROM mcr.microsoft.com/devcontainers/base:...`) |
| **terraform/** | Providers in `versions.tf` and `.terraform.lock.hcl` |

