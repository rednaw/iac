# Platform as Docker Compose

> **Status: Design.** Plan to move the set of system services (Traefik, registry, OpenObserve, Prefect, optionally fail2ban) to a Docker Compose–native stack and reduce Ansible to host bootstrap and config deployment.

## Goal

- **Platform = one (or a few) Compose files.** All platform containers and networks are defined there; lifecycle is `docker compose up -d` (or equivalent), not many Ansible `docker_container` / `docker_network` tasks.
- **Ansible shrinks** to: host bootstrap (Docker, user, SSH, etc.), deploying secrets and generated config into the paths the Compose stack uses, and optional one-offs (Prefect work pool, OpenObserve dashboards).
- **Fail2ban** can be either a host service (current) or a container in the same stack; if containerized, Ansible no longer installs the package or manages systemd for it.
- **Devcontainer** is the control plane: run the platform locally with the same Compose file, and run the remaining automation (Ansible or scripts) from there to deploy to the server.

## Current state

Today the server role uses Ansible to:

| Layer | What Ansible does |
|-------|--------------------|
| **Host** | Base packages, unattended-upgrades, SSH hardening, fail2ban (apt + systemd + config/filters), Docker install, iac user + `/opt/iac` tree. |
| **Containers** | Traefik, registry, OpenObserve, OTEL collector, Prefect (postgres, server, worker). For each: create networks, create/start containers, mount config dirs, set env, healthchecks, Traefik labels. |
| **Config** | Templates (Traefik static/dynamic, registry, OTEL, fail2ban) and files (logrotate, fail2ban filters, htpasswd, dashboard JSON). |
| **One-offs** | Prefect: sync flow code, build worker image, ensure work pool, `prefect deploy --all`. OpenObserve: dashboard import via API. |

So the platform is already “Docker native” in the sense that the services run in containers; the non–Docker-native part is **orchestration**—many Ansible tasks per container/network instead of a single Compose stack.

## Target state

### What moves to Compose

- **Traefik** — Same image, same mounts and ports; defined in the platform Compose file instead of Ansible `docker_container` tasks.
- **Registry** — Same image, volumes, and Traefik labels; defined in Compose.
- **OpenObserve + OTEL collector** — Both services in the same Compose file; networks and env in Compose.
- **Prefect** — Postgres, server, and worker as Compose services; volumes and env in Compose.
- **Fail2ban (optional)** — Either stay on host (Ansible keeps apt/systemd) or run as a container in the stack with bind mounts for `/var/log` and config; then Ansible only deploys config/filter files.

Config files (Traefik YAML, registry config, OTEL config, fail2ban jail/filters) remain **generated and deployed** by Ansible (or a script) into a known directory that the Compose stack mounts—because they depend on secrets and inventory (domains, credentials). So: **topology and lifecycle in Compose; config content still from automation.**

### What stays in Ansible (or equivalent)

| Responsibility | Why it stays |
|----------------|--------------|
| **Docker + Compose install** | Host must have Docker to run the stack. |
| **Base, SSH, unattended-upgrades** | Host hardening; not replaced by Compose. |
| **iac user, `/opt/iac` tree** | Required for app deploys and Prefect paths. |
| **Secrets and config deployment** | Templates (SOPS-decrypted vars, domains) written to paths used by Compose. Could be Ansible or a small script (e.g. envsubst + sops). |
| **Prefect one-offs** | Sync flow code, build worker image, work pool, `prefect deploy --all`—either stay in Ansible or move to a script/Compose hook. |
| **OpenObserve dashboards** | API-based dashboard create/update—small; can stay in Ansible or a one-off script. |

So **realistically a non-trivial amount of automation remains**—but it is focused on bootstrap and config, not on container lifecycle. The “lot of Ansible” becomes “a smaller Ansible playbook (or Ansible + scripts)” run from the devcontainer.

## What becomes possible

- **Run the platform anywhere** — Same Compose stack on laptop, dev VM, CI, or a new server; Ansible only bootstraps the host and drops the project.
- **Local / dev parity** — Run Traefik, registry, OpenObserve, Prefect (and optionally fail2ban) locally from the devcontainer; integration tests and debugging without a live server.
- **Upgrade and rollback like an app** — Change image tags or env in the Compose file and redeploy; rollback = revert file and `docker compose up -d`.
- **Single declarative stack** — One place for dependencies, healthchecks, and restarts; `docker compose config`, `docker compose logs -f` for the whole platform.
- **Compose features** — Profiles for optional services (e.g. no OpenObserve in minimal dev); one dependency graph.
- **Simpler recovery** — Rebuild = bootstrap OS + Docker, copy Compose project and config, `docker compose up -d`.
- **Clear separation** — Ansible = host and secrets; Compose = service topology and runtime. Changes to “what containers run” don’t require changing Ansible task logic.
- **Platform as a first-class stack** — Version the platform in the repo; optionally drive updates from CI (build/push images, then `docker compose pull && up -d` on the server).

## Fail2ban

- **Current:** Ansible installs fail2ban, deploys jail and filter config, manages systemd. Fail2ban reads host logs (e.g. Traefik, auth) and manages host firewall.
- **If kept on host:** No change; Ansible continues to own package and systemd.
- **If moved to Compose:** Run fail2ban in a container (e.g. image that reads logs and applies bans via host network or mounted socket). Ansible then only deploys config/filter files into the path mounted by the container and ensures the Compose stack is up. Package and systemd handling disappear from Ansible.

## Devcontainer as control plane

- **Local platform** — In the devcontainer, run the same platform Compose stack (with dev config/secrets). No Ansible needed for “run the platform” locally.
- **Deploy to server** — From the devcontainer, either:
  - **Option A (minimal Ansible):** One playbook that (1) bootstraps the server if needed, (2) copies the Compose project and rendered config (or templates + vars), (3) runs `docker compose up -d` on the server.
  - **Option B (Ansible only for bootstrap):** Bootstrap (Docker, user, SSH, etc.) is a one-time Ansible run. Ongoing platform deploy: from devcontainer, rsync/scp the Compose project and config, SSH and run `docker compose up -d` (via Taskfile or script). No Ansible in the hot path.

So the devcontainer is the single place to run the platform locally and to run the remaining automation (Ansible or scripts) that deploys to the server.

## Implementation order

1. **Server layout** — Implement [server-layout.md](server-layout.md) first (single tree under `/opt/iac`, user `iac`). Platform Compose and paths should align with that layout.
2. **Define platform Compose** — Add `compose/platform/docker-compose.yml` (and optional overrides) with Traefik, registry, OpenObserve, OTEL, Prefect. Use the same images, ports, volumes, and env as today; only the definition moves from Ansible tasks to Compose.
3. **Config deployment** — Keep Ansible (or a script) that renders and copies config files into the directory used by the Compose project (e.g. `/opt/iac/platform/` or similar). Ensure SOPS and inventory vars feed into those templates.
4. **Ansible: remove container/network tasks** — Replace the server role’s `docker_container` and `docker_network` tasks for platform services with a single “copy project + config, run docker compose up -d” (or equivalent). Retain handlers/notify if config changes should trigger `docker compose up -d` or service restarts.
5. **Fail2ban** — Decide: keep on host (Ansible unchanged for fail2ban) or add fail2ban service to platform Compose and reduce Ansible to config deployment only.
6. **Prefect one-offs** — Keep flow sync, worker build, work pool, and deploy in Ansible or move to a script that runs from the devcontainer (or as a Compose hook / init step).
7. **Devcontainer** — Document and wire “run platform locally” (e.g. `docker compose -f compose/platform/docker-compose.yml up`) and “deploy platform to server” (Task or playbook that syncs and runs compose on the server).
8. **Docs and cleanup** — Update [workflows](workflows.md), [application-deployment](application-deployment.md), and server docs to describe platform-as-Compose; remove or archive obsolete Ansible task files.

## Summary

| Aspect | Before | After |
|--------|--------|-------|
| Platform topology | Many Ansible tasks (containers + networks) | One Compose file (or small set) |
| Platform lifecycle | Ansible playbook | `docker compose up -d` (from devcontainer or server) |
| Ansible server role | Large (traefik, registry, openobserve, prefect, fail2ban tasks) | Smaller (bootstrap + config deployment + optional one-offs) |
| Config (Traefik, registry, OTEL, fail2ban) | Ansible templates → host paths | Same; Ansible or script → paths used by Compose |
| Local platform | Not defined | Same Compose file in devcontainer |
| Deploy from | Ansible from devcontainer | Ansible or script from devcontainer (sync + compose) |

Realistically, **a fair amount of automation remains** (bootstrap + secrets/config + one-offs), but it no longer has to be “a lot of Ansible.” The platform becomes a single, versioned, run-anywhere stack; the devcontainer is where you run it locally and where you run whatever is left of Ansible or scripts for the server.
