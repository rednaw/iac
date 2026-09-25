# Rotate platform registry credentials

Part of [public-secrets](../../plans/public-secrets.md) full rotate. Self-hosted registry login + HTTP secret; cut over on the box; refresh GitHub Actions for the only CI consumer.

## Decided

| | |
|--|--|
| Keys | `registry_username`, `registry_password`, `registry_http_secret` in `../secrets/infra.yml` |
| Username | Keep the existing `registry_username` (htpasswd updates by name; no orphan user) |
| Entropy | `openssl rand -hex 32` for both password and http secret (two separate runs) |
| Auth model | Traefik basic-auth htpasswd; registry `http.secret` is not the login password |
| Cutover order | Sibling write → `configure:apply` → GitHub secrets → CI smoke |
| Traefik reload | htpasswd change must `notify: Restart Traefik` (usersfile is cached until restart). Wired in `registry.yml`. |
| GitHub consumer | Only `rednaw/tientje-ketama`: secrets `REGISTRY_USERNAME` / `REGISTRY_PASSWORD`. Vars `REGISTRY_URL` / `IMAGE_NAME` unchanged |
| Not in GitHub | `registry_http_secret` (box + sibling only) |
| SOPS | Human edits in secrets Dev Container |
| Revoke | No vendor console; old password dies after apply |

## Decide

None.

## Do

### 0. Mint and write sibling

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — none (no plaintext in chat or public tree).

**Human must:** Mint password + http secret → SOPS sibling → push **`rednaw/secrets`**.

**Done as:** Human updated `registry_password` + `registry_http_secret` (username kept).

### 1. Cut over the box + local Docker auth

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — optional watch; Traefik restart when htpasswd notify was missing.

**Human must:** setup + `configure:apply` + registry smoke.

**Done as:** htpasswd notify fix; Traefik restart; `task registry:overview` lists tags.

### 2. Refresh GitHub Actions secrets

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — none (`gh` / console).

**Human must:** Update tientje-ketama `REGISTRY_*` secrets; smoke build-and-push.

**Done as:** Human updated secrets; workflow_dispatch via GitHub UI succeeded ([run 36141205629](https://github.com/rednaw/tientje-ketama/actions/runs/36141205629)). `gh` in iac DC has no auth — UI is fine.
