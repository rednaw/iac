# Registry prune – plan

> **Status: Plan.** Describes the intended design before implementation. See [Backlog](Backlog.md) for tracking.

## Goal

- Prune old image tags from the registry (keep N newest per repo by **creation time**).
- Reclaim disk with registry **garbage-collect** after deletes.
- One script, run on the server by a **Prefect flow** (scheduled).

## Prune logic (crane only)

- **List tags:** `crane ls <registry>/<repo>`
- **Creation time:** `crane config <ref>` → read OCI label `org.opencontainers.image.created` (same as `_build-and-push.yml` and `app:versions`).
- **Sort:** Newest first; keep N; delete the rest with `crane delete <image>@<digest>`.
- **Auth:** None in script. Crane uses Docker config (`~/.docker/config.json` / `/opt/deploy/.docker/config.json`), so it works in devcontainer and for deploy user out of the box.

## Config

- Repo list + keep count (e.g. `rednaw/tientje-ketama: 6`) in config (Ansible-managed or script config file).
- Registry URL from env or same source as app (e.g. `registry.<base_domain>`).

## Entry points

| Where              | How                         | Auth / GC |
|--------------------|-----------------------------|-----------|
| **Server (Prefect)** | Prefect flow on schedule   | Crane uses `/opt/deploy/.docker/config.json`. GC: run locally on server after prune. |

## GC step (server-side)

- **Garbage-collect** must run on the server: `docker exec registry registry garbage-collect` (no remote API).
- **From cron (deploy):** Script runs on server → after prune, same script (or same cron) runs `docker exec registry registry garbage-collect` (deploy needs Docker access, or use sudo/wrapper).
- **From devcontainer (remote):** Two options:
  1. **SSH:** `ssh ubuntu@<hostname> "docker exec registry registry garbage-collect"` (same SSH as `app:versions`).
  2. **Remote Docker:** Use a Docker context with `host=ssh://ubuntu@<hostname>`; then `docker exec registry registry garbage-collect` runs on the remote daemon. Same SSH, nicer interface.

## Remote Docker context (to explore)

- **Idea:** `docker context create remote-dev --docker "host=ssh://ubuntu@dev.<base_domain>"` (and similar for prod).
- **Use case 1:** GC from devcontainer: switch context (or set `DOCKER_HOST`), run `docker exec registry registry garbage-collect`.
- **Use case 2:** Other ops: run any `docker` command against the server without hand-written `ssh ... "docker ..."` strings.
- **Next:** Explore how to create/use contexts from the devcontainer (env, Taskfile, docs) and whether we want to adopt this for GC and beyond.

### Improving existing functionality with remote context

| Current | With remote context |
|--------|----------------------|
| **Traefik ops** ([traefik.md](traefik.md)): `ssh ubuntu@dev.<base_domain> 'sudo docker restart traefik'`, `ssh ... 'sudo docker logs traefik'`, etc. | After `docker context use remote-dev`: `docker restart traefik`, `docker logs traefik`, `docker ps`, `docker network inspect traefik`. No SSH string, no sudo (ubuntu is in docker group per [docker.yml](../ansible/roles/server/tasks/docker.yml)). |
| **Registry GC** (this plan): `ssh ubuntu@host "docker exec registry registry garbage-collect"` | `docker exec registry registry garbage-collect` with context set. |
| **Ad-hoc server Docker**: Inspect app container, logs, exec — today: SSH then run docker on server or type full `ssh host 'docker ...'` | Same context: from devcontainer run `docker ps`, `docker logs <app-container>`, `docker exec -it <container> sh`, etc. |
| **application_versions.py** | No change: it only reads files via SSH (`cat deploy-history.yml`), not Docker. |
| **Tunnels** (Taskfile.tunnel.yml) | No change: port forwarding is a different use case. |

## Implementation outline

1. **Script:** e.g. `prefect/scripts/prune_registry.py` (or `.sh`): read config (repos + keep N), for each repo list tags with crane, get created from `crane config`, sort, delete old ones; run GC on server after prune (same script or flow step).
2. **Prefect flow:** Scheduled flow runs the script on the server; worker has Docker and deploy paths mounted.
3. **Ansible:** Deploy flow code (and scripts) via Prefect role; no cron.
4. **Docs:** Update [Registry](registry.md) and this plan when done.

## References

- OCI labels set in [`.github/workflows/_build-and-push.yml`](../.github/workflows/_build-and-push.yml) (`org.opencontainers.image.created`, `org.opencontainers.image.description`).
- Reading those in [`scripts/application_versions.py`](../scripts/application_versions.py) via `crane config` and `_sort_key_timestamp`.
- Registry config: [Registry](registry.md), [Ansible registry role](../ansible/roles/server/tasks/registry.yml).
