# Prefect project (IaC flows)

This directory is the Prefect project. Ansible syncs it to the server at `/opt/prefect/flows`, builds the worker image from `Dockerfile.worker`, and runs `prefect deploy --all` to register deployments.

- **Server:** Prefect server runs in a Docker container (API + UI).
- **Worker:** Runs in a Docker container (`prefect-worker`) with the Docker socket mounted, so flows can run `docker exec`, use crane for the registry, and access other containers. Work pool: **`host-pool`** (process type; flows run as subprocesses inside the worker container).

Requires: Docker. Flow code is synced to `/opt/prefect/flows`. Registry auth for the worker is in `/opt/prefect/.docker/config.json`.

## Layout

- **`flows/`** — One Python module per flow (or one module with multiple flows). Each flow is a `@flow` function. Entrypoints in `prefect.yaml` are `flows/<module>.py:<flow_name>`.
- **`flows/<flow>/etc/`** — Flow-specific scripts and config
- **`common/`** — Optional. Shared `@task` functions that flows import and call.
- **`prefect.yaml`** — Project name and `deployments` list. Deployments use `work_pool.name: host-pool`.

**Adding a new flow:** Add `flows/<name>.py` (or `flows/<name>/flow.py` + `flows/<name>/etc/`), add a deployment in `prefect.yaml` with `work_pool.name: host-pool`, then re-run Ansible.
