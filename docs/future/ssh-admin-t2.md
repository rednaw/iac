[**<---**](../../README.md)

# Admin SSH on this Mac’s T2

Iac-wide: operator SSH identity is this Intel MacBook’s **T2 Secure Enclave**, not a copyable `id_ed25519`. **Not** the China trip — that may keep the file key until this ships. Trip spec: [vpn-travel-china.md](vpn-travel-china.md).

Implement after explicit go. Open [Decide](#decide) does not block that trip’s Do §0.

---

## Decided

| | |
|--|--|
| Scope | All server purposes (platform, later VPN/honeypot). Same Hetzner `ssh_keys` list. Not a China-only control. |
| Hardware | This admin MacBook: Intel, **Apple T2** (`system_profiler SPiBridgeDataType`). One admin machine; it may travel. iPhone is not SSH admin. |
| Identity | Non-exportable **P-256** in the T2. Chip cannot do Ed25519. Public key is normal `ecdsa-sha2-nistp256` (Hetzner upload + `authorized_keys`). File Ed25519 **retired after** enroll. New Mac = new key, update Hetzner + Ansible. |
| Container | iac Dev Container is Linux. Signing stays on the **host**. Forward host `SSH_AUTH_SOCK` (Secretive or equivalent). Bind-mount of `~/.ssh` files is not enough. |
| Not this | Firewall IP allowlists (home / `ssh-allow-me`). SOPS age key, `hcloud_token`, TFC, TransIP — still files on disk. No MDM, Tailscale, or YubiKey. |
| vs China | Uncoupled. [vpn-travel-china.md](vpn-travel-china.md) does not wait. If this ships **before** the trip, that plan’s home smoke + Burned IP must use the agent (Touch ID in the container path). |

---

## Decide

### Agent on the Mac?

| | Option |
|--|--------|
| **A** | [Secretive](https://github.com/maxgoedjen/secretive) — SE keys, host agent, pubkey Hetzner can store. |
| **B** | Native `sc_auth` + `SSH_SK_PROVIDER=/usr/lib/ssh-keychain.dylib` (no extra app; `sk-` handles; Hetzner UI may reject the pubkey line). |

Choice: _unpicked_

### Touch ID on every SSH sign?

| | Option |
|--|--------|
| **A** | Require biometric (`-t bio` / Secretive equivalent). Hotel Burned IP needs a finger. |
| **B** | Enclave-bound, no per-sign Touch ID. Stolen unlocked session can SSH without a finger. |

Choice: _unpicked_

---

## Do

### 0. Host agent + container

after Agent on the Mac — install A or B. Forward `SSH_AUTH_SOCK` into `.devcontainer/` (not only `~/.ssh`). Prove `ssh ubuntu@prod.${BASE_DOMAIN}` **from the container** with no file private key.

### 1. Enroll on platform

after Touch ID pick — upload pubkey to Hetzner; add the key ID to `secrets/infra.yml` `ssh_keys`; `authorized-keys.yml` already pulls those IDs. `platform:configure:apply` on **prod** (and dev). Then remove the file Ed25519 from Hetzner and from the boxes.

### 2. Later purposes

Reuse the same `ssh_keys` IDs. No per-purpose SSH identity.
