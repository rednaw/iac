# Prefect project (IaC flows)

This directory is the Prefect project: it is synced to the server and bind-mounted into the worker. One Ansible sync deploys everything. Deployments are registered with `prefect deploy --all` (Ansible runs that after sync).

## Layout

- **`flows/`** — One Python module per flow (or one module with multiple flows). Each flow is a `@flow` function. Entrypoints in `prefect.yaml` are `flows/<module>.py:<flow_name>`.
- **`flows/<flow>/etc/`** — Flow-specific scripts and config
- **`common/`** — Optional. Shared `@task` functions that flows import and call. Use this when several flows share the same steps so flow modules stay thin.
- **`prefect.yaml`** — Project name and `deployments` list. Each deployment has an `entrypoint` (flow module and function), optional `schedule`, and `work_pool`.

**Adding a new flow:** Add `flows/<name>.py` with a `@flow` function (or `flows/<name>/flow.py` and put flow-specific scripts/config in `flows/<name>/etc/`), then add a deployment in `prefect.yaml` with the matching `entrypoint`. If the flow needs shared logic, add `@task` functions in `common/` and import them from the flow.

