[**<---**](README.md)

## Troubleshooting

**"secrets/infrastructure-secrets.yml.enc not found"**
- Create `secrets/infrastructure-secrets.yml` and run `task secrets:encrypt`

**"ansible/inventory/dev.ini not found" or "ansible/inventory/prod.ini not found"**
- Run `task terraform:apply -- dev` or `task terraform:apply -- prod` first to generate inventory

**"Error: authentication required" (Terraform)**
- Run `task terraform:login` (from `iac` directory)
- Or create `~/.terraform.d/credentials.tfrc.json` with your token

**Connection timeout**
- Check server IP: `task terraform:output -- dev` (or `terraform:output -- prod`)
- Server may need 30-60 seconds to boot

**"Module not found" (Ansible)**
- Run `task ansible:install`
