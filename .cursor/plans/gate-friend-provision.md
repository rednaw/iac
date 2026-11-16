# Friend Gate provision (hcloud + Task)

Parameterized friend-box provision/destroy/configure in **`iac`**. Peer track to vpn ops hardening (`vpn/.cursor/plans/operations.md`); **both** must finish before Friend 1 migration (`vpn/.cursor/plans/friend1-cutover.md`). Pre-cutover lab = rednaw Hetzner + server `vpn` + `fullmoongate/vpn` control plane. China trip is **over**. **Not legal advice.**

## Decided

| | |
|--|--|
| Ownership | This plan = **iac** (+ `secrets`). Renew ops hardening = **vpn** `operations.md`. Cutover = **vpn** `friend1-cutover.md`. |
| Pre-cutover lab | Develop and prove here against **rednaw** Hetzner (Default/`vpn`, legacy project Gate patterns as needed) and the maintainer `fullmoongate/vpn` control plane. Do not put Friend 1 on their own customer until both this plan and vpn ops hardening are ready. |
| Tool | **B — hcloud + Task** for the whole vpn provision story (friends **and** lab `vpn`). No TF/TFC create/apply to heal renew drift; no “leave IP out of state” TF half-measure. Ansible only for SSH configure. |
| Provision CLI | **`provision:present`** / **`provision:absent`**. Friends: `task gate:provision:present|absent -- <id>`. Lab mirror: `task vpn:provision:present|absent`. Present = create-if-absent (server + primary IPv4 + firewall); absent = destroy-by-name. Idempotent. Not `apply`/`destroy`/`ensure`/`wipe`. |
| Secrets | **`secrets/gate-{id}.yml`** (`gate-1.yml`, …) + `.sops.yaml` rule `gate-[0-9]+\.yml$`. Never platform/`infra.yml` token in friend files. Legacy shared box keeps `gate.yml` until destroy. Lab: **`secrets/vpn.yml`**. |
| Resource names | Friends: always `gate` / `gate-v4` / `gate-firewall` inside each customer. Lab: `vpn` / `vpn-v4` / `vpn-firewall`. Isolation = token/customer. |
| TF roots | `terraform/gate` + TFC `gate` and `terraform/vpn` + TFC `vpn` = **retire**: no further apply; present/absent via hcloud; destroy/abandon workspaces when cool. Archived parallel-TF: [../completed/gate-terraform-parallel.md](../completed/gate-terraform-parallel.md). |
| Lab `vpn` | `vpn:provision:present|absent` + configure from `vpn.yml`. Primary renew = `fullmoongate/vpn` IssueOps; `vpn:provision:renew-ip` = break-glass only. |
| Friends | Never open `iac`. Maintainer only runs provision/configure. |

## Decide

None. (Reopened “keep TF / omit IP from state?” → closed: drop TF for the vpn story.)

## Do

### 0. Retarget iac `vpn:*` to `secrets/vpn.yml`

- [x] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — `vpn-tf-secrets.sh`, `Taskfile.vpn.yml` (config/smoke/configure), `hostkeys` purpose `vpn` load `vpn.yml` only.

**Human must:** set `vpn.yml` `hcloud_token` + `ssh_keys` to Default/platform mirror (still Gate-shaped after Gate→vpn copy); then strip leftover `vpn_*` from `infra.yml`; `task secrets:push` in vpn container when ready; smoke `task vpn:config` / `hostkeys:ip -- vpn`.

### 0b. Demote `vpn:provision:renew-ip` to break-glass

- [x] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — task help / renew-ip desc point at `fullmoongate/vpn` IssueOps as primary; script remains break-glass.

**Human must:** use `fullmoongate/vpn` for renew drills; do not point friends at the vpn repo.

### 1. Secrets parameterization + sops rule

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — can start now: load path `secrets/gate-{id}.yml` for `task gate:* -- <id>`; add `.sops.yaml` rule `gate-[0-9]+\.yml$` in sibling `secrets` (after go). Keep `gate.yml` path for legacy destroy/configure until retirement.

**Human must:** authorize **secrets** sibling edit; create/fill `gate-1.yml` when ready for Friend 1 customer (not required to start Agent wiring).

### 2. hcloud `provision:present` / `provision:absent` — lab `vpn` + friends `gate:* -- <id>`

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — can start now: scripts for present (create-if-absent) / absent (destroy-by-name) of server + managed primary IPv4 + firewall via hcloud. Lab: `vpn` / `vpn-v4` / `vpn-firewall` from `vpn.yml` → `task vpn:provision:present|absent` (retire `plan|apply|destroy` as the operator path). Friends: `gate` / `gate-v4` / `gate-firewall` from `gate-{id}.yml` → `task gate:provision:present|absent -- <id>`. Old TF task names only as explicit TFC teardown helpers until cool-off.

**Human must:** controlled absent→present smoke on rednaw lab `vpn` first; Friend 1 empty customer later — not live friend traffic.

### 3. hostkeys + configure by id

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after Do 1–2: `hostkeys` / `gate:configure:*` take the same `<id>` and force `HCLOUD_TOKEN` + `vpn_*` from that file only. Lab `vpn` already on `vpn.yml`.

**Human must:** review that ambient Default/platform token cannot leak into friend paths.

### 4. Retire TF apply for vpn + legacy gate (docs/help)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — can start now: task help / plan cross-links: no TF `provision:apply` on those roots to create, heal renew drift, or wipe; use `provision:present|absent` only; TFC workspaces abandon when ready.

**Human must:** stop using TF apply on those roots; confirm after lab `vpn:provision:absent` → `present`.
