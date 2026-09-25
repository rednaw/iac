# Rotate OpenObserve credentials

Part of [public-secrets](../../plans/public-secrets.md) full rotate. Root user password for OpenObserve on the platform box.

## Decided

| | |
|--|--|
| Keys | `openobserve_username`, `openobserve_password` in `../secrets/infra.yml` |
| Username | Keep `openobserve_username`; rotate password only |
| Password rules | Ansible: 8–128 chars; at least one lower, upper, digit, and non-alphanumeric (`roles/platform/tasks/openobserve.yml`) |
| Env vs data | `ZO_ROOT_USER_*` seeds root **only on empty** data dir. Compose env alone does not rotate an existing hash |
| Data path | Running container has **no** `ZO_DATA_DIR`; image WORKDIR `/` → default `./data/openobserve/` → container `/data/openobserve` (host `/var/lib/openobserve/openobserve`). Reset must use the **same** path |
| Cutover | **B** — one-time manual on the box: stop OO → `docker run --rm … /openobserve reset -c root` with `ZO_DATA_DIR=/data/openobserve` → `configure:apply` |
| Not in Ansible | No playbook root-reset / password marker |
| Smoke | `task tunnel:start` → UI login; `configure:apply` dashboards succeed |
| Revoke | Old password dead after successful CLI reset |
| SOPS | Human edits in secrets Dev Container |

## Decide

None.

## Do

### 0. Mint and write sibling

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — none.

**Human must:** Mint password meeting complexity rules → SOPS `infra.yml` (`openobserve_password` only; leave username) → push **`rednaw/secrets`**. Never paste into chat.

**Done as:** Sibling updated (password only).

### 1. Manual root reset on the box

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — none (Ansible sync reverted).

**Human must:** On the platform host:

```bash
docker stop openobserve
docker run --rm \
  -v /var/lib/openobserve:/data \
  -e ZO_LOCAL_MODE=true \
  -e ZO_DATA_DIR=/data/openobserve \
  -e ZO_ROOT_USER_EMAIL='<openobserve_username>@observe.local' \
  -e ZO_ROOT_USER_PASSWORD='<openobserve_password>' \
  openobserve/openobserve:v0.91.5 \
  /openobserve reset -c root
```

Then `task platform:configure:apply` → tunnel → UI login with new password → confirm old fails.

**Done as:** Manual reset with new sibling password (`ZO_DATA_DIR=/data/openobserve`); apply/smoke OK; old password rejected, new works.
