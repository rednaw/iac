# Rotate VPN REALITY credentials

Part of [public-secrets](../public-secrets.md) full rotate. Only if these keys exist (or existed) in the sibling / public history. Regen procedure: `docs/future/vpn-travel-china-manual.md` §2.1.

## Decided

| | |
|--|--|
| Rotate keys | `vpn_uuid`, `vpn_reality_private_key`, `vpn_reality_public_key`, `vpn_short_id` |
| Usually keep | `vpn_dest`, `vpn_allowed_ssh_ips` (not credentials; update only if travel roster changes) |
| Mint | `docker run --rm "$XRAY" uuid`; `x25519`; `openssl rand -hex 8` for short_id (manual §2.1) |
| Cutover | Sibling write → `task vpn:configure:apply` → `task vpn:config` → re-import client links |
| Revoke | Old UUID/keys useless once clients use the new link |
| When | Next time you provision/use the VPN box is enough; not blocking platform history orphan if keys never lived in public blobs — still rotate if they did |

## Decide

### Rotate VPN now or defer?

| | Option |
|--|--------|
| **A** | Rotate now (keys were in public ciphertext or you want a clean slate) |
| **B** | Defer until next VPN trip / `provision:renew-ip`; mark public-secrets VPN row deferred explicitly |
| **C** | N/A — confirm keys were never in public history and remove from rotate scope |

Choice: _unpicked_

## Do

### 0. Mint and write sibling (if A)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — none.

**Human must:** After Decide **A**: regenerate per manual §2.1 → SOPS `infra.yml` → push **`rednaw/secrets`**. If **B**/**C**: check Human reviewed and leave Do 1 unchecked or N/A in a note under Decided.

### 1. Apply and re-import clients (if A)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after go: optional watch of vpn configure/config tasks.

**Human must:** `task vpn:configure:apply` → `task vpn:config` → re-import on devices; old link dead.
