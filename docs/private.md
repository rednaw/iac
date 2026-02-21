[**<---**](README.md)

# Private

Local configuration files in your home directory. These are used by this project and should never be committed to Git. Use them from inside the devcontainer.

| File path | Purpose | Location | Created by (intended) |
|-----------|---------|----------|------------------------|
| `~/.ssh/id_rsa` | SSH private key for authenticating with servers | Host | `ssh-keygen` (if not already exists) |
| `~/.ssh/known_hosts` | SSH host keys for servers you've connected to | Host | SSH client (automatically) |
| `~/.ssh/config` | SSH client configuration for server aliases and connection settings | Host | Written by devcontainer setup |
| `~/.config/sops/age/keys.txt` | SOPS private key for decrypting secrets | Host | `task secrets:keygen` |
| `~/.config/hcloud/cli.toml` | Hetzner Cloud CLI configuration and API token | Devcontainer | Devcontainer startup script (from SOPS) |
| `~/.terraform.d/credentials.tfrc.json` | Terraform Cloud authentication token | Devcontainer | Devcontainer startup script (from SOPS) |
| `~/.docker/config.json` | Docker/crane/Trivy auth for private registry in the devcontainer | Devcontainer | Devcontainer startup script — see [Registry](registry.md#authentication) |

## Details

**`~/.ssh/id_rsa*`**
- **Purpose:** SSH key pair for authenticating with Hetzner Cloud servers
- **Setup:** Add the public key (`~/.ssh/id_rsa.pub`) to Hetzner Cloud Console → Security → SSH keys
- **Used by:** Ansible, direct SSH access, Remote-SSH

**`~/.ssh/known_hosts`**
- **Purpose:** Prevents SSH warnings when connecting to known servers
- **Setup:** Automatically managed by SSH client and Ansible
- **Used by:** SSH client, Ansible (with `StrictHostKeyChecking=accept-new`)

**`~/.ssh/config`**
- **Purpose:** SSH client configuration for server aliases, connection settings, and Remote-SSH integration
- **Setup:** Add `Include config.d/iac-admin`; devcontainer setup writes `~/.ssh/config.d/iac-admin` (optional, for Remote-SSH)
- **Used by:** SSH client, Remote-SSH extension (VS Code/Cursor)
- **Note:** Contains server host alias, IP address, user, and SSH options for easy server access

**`~/.config/hcloud/cli.toml`**
- **Purpose:** Hetzner Cloud API token for CLI operations in the devcontainer
- **Setup:** Created from `hcloud_token` in `secrets/infrastructure-secrets.yml` by the devcontainer startup script
- **Used by:** `hcloud` CLI inside the devcontainer, `task server:list-hetzner-keys`

**`~/.config/sops/age/keys.txt`**
- **Purpose:** Private SOPS key for decrypting infrastructure secrets
- **Setup:** Created by `task secrets:keygen` (stored outside repo for security)
- **Used by:** VS Code SOPS extension, Terraform (via SOPS provider), Ansible (via shell)

**`~/.terraform.d/credentials.tfrc.json`**
- **Purpose:** Terraform Cloud authentication token for accessing shared state in the devcontainer
- **Setup:** Created from `terraform_cloud_token` in `secrets/infrastructure-secrets.yml` by the devcontainer startup script
- **Used by:** Terraform CLI inside the devcontainer to authenticate with Terraform Cloud backend

**`~/.docker/config.json`**
- **Purpose:** Docker/crane/Trivy auth for the private registry
- **Details:** See [Registry](registry.md#authentication) for how to log in

## Security risks

Known security risks that have been reviewed and accepted:

| Risk | Severity | Status | Mitigations | Notes |
|------|----------|--------|-------------|-------|
| No backup | MEDIUM | Accepted | Infrastructure can be recreated via Terraform | Will be added before production data |
| No Terraform state backup | LOW | Accepted | State stored in Terraform Cloud, can be restored via `terraform import` if lost | Infrastructure is reproducible from code |
| No automated secret rotation | LOW | Accepted | Manual rotation process | Pragmatic tradeoff |
| Passwordless sudo without restrictions | LOW | Accepted | IP-restricted SSH, key-based auth, fail2ban, audit logging | Pragmatic tradeoff |

## Related

- [Secrets](secrets.md) — SOPS key setup and management
- [Registry](registry.md) — Docker registry authentication
- [Launch the IaC devcontainer](launch-devcontainer.md) — How these files are used in the devcontainer
