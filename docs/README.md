[**<---**](../README.md)
# Infrastructure as Code
<table>
<tr>
<td valign="top">

- [Geting started](INSTALL.md)
- [Run Curson on the server](CURSOR.md)
- [Application deployment](application-deployment.md)

</td>
<td width="80"></td>
<td valign="top">

- [Testing](TESTING.md)
- [Tools and technologies used](TOOLS.md)
- [Secrets and lies](SECURITY.md)
- [Troubleshooting](TROUBLESHOOTING.md)



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
  task secrets:decrypt                  # Decrypt secrets for editing
  task secrets:encrypt                  # Encrypt secrets

Application Deployment:
  task application:deploy -- <WORKSPACE> <APP_ROOT> <SHA>

Registry:
  task registry:overview                # List tags (TAG, CREATED, DESCRIPTION) for all repos

Images:
  task application:overview -- <WORKSPACE> <IMAGE_REPO>  # Show image overview with deployment status

Utilities:
  task server:check-status              # Check if servers are up (checks both dev and prod)
  task server:list-hetzner-keys         # List Hetzner SSH keys with IDs
  task server:setup-remote-cursor       # Add server to ~/.ssh/config for Cursor Remote-SSH
```
