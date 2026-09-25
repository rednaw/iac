# Rotate Hetzner Cloud token

Part of [public-secrets](../../plans/public-secrets.md) full rotate. `hcloud_token` lived in public ciphertext; replaced in private sibling and old token revoked.

## Decided

| | |
|--|--|
| Key | `hcloud_token` in `../secrets/infra.yml` |
| Mint | New Hetzner API token (read/write as today) |
| Smoke | `hcloud server list`; label add/remove; `task platform:provision:plan` |
| Revoke | Delete old token in Hetzner console |
| Status | Done (minted, pushed, revoked, smoke passed) |

## Decide

None.

## Do

### 0. Mint, write, smoke, revoke

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — none beyond sibling wiring (public-secrets Do 0–1).

**Human must:** Mint in Hetzner → SOPS sibling → push secrets → reload setup → smoke → revoke old.

**Done as:** Human completed mint, secrets push, revoke, and post-revoke smokes.
