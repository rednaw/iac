# Rotate Terraform Cloud token

Part of [public-secrets](../../plans/public-secrets.md) full rotate. `terraform_cloud_token` lived in public ciphertext; replaced in private sibling and old token revoked.

## Decided

| | |
|--|--|
| Key | `terraform_cloud_token` in `../secrets/infra.yml` |
| Mint | New TFC user/team token |
| Smoke | `task platform:provision:plan`; temp workspace var create/delete |
| Revoke | Revoke old TFC token |
| Local refresh | `devcontainer-setup.sh` writes `TF_TOKEN_app_terraform_io` from sibling |
| Status | Done (minted, pushed, revoked, smoke passed) |

## Decide

None.

## Do

### 0. Mint, write, smoke, revoke

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — none beyond sibling wiring (public-secrets Do 0–1).

**Human must:** Mint in TFC → SOPS sibling → push secrets → reload setup → smoke → revoke old.

**Done as:** Human completed mint, secrets push, revoke, and post-revoke smokes.
