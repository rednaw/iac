[**<---**](../README.md)

# Roadmap

The repo currently supports one server type ("the platform") and one app at a time. These plans add support for multiple server types, multiple apps, and platform enhancements.

```mermaid
flowchart LR
    restructure["Phase 1<br/>Restructuring"]
    dx["Phase 2<br/>Secrets & mounts"]

    subgraph servers ["New server types"]
        vpn["VPN server"]
        honeypot["Honeypot server"]
        future["..."]
    end

    subgraph enhancements ["Platform enhancements"]
        grafana["Grafana dashboards"]
    end

    restructure --> servers
    restructure --> dx
    dx --> servers
    restructure -.->|not strictly blocked| enhancements
```

---

## Phase 1 — Restructuring

Decomposes the repo so different server types compose from shared building blocks. Three sequential steps, each independently deployable and verifiable:

| Step | What | Verifiable by | Status |
|------|------|---------------|--------|
| **1a. Task layer** | Extract `_terraform:*`, `_ansible:*` internal tasks. Rename `terraform:*`+`ansible:*` to `platform:*`. | All existing `task` commands still work under new names. | Done |
| **1b. Ansible** | Split `roles/server/` into `roles/base/` + `roles/platform/`. | `task platform:configure:apply -- dev` produces identical server state. | Done |
| **1c. Terraform** | Extract `modules/server/`, move root to `terraform/platform/`. | `terraform plan` shows zero changes. | Done |

Design: **[Repo restructuring](restructuring.md)**

---

## Phase 2 — Secrets and mounts

Moves from "clone and use" to "fork and use." Infra secrets (`secrets/infra.yml`) live in the fork, committed and SOPS-encrypted. App config (per-app `iac.yml` — just image name and domains) stays in each app repo. Single directory mount replaces the per-app mount.

| Before | After |
|--------|-------|
| Clone the repo, secrets in app mount | Fork the repo, infra secrets committed in fork |
| One `iac.yml` with everything | `secrets/infra.yml` (infra) + per-app `iac.yml` (app config) |
| `APP_HOST_PATH` → one app | `APPS_HOST_PATH` → all apps |
| `task app:deploy -- dev abc123` | `task app:deploy -- dev app1 abc123` |
| Rebuild devcontainer to switch apps | All apps always available |

Design: **[Secrets and mounts](secrets-and-mounts.md)**

---

## Phase 3 — New server types

Each server type follows the same pattern: Terraform root composing `modules/server`, an Ansible role composing `roles/base`, and a Task namespace calling the shared internal tasks. Independent of each other — build in any order.

### VPN server

Dedicated Hetzner VPS for personal VPN (Xray/VLESS+REALITY, WireGuard). Built for a China trip, destroyable after.

- **Cost:** ~€4.50/month (CX23, Germany) or ~€7/month (CX23 equivalent, Singapore)
- **Blocked by:** Phase 1 + Phase 2

Design: **[VPN for China travel](vpn-travel-china.md)**

### Honeypot server

Low-interaction honeypot (T-Pot) to observe attacker behavior. Completely isolated from the platform, strict egress filtering.

- **Cost:** ~€18/month (CX43 + block storage, Germany)
- **Blocked by:** Phase 1 + Phase 2

Design: **[Honeypot server](honeypot.md)**

---

## Platform enhancements

Not blocked by restructuring, lower priority.

### Grafana as dashboard layer

Add Grafana on top of OpenObserve for community dashboards (WireGuard, Xray, system metrics). Parked — revisit when dashboard needs outgrow OpenObserve.

Design: **[Grafana exploration](grafana-exploration.md)**
