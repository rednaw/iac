# Friend Gate provision (hcloud + Task)

> **Superseded for stack/engine:** living plan is [`provision-simplify.md`](provision-simplify.md) (one stack, all boxes, no Terraform). Keep this file only for Friend 1 sequence notes until those Do items are folded/archived.

Parameterized friend-box provision/destroy/configure in **`iac`**. Peer track to vpn ops hardening (`vpn/.cursor/plans/operations.md`); **both** must finish before Friend 1 migration (`vpn/.cursor/plans/friend1-cutover.md`). Pre-cutover lab = rednaw Hetzner + server `vpn` + `fullmoongate/vpn` control plane. China trip is **over**. **Not legal advice.**

## Decided

| | |
|--|--|
| Ownership | This plan = **iac** (+ `secrets`). Renew ops hardening = **vpn** `operations.md`. Cutover = **vpn** `friend1-cutover.md`. |
| Pre-cutover lab | Develop and prove **only on lab `vpn`** (rednaw Default + `fullmoongate/vpn`). **Do not touch** live legacy Gate or platform for this track. |
| Sequence | **1)** vpn-only development (iac lab + vpn ops). **2)** go-live Friend 1 on **fullmoongate1/gate**. **3)** communication. **4)** full decommission of legacy `gate` (shared box / TFC `gate` / `gate.yml`). Platform stays TF throughout. |
| Do 1 timing | **Defer** secrets parameterization (`gate-{id}.yml` + sops rule) until closer to Friend 1 go-live. Stay vpn-only for now. |
| Tool | **B — hcloud + Task** for the vpn provision story (lab `vpn`, then friends). No TF/TFC create/apply to heal renew drift. Ansible only for SSH configure. **Platform stays Terraform** (TFC `platform` + standing SSH allowlist + TransIP DNS). |
| Provision CLI | **`provision:present`** / **`provision:absent`**. Friends: `task gate:provision:present|absent -- <id>`. Lab mirror: `task vpn:provision:present|absent`. Present = create-if-absent (server + primary IPv4 + firewall); absent = destroy-by-name. Idempotent. Not `apply`/`destroy`/`ensure`/`wipe`. |
| Secrets | **`secrets/gate-{id}.yml`** (`gate-1.yml`, …) + `.sops.yaml` rule `gate-[0-9]+\.yml$`. Never platform/`infra.yml` token in friend files. Legacy shared box keeps `gate.yml` until destroy. Lab: **`secrets/vpn.yml`**. |
| Resource names | Friends: always `gate` / `gate-v4` / `gate-firewall` inside each customer. Lab: `vpn` / `vpn-v4` / `vpn-firewall`. Isolation = token/customer. |
| TF roots | `terraform/platform` + TFC `platform` = **keep**. `terraform/vpn` + TFC `vpn` = **retire** (delete workspace when cool; do not TFC-destroy live box). `terraform/gate` + TFC `gate` = **retire** when gate is on hcloud. Archived parallel-TF: [../completed/gate-terraform-parallel.md](../completed/gate-terraform-parallel.md). |
| Lab `vpn` | `vpn:provision:present|absent` + configure from `vpn.yml`. Primary renew = `fullmoongate/vpn` IssueOps; `vpn:provision:renew-ip` = break-glass only. |
| Two SSH models | **VPN family** (lab `vpn` + friends `gate`): Task + hcloud; **no standing SSH allowlist**; ICMP+443 only; open 22 via `task vpn:ssh:allow` / `gate:ssh:allow`, close via `:ssh:deny` (description `Allow SSH from trusted IPs`, kept across `present`). **Platform:** Terraform + standing `allowed_ssh_ips`; not on the allow path. |
| Legacy gate SSH | **Temporary exception:** until Do 2 (`gate:provision:present\|absent`), legacy `terraform/gate` may still apply `vpn_allowed_ssh_ips`. End state = same as lab vpn (markers only). |
| Friends | Never open `iac`. Maintainer only runs provision/configure. |

## Decide

None.

## Do

### 0. Retarget iac `vpn:*` to `secrets/vpn.yml`

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — `vpn-secrets.sh` (was `vpn-tf-secrets.sh`), `Taskfile.vpn.yml` (config/smoke/configure), `hostkeys` purpose `vpn` load `vpn.yml` only.

**Human must:** set `vpn.yml` `hcloud_token` + `ssh_keys` to Default/platform mirror (still Gate-shaped after Gate→vpn copy); then strip leftover `vpn_*` from `infra.yml`; `task secrets:push` in vpn container when ready; smoke `task vpn:vless-link` / `hostkeys:ip -- vpn`.

### 0b. Demote `vpn:provision:renew-ip` to break-glass

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — task help / renew-ip desc point at `fullmoongate/vpn` IssueOps as primary; script remains break-glass.

**Human must:** use `fullmoongate/vpn` for renew drills; do not point friends at the vpn repo.

### 1. Secrets parameterization + sops rule

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — **deferred** until closer to Friend 1 go-live (Do 1 timing). Then: load path `secrets/gate-{id}.yml` for `task gate:* -- <id>`; add `.sops.yaml` rule `gate-[0-9]+\.yml$` in sibling `secrets` (after go). Keep `gate.yml` until legacy decommission. Friend files need not require `vpn_allowed_ssh_ips`.

**Human must:** when unblocking — authorize **secrets** sibling edit; create/fill Friend 1 file (fullmoongate1).

### 2a. Lab `vpn:provision:present|absent` (hcloud)

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — `scripts/box-provision.sh present|absent` (`BOX_NAME` → `<name>` / `<name>-v4` / `<name>-firewall`; present converges standing rules and keeps `Allow SSH from trusted IPs` rules; never re-addresses an existing server; absent also removes `<name>-v4-new-*` / `-hold-*` / `-burned-*`). `scripts/vpn-secrets.sh` (was `vpn-tf-secrets.sh`) exports `HCLOUD_TOKEN` + `BOX_SSH_KEYS_JSON` from `vpn.yml`. `terraform/vpn` removed; `test:terraform:*` = platform only.

**Human must:** `task vpn:provision:present` → `task vpn:ssh:allow` (opens /32 + hostkeys:accept) → `vpn:configure:bootstrap` → `vpn:configure:apply` → `vpn:vless-link`; optional: drop unused `vpn_allowed_ssh_ips` from `vpn.yml`; then vpn window `task secrets:push` + `task denylist:push`. **TFC workspace `vpn`:** deleted via API (2026-11-20; was 0 resources; live box untouched). Leave `gate` + `platform`. Console: drop any leftover defunct SSH rule if still present.

### 2a-ssh. VPN-family travel SSH CLI (`*:ssh:allow` / `:deny`)

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — `task vpn:ssh:allow|deny` and `gate:ssh:allow|deny` via `scripts/ssh-allow.sh` / `ssh-deny.sh` (load that purpose’s secrets; `-l purpose=<name>`; not platform). No root `ssh-allow-me` / `ssh-revoke-me`. Marker kept across `present`.

**Human must:** after present, smoke `task vpn:ssh:allow`; confirm platform firewall unchanged. Gate: `task gate:ssh:allow` (loads Gate token).

### 2. Friends `gate:provision:present|absent -- <id>` (Friend 1 go-live)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — **after vpn-only + Do 1:** reuse `scripts/box-provision.sh` with `BOX_NAME=gate` + `gate-{id}.yml` → `task gate:provision:present|absent -- <id>`. Target go-live: **fullmoongate1/gate**. Do not migrate legacy shared Gate in this step.

**Human must:** controlled provision on Friend 1 customer; then cutover per `vpn/.cursor/plans/friend1-cutover.md`.

### 3. hostkeys + configure by id

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after Do 1–2: `hostkeys` / `gate:configure:*` take the same `<id>` and force token + `vpn_*` from that file only. Lab `vpn` already on `vpn.yml`.

**Human must:** review no Default/platform token leak into friend paths.

### 4. Retire TF for lab vpn (docs/help + TFC `vpn`)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — vpn-only now: help/tips — no `vpn:provision:apply`; present/absent only. Do not change gate/platform TF help until decommission phase.

**Human must:** DELETE TFC workspace `vpn` via API when cool (abandon state; do not TFC-destroy live box). Leave `gate` + `platform` workspaces until later.

### 5. Communication (after Friend 1 live)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — none until asked (draft copy only if requested).

**Human must:** tell friends / operators the new path (fullmoongate1 live; legacy gate sunset timeline).

### 6. Decommission legacy gate

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after communication: remove/retire `terraform/gate`, gate TF tasks, TFC `gate` workspace delete via API; wipe shared box via hcloud absent when traffic gone; `gate.yml` retirement.

**Human must:** confirm no remaining users on legacy shared Gate; run absent / TFC delete; archive `fullmoongate/gate` when ready.
