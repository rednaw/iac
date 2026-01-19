[**<---**](../README.md)
# Infrastructure as Code
- [Setting up your environment](INSTALL.md)
- [Static code analysis](TESTING.md)
- [Tools used](TOOLS.md)
- [Security](SECURITY.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Running Curson on the server](CURSOR.md)
```
Infrastructure as Code

Terraform commands:
  task terraform:login                  # Authenticate with Terraform Cloud
  task terraform:init -- <workspace>    # Initialize workspace (dev or prod)
  task terraform:plan -- <workspace>    # Plan changes (dev or prod)
  task terraform:apply -- <workspace>   # Apply changes (dev or prod)
  task terraform:destroy -- <workspace> # Destroy resources (dev or prod)
  task terraform:output -- <workspace>  # Show outputs (dev or prod)

Ansible commands:
  task ansible:install                  # Install required collections
  task ansible:bootstrap -- <workspace> # One-time bootstrap as root (dev or prod)
  task ansible:run -- <workspace>       # Configure server (Docker, Nginx, security)

Testing:
  task test:run                         # Run all tests (validate, format check, security scan)

Secrets Management (SOPS):
  task secrets:keygen                   # Generate age key pair
  task secrets:decrypt                  # Decrypt secrets for editing
  task secrets:encrypt                  # Encrypt secrets

Utilities:
  task server:check-status              # Check if servers are up (checks both dev and prod)
  task server:list-hetzner-keys         # List Hetzner SSH keys with IDs
  task server:setup-remote-cursor       # Add server to ~/.ssh/config for Cursor Remote-SSH
```
