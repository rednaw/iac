[**<---**](README.md)

# Private (host config)

What must exist on your machine **outside** the project. Never in Git. The devcontainer mounts `~/.ssh` and `~/.config/sops` from the host; everything else (hcloud, Terraform token, registry auth) is configured inside the container from the encrypted secrets in `.iac/iac.yml` in your project.

| File (on host) | Purpose | Created by |
|----------------|--------|------------|
| `~/.ssh/id_rsa` | SSH to servers | You: run `ssh-keygen`; add `id_rsa.pub` to Hetzner Console → SSH keys |
| `~/.config/sops/age/keys.txt` | Decrypt secrets | You: run `task secrets:keygen` once (from inside devcontainer; file lives on host via mount) |
| `~/.ssh/config` | Server aliases, port forwards | Devcontainer writes on first run |
| `~/.ssh/config.d/iac-admin` | Server aliases, port forwards | Devcontainer writes on first run |

**Related:** [Secrets](secrets.md) · [Registry](registry.md) · [Launch devcontainer](launch-devcontainer.md)
