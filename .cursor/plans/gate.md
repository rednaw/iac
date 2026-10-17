## Add parallel Gate provision/configure in `iac` (do not touch live trip VPN)

Spec: sibling `../gate/.cursor/plans/vpn-control-plane.md` → Decided **Gate provision path** + Do **1**.

### Confirmed
1. Ansible/`gate.yml` keep literal `vpn_*` key names (same shape as trip `infra.yml`).
2. `ssh_keys` in `gate.yml` are **new** IDs from Cloud project Gate.
3. Empty TFC workspace `gate` already exists (same org).
4. `gate:*` / `hostkeys -- gate` always load `HCLOUD_TOKEN` from `gate.yml` (overwrite ambient Default/Rednaw).
5. No `task gate:config` in `iac` (emit lives in private `gate` repo later).
6. Public name `gate` / `terraform/gate` is fine.

### Goal
Reproduce `terraform/vpn` as a **second** root for Hetzner Cloud project **Gate**, so we can `task gate:provision:*` / `gate:configure:*` without using Default token **Rednaw** or TFC workspace `vpn`.

### Do
1. [x] `terraform/gate/` — server `gate`, primary IP `gate-v4`, firewall `gate-firewall`, workspace `gate`, var `gate_allowed_ssh_ips`.
2. [x] `scripts/gate-tf-secrets.sh` — `gate.yml` only → TF vars + `HCLOUD_TOKEN`.
3. [x] TFC org still from `infra.yml` via `_terraform:init`.
4. [x] `tasks/Taskfile.gate.yml` + root include; configure passes `secrets_file=…/gate.yml`.
5. [x] `hostkeys` purpose `gate` → server `gate` + force Gate token.
6. [x] Ambient Default token overwritten on every gate hcloud path.
7. [x] Help text for `task gate:…` (not trip vpn).

### Do not
- Retarget live `terraform/vpn` / TFC `vpn` / `vpn-tf-secrets.sh`.
- Put Gate token into `infra.yml`.
- Apply/destroy against Default / server `vpn` (agent).
- Renew / IssueOps / stub `vpn:provision:renew-ip` (later, private `gate` repo).
- Add `gate:config` in `iac` (emit in private `gate` repo).
- Commit or print secret values.

### Human will do after this code
- Ensure `gate.yml` has token, Gate SSH key ids, Fresh `vpn_*`, `vpn_allowed_ssh_ips` (world for first apply, then home).
- Run plan/apply/configure/lock themselves.

### Done when
`task gate:provision:plan` initializes against workspace `gate` and plans create of `gate` + `gate-v4` + firewall using vars from `gate.yml`; `task vpn:provision:plan` still Default/trip.
