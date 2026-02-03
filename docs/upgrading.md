[**<---**](README.md)

## How upgrading works

The IaC toolkit leverages many tools and techologies, see [Tools and technologies used](TOOLS.md). These tools are in constant development and to keep up to date  upgrades are automated by **[Renovate](https://docs.renovatebot.com/)** as much as possible. 

Renovate runs in CI: the workflow [`.github/workflows/renovate.yml`](../.github/workflows/renovate.yml) runs on a weekly schedule and can be triggered manually. It is configured by [`renovate.json`](../renovate.json) and a repository secret `RENOVATE_TOKEN` (GitHub PAT with `repo` and `workflow` scope).

---

## In scope (Renovate-managed)

These dependencies get upgrade PRs from Renovate.

| Source | What | Manager |
|--------|------|---------|
| **GitHub Actions** | Workflow files (e.g. `renovate.yml`, `static-code-analysis.yml`) and action versions | `github-actions` |
| **Dockerfile** | Base image (`FROM mcr.microsoft.com/devcontainers/base:...`) | `dockerfile` |
| **terraform/** | Providers in `versions.tf` and `.terraform.lock.hcl` | `terraform` |
| **ansible/requirements.yml** | Ansible Galaxy collections | `ansible-galaxy` |
| **requirements.txt** | Python deps: ansible, ansible-lint, PyYAML (Ansible venv in image) | `pip_requirements` |
| **mise.toml** | **5 of 9 CLI tools:** terraform, sops, yq, tfsec, shellcheck | `mise` |

The same image (built from the root Dockerfile) is used by the Dev Container and by CI; upgrading any of the above and merging keeps dev and CI in sync.

---

## Not in scope (manual or unversioned)

These are either not managed by Renovate or have no version in the repo.

| Source | What | Why |
|--------|------|-----|
| **Dockerfile** | Apt packages (`curl`, `unzip`, `jq`, etc.) | Unversioned package names; no version in file to bump. |
| **Dockerfile** | Cursor install (`curl … cursor.com/install`) | No version stored in repo. |
| **mise.toml** | **4 of 9 CLI tools:** age, task, crane, hcloud | Not in Renovate’s mise manager short-name list; bump versions by hand in `mise.toml`. |
| **Other** | Mise binary (from official image in Dockerfile) | Comes from `jdxcode/mise` image; update by changing the image tag if needed. |

To upgrade the four manual mise tools, edit `mise.toml`, update the version (no `v` prefix, e.g. `1.42.0`), rebuild the image and run tests.

---

## Summary

- **Automated:** GitHub Actions, Dockerfile base image, Terraform providers, Ansible Galaxy, Python (requirements.txt), and five CLI tools in mise.toml (terraform, sops, yq, tfsec, shellcheck).
- **Manual:** Apt packages, Cursor, and four CLI tools in mise.toml (age, task, crane, hcloud).

For the list of tools and where their versions live, see [Tools and technologies used](TOOLS.md).
