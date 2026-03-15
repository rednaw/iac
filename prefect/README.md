# Prefect project (IaC flows)

This directory is the Prefect project. Ansible syncs it to the server at `/opt/iac/prefect/flows`, builds the worker image from `Dockerfile.worker`, and runs `prefect deploy --all` to register deployments.

- **Server:** Prefect server runs in a Docker container (API + UI).
- **Worker:** Runs in a Docker container (`prefect-worker`) with the Docker socket mounted and `/opt/iac` mounted (flow code at `/opt/iac/prefect/flows`), so flows can run `docker exec`, use crane for the registry, and access other containers. Work pool: **`host-pool`** (process type; flows run as subprocesses inside the worker container). Registry auth: `DOCKER_CONFIG=/opt/iac/.docker` (shared with iac user). See [Server layout](../docs/server-layout.md).

Requires: Docker. Flow code is synced to `/opt/iac/prefect/flows`. Registry auth is at `/opt/iac/.docker` (shared).

## Layout

- **`<flow>/`** — One directory per flow (e.g. `registry_prune/`), each with `flow.py` containing a `@flow` function. Entrypoints in `prefect.yaml` are `<flow>/flow.py:<flow_name>`.
- **`prefect.yaml`** — Project name and `deployments` list. Deployments use `work_pool.name: host-pool`.

**Adding a new flow:** Add `<name>/flow.py`, add a deployment in `prefect.yaml` with `work_pool.name: host-pool`, then re-run Ansible.
