# Friend Gate provision (hcloud + Task)

Parameterized friend-box provision/destroy/configure in **`iac`**. Peer track to vpn ops hardening (`vpn/.cursor/plans/operations.md`); **both** must finish before Friend 1 migration (`vpn/.cursor/plans/friend1-cutover.md`). Pre-cutover lab = rednaw Hetzner + server `vpn` + `fullmoongate/vpn` control plane. China trip is **over**. **Not legal advice.**

## Decided

| | |
|--|--|
| Ownership | This plan = **iac** (+ `secrets`). Renew ops hardening = **vpn** `operations.md`. Cutover = **vpn** `friend1-cutover.md`. |
| Pre-cutover lab | Develop and prove here against **rednaw** Hetzner (Default/`vpn`, legacy project Gate patterns as needed) and the maintainer `fullmoongate/vpn` control plane. Do not put Friend 1 on their own customer until both this plan and vpn ops hardening are ready. |
| Tool | **B — hcloud + Task** (no TF/TFC for friend boxes). `task gate:provision:* -- <id>` → that friend’s `HCLOUD_TOKEN` → create-if-absent / destroy-by-name. Ansible only for SSH configure. |
| Secrets | **`secrets/gate-{id}.yml`** (`gate-1.yml`, …) + `.sops.yaml` rule `gate-[0-9]+\.yml$`. Never platform/`infra.yml` token in friend files. Legacy shared box keeps `gate.yml` until destroy. |
| Resource names | Always `gate` / `gate-v4` / `gate-firewall` inside each customer (isolation = token/customer). |
| Legacy TF | `terraform/gate` + TFC `gate` + `gate.yml` = rednaw shared legacy only; **no further apply** to heal renew drift — destroy/teardown when cutovers allow. Archived parallel-TF work: [../completed/gate-terraform-parallel.md](../completed/gate-terraform-parallel.md). |
| Dev `vpn` box | Stays `terraform/vpn` / TFC `vpn` / `vpn:*` for wipe/configure. **SoT = `secrets/vpn.yml`** (not `infra.yml`) for Hetzner + `vpn_*`. Primary renew = `fullmoongate/vpn` IssueOps; demote `task vpn:provision:renew-ip` to break-glass. |
| Friends | Never open `iac`. Maintainer only runs provision/configure. |

## Decide

None.

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

### 2. hcloud ensure/destroy + Task `gate:provision:* -- <id>`

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — can start now: replace **friend** use of `terraform/gate` with scripts that ensure/destroy `gate` / `gate-v4` / `gate-firewall` via hcloud from the id’s secrets file; wire `tasks/Taskfile.gate.yml` CLI id; leave legacy TF tasks usable for rednaw `gate.yml` destroy until cool-off.

**Human must:** controlled smoke on rednaw lab (or Friend 1 empty customer when console ready) — not live friend traffic.

### 3. hostkeys + configure by id

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after Do 1–2: `hostkeys` / `gate:configure:*` take the same `<id>` and force `HCLOUD_TOKEN` + `vpn_*` from that file only.

**Human must:** review that ambient Default/platform token cannot leak into friend paths.

### 4. Record no-further-TF for legacy gate / renew drift

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — can start now: task help / plan cross-links: do not `task gate:provision:apply` / `vpn:provision:apply` to heal a renewed IP; destroy or hcloud teardown only.

**Human must:** avoid TF apply on legacy gate / drifted vpn until intentional destroy.
