# Rotate GitHub OAuth (cms-oauth)

Part of [public-secrets](../public-secrets.md) full rotate. Platform `cms-oauth` on the VPS brokers Sveltia for Pages tenants.

## Decided

| | |
|--|--|
| Keys | `github_oauth_client_id`, `github_oauth_client_secret` in `../secrets/infra.yml` |
| Non-secret keepers | `cms_oauth_allowed_domains`, `github_oauth_hostname` (optional hygiene only) |
| Mint | New GitHub OAuth App client secret (or new app + id/secret) |
| Cutover | Sibling write → `task platform:configure:apply` |
| Smoke | Sveltia login on a Pages tenant (`simonacella.github.io` or `anticobagliosiciliano`) |
| Revoke | Revoke old client secret in GitHub OAuth App settings |
| SOPS | Human edits in secrets Dev Container |

## Decide

### New secret only vs new OAuth App

| | Option |
|--|--------|
| **A** | Rotate client secret on the existing OAuth App; keep `github_oauth_client_id` |
| **B** | Create a new OAuth App; update both id and secret (and callback URL if needed) |

Choice: _unpicked_

## Do

### 0. Mint and write sibling

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — none.

**Human must:** After Decide: mint in GitHub → SOPS `infra.yml` → push **`rednaw/secrets`**.

### 1. Apply, smoke, revoke old

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after go: optional watch of configure apply.

**Human must:** `task platform:configure:apply` → Sveltia login smoke on one tenant → revoke old client secret in GitHub.
