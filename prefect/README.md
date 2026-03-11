# Prefect project (IaC flows)

This directory is the Prefect project. Ansible syncs it to the server at `/opt/prefect/flows` and runs `prefect deploy --all` to register deployments.

- **Server:** Prefect server runs in a Docker container (API + UI).
- **Worker:** Runs on the **host** as a systemd service (`prefect-worker`), so flows can use Docker, `/opt/deploy`, and host paths. Work pool: **`host-pool`**. Future self-contained flows can use a separate container worker and pool.

Requires: deploy user (in docker group), Docker. Flow code is synced to `/opt/prefect/flows`; the host has a venv at `/opt/prefect/venv` with Prefect and PyYAML.

## Layout

- **`flows/`** — One Python module per flow (or one module with multiple flows). Each flow is a `@flow` function. Entrypoints in `prefect.yaml` are `flows/<module>.py:<flow_name>`.
- **`flows/<flow>/etc/`** — Flow-specific scripts and config
- **`common/`** — Optional. Shared `@task` functions that flows import and call.
- **`prefect.yaml`** — Project name and `deployments` list. Host-job deployments use `work_pool.name: host-pool`.

**Adding a new host flow:** Add `flows/<name>.py` (or `flows/<name>/flow.py` + `flows/<name>/etc/`), add a deployment in `prefect.yaml` with `work_pool.name: host-pool`, then re-run Ansible.
