# Rotate TransIP API key

Part of [public-secrets](../public-secrets.md) full rotate. Account name + private key may have lived in public ciphertext.

## Decided

| | |
|--|--|
| Keys | `transip_account_name`, `transip_private_key` in `../secrets/infra.yml` |
| Mint | New TransIP API key pair (if the private key was ever in public ciphertext — assume yes for this migration) |
| Smoke | Terraform plan that touches DNS, or a dry DNS read via the provider |
| Revoke | Revoke old TransIP API key in TransIP console |
| SOPS | Human edits in secrets Dev Container |

## Decide

None.

## Do

### 0. Mint and write sibling

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — none (no plaintext in chat).

**Human must:** Mint new TransIP key pair → SOPS `infra.yml` → commit/push **`rednaw/secrets`**.

### 1. Smoke, then revoke old

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after go: optional watch of `task platform:provision:plan` (DNS resources).

**Human must:** Reload setup if needed → plan/smoke DNS → revoke old TransIP key → mark this plan Human-reviewed.
