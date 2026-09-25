# Rotate GitHub OAuth (cms-oauth)

Part of [public-secrets](../../plans/public-secrets.md) full rotate. Platform `cms-oauth` on the VPS brokers Sveltia for Pages tenants.

## Decided

| | |
|--|--|
| Keys | `github_oauth_client_id`, `github_oauth_client_secret` in `../secrets/infra.yml` |
| Non-secret keepers | `cms_oauth_allowed_domains`, `github_oauth_hostname` (optional hygiene only) |
| Mint shape | **A** — new client secret on the **existing** OAuth App; keep `github_oauth_client_id` |
| Cutover | Sibling write → `task platform:configure:apply` |
| Smoke | Sveltia login on a Pages tenant (`simonacella.github.io` or `anticobagliosiciliano`) |
| Revoke | Revoke old client secret in GitHub OAuth App settings (after smoke) |
| SOPS | Human edits in secrets Dev Container |

## Decide

None.

## Do

### 0. Mint and write sibling

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — none.

**Human must:** In the existing GitHub OAuth App → generate new client secret → SOPS `infra.yml` (`github_oauth_client_secret` only; leave `github_oauth_client_id`) → push **`rednaw/secrets`**. Never paste the secret into chat.

**Done as:** Human minted new client secret and wrote sibling (client_id kept).

### 1. Apply, smoke, revoke old

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — after go: optional watch of configure apply.

**Human must:** `task platform:configure:apply` → Sveltia login smoke on one tenant → revoke the **previous** client secret in the same OAuth App.

**Done as:** `configure:apply` redeployed cms-oauth; Sveltia login OK on both tenants; old client secret revoked.
