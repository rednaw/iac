[**<---**](README.md)

## Local Configuration Files

These files live in your **home directory**, are used by this project, and should **never** be committed to Git. The intended workflow is to use them from inside the **devcontainer**.

| File path | Purpose | Location | Created by (intended) |
|-----------|---------|----------|------------------------|
| `~/.ssh/id_rsa` | SSH private key for authenticating with servers | Host | `ssh-keygen` (if not already exists) |
| `~/.ssh/known_hosts` | SSH host keys for servers you've connected to | Host | SSH client (automatically) |
| `~/.ssh/config` | SSH client configuration for server aliases and connection settings | Host | `task server:setup-remote-cursor` (optional) |
| `~/.config/sops/age/keys.txt` | SOPS private key for decrypting secrets | Host | `task secrets:keygen` |
| `~/.config/hcloud/cli.toml` | Hetzner Cloud CLI configuration and API token | Devcontainer | Devcontainer startup script (from SOPS) |
| `~/.terraform.d/credentials.tfrc.json` | Terraform Cloud authentication token | Devcontainer | Devcontainer startup script (from SOPS) |
| `~/.docker/config.json` | Docker/crane/Trivy auth for private registry in the devcontainer | Devcontainer | Devcontainer startup script — see [Registry](registry.md#authentication-how-to-log-in) |

### Details

**`~/.ssh/id_rsa*`**
- **Relevance:** Your SSH key pair used to authenticate with Hetzner Cloud servers
- **Setup:** Add the public key (`~/.ssh/id_rsa.pub`) to Hetzner Cloud Console → Security → SSH keys
- **Used by:** Ansible, direct SSH access, `task server:setup-remote-cursor`

**`~/.ssh/known_hosts`**
- **Relevance:** Prevents SSH warnings when connecting to known servers
- **Setup:** Automatically managed by SSH client and Ansible
- **Used by:** SSH client, Ansible (with `StrictHostKeyChecking=accept-new`)

**`~/.ssh/config`**
- **Relevance:** SSH client configuration for server aliases, connection settings, and Cursor Remote-SSH integration
- **Setup:** Created/updated by `task server:setup-remote-cursor` (optional, for Cursor Remote-SSH)
- **Used by:** SSH client, Cursor Remote-SSH extension
- **Note:** Contains server host alias, IP address, user, and SSH options for easy server access

**`~/.config/hcloud/cli.toml`**
- **Relevance:** Stores your Hetzner Cloud API token for CLI operations in the devcontainer
- **Setup:** Created from `hcloud_token` in `secrets/infrastructure-secrets.yml` by the devcontainer startup script
- **Used by:** `hcloud` CLI inside the devcontainer, `task server:list-hetzner-keys`

**`~/.config/sops/age/keys.txt`**
- **Relevance:** Your private SOPS key for decrypting infrastructure secrets
- **Setup:** Created by `task secrets:keygen` (stored outside repo for security)
- **Used by:** VS Code SOPS extension, Terraform (via SOPS provider), Ansible (via shell)

**`~/.terraform.d/credentials.tfrc.json`**
- **Relevance:** Terraform Cloud authentication token for accessing shared state in the devcontainer
- **Setup:** Created from `terraform_cloud_token` in `secrets/infrastructure-secrets.yml` by the devcontainer startup script
- **Used by:** Terraform CLI inside the devcontainer to authenticate with Terraform Cloud backend

**`~/.docker/config.json`**
- **Relevance:** Docker/crane/Trivy auth for the private registry (overview, app deploys).
- **Details:** See [Registry](registry.md#authentication-how-to-log-in).

## Known Security Risks

This section documents known security risks that have been reviewed and accepted for now.

| Risk | Severity | Status | Mitigations | Notes |
|------|----------|--------|-------------|-------|
| No backup | MEDIUM | Accepted | Infrastructure can be recreated via Terraform | Will be added before production data |
| No Terraform state backup | LOW | Accepted | State stored in Terraform Cloud, can be restored via `terraform import` if lost | Infrastructure is reproducible from code |
| No automated secret rotation | LOW | Accepted | Manual rotation process | Pragmatic tradeoff |
| Passwordless sudo without restrictions | LOW | Accepted | IP-restricted SSH, key-based auth, fail2ban, audit logging | Pragmatic tradeoff |

