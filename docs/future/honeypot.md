[**<---**](README.md)

# Honeypot server

Ephemeral dedicated Hetzner VPS running a standalone [T-Pot](https://github.com/telekom-security/tpotce) Hive to observe internet attackers. Completely isolated from the platform and VPN boxes. Not a real vulnerable system — simulated services only. Kibana lives on the box; no OpenObserve shipping.

## Decided

| | |
|--|--|
| Interaction | Low-interaction only (T-Pot Hive). High-interaction deferred |
| Software | Standalone T-Pot **Hive** (upstream Sensor requires a Hive and cannot target OpenObserve — rejected) |
| Host | Dedicated CX53 (32 GB RAM, 320 GB local disk). No block volume. Hetzner backups off |
| Lifecycle | Ephemeral campaigns: provision → observe → destroy. Duration chosen by the human |
| Naming | TFC workspace `honeypot`; server / firewall / Ansible inventory `honeypot` (mirror VPN). No DNS |
| Isolation | No private network to platform/VPN. No platform credentials, registry, or SOPS key on the box. Dedicated SSH key |
| Inbound | Public TCP/UDP **1–64000**. Cowrie on public **22**. Real SSH **64295** and web UI **64297** restricted to admin IPs |
| Observability | Built-in Elastic/Kibana on the box only. No OpenObserve, no public ingest endpoint |
| Community | T-Pot community data submission **disabled** |
| Retention | Local honeypot data ~7 days; malware/binaries stay on the box and die with destroy |
| Egress | Maintenance mode: temporary HTTPS for install/update. Runtime: established + fixed DNS resolvers only |
| Pattern | Same as VPN: `terraform/honeypot/` → `modules/server`; `roles/honeypot/` + `playbooks/honeypot.yml` = `[base, honeypot]`; `tasks/Taskfile.honeypot.yml` |

## Decide

None.

## Do

Checkboxes track status only. The agent may change only **Agent** boxes; only the human may change **Human** boxes. Task bodies assign the work.

### 0. Prerequisites and secrets

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after `remove-dev.md` and `public-secrets.md` land (or against current `secrets/` until then): add honeypot keys to the secrets scaffold (`honeypot_allowed_ssh_ips`, dedicated SSH key IDs, T-Pot web user/password hash, pinned T-Pot version/repo); add `scripts/honeypot-tf-secrets.sh` mirroring `vpn-tf-secrets.sh`; assert only honeypot keys are required on that purpose.

**Human must:** Create TFC workspace `honeypot`. Generate a dedicated Hetzner SSH key for this purpose only. Store `honeypot_allowed_ssh_ips`, key IDs, and T-Pot web credentials in the active SOPS secrets repo. Do not paste plaintext secrets into chat.

### 1. Shared plumbing

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — can start now:
- Parameterize SSH listen port in `terraform/modules/server/` (default 22; honeypot uses 64295) and in `ansible/roles/base` SSH + fail2ban jails.
- Extend `tasks/Taskfile.hostkeys.yml` and `tasks/Taskfile._ansible.yml` for purpose `honeypot` (inventory name `honeypot`, API IPv4, port 64295).
- Add `honeypot` to `tasks/Taskfile.test.yml` validation loops.
- Prove platform and VPN still plan/configure with unchanged defaults.

**Human must:** Review the shared-module diffs; confirm no change to platform SSH on 22 or VPN behavior.

### 2. Terraform root

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 1: create `terraform/honeypot/` composing `modules/server`:
- Image Debian 13 (T-Pot supported), type `cx53`, `backups = false`, no TransIP/DNS, workspace `name = "honeypot"`.
- Inbound: TCP/UDP 1–64000 from anywhere; SSH rule on **64295** from `honeypot_allowed_ssh_ips`; management **64297** from the same allowlist; ICMP as module default.
- Labels `purpose=honeypot`, `iac_managed=true` (via module).

**Human must:** Review `task honeypot:provision:plan` (in-place create only). Apply. Run `task hostkeys:accept -- honeypot` against port 64295.

### 3. T-Pot Hive install

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 2:
- `ansible/playbooks/honeypot.yml` = `[base, honeypot]`. Adjust base Docker install so it does not conflict with T-Pot's installer (clean host path preferred: skip or defer stock Docker when purpose is honeypot).
- `roles/honeypot/tasks/tpot.yml`: pinned upstream unattended Hive install (`install.sh -s -t h …`); disable Ewsposter / community submission; set local retention ~7 days; reboot + second run for idempotence.
- Document that T-Pot moves real SSH to 64295 and binds Cowrie on 22.

**Human must:** Run `task honeypot:configure:apply`, allow the reboot, rerun until idempotent. Confirm Cowrie answers on public 22 and `ssh -p 64295` still works from an allowlisted IP.

### 4. Egress containment

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 3: `roles/honeypot/tasks/egress.yml` with two modes covering host + Docker IPv4/IPv6:
- **Maintenance:** allow DNS + HTTPS (and whatever the installer needs) for install/update.
- **Runtime:** allow established/related + fixed DNS resolvers only; drop everything else (no arbitrary HTTP/HTTPS/SMTP, no path to platform/VPN IPs).
- Task hooks to switch modes; default after configure is **runtime**.

**Human must:** Enter maintenance, pull/update once, switch to runtime, then prove `curl` to arbitrary hosts fails while DNS still works. Do this before treating the box as exposed.

### 5. Task namespace

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 1–2: `tasks/Taskfile.honeypot.yml` with `provision:*`, `configure:*`, `maintenance:on|off`, status, and destroy; include from root `Taskfile.yml` help; no env argument.

**Human must:** Use the new commands without `dev`/`prod`. Prefer destroy over long idle billing.

### 6. Exposure and verify

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 4–5: read-only checks — public honeypot ports open; 64295/64297 closed from non-allowlisted IPs; community submission off; runtime egress holds; no route/credentials toward platform.

**Human must:** Open `https://<honeypot-ip>:64297`, log into Kibana, confirm live captures, then accept the campaign.

### 7. Campaign destroy

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 5: pre-destroy checklist task; after destroy, verify no residual Hetzner volume, DNS, primary IP, or Terraform resources for `honeypot`.

**Human must:** Export only sanitized notes/screenshots if desired — **never** copy malware binaries off the box. Run `task honeypot:provision:destroy`. Revoke campaign-specific web password / rotate allowlist entries if they were temporary.

### 8. Roadmap sync

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — with this rewrite: keep `docs/future/README.md` honeypot blurb aligned; remove any remaining Sensor / OpenObserve / `honeypot-dev` / tunnel references in iac docs that this plan supersedes.

**Human must:** Review the operational campaign workflow end-to-end once implementation exists.
