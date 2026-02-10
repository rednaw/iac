[**<---**](README.md)

## Troubleshooting

**"secrets/infrastructure-secrets.yml not found"**
- Create the file and encrypt it. See [secrets.md](secrets.md) for setup instructions.

**"Error: authentication required" (Terraform)**
- In the devcontainer, ensure your SOPS key is in place (`~/.config/sops/age/keys.txt`) and that `secrets/infrastructure-secrets.yml` contains `terraform_cloud_token`. The devcontainer startup script writes `~/.terraform.d/credentials.tfrc.json` automatically.
- If you are running Terraform **outside** the devcontainer, run `terraform login` or create `~/.terraform.d/credentials.tfrc.json` with your token.

**Connection timeout**
- Check hostname: `task server:check-status`. Ensure `dev.rednaw.nl` / `prod.rednaw.nl` resolve and point at the server.
- Server may need 30-60 seconds to boot after `terraform apply`

**"Module not found" (Ansible)**
- Run `task ansible:install`

**"Host key verification failed"**
- Tasks run `hostkeys:prepare` before SSH/Ansible and use `StrictHostKeyChecking=accept-new` only. See [SSH host keys](SSH-host-keys.md).
