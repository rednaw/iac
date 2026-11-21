# One stack: Ansible

**All** boxes: cloud + DNS + OS via **Ansible**; Task = UX. This plan covers the remaining **friend provision** and **legacy gate decommission** in `iac`. Renew code, security and Friend 1 cutover: [`vpn/.cursor/plans/vpn.md`](../../../vpn/.cursor/plans/vpn.md). **Not legal advice.**

## Decided

| | |
|--|--|
| Ownership | This plan = **iac** (+ `secrets` when a Do says so). The renew side and the Friend 1 cutover live in `vpn` `vpn.md`. |
| Engine | **Ansible** = desired state: server, primary IPv4, standing firewall rules, DNS, OS/apps. Official **`hetzner.hcloud`** only; TransIP via the DIY `ansible/library/transip_dns.py`. Task wraps playbooks. |
| Ops scripts | One-off ops stay thin Task + `hcloud` scripts: `<purpose>:ssh:allow\|deny\|shell`, `hostkeys`, break-glass `vpn:provision:renew-ip` (fate: `vpn.md` Decide). |
| Uniformity | Same engine/SSH model for all boxes, platform included. |
| SSH | **No standing SSH allowlist.** `<purpose>:ssh:allow` adds a /32 rule (description `Allow SSH from trusted IPs`); `:ssh:deny` removes them. Converge **keeps** marker rules. |
| Firewall standing | REALITY: ICMP+443. Platform: ICMP+80+443. Firewalls labelled `purpose=<name>`. |
| Names | `platform`/`platform-v4`/`platform-firewall`; `vpn`/`vpn-v4`/`vpn-firewall`; friends `gate`/`gate-v4`/`gate-firewall` (isolation = token). |
| DNS | `ansible/roles/platform_dns`: apex/registry/auth/analytics A+AAAA, www, null MX + SPF + DMARC (base and app domains). |
| Downtime | REALITY boxes: none for routine ops; IP renew = brief poweroff. Platform: converge in place. |
| Legacy gate | Not migrated, unmanaged: no provision tasks. Only `gate:ssh:*` / `gate:configure:*` until decommission. |
| Secrets files | Platform `infra.yml`. Lab `vpn.yml`. Friends `gate-{id}.yml` + `.sops.yaml` rule `gate-[0-9]+\.yml$` (deferred until near Friend 1 go-live). Legacy `gate.yml` until decommission. Never the platform token in friend files. |
| Friends | Never open `iac`. Maintainer only runs provision/configure. |
| Shipped | Lab `vpn` and platform on Ansible (`hcloud_box` profiles `reality` / `platform`, `platform_dns`, adopt-in-place); old provisioning stack purged from repo, CI and tooling. |

## Decide

None.

## Do

### 0. Friend secrets parameterization

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — deferred until near Friend 1 go-live: `task gate:* -- <id>` loads `secrets/gate-{id}.yml`; `.sops.yaml` rule `gate-[0-9]+\.yml$` in sibling `secrets` (after go).

**Human must:** authorize the `secrets` sibling edit; create and fill `gate-1.yml` (fullmoongate1).

### 1. Friend boxes by `<id>`

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 0: `gate:provision:*`, `gate:ssh:*`, `hostkeys`, `gate:configure:*` take `<id>` and use only that file's token + `vpn_*` (same `provision.yml`, profile `reality`).

**Human must:** provision on Friend 1's customer (`present` → `ssh:allow` → `hostkeys:accept` → bootstrap → configure); confirm no platform/Default token in friend paths; continue with `vpn.md` Do 9.

### 2. Decommission legacy gate

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after `vpn.md` **Legacy cool-off**: remove `tasks/Taskfile.gate.yml`, `scripts/gate-secrets.sh`, gate branches in `ssh-allow.sh` / `ssh-deny.sh` / `Taskfile.hostkeys.yml` / help.

**Human must:** confirm no one is left on legacy; delete server / IP / firewall in project Gate (hcloud or console); retire `gate.yml`.
