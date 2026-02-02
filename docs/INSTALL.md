[**<---**](README.md)

Follow the steps below from top to bottom and you will be able to manage your infrastructure in a software defined way!

## Development environment

Open the repo in VS Code and use the Dev Container so all tools and versions are pre-installed:

1. Install [Docker](https://docs.docker.com/get-docker/) and [VS Code](https://code.visualstudio.com/) (or [Cursor](https://cursor.com/)).
2. Install the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension.
3. Clone the repo and open the `iac` folder in VS Code.
4. When prompted, choose **Reopen in Container** (or Command Palette → “Dev Containers: Reopen in Container”).
5. Wait for the image to build (first time only). After that you have Terraform, Ansible, SOPS, Task, and the rest available in the terminal.

Tool versions are defined in `aqua.yaml` and `Dockerfile`; CI uses the same image. Next step is setting up credentials (SOPS key, SSH, hcloud, Terraform Cloud) as outlined below; the Dev Container mounts them from your host.

## Initialize hcloud CLI:
- Create API token (Hetzner console → Security → API tokens)
- Initialize hcloud
  ```bash
  hcloud context create default  # paste API token
  hcloud context use default
  ```

## Secrets (SOPS)

Follow the setup in [secrets.md](secrets.md) to generate your key pair and get added to the encrypted secrets.

## Configure SSH

Login to the server for maintenance and troubleshooting

### Add your SSH key to Hetzner Cloud:
   - Go to Hetzner Cloud Console → Project → Security → SSH keys
   - Add your public SSH key (`~/.ssh/id_rsa.pub`)

### Add your Hetzner key ID and IP address to infrastructure secrets:
   SSH access is restricted to specific IP addresses for security. The Hetzner Cloud firewall only allows SSH connections from IPs listed in `allowed_ssh_ips`, preventing unauthorized access attempts from the entire internet.
   
   - Get your Hetzner key ID: `task server:list-hetzner-keys` (requires hcloud CLI to be initialized, see above)
   - Find your current IP address: Visit [https://whatismyipaddress.com/](https://whatismyipaddress.com/)
   - Edit secrets (in VS Code with SOPS extension, or CLI):
     ```bash
     # Open secrets/infrastructure-secrets.yml in VS Code
     # Or use CLI: SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/infrastructure-secrets.yml
     
     # Add your Hetzner key ID to the ssh_keys list
     # Add your IP address to allowed_ssh_ips (use /32 for single IP, e.g., "101.56.48.148/32")
     
     # Save and commit
     git add secrets/infrastructure-secrets.yml && git commit -m "Add SSH key and IP for <username>"
     ```
   - Apply the firewall changes: `task terraform:apply -- dev` (or `terraform:apply -- prod` for production)
   - **Note:** `task terraform:apply -- <workspace>` requires Terraform Cloud to be initialized first, see below. If you haven't initialized yet, complete the Terraform Cloud setup first, then come back to apply the firewall changes.
   - **Note:** If your IP address changes (e.g., different network, VPN), update `allowed_ssh_ips` and re-apply to the appropriate workspace
   - **Note:** Don't forget the `--` separator when passing the workspace argument!

## Terraform Cloud

Team support for Terraform, see [StateManagement.md](past/StateManagement.md) for rationale and details.

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

