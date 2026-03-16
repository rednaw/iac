[**<---**](README.md)

# Backup with Hetzner Storage Box

> **Status: Design document.** 

Service-aware backups to [Hetzner Storage Box](https://www.hetzner.com/storage/storage-box): Postgres dumps and volume data. Once this is in place and working, **Hetzner Cloud image backups will be removed** (no more server snapshots/images for backup).

## Backup engine: Restic

**[Restic](https://restic.net/)** is the backup tool of choice. It supports Storage Box via **SFTP** (port 23 via `~/.ssh/config` or URL). One Restic repo per app on the box; deduplication and compression keep storage and transfer small. Encryption is built-in (AES-256); the **repo password** is stored in SOPS and deployed to the server (e.g. `RESTIC_PASSWORD_FILE`), so no SOPS runtime on the server. Restore from the devcontainer: decrypt SOPS to get the password, then `restic restore`.

**Retention** is **count-based**: `restic forget --keep-daily 7 --keep-weekly 4 ...` keeps the last N snapshots per interval. That gives predictable restore points regardless of backup frequency. Then `restic prune` reclaims space. This fits intermittent or low-frequency runs (e.g. daily Prefect schedule) better than time-based "keep for N hours."

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

- **Per-app spec:** Each app defines what to back up in **`.iac/iac.yml`** (e.g. a `backup:` key). Not in the IaC repo; not a separate `backup.yml`. Different apps can describe different components (Postgres, one or more volume-backed dirs).
- **Spec on server:** We deploy only the **backup spec** to the server (e.g. `.iac/backup.yml`), not the full `iac.yml`, so the backup process can read it from `/opt/iac/deploy/<app_slug>/.iac/backup.yml` without exposing other secrets.
- **One Restic repo per app:** Each app has a Restic repository on Storage Box (e.g. `sftp:uXXXXX@uXXXXX.your-storagebox.de:<app_slug>`). The flow creates one snapshot per run: it builds a backup source (postgres dump + volume contents in a temp dir), runs `restic backup`, then `restic forget` and `restic prune` for retention. Restic handles encryption, dedup, and compression.
- **Data in volumes only:** Apps must use Docker volumes for data that is backed up (no bind mounts for that data). The backup flow captures from volumes (e.g. via `docker compose exec` for Postgres and a service that mounts the volume for tar or direct read).
- **Runs server-side via Prefect:** Backup is a Prefect flow that runs on the worker (server, Docker socket). Schedule or manual run triggers the flow; it reads deploy dirs and each app's backup spec, builds the backup source, runs Restic, then forget/prune. No cron on the server.
- **Deprecate image backups:** When Storage Box backup is done and verified, we will remove the Hetzner Cloud image/snapshot backups (stop creating and retaining them).
- **Backup spec only on server:** `iac.yml` is secret-heavy and most of those secrets are not needed on the server. We deploy only a **backup-only subset** (e.g. `.iac/backup.yml`) so the flow can read postgres service, env keys, and volume list without exposing the rest of iac.yml.

## What to back up (example: tientje-ketama)

| Data            | Location on server                          | How to capture                    |
|-----------------|---------------------------------------------|-----------------------------------|
| Postgres        | In Docker volume (e.g. `tientje-ketama_postgres_data`) | `docker compose exec db pg_dump`  |
| Uploads         | In a Docker volume (app must use volume, not bind mount) | `tar` from a container that mounts the volume |

- **Deploy path:** Apps live under `/opt/iac/deploy/<app_slug>/`. `.env` and the backup spec (e.g. `.iac/backup.yml`) are deployed there; the full `iac.yml` is not. Compose must use **volumes** for any data to be backed up. See [Server layout](server-layout.md).
- **Dump:** Run `pg_dump` inside the `db` container; DB name/user from `.env`. The backup spec in `iac.yml` identifies the Postgres service and (if needed) env var names.

## Where the backup runs

**Prefect flow on the server (worker).**

- The flow runs on the existing Prefect worker (Docker socket, server). It iterates over apps, reads each app's backup spec, builds the backup source (postgres dump + volume tarballs in a temp dir), runs `restic backup` to the app's repo on Storage Box, then `restic forget` and `restic prune`. No cron; schedule is a Prefect schedule (e.g. daily). See [Server layout](server-layout.md).
- **On the server:** Storage Box SSH key and Restic repo password file live under the Prefect subtree (e.g. `/opt/iac/prefect/.ssh/`, `/opt/iac/prefect/.restic-password`), deployed by Ansible from SOPS. The flow sets `RESTIC_REPOSITORY` and `RESTIC_PASSWORD_FILE` (or equivalent) so Restic can connect to the box and decrypt the repo.

## Backup layout on Storage Box

One **Restic repository** per app, under `/home/` on the box (e.g. `tientje-ketama/`). Each repo has the usual Restic layout: `config`, `data/`, `index/`, `keys/`, `locks/`, `snapshots/`. Restic handles encryption, dedup, and compression; the box only ever sees ciphertext. Retention is managed by `restic forget` (count-based: e.g. keep last 7 daily, 4 weekly) then `restic prune` to reclaim space.

## Secrets and Ansible

- **Storage Box SSH key:** Generate a key pair for the box only (e.g. `storagebox_id_ed25519`). Put the **private** key in SOPS. Ansible deploys it to the server under the Prefect subtree (e.g. `/opt/iac/prefect/.ssh/storagebox_id_ed25519`, mode `0600`). Add the **public** key to the Storage Box in Hetzner Console. See [Server layout](server-layout.md).
- **Storage Box host key:** Add the box to `known_hosts` on the server (Ansible one-time task or script) so the backup flow doesn't hang on first connect.
- **Restic repo password:** Store the Restic repository password in SOPS (e.g. in app secrets or a dedicated backup secret). Ansible deploys it to the server as a file (e.g. `/opt/iac/prefect/.restic-password`, mode `0600`). The backup flow uses `RESTIC_PASSWORD_FILE`; for restore from the devcontainer, decrypt SOPS to get the password (or use a Task that writes it to a temp file).

## Backup flow (high level)

Prefect flow runs on the worker (server). For each app with a backup spec file (e.g. `.iac/backup.yml`):

1. Read `/opt/iac/deploy/<app_slug>/.iac/backup.yml` → backup config (postgres service name, volume/dir list).
2. Create temp dir for backup source.
3. **Postgres:** `docker compose exec -T <db_service> pg_dump -U <user> -Fc <db> > .../postgres.dump` (user/db from .env or spec). Optionally gzip to save space before Restic.
4. **Volume dirs:** For each volume/dir in spec, produce a tarball (e.g. run a container that mounts the volume and tars the path). Add to temp dir (e.g. `uploads.tar.gz`).
5. **Restic backup:** Set `RESTIC_REPOSITORY=sftp:.../<app_slug>`, `RESTIC_PASSWORD_FILE=...`. Run `restic backup <temp_dir>` (tags optional, e.g. for retention rules).
6. **Retention:** Run `restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12` (or configurable), then `restic prune`.
7. Remove temp dir.

Log success/failure per app; Prefect run logs are the audit trail.

## Restore (from devcontainer)

1. **Connect to repo:** Ensure Storage Box SSH key and host are in `~/.ssh/` (or use `-o sftp.args="-i /path/to/key"`). Get Restic repo password from SOPS (decrypt `iac.yml` or backup secret), set `RESTIC_PASSWORD` or `RESTIC_PASSWORD_FILE`.
2. **List snapshots:** `restic -r sftp:uXXXXX@uXXXXX.your-storagebox.de:<app_slug> snapshots`. Note the snapshot ID (or use `latest`).
3. **Restore:** `restic restore <snapshot_id> --target ./restore` (or `latest`). This restores the backup-source layout (e.g. `postgres.dump`, `uploads.tar.gz`).
4. **Restore DB:** Copy `restore/postgres.dump` to server (or run from devcontainer via SSH). On server: `docker compose exec -T db pg_restore -U postgres -d <db> --clean --if-exists < postgres.dump`. Prefer doing this with app stopped or in maintenance mode.
5. **Restore uploads:** Copy `restore/uploads.tar.gz` (or similar) to server, decompress and extract into the volume target path.

A Taskfile task or `scripts/restore-from-storagebox.sh` can wrap these steps and take app name + snapshot as arguments when you implement.

## Retention

- **Count-based:** `restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12` (or similar). One snapshot can satisfy multiple rules (e.g. daily and weekly). Then `restic prune` to reclaim space. Run as part of the backup flow or a separate scheduled flow.
- **Storage Box snapshots:** You can enable snapshots on the box (10–40 depending on tier) as an extra safety net; they are separate from Restic retention.

## Relation to existing backups

- **Hetzner Cloud image backups** (`backups = true` in Terraform, `task backup:list`, `task backup:restore`) remain useful for "restore the whole server to a point in time." They are not service-aware and cost 20% of the server.
- **Storage Box backup** is complementary: smaller, service-aware, and restorable without replacing the disk. You can keep both (e.g. weekly image backup + daily Storage Box), or reduce/disable image backups if you fully rely on Storage Box.

## Shape of `backup:` in iac.yml (decided)

Explicit over convention; verbosity is fine. Example:

```yaml
backup:
  postgres:
    service: db                    # compose service name
    user_env: POSTGRES_USER        # key in .env for DB user
    db_env: POSTGRES_DB            # key in .env for DB name
  volumes:
    - service: app                 # service that mounts the volume
      path: /data/uploads         # path inside that container (tar will capture this)
```

- **postgres:** Optional. If present, the flow runs `pg_dump` from that service; user and DB name are read from the deploy dir `.env` using the given env keys. No defaulted names; app must specify.
- **volumes:** List of `service` + `path`. For each, the flow runs a container (e.g. `docker compose run --rm <service> tar cf - -C <path> .`) to produce a tarball. Order is preserved in the archive.
- Omit `postgres` or `volumes` if an app has only one or the other. Empty `volumes: []` = no volume backup.

## Open decisions

1. **Retention policy:** Defaults for `restic forget` (e.g. `--keep-daily 7 --keep-weekly 4 --keep-monthly 12`); configurable in the flow or in the app backup spec.

## Implementation outline (when you add code)

- **Deploy backup spec to server:** In the app deployment path (Ansible deploy_app or app deploy script), deploy only the **backup spec** to the server (e.g. extract `backup:` from `.iac/iac.yml` and write to `/opt/iac/deploy/<app_slug>/.iac/backup.yml`). The flow reads this file to get postgres service, env keys, and volumes.
- **Prefect flow:** New flow that for each app reads the backup spec, builds the backup source (postgres dump + volume tarballs), runs `restic backup` to the app's repo on Storage Box (SFTP), then `restic forget` and `restic prune`. Scheduled (e.g. daily) or manual.
- **Ansible:** Deploy Storage Box SSH key and known_hosts, and Restic repo password file, under `/opt/iac/prefect/`. No cron; Prefect runs the backup.
- **Taskfile / restore:** e.g. `backup:storagebox-snapshots`, `backup:storagebox-restore` (connect to repo, list snapshots, restore to target); restore script or doc for manual steps.
- **Docs:** Short "Service-aware backup (Storage Box)" section in [backups.md](backups.md) linking here; document `backup:` key in iac.yml for app authors.

## Next steps

1. Create a Storage Box (BX11 or larger) in Hetzner Console; enable SSH (port 23); add SSH key.
2. Add Storage Box SSH key and Restic repo password to SOPS; Ansible deploys them to the server.
3. Add deployment of backup spec only (e.g. `.iac/backup.yml`) to server when deploying an app.
4. Implement Prefect backup flow (Restic backup + forget + prune) and restore script or Taskfile tasks.
