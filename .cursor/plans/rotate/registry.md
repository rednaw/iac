# Rotate platform registry credentials

Part of [public-secrets](../public-secrets.md) full rotate. Self-hosted registry login + HTTP secret; cut over on the box; refresh GitHub Actions for the only CI consumer.

## Decided

| | |
|--|--|
| Keys | `registry_username`, `registry_password`, `registry_http_secret` in `../secrets/infra.yml` |
| Username | Keep the existing `registry_username` (htpasswd updates by name; no orphan user) |
| Entropy | `openssl rand -hex 32` for both password and http secret (two separate runs) |
| Auth model | Traefik basic-auth htpasswd; registry `http.secret` is not the login password |
| Cutover order | Sibling write → `configure:apply` → GitHub secrets → CI smoke |
| GitHub consumer | Only `rednaw/tientje-ketama`: secrets `REGISTRY_USERNAME` / `REGISTRY_PASSWORD`. Vars `REGISTRY_URL` / `IMAGE_NAME` unchanged |
| Not in GitHub | `registry_http_secret` (box + sibling only) |
| SOPS | Human edits in secrets Dev Container |
| Revoke | No vendor console; old password dies after apply |

## Decide

None.

## Do

### 0. Mint and write sibling

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — none (no plaintext in chat or public tree).

**Human must:**
1. `openssl rand -hex 32` twice → password + http secret.
2. Secrets DC: edit `infra.yml` — keep username; set new password + http secret; save.
3. Commit + push **`rednaw/secrets`** (`infra.yml` only).

### 1. Cut over the box + local Docker auth

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after Human says secrets are pushed and go: optional read-only watch of apply; no live fixes unless asked.

**Human must:**
1. iac DC: `bash .devcontainer/devcontainer-setup.sh`
2. `task platform:configure:apply`
3. Smoke: `docker login registry.rednaw.nl` or `task registry:list`; confirm old password fails

### 2. Refresh GitHub Actions secrets

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — none (`gh secret` / console; no values in chat).

**Human must:**
1. `rednaw/tientje-ketama`: set `REGISTRY_USERNAME` and `REGISTRY_PASSWORD` to match sibling.
2. Smoke: `gh workflow run build-and-push.yml --repo rednaw/tientje-ketama` then `gh run watch`.
