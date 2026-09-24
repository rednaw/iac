[**<---**](../../README.md)

# VPN for China travel

Dedicated Hetzner VPS for a personal trip (MacBook + iPhone). Same account as platform (`rednaw.nl`). **Not legal advice.**

**Implemented** (files in repo, nothing provisioned): `terraform/vpn/` (managed `hcloud_primary_ip` + server), `ansible/roles/vpn/` + `playbooks/vpn.yml`, `tasks/Taskfile.vpn.yml` (`provision:renew-ip`), purpose-parameterised `hostkeys:*` / `_terraform:*` / `_ansible:*` (ansible_host = API IPv4, `StrictHostKeyChecking=yes`), `hostkeys:accept`, root `ssh-allow-me` / `ssh-revoke-me`, firewall label `iac_managed=true` in `modules/server`. Do = review fixes + rollout + smoke. Dest is a roster (pick at smoke). Operator manual: [vpn-travel-china-manual.md](vpn-travel-china-manual.md).

---

## Decided

| | |
|--|--|
| Box | **Two Hetzner servers, one account.** **Platform** = long-running (`rednaw.nl`, stable IPs, single box). **VPN** = one throwaway box (destroy when done). No `vpn-dev`. VPN-only stack (no Traefik, registry, apps). `nbg1`. `cx23`. `backups = false`. Home smoke is this same box. |
| Account | Same Hetzner **account** as platform. Shared `hcloud_token`. |
| Cloud admin | **Full secrets stay on this laptop** (`hcloud_token` / TFC / TransIP). No VPN-only project, no off-machine stash. Theft/unlock = APIs for the whole account. After `ssh-allow-me`, `platform:configure:*` from China works. |
| Exit use | **Personal only** (this Mac + iPhone). No sharing QR/UUID, P2P/torrent, SMTP, scanning, mining. Intended use is not a ToS complaint. Residual: leaked keys or a compromised box → Hetzner email, usually **that IP/server** first; account freeze is ignore/repeat and would still hit **`rednaw.nl`**. Watch the account mail on the trip. |
| Admin | **This MacBook** is the only admin device (age key, SSH private key, clone, Docker). It travels. The iPhone is a VPN **client** only — no SOPS, no `task`. Not a “trusted devices” layer (no MDM, no device certs, no Tailscale). SE-bound SSH is platform work: [ssh-admin-t2.md](ssh-admin-t2.md). This trip may keep the file key. |
| Network vs device | **SSH standing lists trust home IPs**, not this laptop. Not at home → `ssh-allow-me` (all iac boxes). **Cloud APIs follow the disk.** |
| Singapore | Out. |
| Protocol | **REALITY only** on TCP **443**: VLESS + `xtls-rprx-vision`. No Let’s Encrypt cert on 443. No WS+TLS, WireGuard, or Hysteria2. **One dest live at a time** (client SNI = `dest` / `serverNames` / `fp=`). Not a multi-site inbound. Hostname is a **roster**, not frozen in this plan. |
| Xray | Container on `roles/base` Docker, **`network_mode: host`** (bridge cannot egress IPv6). Pin image digest. No native binary. |
| Keys | UUID + REALITY keypair + short_id **persist** in secrets. IP renew or wipe keeps them; QR differs in address (and SNI if dest stepped with a burn). Rotate UUID/keys only if a QR leaked (manual). |
| Client | [OneXray](https://apps.apple.com/us/app/onexray/id6745748773) only (both devices; App Store, macOS 13+). Rule: `geosite:cn` **direct**, rest VLESS. No `geoip:cn` (poisoned DNS). Download GeoData at home. Not per-app VPN. TUN IPv6 **on** (app default). Do not disable IPv6 on the devices. |
| IPv6 | VPS stays dual-stack. Share links IPv4-only. Device IPv6 is captured by OneXray TUN and egresses from the VPS, not the hotel. Home SSH may use AAAA if home IPv6 is on the standing list. Travel extra SSH is IPv4 `/32` only. |
| Primary IPv4 | VPN uses a Terraform **`hcloud_primary_ip`** (`nbg1`, `auto_delete = false`) attached via `public_net.ipv4`. Not ephemeral-with-server. Platform unchanged. |
| Leak | Non-CN traffic that leaves via hotel/eSIM while OneXray is on (destinations see a Chinese IP). Usual hole: IPv6 Happy-Eyeballs skipping an IPv4-only TUN. Also DNS to the hotel resolver, WebRTC STUN, tunnel down with no kill switch. `geosite:cn` **direct** is not a leak. |
| eSIMs | **Consumer + management.** At least one **home-routed** travel eSIM for **iPhone daily cellular** (Western apps, no OneXray on cell). Confirm home-routing before buy; watch FUP if labelled unlimited. **Second** (or more) eSIM/carrier for repair if the first is bad. Admin (IaC / Console / SSH) still uses eSIM cellular with OneXray **off**. Not a guarantee — routing can change. |
| Internet | **Split.** iPhone **cellular** → home-routed eSIM (OneXray off). **Hotel Wi-Fi + MacBook** → OneXray → this VPS (LAN only reaches the tunnel). Habit: hotel = VPN on, outside = VPN off. When VPS IP is burned: phone stays on eSIM; Mac waits for IP renew (or wipe if wedged) or brief tether. No second commercial VPN brand. |
| Ops DNS | No `vpn.rednaw.nl`. No TransIP record in `terraform/vpn/`. TLS name is dest, never ours. Share links embed **IPv4**. |
| SSH/Ansible host | Always IPv4 from TFC / `hcloud`, never the hostname. |
| Timeline | ~1 month. |
| SSH | **Never `0.0.0.0/0` / `::/0`.** Standing lists: platform `allowed_ssh_ips` and VPN `vpn_allowed_ssh_ips` = **home only**. Do not put the VPN IP on platform’s list. Do not put platform IPs on the VPN list. No jump `platform → VPN`. |
| Travel SSH | Root tasks `ssh-allow-me` / `ssh-revoke-me` — **all** iac-managed Hetzner firewalls in one go (platform, VPN, later honeypot). **Skip at home.** Extra rule: current public IPv4 `/32` only. Detect `-4`; SSH `-4`. Fail loud if no public v4. Refuse if that IP is any iac server. Extra rules are not Terraform, not SOPS, not git. Next `<purpose>:provision:apply` **drops** that box’s extra rule — expected. No per-purpose allow-me. |
| Travel admin | **This MacBook** — only machine with the age key, clone, and Docker. It travels. Repair is eSIM + this laptop (devcontainer). Do not Console-delete the VM (TFC desync). Wedged box → Console and/or `ssh-allow-me`, then wipe path if needed. |
| Burned IP | **Default: renew IPv4, keep disk.** OneXray off → replace `hcloud_primary_ip` only → **fail loud if new address equals old** (retry) → `ssh-allow-me` (**skip at home**) → `hostkeys:accept -- vpn` → optional next `vpn_dest` → `vpn:config` (both devices) → OneXray on. No bootstrap/configure. Same SOPS keys. Disk survives because `public_net` is **not** ForceNew (provider updates the server in place); the box hard power-cycles **twice per attempt** and is briefly IPv4-less. |
| Wedged / wipe | Disk bad, Docker/Xray wedged, or compromise → destroy/recreate **server** (and IP as needed) → `hostkeys:accept` → bootstrap → configure → `vpn:config`. Full circle. |
| Hostkey | Provision never SSH. VPN has no FQDN — `hostkeys:prepare` does not invent one. After IP renew or wipe (+ `ssh-allow-me` when away), `hostkeys:accept -- vpn` to the API IPv4 (`-4`, `accept-new`, own-IP wipe first) must succeed before Ansible with `StrictHostKeyChecking=yes`. |
| Post-trip | Destroy VPN primary IP + server + firewall and TFC `vpn`. No DNS record to delete. |
| Competition (ops) | **Home-routed roaming eSIM** can carry Western apps on **phone cellular** with no tunnel (hotel Wi-Fi and laptop still need something else). **Commercial apps** (Astrill etc.) are flaky in 2026; Astrill’s strong mode is weak on **iOS** — OneXray+REALITY stays the right primary for this Mac+iPhone pair. **iCal/shared-pool “airports”** are not our path. Treat any single tunnel as **disposable** (already Burned IP). Prefer a **heterogeneous** fallback when the VPS is dead — not two copies of the same REALITY box unless we explicitly add standby. |
| fail2ban on VPN | **Off.** No package, no sshd jail, no AbuseIPDB. Safe because Hetzner already gates TCP/22 to `vpn_allowed_ssh_ips` (home) + travel `/32` via `ssh-allow-me` — the jail cannot see attackers the firewall rejects, and on a first hotel SSH it can only ban the operator (`ignoreip` is platform `allowed_ssh_ips`, never the travel IP). Platform keeps base jail + Traefik as today. |

REALITY: VPS forwards keyless probes to dest. Our name is not in the handshake. If REALITY fails: phone keeps working on eSIM cellular; use eSIM to **repair** (Burned IP renew, or wipe if wedged), then OneXray again on Wi-Fi/Mac. No dest change on a **live** (burned) IP. A successful renew may take the next roster name (`vpn:config` both devices).

Dropped: Tailscale / Headscale / wstunnel / public 22 / jump `platform → VPN`. Renewing the primary IPv4 is the GFW-IP lever; wipe only when the disk is the problem; platform stays put.

**Dest** (one live at a time; pick at home smoke from the CX23; Burned IP may step). Must: TLS 1.3 + h2 + **X25519**, HTTP 200 on the SNI hostname (no 301-to-`www`, no other bounce), looks like the real site from `nbg1` (not CDN 403), cert/handshake record under 8192. Local pre-filter is not enough — re-check from the box (manual §2.3).

Try order:

| Rank | Host | Why |
|--|--|--|
| 1 | `seapalace.nl` | TransIP `77.72.150.234` (Signet NL). Apex canonical. Rare SNI. |
| 2 | `jamstudios.nl` | Denit `80.247.175.21`. Apex canonical. Rare SNI. |
| 3 | `decorrespondent.nl` | One EC2 `eu-central-1`, nginx. Apex canonical. |

Spares (same IPs as #1/#2 — reverse-IP neighbours that passed local pre-filter). Prefer a different SNI after a burn; still verify from the CX23 before setting `vpn_dest`.

- TransIP / seapalace IP: `amateurkunstamstelveen.nl` `arcadic.nl` `catercompany.eu` `damiro-ontruiming.nl` `fueldesign.nl` `getsalesdone.eu` `jbscleaningservice.nl` `jbsgroep.nl` `lindeman-schuttingen.nl` `lobatto.eu` `nickfalkenberg.com` `puuragenturen.com` `radicalcup.nl` `shirtshop-amsterdam.com` `shirtshop-amsterdam.nl` `svrap.nl` `time2choco.nl` `toffeebreak.com` `toffeebreak.eu` `toffeebreak.net` `xbrands.nl`
- Denit / jamstudios IP: `advocatenkantoor.nl` `autom8-it.nl` `auvimedia.nl` `beertema.nl` `dependans.nl` `elsburgeronland.nl` `haagspreventienetwerk.nl` `idmaker.nl` `inclusiefmedia.nl` `joytofilms.com` `kerkdebron.org` `kippenburg.nl` `lindhout-es.nl` `maartenwoud.nl` `mijderwijk.nl` `mijndenhaag.org` `mirjam-ouwerkerk.nl` `paian.nl` `radiobeurslisse.nl` `robvankan.nl` `sinister.nl` `slampampers.nl` `smartlappenkoor.com` `teletrailer-huren.nl` `thatsmagic.nl` `tradeservice.nl` `trouwautoverhuur.nl` `van-grinsven.nl` `vioolpianolesnijmegen.nl` `waltergoeting.nl`

Out: our names (`tientjeketama.nl` `rednaw.nl` `*.github.io`); landlord / GFW-class (`www.hetzner.com` `www.apple.com`); gov costume (`ind.nl`); CDN / TLS1.2 / geo (`bol.com` Akamai; `ah.nl` `funda.nl` `nu.nl` `www.ns.nl` Akamai; `marktplaats.nl` `knmi.nl` `npo.nl` CloudFront/AGA; Cloudflare edges; `www.kieskeurig.nl` Bunny; `www.startpagina.nl` TLS1.2; `sap.com` geo); apex→`www` (`independer.nl` Azure App Gateway — `www` is canonical). Shared-host adjacency is for **finding** spares, not a REALITY benefit by itself.

---

## Decide

### Platform box lookup in `hostkeys:ip`?

`-- platform <env>` re-derives `${BASE_DOMAIN//./-}-<env>`, a second copy of `locals.server_name`, which silently breaks if `var.server_name` is ever set.

| | Option |
|--|--------|
| **A** | Keep the re-derivation. `var.server_name` stays unused in practice. |
| **B** | Look up by label instead (`hcloud server list -l …`): platform `environment=<env>`, VPN `purpose=vpn`. Name-independent; both roots already carry the labels. |

Choice: _unpicked_

## Do

### 0. Review fixes

can start now — all of this (fail2ban pick locked).

- **fail2ban off on VPN**: `roles/base` default on; `playbooks/vpn.yml` sets the skip var. Skip the whole `fail2ban.yml` import (no package → no jail → no AbuseIPDB). Platform unchanged. Manual §4: note fail2ban is platform-only on this trip box.
- **`renew-ip` init** (`tasks/Taskfile.vpn.yml`): call `:_terraform:init` with `TF_DIR` instead of the hand-rolled `terraform init` (exact-name backend `vpn` in `versions.tf` — no `WORKSPACE` / `TF_WORKSPACE` / prefix mode). Keep unsetting stale `TF_WORKSPACE` if present. Today it still inlines init, hides stdout, and duplicates `_terraform:init`; hotel path should share the same init helper as `vpn:provision:*`.
- **`hostkeys:accept` retry** (`tasks/Taskfile.hostkeys.yml`): bounded loop (~10 × 5 s) around the `ubuntu`/`root` attempt. A single `ConnectTimeout=10` shot races cloud-init on a fresh box and the power-cycle after `renew-ip`. Fix or drop the gate in `scripts/validate-stack.py` too: `server:check-status` exits 0 even when unreachable and takes no workspace, so `wait_for_server` never waits.
- **`ssh-revoke-me` multi-IP rule** (`scripts/ssh-revoke-me.sh`): `delete-rule` matches a whole rule, so a marker rule holding two `source_ips` never matches `--source-ips "$IP"`. Delete per rule, not per IP. Reachable via the by-hand Console fallback manual §5 recommends.
- **`ssh-allow-me` robustness** (`scripts/ssh-allow-me.sh`): a second detection URL after `api.ipify.org`; capture `hcloud server list` into a variable before `grep -Fxq`, because `grep -q` plus `pipefail` makes the "refuse an iac server address" guard fail open when `hcloud` takes SIGPIPE.
- **`vpn-tf-secrets.sh` null guard**: fail with "missing from `secrets/infra.yml` (manual §2.1)" rather than handing Terraform `null` for `ssh_keys` / `vpn_allowed_ssh_ips`. Otherwise the first rollout error is a raw type error.
- **Manual edits** (`vpn-travel-china-manual.md`): §6.1 — renew hard power-cycles the box twice per attempt (poweroff → unassign → on → delete IP, then off → assign → on) and it is briefly IPv4-less; Xray returns on `unless-stopped`. §2.2 — `provision:apply` does not print the IPv4, `provision:output` does. §2.4 — one link, not links. Back-link `../../README.md` like every other `docs/future/*.md`.

### 1. Rollout (one-time, at home)

- TFC: create workspace `vpn` in the org, then `task vpn:provision:reconfigure`.
- Secrets: generate + add `vpn_uuid`, `vpn_reality_private_key`, `vpn_reality_public_key`, `vpn_short_id`, `vpn_dest` (roster #1 for now), `vpn_allowed_ssh_ips` (home only). Manual §2.1. Generate **once**; never regenerate on apply.
- Platform: ensure `iac_managed=true` firewall label via `task platform:provision:apply` if needed. Then one-time `task hostkeys:accept -- platform` if Ansible IPv4/`StrictHostKeyChecking=yes` is not yet proven.

### 2. Home smoke, then trip

Home tests on this VPN box prove the stack, **not** the GFW. Try dest **try-order then spares from the CX23**; first that TLS-1.3-handshakes and HTTP-looks-like-the-site is the trip dest until a Burned IP (checks incl. X25519: manual §2.3).

Operator: OneXray installed on **Mac and iPhone** before departure; GeoData downloaded; iOS one VPN at a time, Private Relay off, **clock correct** (REALITY is intolerant); Rule `geosite:cn` direct; kill switch; TUN IPv6 on. Home smoke: with VPN on, v4 **and** v6 test pages show the VPS, not the house; DNS not the ISP; WebRTC not the LAN. Rehearse **Burned IP renew** (`task vpn:provision:renew-ip`) at home (skip `ssh-allow-me`); rehearse wipe path once if time. Rehearse **split habit**: cellular data = travel eSIM + OneXray off; join a Wi-Fi → OneXray on → confirm egress is VPS; leave Wi-Fi → OneXray off.

Buy/install **home-routed** travel eSIM(s) before departure; verify Western apps on cellular **without** VPN at home if the plan allows a pre-trip check (or accept first verify on arrival).

Day-0: captive portal (OneXray off) → join hotel Wi-Fi → OneXray on (Mac + iPhone). Outside: OneXray off, iPhone on eSIM cellular. Admin/repair: eSIM + OneXray off on the MacBook path as today.

If REALITY dies: phone stays on eSIM; Mac offline or brief tether; eSIM to run Burned IP renew (or wipe if wedged); then OneXray on Wi-Fi/Mac again. Chinese apps / banking without VPN as needed. Do not download a new client in China. Hetzner abuse mail: answer it; see Exit use.

---

## Trip checklist

- [ ] OneXray (Mac + iPhone) + offline configs (IPv4 + dest SNI) + GeoData
- [ ] Rule `geosite:cn` direct; kill switch; TUN IPv6 on; clock; home smoke (VPS v4+v6, not house; DNS; WebRTC)
- [ ] **Split habit** rehearsed: cell = eSIM + VPN off; hotel Wi-Fi = VPN on
- [ ] Home-routed travel eSIM installed (Cellular Data = that line; voice/SMS on home if desired); FUP known; spare carrier if possible
- [ ] This MacBook travels (age key + clone + Docker; no other copy)
- [ ] eSIM usable for **management** (Console/TFC); MacBook can tether; OneXray **off** when admin’ing on cellular
- [ ] Hetzner Console, TFC, TransIP logins + 2FA verified from this MacBook (the whole repair path assumes them)
- [ ] Banking / essentials without VPN
- [ ] Day-0 procedure
- [ ] Burned IP renew (eSIM, OneXray off): `task vpn:provision:renew-ip` → `ssh-allow-me` (skip at home) → `hostkeys:accept -- vpn` → optional next dest → `vpn:config` (both devices) → OneXray on
- [ ] Wedged wipe path known: `vpn:provision:destroy` / `apply` → bootstrap → configure → `vpn:config`
- [ ] `ssh-allow-me` / `ssh-revoke-me` (not at home; all iac boxes)
- [ ] docker-ce + Xray digest held
- [ ] Post-trip destroy VPN box + TFC `vpn`
