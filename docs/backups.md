[**<---**](README.md)

# Backups

[**Prefect**](https://www.prefect.io/) runs [**Restic**](https://restic.net/) per app: local repo under `/opt/iac/prefect/backups/<slug>`, or [Hetzner Storage Box](https://www.hetzner.com/storage/storage-box) over SFTP when the server has `RESTIC_REPOSITORY_BASE`. Optional **`.iac/backup.yml`** (see [app mount](application-deployment.md#app-mount)) defines retention, Postgres dumps, and volume paths; deploy copies it to `backup.yml` next to compose.

**`<slug>`** = basename of `image_name` in `app/.iac/iac.yml` (same as deploy dir and [`resolve-image.yml`](../ansible/roles/deploy_app/tasks/resolve-image.yml)).

## Tasks (devcontainer)

App mounted, `BASE_DOMAIN` set, SSH to `ubuntu@dev|prod.<domain>`.

| Task | |
|------|---|
| `task backup:snapshots -- dev` | List snapshots (**local** repo on server) |
| `task backup:restore -- dev [snapshot] [...]` | [`prefect/backup/restore_from_backup.py`](../prefect/backup/restore_from_backup.py) in `prefect-worker` |

```bash
task backup:snapshots -- dev
task backup:restore -- dev latest
task backup:restore -- dev abc12345 --confirm
```

Slug comes from `image_name` (same as `task app:deploy`). 

Helpers (require `BACKUP_APP_SLUG`): [`scripts/restic-restore.sh`](../scripts/restic-restore.sh), [`scripts/restic-snapshots.sh`](../scripts/restic-snapshots.sh).

## backup.yml

One optional file per app at `.iac/backup.yml`.

- **`retention`:** `keep_daily`, `keep_weekly`, `keep_monthly` → `restic forget` / `prune`.
- **`postgres`:** optional list; each entry runs `pg_dump` in the **running** service; user and DB from deploy `.env` via `user_env` / `db_env`. Output: `postgres_<service>.dump`.
- **`volumes`:** list of `service` + `path` for tar capture (`docker compose run` + tar). Data you care about must live in **Docker volumes**, not bind mounts.

```yaml
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

## Code

| Piece | Location |
|-------|----------|
| Deploy `backup.yml` | [`prepare-server.yml`](../ansible/roles/deploy_app/tasks/prepare-server.yml) |
| Capture + backup | [`capture_postgres.py`](../prefect/backup/capture_postgres.py), [`capture_volumes.py`](../prefect/backup/capture_volumes.py), [`flow.py`](../prefect/backup/flow.py) |
| Restore (local repo) | [`restore_from_backup.py`](../prefect/backup/restore_from_backup.py) |

[`flow.py`](../prefect/backup/flow.py) runs on `prefect-worker` (Docker socket). Storage Box SSH key, `known_hosts`, and Restic password: SOPS → `/opt/iac/prefect/` via Ansible. After changing flows: `task workflow:deploy`.

## Hetzner Storage Box (optional)

Restic talks to the box over **SFTP on port 23** (not 22). One Restic repo per app, e.g. `sftp:uXXXXX@uXXXXX.your-storagebox.de:<app_slug>`; writable area is under the box’s `/home/`. Add the box SSH key in [Hetzner Console](https://docs.hetzner.com/storage/storage-box/backup-space-ssh-keys); keep the private key and Restic repo password in SOPS for Ansible.

**Rough steps:** create the box → add key in Console → SOPS + Ansible → `RESTIC_REPOSITORY_BASE` on the server (see Ansible / server Prefect role) → `task workflow:deploy`.

**Restore from your laptop** (not `task backup:restore`, which targets the **local** repo on the server): decrypt SOPS for `RESTIC_PASSWORD`, then `restic -r sftp:… snapshots` and `restic restore … --target ./restore`. Under the restore tree, dumps and volume tars sit under `…/backup-staging/<slug>/`; put DBs back with `pg_restore`, files with tar / `docker compose cp` as you prefer.
