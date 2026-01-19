[**<---**](README.md)

## Local Configuration Files

The following files are created outside the repository during setup. These are personal configuration files that should **never** be committed to Git.

| File Path | Purpose | Created By |
|-----------|---------|------------|
| `~/.ssh/id_rsa ` | SSH private key for authenticating with servers | `ssh-keygen` (if not already exists) |
| `~/.ssh/known_hosts` | Stores SSH host keys for servers you've connected to | SSH client (automatically) |
| `~/.ssh/config` | SSH client configuration for server aliases and connection settings | `task server:setup-remote-cursor` (optional) |
| `~/.config/hcloud/cli.toml` | Hetzner Cloud CLI configuration and API token | `hcloud context create` |
| `~/.config/sops/age/keys-{username}.txt` | SOPS private key for decrypting secrets | `task secrets:keygen` |
| `~/.terraform.d/credentials.tfrc.json` | Terraform Cloud authentication token | `task terraform:login` |

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
- **Relevance:** Stores your Hetzner Cloud API token for CLI operations
- **Setup:** Created when running `hcloud context create default`
- **Used by:** `hcloud` CLI, `task server:list-hetzner-keys`

**`~/.config/sops/age/keys-{username}.txt`**
- **Relevance:** Your private SOPS key for decrypting infrastructure secrets
- **Setup:** Created by `task secrets:keygen` (stored outside repo for security)
- **Used by:** `task secrets:decrypt`, `task secrets:encrypt`, Terraform (via SOPS provider), Ansible (via SOPS lookup)

**`~/.terraform.d/credentials.tfrc.json`**
- **Relevance:** Terraform Cloud authentication token for accessing shared state
- **Setup:** Created when running `task terraform:login`
- **Used by:** Terraform CLI to authenticate with Terraform Cloud backend

## Known Security Risks

This section documents known security risks that have been reviewed and accepted for now.

| Risk | Severity | Status | Mitigations | Notes |
|------|----------|--------|-------------|-------|
| No monitoring/alerting | MEDIUM | Accepted | Infrastructure-as-code for recovery | Will be added before production traffic |
| No backup | MEDIUM | Accepted | Infrastructure can be recreated via Terraform | Will be added before production data |
| No Terraform state backup | LOW | Accepted | State stored in Terraform Cloud, can be restored via `terraform import` if lost | Infrastructure is reproducible from code |
| No automated secret rotation | LOW | Accepted | Manual rotation process | Pragmatic tradeoff |
| Passwordless sudo without restrictions | LOW | Accepted | IP-restricted SSH, key-based auth, fail2ban, audit logging | Pragmatic tradeoff |

