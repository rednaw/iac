# One stack: Ansible (no Terraform)

**All** boxes: cloud + DNS + OS via **Ansible**; Task = UX; **no Terraform**. Includes the Friend 1 track (lab vpn → fullmoongate1 go-live → communication → legacy gate decommission). Earlier vpn-family work: [../completed/gate-friend-provision.md](../completed/gate-friend-provision.md).

**Not legal advice.**

## Decided

| | |
|--|--|
| Ownership | This plan = **iac** (+ `secrets` when a Do says so). Renew ops hardening = **vpn** `operations.md`; Friend 1 cutover = **vpn** `friend1-cutover.md`. Both peer tracks finish before Friend 1 cutover. |
| Sequence | **1)** lab `vpn` development. **2)** Friend 1 go-live on **fullmoongate1/gate**. **3)** communication. **4)** decommission legacy `gate`. Platform adoption: any time. Terraform purge: last. |
| Engine | **Ansible** = desired state: server, primary IPv4, firewall standing rules, DNS, OS/apps. Task wraps playbooks. |
| Ops scripts | One-off ops stay thin Task + `hcloud` scripts: `<purpose>:ssh:allow\|deny\|shell`, `hostkeys`, break-glass `vpn:provision:renew-ip`. |
| Hetzner | Official collection **`hetzner.hcloud`** only. |
| TransIP | **Simplest DIY** (thin `uri` or tiny local module) — no third-party TransIP Galaxy deps. |
| Terraform | **Not viable** — stop operator TF; DELETE TFC workspaces via API after Ansible owns resources (abandon state; never TFC-destroy live boxes). |
| Uniformity | **Same engine/SSH model for all boxes, platform included.** |
| SSH | **No standing SSH allowlist.** `<purpose>:ssh:allow` adds a /32 rule (description `Allow SSH from trusted IPs`); `:ssh:deny` removes them. Firewall converge **keeps** marker rules → allow once after create (or when operator IP changes). |
| Firewall standing | REALITY: ICMP+443. Platform: ICMP+80+443. Firewalls labelled `purpose=<name>`. |
| Names | `platform`/`platform-v4`/`platform-firewall`; `vpn`/`vpn-v4`/`vpn-firewall`; friends `gate`/`gate-v4`/`gate-firewall` (isolation = token). |
| Platform cutover | **Adopt in place** by name — keep server, disk, IP; no recreate. Hetzner backups stay on. |
| DNS | TransIP records = today’s `terraform/platform/dns.tf` set: apex/registry/auth/analytics A+AAAA, www, null MX + SPF + DMARC (base and app domains). Values from `infra.yml` + server IPs. |
| Downtime | **Gate / lab vpn (REALITY):** none for routine ops — converge in place; IP renew = brief poweroff only. **Platform:** downtime acceptable but adopt-in-place avoids it. |
| Legacy gate | **Not migrated** — stays on `terraform/gate` + TFC `gate` untouched until decommission. |
| Secrets files | Platform: `infra.yml`. Lab: `vpn.yml`. Friends: `gate-{id}.yml` + `.sops.yaml` rule `gate-[0-9]+\.yml$` — **deferred** until near Friend 1 go-live. Legacy `gate.yml` until decommission. Never platform token in friend files. |
| Lab vpn | Rewrite provision onto Ansible; keep renew + vless-link. Primary renew = `fullmoongate/vpn` IssueOps. |
| Friends | Never open `iac`. Maintainer only runs provision/configure. |

## Decide

None.

## Do

### 0. Fold friend plan

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — friend sequence, deferred secrets, peer-track links folded here; `gate-friend-provision.md` archived to `.cursor/completed/`.

**Human must:** use this file as the living provision plan.

### 1. Ansible provision skeleton (lab vpn)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — add `hetzner.hcloud` to `ansible/requirements.yml`; role/playbook for cloud box (server + primary IPv4 + firewall profile, marker rules preserved); SOPS → vars; Task entrypoint replacing `vpn:provision:present|absent`; retire `scripts/box-provision.sh`. Ops scripts unchanged.

**Human must:** converge lab `vpn` in place (no recreate) → `task vpn:ssh:allow` → `vpn:configure:apply` → `vpn:vless-link`; confirm REALITY link still works.

### 2. Platform adopt on Ansible

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — platform profile (ICMP+80+443, backups on, `purpose=platform`); DIY TransIP for the `dns.tf` record set; `platform:ssh:allow|deny|shell` via existing ops scripts loading `infra.yml`; drop standing `allowed_ssh_ips`; Task replaces TF provision tasks.

**Human must:** `task platform:ssh:allow` before the first converge; run converge, confirm server/IP unchanged and DNS records identical; then approve DELETE of TFC `platform` via API.

### 3. Friend secrets parameterization

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — **deferred** until near Friend 1 go-live: `task gate:* -- <id>` loads `secrets/gate-{id}.yml`; `.sops.yaml` rule `gate-[0-9]+\.yml$` in sibling `secrets` (after go). No `vpn_allowed_ssh_ips` required.

**Human must:** authorize the `secrets` sibling edit; create/fill `gate-1.yml` (fullmoongate1).

### 4. Friend 1 go-live (fullmoongate1/gate)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after Do 1 + 3: same playbook with `gate-{id}.yml`; `gate:ssh:*`, `hostkeys`, `gate:configure:*` take `<id>` and use only that file’s token + `vpn_*`.

**Human must:** provision on Friend 1 customer; review no platform/Default token in friend paths; cut over per `vpn/.cursor/plans/friend1-cutover.md`.

### 5. Communication (after Friend 1 live)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — none until asked (draft copy only if requested).

**Human must:** tell friends / operators the new path (fullmoongate1 live; legacy gate sunset timeline).

### 6. Decommission legacy gate

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — remove `terraform/gate`, gate TF tasks, `scripts/gate-tf-secrets.sh` legacy paths.

**Human must:** confirm no users left on legacy Gate; delete server/IP/firewall in that customer; DELETE TFC `gate` via API; retire `gate.yml`; archive `fullmoongate/gate` when ready.

### 7. Purge Terraform from repo + CI

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — delete remaining TF roots/modules; remove `test:terraform:*` / tfsec; replace `terraform.mdc` with hcloud/Ansible invariants; propose `project.mdc` identity line + `rednaw-map` skill updates (sibling/skill edits after go).

**Human must:** confirm TFC holds no iac workspaces you care about.
