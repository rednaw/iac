[**<---**](README.md)

# Backup with Hetzner Storage Box

> **Status: Design document.** 

Service-aware backups to [Hetzner Storage Box](https://www.hetzner.com/storage/storage-box): Postgres dumps and volume data. Once this is in place and working, **Hetzner Cloud image backups will be removed** (no more server snapshots/images for backup).

## Backup engine: Restic

**[Restic](https://restic.net/)** is the backup tool of choice. It supports Storage Box via **SFTP** (port 23 via `~/.ssh/config` or URL). One Restic repo per app on the box; deduplication and compression keep storage and transfer small. Encryption is built-in (AES-256); the **repo password** is stored in SOPS and deployed to the server (e.g. `RESTIC_PASSWORD_FILE`), so no SOPS runtime on the server. Restore from the devcontainer: decrypt SOPS to get the password, then `restic restore`.

**Retention** is **count-based** and explicitly set per app in `.iac/backup.yml` (e.g. keep-daily 7, keep-weekly 4, keep-monthly 12). `restic forget` keeps the last N snapshots per interval; then `restic prune` reclaims space. This fits intermittent or low-frequency runs (e.g. daily Prefect schedule) better than time-based "keep for N hours."

**RPO and app impact:** Running backups often improves RPO (fresher restore points), but the schedule must have **no meaningful impact on app performance**. pg_dump, Restic reads, and uploads compete for CPU, I/O, and network on a single server; if the app slows or stalls during backup, run less often or off-peak. Choose a schedule that keeps the app healthy first; achievable RPO is what you get within that constraint.

## Why Storage Box

- **Cost:** BX11 (1 TB) ≈ €3.81/month — cheaper than Object Storage's €4.99 minimum and than the 20% server fee for 7 image backups.
- **Service-aware:** Back up database dumps and uploads only; restore without rebuilding the whole server.
- **Access:** SSH (port 23), rsync, SFTP, BorgBackup; fits scripting and cron.
- **Location:** Same provider as the server; optional snapshots on the box (10–40 depending on tier).

## How Storage Box access works

- **Endpoint:** `uXXXXX@uXXXXX.your-storagebox.de` (username = Storage Box ID from Hetzner Console).
- **SSH port:** **23** (not 22). Use `ssh -p23` and `rsync -e 'ssh -p23'`.
- **Writable path:** Only `/home/`. Use **relative** paths; each app's Restic repo lives at e.g. `tientje-ketama/` (one repo per app).
- **Auth:** SSH key (OpenSSH one-line format) or password. Key is preferred; add via [Hetzner Console → Storage Box → SSH keys](https://docs.hetzner.com/storage/storage-box/backup-space-ssh-keys) or `ssh-copy-id -p 23 -s uXXXXX@uXXXXX.your-storagebox.de`.

Example:

```bash
rsync -e 'ssh -p23' -avz --progress ./local/ uXXXXX@uXXXXX.your-storagebox.de:tientje-ketama/
```

## Application backup design (decided)

- **Part of the app–platform contract:** **`.iac/backup.yml`** is an optional contract file in the app repo. If present, it is deployed with the app and the platform runs service-aware backup for that app. The file defines retention (restic forget keep-* values) and what to back up (postgres list, volumes list). See [Application deployment](application-deployment.md#app-mount) for the full `.iac/` contract.
- **On server:** We deploy it as `backup.yml` next to the compose files (not inside `.iac/`), so the backup flow reads `/opt/iac/deploy/<app_slug>/backup.yml`.
- **One Restic repo per app:** Each app has a Restic repository on Storage Box (e.g. `sftp:uXXXXX@uXXXXX.your-storagebox.de:<app_slug>`). The flow creates one snapshot per run: it builds a backup source (postgres dump + volume contents in a temp dir), runs `restic backup`, then `restic forget` and `restic prune` for retention. Restic handles encryption, dedup, and compression.
- **Data in volumes only:** Apps must use Docker volumes for data that is backed up (no bind mounts for that data). The backup flow captures from volumes (e.g. via `docker compose exec` for Postgres and a service that mounts the volume for tar or direct read).
- **Runs server-side via Prefect:** Backup is a Prefect flow that runs on the worker (server, Docker socket). Schedule or manual run triggers the flow; it reads deploy dirs and each app's backup spec, builds the backup source, runs Restic, then forget/prune. No cron on the server.
- **Deprecate image backups:** When Storage Box backup is done and verified, we will remove the Hetzner Cloud image/snapshot backups (stop creating and retaining them).
- **Backup file only:** `.iac/backup.yml` contains only backup config (retention + sources); we deploy it as-is so the flow can read it without exposing app secrets from `iac.yml`.

## What to back up (example: tientje-ketama)

| Data            | Location on server                          | How to capture                    |
|-----------------|---------------------------------------------|-----------------------------------|
| Postgres        | In Docker volume (e.g. `tientje-ketama_postgres_data`) | `docker compose exec db pg_dump`  |
| Uploads         | In a Docker volume (app must use volume, not bind mount) | `tar` from a container that mounts the volume |

- **Deploy path:** Apps live under `/opt/iac/deploy/<app_slug>/`. `.env` and `backup.yml` (when present) are deployed there next to the compose files. Compose must use **volumes** for any data to be backed up. See [Server layout](server-layout.md).
- **Dump(s):** For each entry in `postgres` in backup.yml, run `pg_dump` inside that service’s container; DB name/user from `.env` via the entry’s env keys.

## Where the backup runs

**Prefect flow on the server (worker).**

- The flow runs on the existing Prefect worker (Docker socket, server). It iterates over apps, reads each app's backup spec, builds the backup source (postgres dump + volume tarballs in a temp dir), runs `restic backup` to the app's repo on Storage Box, then `restic forget` and `restic prune`. No cron; schedule is a Prefect schedule (e.g. daily). See [Server layout](server-layout.md).
- **On the server:** Storage Box SSH key and Restic repo password file live under the Prefect subtree (e.g. `/opt/iac/prefect/.ssh/`, `/opt/iac/prefect/.restic-password`), deployed by Ansible from SOPS. The flow sets `RESTIC_REPOSITORY` and `RESTIC_PASSWORD_FILE` (or equivalent) so Restic can connect to the box and decrypt the repo.

## Backup layout on Storage Box

One **Restic repository** per app, under `/home/` on the box (e.g. `tientje-ketama/`). Each repo has the usual Restic layout: `config`, `data/`, `index/`, `keys/`, `locks/`, `snapshots/`. Restic handles encryption, dedup, and compression; the box only ever sees ciphertext. Retention is managed by `restic forget` using the `retention` section of each app’s `backup.yml` on the server, then `restic prune` to reclaim space.

## Secrets and Ansible

- **Storage Box SSH key:** Generate a key pair for the box only (e.g. `storagebox_id_ed25519`). Put the **private** key in SOPS. Ansible deploys it to the server under the Prefect subtree (e.g. `/opt/iac/prefect/.ssh/storagebox_id_ed25519`, mode `0600`). Add the **public** key to the Storage Box in Hetzner Console. See [Server layout](server-layout.md).
- **Storage Box host key:** Add the box to `known_hosts` on the server (Ansible one-time task or script) so the backup flow doesn't hang on first connect.
- **Restic repo password:** Store the Restic repository password in SOPS (e.g. in app secrets or a dedicated backup secret). Ansible deploys it to the server as a file (e.g. `/opt/iac/prefect/.restic-password`, mode `0600`). The backup flow uses `RESTIC_PASSWORD_FILE`; for restore from the devcontainer, decrypt SOPS to get the password (or use a Task that writes it to a temp file).

## Backup flow (high level)

Prefect flow runs on the worker (server). For each app that has `backup.yml` in its deploy dir:

1. Read `/opt/iac/deploy/<app_slug>/backup.yml` → retention + postgres list + volumes list.
2. Create temp dir for backup source.
3. **Postgres:** For each item in `postgres`, run `docker compose exec -T <service> pg_dump -U <user> -Fc <db> > .../postgres_<service>.dump` (user/db from .env using the item’s env keys). Optionally gzip to save space before Restic.
4. **Volume dirs:** For each item in `volumes`, produce a tarball (e.g. run a container that mounts the volume and tars the path). Add to temp dir (e.g. `uploads.tar.gz`).
5. **Restic backup:** Set `RESTIC_REPOSITORY=sftp:.../<app_slug>`, `RESTIC_PASSWORD_FILE=...`. Run `restic backup <temp_dir>` (tags optional).
6. **Retention:** From backup.yml `retention`, run `restic forget --keep-daily <keep_daily> --keep-weekly <keep_weekly> --keep-monthly <keep_monthly>`, then `restic prune`.
7. Remove temp dir.

Log success/failure per app; Prefect run logs are the audit trail.

## Restore (from devcontainer)

1. **Connect to repo:** Ensure Storage Box SSH key and host are in `~/.ssh/` (or use `-o sftp.args="-i /path/to/key"`). Get Restic repo password from SOPS (decrypt `iac.yml` or backup secret), set `RESTIC_PASSWORD` or `RESTIC_PASSWORD_FILE`.
2. **List snapshots:** `restic -r sftp:uXXXXX@uXXXXX.your-storagebox.de:<app_slug> snapshots`. Note the snapshot ID (or use `latest`).
3. **Restore:** `restic restore <snapshot_id> --target ./restore` (or `latest`). This restores the backup-source layout (e.g. `postgres_db.dump`, `postgres_analytics_db.dump`, `uploads.tar.gz`).
4. **Restore DB(s):** For each dump file (e.g. `restore/postgres_db.dump`), copy to server and run `docker compose exec -T <service> pg_restore -U <user> -d <db> --clean --if-exists < postgres_db.dump`. Prefer doing this with app stopped or in maintenance mode.
5. **Restore uploads:** Copy `restore/uploads.tar.gz` (or similar) to server, decompress and extract into the volume target path.

A Taskfile task or `scripts/restore-from-storagebox.sh` can wrap these steps and take app name + snapshot as arguments when you implement.

## Retention

- **Configured in each app’s backup config** (in repo: `.iac/backup.yml`; on server: `backup.yml`) under `retention:`: `keep_daily`, `keep_weekly`, `keep_monthly` (e.g. 7, 4, 12). The backup flow runs `restic forget` with those values, then `restic prune`. One snapshot can satisfy multiple rules (e.g. daily and weekly).
- **Storage Box snapshots:** You can enable snapshots on the box (10–40 depending on tier) as an extra safety net; they are separate from Restic retention.

## Relation to existing backups

- **Hetzner Cloud image backups** (`backups = true` in Terraform, `task backup:list`, `task backup:restore`) remain useful for "restore the whole server to a point in time." They are not service-aware and cost 20% of the server.
- **Storage Box backup** is complementary: smaller, service-aware, and restorable without replacing the disk. You can keep both (e.g. weekly image backup + daily Storage Box), or reduce/disable image backups if you fully rely on Storage Box.

## Shape of `.iac/backup.yml` (decided)

Part of the [app–platform contract](application-deployment.md#app-mount): one file per app in the app repo at `.iac/backup.yml`. When present, deploy copies it to the server as `backup.yml` (next to the compose files); the backup flow reads it there. It contains **retention** (restic forget keep-* values) and **what to back up** (postgres list, volumes list). Explicit over convention; verbosity is fine. **postgres** and **volumes** are both lists.

Example (one postgres, one volume):

```yaml
# Restic forget retention (explicit defaults)
retention:
  keep_daily: 7
  keep_weekly: 4
  keep_monthly: 12

postgres:
  - service: db
    user_env: POSTGRES_USER
    db_env: POSTGRES_DB

volumes:
  - service: app
    path: /app/uploads
```

Two databases, one volume:

```yaml
retention:
  keep_daily: 7
  keep_weekly: 4
  keep_monthly: 12

postgres:
  - service: db
    user_env: POSTGRES_USER
    db_env: POSTGRES_DB
  - service: analytics_db
    user_env: ANALYTICS_POSTGRES_USER
    db_env: ANALYTICS_POSTGRES_DB

volumes:
  - service: app
    path: /app/uploads
```

- **retention:** Required. `keep_daily`, `keep_weekly`, `keep_monthly` (integers). Used for `restic forget` then `restic prune`.
- **postgres:** Optional. List of dumps. For each item the flow runs `pg_dump` from that service; user and DB name are read from the deploy dir `.env` using the given env keys. Filenames in the backup source can include service (e.g. `postgres_db.dump`). No defaulted names; app must specify.
- **volumes:** List of `service` + `path`. For each item the flow runs a container (e.g. `docker compose run --rm <service> tar cf - -C <path> .`) to produce a tarball. Order is preserved in the archive.
- **Extensible:** Other service types (e.g. `opensearch`) can be added later as additional list keys in this file. Same pattern: one key per type, value is a list of items; the flow implements capture and filename for each type. Omit any key if the app has none of that type; empty list = none.

## Implementation outline (when you add code)

- **Deploy backup config to server:** Done. [`ansible/roles/deploy_app/tasks/prepare-server.yml`](../ansible/roles/deploy_app/tasks/prepare-server.yml) copies the app’s `.iac/backup.yml` to `{{ deploy_target }}/backup.yml` when present.
- **Volume capture:** Implemented in [`prefect/backup/capture_volumes.py`](../prefect/backup/capture_volumes.py). Reads `backup.yml` from a deploy dir and, for each `volumes` entry, runs `docker compose run --rm <service> tar cf - -C <path> .` and writes the tarball to a directory. Synced to the server with Prefect flow code (no separate copy). Run on the server: `python /opt/iac/prefect/flows/backup/capture_volumes.py /opt/iac/deploy/<app_slug>`. The backup flow imports and calls `capture_volumes(deploy_dir, out_dir)`.
- **Prefect flow:** [`prefect/backup/flow.py`](../prefect/backup/flow.py) — `run_backup`. For each app with `backup.yml`: capture volumes, run `restic backup`, then `restic forget` (from the file’s `retention`) and `restic prune`. Scheduled daily at 03:00 UTC. **Repository:** If `RESTIC_REPOSITORY_BASE` is set, uses Storage Box (SFTP) at `{base}:{app_slug}` and requires `RESTIC_PASSWORD_FILE` and SSH key at `/opt/iac/prefect/.ssh/storagebox_id_ed25519`. If not set, uses **local** backend at `/tmp/backup/{app_slug}` with password from `RESTIC_PASSWORD` (default `local`). Postgres capture not yet in the flow.
- **Ansible:** Deploy Storage Box SSH key and known_hosts, and Restic repo password file, under `/opt/iac/prefect/`. No cron; Prefect runs the backup.
- **Taskfile / restore:** e.g. `backup:storagebox-snapshots`, `backup:storagebox-restore` (connect to repo, list snapshots, restore to target); restore script or doc for manual steps.
- **Docs:** Short "Service-aware backup (Storage Box)" section in [backups.md](backups.md) linking here; document `.iac/backup.yml` for app authors.

## Next steps

1. Create a Storage Box (BX11 or larger) in Hetzner Console; enable SSH (port 23); add SSH key.
2. Add Storage Box SSH key and Restic repo password to SOPS; Ansible deploys them to the server.
3. Deployment of backup config: copy `.iac/backup.yml` from app repo to server as `backup.yml` in the deploy dir (done in prepare-server).
4. Implement Prefect backup flow (Restic backup + forget + prune) and restore script or Taskfile tasks.
