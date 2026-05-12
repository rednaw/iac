[**<---**](README.md)

# Repo layout: composable server purposes

The repository is structured so **multiple server types** can share Terraform (**`modules/server`**), Ansible (**`roles/base`** + purpose roles), and Task internals. Use this when adding roots such as [VPN](vpn-travel-china.md) or [honeypot](honeypot.md).

---

## Terraform

- **`terraform/modules/server/`** — Hetzner VPS, baseline firewall (SSH from allowlisted IPs, ICMP).
- **`terraform/platform/`** — Calls the module, adds **80/TCP** and **443/TCP**, application DNS; remote state workspaces use the **`platform-*`** prefix.

A new server type adds another Terraform root next to **`platform/`** that reuses **`modules/server`** with different firewall/DNS inputs.

---

## Ansible

- **`roles/base/`** — OS baseline, Docker, SSH hardening, unattended upgrades, fail2ban (SSH-focused).
- **`roles/platform/`** — Traefik, registry, OpenObserve, Prefect, platform fail2ban rules, **`iac-user`**, and related glue.
- **`playbooks/server.yml`** applies **`[base, platform]`** for the main platform host.
- **`playbooks/bootstrap.yml`** — initial root bootstrap before **`ubuntu`** applies.

Shared includes such as [`ansible/tasks/secrets.yml`](../../ansible/tasks/secrets.yml) load **`secrets/infra.yml`** for any playbook.

New server types ship as **`roles/<purpose>/`** plus a playbook **`[base, <purpose>]`** (or **`[base, platform, …]`** when intentionally stacked).

### Why only two Ansible layers?

Platform services on one host share filesystem paths, Docker networks, and logging relationships (Traefik ↔ fail2ban, registry ↔ Traefik **`auth/`**, OpenObserve network). Splitting each microservice into its own role would add interface churn without benefit until hosts are physically separated. **`base` + purpose** matches “reuse hardening everywhere; swap the stack above it.”

---

## Tasks

### Platform operator commands

| Command |
|---------|
| `task platform:provision:plan -- dev` |
| `task platform:provision:apply -- dev` |
| `task platform:provision:destroy -- dev` |
| `task platform:provision:output -- dev` |
| `task platform:provision:reconfigure` |
| `task platform:configure:bootstrap -- dev` |
| `task platform:configure:apply -- dev` |

### Namespaces that stay platform-centric

| Namespace | Reason |
|-----------|--------|
| `app:*` | Platform deploys application stacks |
| `workflow:*` | Prefect runs on the platform |
| `tunnel:*` | Admin UI SSH tunnels |
| `registry:*` | Private registry |
| `backup:*` | Per-app Restic |
| `secrets:*` | SOPS / **`secrets/`** |
| `test:*` | Lint and validation |

### Internal tasks (shared machinery)

| Internal task | Role |
|---------------|------|
| `_terraform:init` | `terraform init` with org from **`secrets/infra.yml`**, parameterized **`TF_DIR`** |
| `_terraform:secrets` | Decrypt **`secrets/infra.yml`**, export **`TF_VAR_*`** |
| `_terraform:plan` / `apply` / `destroy` | Workspace selection + Terraform command |
| `_ansible:run` | Parameterized **`ansible-playbook`** |
| `_ansible:bootstrap` | Bootstrap playbook |

Purpose-specific Taskfiles wrap these with **`TF_DIR`**, workspace prefix, inventory, and hostname.

### Hostname mapping

`hostkeys:hostname -- dev|prod` resolves to **`dev.<base_domain>`** / **`prod.<base_domain>`** for the platform. Additional purposes can adopt **`{purpose}-{env}.<base_domain>`** once Terraform DNS supports them.

---

## Extension checklist

1. **Terraform** — New **`terraform/<purpose>/`** root composing **`modules/server`** (+ DNS/firewall specific to that purpose).
2. **Ansible** — New **`roles/<purpose>/`** and playbook chaining **`base`** + that role.
3. **Tasks** — Thin namespace forwarding into **`_terraform:*`** / **`_ansible:*`** with the right paths.

Keep **`roles/platform/tasks/main.yml`** a flat include list without hidden ordering assumptions; duplicate **`include_tasks`** where two components need the same helper.

---

## Discipline for future splits

- Parameterize extra firewall rules on **`modules/server`** inputs (`terraform/platform/` supplies HTTP/S; specialty roots inject their own).
- Document cross-role filesystem and Docker-network assumptions inside **`roles/platform/`** when they affect future multi-host moves.

Explicit non-goals unless needed later: private networks between unrelated servers, cross-host secret sync beyond Ansible facts, multi-host orchestration beyond SSH-per-host invocations.
