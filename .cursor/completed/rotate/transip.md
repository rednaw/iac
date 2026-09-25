# Rotate TransIP API key

Part of [public-secrets](../../plans/public-secrets.md) full rotate. Account name + private key may have lived in public ciphertext.

## Decided

| | |
|--|--|
| Keys | `transip_account_name`, `transip_private_key` in `../secrets/infra.yml` |
| Not SSH | `transip_private_key` is a **TransIP API** PEM (control-panel key pair). Unrelated to `~/.ssh/id_rsa` (host SSH) or `ssh_keys` (Hetzner authorized_keys) |
| Consumer | Terraform `aequitas/transip` via `scripts/platform-tf-secrets.sh` → `TF_VAR_transip_*` → `provider "transip"` → `terraform/platform/dns.tf` |
| Mint | New API key pair in TransIP console (label + download/store private PEM) |
| Smoke | `task platform:provision:plan` (DNS) |
| Revoke | Revoke old TransIP API key in TransIP console |
| SOPS | Human edits in secrets Dev Container |

## Decide

None.

## Do

### 0. Mint and write sibling

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — none (no plaintext in chat).

**Human must:** Mint new TransIP key pair → SOPS `infra.yml` → commit/push **`rednaw/secrets`**.

**Done as:** Human generated new API key, wrote sibling, pushed.

### 1. Smoke, then revoke old

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — optional watch of `task platform:provision:plan`.

**Human must:** Plan/smoke DNS → revoke old TransIP key.

**Done as:** `platform:provision:plan` OK with new key; old API key removed in TransIP console.
