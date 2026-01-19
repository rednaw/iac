[**<---**](README.md)

Follow the steps below from top to bottom and you will be able to manage the Milledoni infrastructure in a software defined way!

## Install Tools
```bash
# For production
brew install terraform ansible sops age hcloud go-task/tap/go-task

# For testing
brew install tfsec ansible-lint shellcheck
pip install PyYAML
```

## Initialize hcloud CLI:
- Create API token (Hetzner console → Security → API tokens)
- Initialize hcloud
  ```bash
  hcloud context create default  # paste API token
  hcloud context use default
  ```

## Secrets Operations (SOPS)

Securely store secrets in Git

### How It Works

**Multi-key encryption:** Each team member has their own key pair. Secrets are encrypted with all public keys, so anyone can decrypt with their private key.

**File structure:**
```
secrets/infrastructure-secrets.yml.enc              # Encrypted secrets (in Git)
secrets/sops-key-{username}.pub                     # Your public key (in Git)
~/.config/sops/age/keys-{username}.txt            # Your private key (outside repo, secure location)
.sops.yaml                                        # Auto-generated configuration file (NOT in Git)
```

### Initial Setup

Encrypted secrets file (`secrets/infrastructure-secrets.yml.enc`) created and committed, it contains:
- 'Main' Hetzner Cloud API token used by terraform 
- Hetzner SSH key IDs for all team members, needed for running ansible and SSH access
- Allowed SSH IP addresses for firewall source IP filtering (restricts SSH access to specific IPs)


### New Team Members

#### Generate a SOPS key pair:
   ```bash
   task secrets:keygen
   git add secrets/sops-key-*.pub
   git commit -m "Add SOPS public key"
   ```

#### Your SOPS private key is stored securely:
   - Private key is stored in `~/.config/sops/age/keys-{username}.txt` (outside the repo)
   - For backup, consider storing in a password manager (1Password, Bitwarden, etc.)

#### Add your SOPS key to the list of keys that can decrypt
  - Ask an existing team member to:
     ```bash
     git pull
     task secrets:decrypt
     task secrets:encrypt  # Re-encrypts with all public keys (including yours)
     git add secrets/infrastructure-secrets.yml.enc && git commit
     ```
  - Pull the updated secrets file: `git pull`
  - Now you can also encrypt/decrypt secrets, currently only the infrastructure secrets, in the future also application secrets (database password etc.)

### Remove Team Member
1. Remove their public SOPS key from Git
2. Re-encrypt: `task secrets:decrypt` → `task secrets:encrypt` → commit


## Configure SSH

Login to the server for maintenance and troubleshooting

### Add your SSH key to Hetzner Cloud:
   - Go to Hetzner Cloud Console → Project → Security → SSH keys
   - Add your public SSH key (`~/.ssh/id_rsa.pub`)

### Add your Hetzner key ID and IP address to infrastructure secrets:
   SSH access is restricted to specific IP addresses for security. The Hetzner Cloud firewall only allows SSH connections from IPs listed in `allowed_ssh_ips`, preventing unauthorized access attempts from the entire internet.
   
   - Get your Hetzner key ID: `task server:list-hetzner-keys` (requires hcloud CLI to be initialized, see above)
   - Find your current IP address: Visit [https://whatismyipaddress.com/](https://whatismyipaddress.com/)
   - Decrypt, edit, and re-encrypt:
     ```bash
     task secrets:decrypt                   # Decrypt for editing
     # Edit secrets/infrastructure-secrets.yml:
     #   - Add your Hetzner key ID to the ssh_keys list
     #   - Add your IP address to the allowed_ssh_ips list (use /32 for single IP, e.g., "101.56.48.148/32")
     task secrets:encrypt                   # Re-encrypt
     rm secrets/infrastructure-secrets.yml     # Remove unencrypted file
     git add secrets/infrastructure-secrets.yml.enc && git commit
     ```
   - Apply the firewall changes: `task terraform:apply -- dev` (or `terraform:apply -- prod` for production)
   - **Note:** `task terraform:apply -- <workspace>` requires Terraform Cloud to be initialized first, see below. If you haven't initialized yet, complete the Terraform Cloud setup first, then come back to apply the firewall changes.
   - **Note:** If your IP address changes (e.g., different network, VPN), update `allowed_ssh_ips` and re-apply to the appropriate workspace
   - **Note:** Don't forget the `--` separator when passing the workspace argument!

## Terraform Cloud

Team support for Terraform, see [StateManagement.md](docs/StateManagement.md) for rationale and details.

### Initial Setup

- Terraform Cloud account and organization (`milledoni`) created
- Execution mode set to `Local` at organization level
- Backend configured in `terraform/versions.tf`:
  - Organization: `milledoni`
  - Workspaces: `giftfinder-dev`, `giftfinder-prod` (separate environments)

### Workspace Setup

**Create workspaces in Terraform Cloud (one-time setup):**

1. Go to Terraform Cloud → Organization `milledoni`
2. Create workspace: `giftfinder-dev`
   - **Workspace name:** `giftfinder-dev`
3. Create workspace: `giftfinder-prod`
   - **Workspace name:** `giftfinder-prod`

**Notes:** 
- The environment is automatically derived from the workspace name (e.g., `giftfinder-dev` → `dev`)
- Other variables (server_type, server_location, etc.) can be set via `-var` flags or `.tfvars` files if you want different configurations per environment
- Workspaces must be created in Terraform Cloud before running `task terraform:init -- dev` or `terraform:init -- prod`
- **Important:** Use `--` separator when passing workspace arguments (e.g., `task terraform:init -- dev`)

### New Team Members

#### Get added to organization:

Ask an existing team member to add you to the `milledoni` organization in Terraform Cloud

#### Authenticate:
```bash
task terraform:login
```
Follow prompts to generate and save token

#### Initialize workspace:
```bash
task terraform:init -- dev    # For dev environment
task terraform:init -- prod   # For prod environment
```

**Notes:**
- The `--` separator is required to pass arguments to Taskfile tasks.
- You must complete the SOPS setup first (above) before running `task terraform:init`, as Task expects your SOPS key file to exist.

#### How it works:
- Terraform runs locally on your machine
- State is stored in Terraform Cloud (separate state per workspace)
- Automatic locking prevents conflicts
- Each environment (dev/prod) has its own workspace and state

In the event that Terraform Cloud is unreachable while you need to make changes you can always recover state using [`terraform import`](https://developer.hashicorp.com/terraform/tutorials/state/state-import).


## Provision Server

### First Time Setup (Dev Environment)
```bash
task terraform:init -- dev              # Initialize Terraform for dev
task terraform:apply -- dev             # Create dev server
task ansible:install                    # Install Ansible collections (once)
task ansible:bootstrap -- dev           # Setup ubuntu user (one-time, requires server IP)
task ansible:run -- dev                 # Configure dev server
```

**Get server IP:** `task terraform:output -- dev` or `task terraform:output -- prod`

Change dev to prod for production environment.

