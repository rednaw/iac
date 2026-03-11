# Registry prune (Prefect)

> **Status: Implemented.** Registry pruning is triggered by a scheduled Prefect flow. See [Backlog](Backlog.md) for tracking.

## Goal

- Prune old image tags from the registry (keep N newest per repo by **creation time**).
- Reclaim disk by running registry **garbage-collect** on the server after deletes.
- Trigger: a **Prefect flow** on a schedule; the flow runs on the **host** (Prefect worker is a systemd service), so the script has Docker and deploy paths.

## Prune logic (crane)

- **List tags:** `crane ls <registry>/<repo>`
- **Creation time:** `crane config <ref>` → read OCI label `org.opencontainers.image.created` (same as `_build-and-push.yml` and `app:versions`).
- **Sort:** Newest first; keep N; delete the rest with `crane delete <image>@<digest>`.
- **Auth:** Crane uses Docker config (`~/.docker/config.json` / `/opt/deploy/.docker/config.json`), so it works for the deploy user on the server.

## Protect deployed tag

If a tag that is currently deployed is pruned, the running app is unaffected but **re-deploy or rollback to that tag will fail** (pull fails). The prune script **must never delete the tag or digest that is currently deployed** for any app.

Deployment state is written by the app deploy role to the server:

- **`/opt/deploy/<app>/deploy-info.yml`** — Overwritten on each deploy. Contains the **current** image: `image.repo`, `image.tag`, `image.digest`, plus `app`, `workspace`, `deployment.deployed_at`. See [Application deployment – Deployment Records](application-deployment.md#deployment-records-if-you-joined).
- **`/opt/deploy/<app>/deploy-history.yml`** — Append-only list; each entry has `image.tag`, `image.digest`, `deployment.workspace`. The last entry for a workspace is the currently deployed version (used by `scripts/application_versions.py`).

The Prefect worker runs on the host, so the script reads `/opt/deploy` and uses the host’s Docker directly. For each repo, the script derives the app slug (e.g. repo `rednaw/tientje-ketama` → app `tientje-ketama`) and checks for **`/opt/deploy/<app_slug>/deploy-info.yml`**. If the file exists: the script **must** read it and **must not** delete the tag or digest listed there (that tag/digest is always protected, in addition to "keep N newest"). If the file does not exist (no deploy record for that repo): no protection is applied; the script keeps N newest by creation time only.

## Config

- Repo list + keep count (e.g. `rednaw/tientje-ketama: 6`) in config (Ansible-managed or script config file).
- Registry URL from env or same source as app (e.g. `registry.<base_domain>`).

## GC after prune

- **Garbage-collect** must run on the server (no remote API): `docker exec registry registry garbage-collect`.
- The Prefect flow (or the script it runs) executes this on the server after pruning tags, so the registry process reclaims disk.

## Implementation

1. **Flow:** `flows/registry_prune/flow.py` — Prefect flow that runs the script. Deployment in `prefect.yaml` (daily 02:00 UTC).
2. **Script:** `flows/registry_prune/etc/registry_prune.py` — reads `registry_prune_config.yml` in same dir (repos + keep N); for each repo, derives app slug and, if `/opt/deploy/<app_slug>/deploy-info.yml` exists, reads it and marks that tag/digest as protected; lists tags via `crane` (run in Docker with host network), gets creation time from `crane config`, sorts, keeps protected + N newest, deletes the rest with `crane delete`; then runs `docker exec registry registry garbage-collect /etc/distribution/config.yml` on the server. Registry auth from `/opt/deploy/.docker`; `REGISTRY_URL` from env (set by Ansible on the worker).
3. **Ansible:** Prefect role syncs flow code, runs the worker on the host (systemd), and sets `REGISTRY_URL=registry.<base_domain>` for the worker; no cron.
4. **Config:** `prefect/flows/registry_prune/etc/registry_prune_config.yml` — `repos` list with `name` and `keep`; extend for more repos.

## References

- Deployment records (deploy-info.yml, deploy-history.yml): [Application deployment – Deployment Records](application-deployment.md#deployment-records-if-you-joined). Written by [record-deployment.yml](../ansible/roles/deploy_app/tasks/record-deployment.yml); read by [application_versions.py](../scripts/application_versions.py).
- OCI labels set in [`.github/workflows/_build-and-push.yml`](../.github/workflows/_build-and-push.yml) (`org.opencontainers.image.created`, `org.opencontainers.image.description`).
- Reading those in [`scripts/application_versions.py`](../scripts/application_versions.py) via `crane config` and `_sort_key_timestamp`.
- Registry config: [Registry](registry.md), [Ansible registry role](../ansible/roles/server/tasks/registry.yml).
