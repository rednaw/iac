# VPN for China travel

Dedicated Hetzner VPS (REALITY / VLESS) for a ~1‑month trip: **three Western travellers** (3 phones) + **hotel MacBook** (admin + work). Same Hetzner account as platform (`rednaw.nl`). **Not legal advice.**

Operator manual: [../ideas/vpn-travel-china-manual.md](../ideas/vpn-travel-china-manual.md).  
Custom Routing JSON: [../ideas/onexray-custom-routing-cn.json](../ideas/onexray-custom-routing-cn.json).  
Dest roster / notes: [../ideas/vpn-travel-china.md](../ideas/vpn-travel-china.md).  
eSIM price/GB/reviews: [../ideas/china-esim-comparison.md](../ideas/china-esim-comparison.md).

**Live now (home):** TFC `vpn`; server `vpn` = `2.31.1.95` / `2a01:4f8:1c16:ad0a::/64` (`nbg1`; pool recycled this address after renew away from `157.90.17.23`); dest `amateurkunstamstelveen.nl`; **one shared UUID**; Mac (+ Dev Container) smoke passed via `api.ipify.org` when OneXray is on.

---

## Decided

| | |
|--|--|
| Box | Two Hetzner servers, one account. **Platform** = `rednaw.nl`. **VPN** = throwaway (`nbg1`, `cx23`, `backups=false`). No Traefik/apps on VPN. Destroy post-trip. |
| Account | Shared `hcloud_token`. Abuse/freeze can hit platform. Watch Hetzner mail. |
| Cloud admin | Secrets only on the **hotel MacBook** (age, SSH, TFC, TransIP). |
| Exit use | Three travellers + hotel laptop. **One shared VLESS UUID**. No further sharing; no P2P/torrent/SMTP/scanning/mining. Leak → rotate UUID for all. |
| Trip workload | Phones: normal use + **WeChat / Alipay / Didi** (hard). Hotel Wi‑Fi + OneXray: **rednaw work** (SSH/Ansible/Terraform), Netflix/general Western net. **Cities: Beijing, Shanghai + other mainland cities** (multi-city / likely HSR between). |
| Admin | MacBook in hotel; phones are clients only. Server work = laptop + hotel Wi‑Fi + OneXray on; `ssh-allow-me` when not on home SSH list. |
| Keys | REALITY keypair + short_id + one `vpn_uuid` in secrets. Persist across IP renew/wipe. |
| Protocol | REALITY, TCP 443, VLESS + `xtls-rprx-vision`. One dest at a time. |
| Xray | Docker, `network_mode: host`, digest-pinned. fail2ban **off** on VPN. |
| Client | OneXray on phones + Mac when using the VPS (esp. hotel Wi‑Fi). Shared Custom Routing JSON (`geosite:CN` direct, no `geoip:CN`). GeoData at home. TUN IPv6 on. No kill switch. |
| Phone connectivity | **KPN** = home number; data roaming **off** in CN (SMS/2FA). **Bought:** **2× Trip.com** [57042119](https://www.trip.com/things-to-do/detail/57042119?locale=en-XX&curr=EUR) **Total 50 GB / 30 d** (international breakout; CMCC; install at home, activate in CN). **1× phone eSIM still open** (see Decide). **Mainland tourist SIM** = contingency only. ≥1× iPhone 13. |
| Habit | Street/cell: eSIM data, OneXray **off** (eSIM already clears the GFW) — **order Didi in this mode**. Hotel Wi‑Fi: OneXray **on** for Mac (and phones when you want the shared Hetzner exit). Captive portal: VPN off → clear → on. Repair/admin: OneXray **off**. Do not order Didi with OneXray forcing a Hetzner exit. |
| OneXray vs eSIM | Complementary, not duplicates. **eSIM** = phone independence outdoors (and indoors if you prefer). **VPS** = hotel Mac, rednaw admin, shared exit, Burned-IP story. Do not rely on eSIM for the laptop. |
| IPv6 | VPS dual-stack; share links IPv4-only. |
| Primary IPv4 | Managed `hcloud_primary_ip` for Burned IP renew without wipe. |
| Dest | Live `#1` `amateurkunstamstelveen.nl`. Roster: #2 `seapalace.nl`, #3 `jamstudios.nl`. Burn = our IP, not dest’s. |
| Burned IP | Trip: `ssh-allow-me` first (skip at home). Then `vpn:provision:renew-ip` (= IP replace → `hostkeys:accept -- vpn` → `vpn:config`). Optional dest step after: `configure:apply` → `vpn:config` again. Re-import all devices. |
| Wedged | destroy/apply → hostkeys → bootstrap → configure → `vpn:config`. |
| SSH | Home-only standing lists; travel `ssh-allow-me` / `ssh-revoke-me`. |
| Ops DNS | No VPN hostname; links embed IPv4. |
| Competition | No second commercial VPN by default. |
| Platform name | Literal `"platform"`; no `var.server_name`. |

---

## Decide

### Phone eSIM — 3rd phone only?

**2× Trip.com** [57042119](https://www.trip.com/things-to-do/detail/57042119?locale=en-XX&curr=EUR) **Total 50 GB / 30 d** already bought. Same options as before for the remaining phone (or skip if only two travellers need data).

| | Option | ~30 d | Why |
|--|--|--|--|
| **A** | **Nomad** 20 / 50 GB | ≈ €22 / €31 | Dual Unicom/Telecom; multi-city |
| **B** | **Trip.com** 57042119 again (20 or 50 GB) | ≈ €9 / €22 | Match the two already bought |
| **C** | **Airalo** 20 / 50 GB | ≈ €35 / €43 | Brand premium |
| **D** | **Holafly** unlimited 30 d | ≈ €65 | Comfort only |
| **E** | No 3rd eSIM | €0 | Only two phones need China data |

Choice: _unpicked_

### Streaming (Netflix) on hotel Wi‑Fi?

GFW reachability ≠ Netflix allowlist. Hetzner ASN often blocked.

| | Option |
|--|--|
| **A** | Accept flaky Netflix on the VPS; smoke at home. |
| **B** | Phone streaming on travel eSIM (OneXray off); Mac still VPS or skip. |
| **C** | Offline-first downloads at home; live stream best-effort on VPS. |
| **D** | Second streaming-oriented VPN (reopens “no second brand”). |
| **E** | Extra DIY residential/media exit. |

Choice: _unpicked_

---

## Do

### 0. Review / hardening leftovers

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — `renew-ip` → `:_terraform:init`; `hostkeys:accept` retry; `ssh-revoke-me` multi-IP; `ssh-allow-me` robustness; manual aligned to this plan (hotel OneXray, shared UUID, no dual-CN-SIM default, no kill-switch claim, OneXray UI names; eSIM brand per Decide).

**Human must:** review diffs.

### 1. Phone data kit

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — none beyond doc accuracy.

**Human must:** **2× Trip.com Total 50 GB / 30 d bought** — install QR on the two phones at home (do not burn activation until CN if possible); smoke Western app + WeChat/Alipay + **Didi**, OneXray off once on China radio. Pick Decide for **3rd phone** if needed. Keep KPN for SMS. Mainland SIM only if Didi/signup SMS fails. Name the other two phone models when known.

### 2. OneXray fleet at home

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — keep routing JSON + manual aligned.

**Human must:** same `task vpn:config` link on 3 phones + Mac; Custom Routing + GeoData; Private Relay off; clock OK; smoke hotel-style (Wi‑Fi + OneXray → `api.ipify.org` = VPS). Rehearse Burned IP renew at home if time.

### 3. Streaming (after Streaming Decide)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — doc-only unless D/E.

**Human must:** per pick (VPS smoke / Nomad stream / offline downloads / …).

### 4. Trip ops (human)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — none.

**Human must:** Day-0 captive portal → OneXray on; repair via Nomad/KPN path + OneXray off; Hetzner/TFC/TransIP 2FA on laptop; post-trip destroy VPN + TFC `vpn`; no new VPN client download in China.
