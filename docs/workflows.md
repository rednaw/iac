[**<---**](README.md)

# Workflows

Scheduled tasks and multi-step workflows run on [Prefect](https://www.prefect.io/). Server and worker run in Docker on the server; the worker has the Docker socket so flows can run `docker exec`, use crane, and access containers. Flow code lives under [`prefect/`](../prefect/) (one dir per flow).

```mermaid
flowchart LR
    subgraph REPO["IaC Repo"]
        FLOWS(prefect/<br/>registry_prune/, …)
    end
    subgraph SERVER["Server"]
        subgraph PREFECT["Prefect"]
            PSERVER(Prefect server<br/>UI + API + Postgres)
            PWORKER(Prefect worker<br/>Docker socket, host-pool)
        end
        DOCKER(Docker daemon<br/>registry, app containers)
    end
    FLOWS --> PWORKER
    PWORKER --> DOCKER
    PSERVER -->|schedules + state| PWORKER
```

**Use for:** Scheduled tasks (backups, cleanup, reports), multi-step jobs (ETL, batch), server ops (registry prune, maintenance). **Not for:** Real-time or webhook handling — use your app.

## Open the UI

```bash
task tunnel:start -- dev
```

Then open **http://localhost:57802/**. UI is internal-only (SSH tunnel, like OpenObserve/Traefik). "Upgrade" / "Prefect Cloud" prompts are upstream; hide with uBlock Origin if needed.

## Run a flow

Deployments → pick deployment → **Run**. Flow Runs tab for logs and state.

## Add a new flow

1. **Write the flow** — Add `prefect/<flow_name>/flow.py` (e.g. [`prefect/registry_prune/flow.py`](../prefect/registry_prune/flow.py) as reference). Use `@flow` and your steps.
2. **Define the deployment** — In [`prefect/prefect.yaml`](../prefect/prefect.yaml) add an entry under `deployments:` with `entrypoint`, `name`, `work_pool: name: host-pool`, and `schedules:` (cron, interval, or [RRule](https://docs.prefect.io/latest/concepts/schedules/)).
3. **Deploy** — `task ansible:run -- dev`. Ansible syncs `prefect/` to `/opt/iac/prefect/flows`, builds the worker image, runs `prefect deploy --all`.
4. **Verify** — Prefect UI → Deployments; your deployment and next run time should appear.

## Flows

| Flow | File | Schedule |
|------|------|----------|
| Registry prune | [`prefect/registry_prune/flow.py`](../prefect/registry_prune/flow.py) | Daily 02:00 UTC |

**Registry prune:** Keeps 6 newest image tags per repo, deletes the rest, protects current deploy (from `deploy-info.yml`), then `registry garbage-collect`. `REGISTRY_URL` set on worker by Ansible.

## Worker access

Worker container `prefect-worker` has: flow code at `/opt/iac/prefect/flows/` (synced by Ansible), Docker socket, `DOCKER_CONFIG=/opt/iac/.docker` (registry auth). See [Server layout](server-layout.md). No Prefect secret blocks needed for registry.

## Logs

| Where | How |
|-------|-----|
| Flow run logs | Prefect UI → Flow Runs → run → Logs |
| Server logs | OpenObserve **docker-containers** stream, filter `prefect-server`. See [Monitoring](monitoring.md). |
| Worker logs | `docker logs prefect-worker` |

Server runs with `--analytics-off`; no telemetry to Prefect Cloud.

See [Troubleshooting](troubleshooting.md) for Prefect and workflow issues.

See [Monitoring](monitoring.md), [Remote-SSH](remote-ssh.md), [Registry](registry.md), [Application deployment](application-deployment.md).
