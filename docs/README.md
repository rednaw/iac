[**<---**](../README.md)
# Infrastructure as Code
<table>
<tr>
<td valign="top">

- [Getting started](INSTALL.md)
- [Secrets management](secrets.md)
- [Application deployment](application-deployment.md)
- [Upgrading dependencies](upgrading.md)
- [Monitoring](monitoring.md)

</td>
<td width="80"></td>
<td valign="top">

- [Testing](TESTING.md)
- [Tools and technologies used](TOOLS.md)
- [Security](SECURITY.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Run Cursor on the server](CURSOR.md)



</td>
</tr>
</table>

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
  task secrets:generate-sops-config     # Generate .sops.yaml
  Edit secrets in VS Code (SOPS extension handles encryption)

Application Deployment (run from app directory):
  task iac:deploy -- <WORKSPACE> <SHA>

Registry:
  task registry:overview                # List tags (TAG, CREATED, DESCRIPTION) for all repos

Images (run from app directory):
  task iac:versions -- <WORKSPACE>  # Show available versions with deployment status

Utilities:
  task server:check-status              # Check if servers are up (checks both dev and prod)
  task server:list-hetzner-keys         # List Hetzner SSH keys with IDs
  task server:setup-remote-cursor       # Add server to ~/.ssh/config for Cursor Remote-SSH
```
