# Rotate OpenObserve credentials

Part of [public-secrets](../public-secrets.md) full rotate. Root user password (and username if changed) for OpenObserve on the platform box.

## Decided

| | |
|--|--|
| Keys | `openobserve_username`, `openobserve_password` in `../secrets/infra.yml` |
| Password rules | Ansible: 8–128 chars; at least one lower, upper, digit, and non-alphanumeric (`roles/platform/tasks/openobserve.yml`) |
| Cutover | Sibling write → `task platform:configure:apply` (root password applied via compose env) |
| Smoke | `task tunnel:start` → OpenObserve UI login; or confirm apply sets `ZO_ROOT_USER_PASSWORD` |
| Revoke | Old password dead after apply (no separate console) |
| SOPS | Human edits in secrets Dev Container |

## Decide

### Keep username?

| | Option |
|--|--------|
| **A** | Keep `openobserve_username`; rotate password only |
| **B** | Change username and password together |

Choice: _unpicked_

## Do

### 0. Mint and write sibling

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — none.

**Human must:** After Decide: mint password meeting complexity rules → SOPS `infra.yml` → push **`rednaw/secrets`**.

### 1. Apply and smoke

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after go: optional watch of configure apply.

**Human must:** `task platform:configure:apply` → tunnel → UI login with new creds → confirm old password fails.
