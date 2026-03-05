[**<---**](README.md)

# Backup with Hetzner Storage Box

> **Status: Design document.** This describes the intended approach. Implementation steps are in the [Open decisions](#open-decisions) and [Implementation outline](#implementation-outline) sections.

Service-aware backups to [Hetzner Storage Box](https://www.hetzner.com/storage/storage-box): Postgres dumps and app uploads, as a complement or replacement for Hetzner Cloud image backups.

## Why Storage Box

- **Cost:** BX11 (1 TB) ≈ €3.81/month — cheaper than Object Storage's €4.99 minimum and than the 20% server fee for 7 image backups.
- **Service-aware:** Back up database dumps and uploads only; restore without rebuilding the whole server.
- **Access:** SSH (port 23), rsync, SFTP, BorgBackup; fits scripting and cron.
- **Location:** Same provider as the server; optional snapshots on the box (10–40 depending on tier).

## How Storage Box access works

- **Endpoint:** `uXXXXX@uXXXXX.your-storagebox.de` (username = Storage Box ID from Hetzner Console).
- **SSH port:** **23** (not 22). Use `ssh -p23` and `rsync -e 'ssh -p23'`.
- **Writable path:** Only `/home/`. Use **relative** paths, e.g. `tientje-ketama/2026-03-05/backup.tar.age`.
- **Auth:** SSH key (OpenSSH one-line format) or password. Key is preferred; add via [Hetzner Console → Storage Box → SSH keys](https://docs.hetzner.com/storage/storage-box/backup-space-ssh-keys) or `ssh-copy-id -p 23 -s uXXXXX@uXXXXX.your-storagebox.de`.

Example:

```bash
rsync -e 'ssh -p23' -avz --progress ./local/ uXXXXX@uXXXXX.your-storagebox.de:tientje-ketama/2026-03-05/
```

## What to back up (tientje-ketama)

| Data            | Location on server                          | How to capture                    |
|-----------------|---------------------------------------------|-----------------------------------|
| Postgres        | In Docker volume `tientje-ketama_postgres_data` | `docker compose exec db pg_dump`  |
| Uploads (mp3s)  | `/opt/deploy/tientje-ketama/uploads`        | `tar` (or rsync for incremental)   |

- **Deploy path:** Apps live under `/opt/deploy/<app_slug>/` (e.g. `/opt/deploy/tientje-ketama/`). Compose uses `./uploads` → that directory; Postgres uses a named volume managed by Docker.
- **Dump:** Run `pg_dump` inside the `db` container so we don't need a Postgres client on the host. Use `.env` in the deploy dir for `POSTGRES_PASSWORD` and DB name.

## Where the backup runs

**Recommended: on the server (cron + script).**

- Pros: Direct access to Docker and `/opt/deploy`; one place for credentials; no streaming over SSH.
- Cons: Storage Box SSH key (and optionally age public keys) must be on the server; we store the key in SOPS and deploy it with Ansible.

Alternative: run from the devcontainer via SSH (dump + uploads streamed over SSH, then push to Storage Box). Possible but more complex and slower; only consider if you don't want any backup secrets on the server.

## Backup layout on Storage Box

Suggested layout (one directory per run, e.g. per day):

```
tientje-ketama/
  2026-03-05/
    backup.tar.age    # single encrypted archive (postgres dump + uploads tarball)
  2026-03-06/
    backup.tar.age
  ...
```

- One file per run keeps retention simple (delete old directories).
- **Encryption:** Use **age** (same keys as SOPS). Encrypt before rsync so the box only ever sees ciphertext. Server only needs age **public** keys to encrypt; restore is done from the devcontainer (has private key): download, `age -d`, then extract and load.

Optional variant: store `postgres.dump` and `uploads.tar` separately (still encrypted) if you want to restore only DB or only uploads.

## Secrets and Ansible

- **Storage Box SSH key:** Generate a key pair for the box only (e.g. `storagebox_id_ed25519`). Put the **private** key in SOPS (e.g. in `app/.iac/iac.yml` or a dedicated file). Ansible deploys it to the server (e.g. `/opt/deploy/.ssh/storagebox_id_ed25519`, mode `0600`, owner `deploy`). Add the **public** key to the Storage Box in Hetzner Console (or via `install-ssh-key` once with password).
- **Storage Box host key:** Add the box to `known_hosts` on the server (Ansible one-time task or script) so cron doesn't hang on first connect.
- **Age:** Store age **public** key(s) on the server for encryption; private key stays in the devcontainer / your machine for restore only.

## Backup script (high level)

Run as `deploy` on the server (e.g. from cron at 02:00):

1. `cd /opt/deploy/tientje-ketama`
2. Create temp dir, e.g. `/tmp/backup-$$`
3. **Postgres:** `docker compose exec -T db pg_dump -U postgres -Fc tientje_ketama > /tmp/backup-$$/postgres.dump` (or plain SQL with `-Fp` if you prefer)
4. **Uploads:** `tar cf /tmp/backup-$$/uploads.tar uploads/`
5. **Bundle:** `tar cf /tmp/backup-$$/backup.tar -C /tmp/backup-$$ postgres.dump uploads.tar`
6. **Encrypt:** `age -R /path/to/age-pubkeys.txt -o /tmp/backup-$$/backup.tar.age /tmp/backup-$$/backup.tar`
7. **Upload:** `rsync -e 'ssh -p23 -i /opt/deploy/.ssh/storagebox_id_ed25519' -a /tmp/backup-$$/backup.tar.age uXXXXX@uXXXXX.your-storagebox.de:tientje-ketama/$(date +%Y-%m-%d)/`
8. Remove temp dir.

Use `set -e` and simple logging (e.g. to a log file or cron mail). Optionally verify: after upload, list the remote path and check file size.

## Restore (from devcontainer)

1. **Download:** `rsync -e 'ssh -p23' -avz uXXXXX@uXXXXX.your-storagebox.de:tientje-ketama/2026-03-05/backup.tar.age ./`
2. **Decrypt:** `age -d -i ~/.config/sops/age/keys.txt -o backup.tar backup.tar.age`
3. **Extract:** `tar xf backup.tar` → `postgres.dump`, `uploads.tar`
4. **Restore DB:** Copy `postgres.dump` to server (or run restore from devcontainer via SSH). On server: `docker compose exec -T db pg_restore -U postgres -d tientje_ketama --clean --if-exists < postgres.dump` (or `psql < postgres.sql` if you used plain SQL). Prefer doing this with app stopped or in maintenance mode.
5. **Restore uploads:** Copy `uploads.tar` to server, e.g. `scp uploads.tar deploy@server:/opt/deploy/tientje-ketama/`, then on server `tar xf uploads.tar` in that dir (adjust paths if needed).

A small `scripts/restore-from-storagebox.sh` (or Taskfile tasks) can wrap these steps and take date + app name as arguments when you implement.

## Retention

- **On Storage Box:** Keep last N daily dirs (e.g. 14 or 30). Either a cron job on the server that runs `ssh -p23 ... "ls tientje-ketama"` and deletes older dirs, or a Taskfile task run manually.
- **Storage Box snapshots:** You can enable snapshots on the box (10–40 depending on tier) as an extra safety net; they are separate from the directory pruning above.

## Relation to existing backups

- **Hetzner Cloud image backups** (`backups = true` in Terraform, `task backup:list`, `task backup:restore`) remain useful for "restore the whole server to a point in time." They are not service-aware and cost 20% of the server.
- **Storage Box backup** is complementary: smaller, service-aware, and restorable without replacing the disk. You can keep both (e.g. weekly image backup + daily Storage Box), or reduce/disable image backups if you fully rely on Storage Box.

## Open decisions

1. **One backup script per app vs generic:** Start with tientje-ketama; later make the script (or Ansible role) parameterised by app name and compose path so other apps can use the same flow.
2. **Cron on server vs triggered from CI:** Cron is simple and doesn't depend on GitHub. A scheduled workflow could SSH into the server and run the script, but then CI needs SSH access; usually cron on the server is enough.
3. **Compression:** `postgres.dump` and uploads can be gzipped before putting in the tar (e.g. `uploads.tar.gz`). MP3s don't compress much; the dump will. Optional.
4. **Monitoring:** Optionally send a heartbeat or log to a channel (e.g. OpenObserve, or a simple "last backup" file in a known place) so you notice if backups stop.

## Implementation outline (when you add code)

- **Taskfile tasks:** e.g. `backup:storagebox-list` (list backup dates), `backup:storagebox-restore` (download + decrypt + instructions or script). Optionally `backup:storagebox-run` to trigger backup from devcontainer.
- **Server script:** e.g. `/opt/deploy/scripts/backup-to-storagebox.sh` deployed by Ansible from a template; cron as `deploy`.
- **Restore script:** e.g. `scripts/restore-from-storagebox.sh` in the repo, run from devcontainer; takes workspace, app name, date.
- **Docs:** Add a short "Service-aware backup (Storage Box)" section to [backups.md](backups.md) linking here.

## Next steps

1. Create a Storage Box (BX11 or larger) in Hetzner Console; enable SSH (port 23); add SSH key.
2. Add Storage Box credentials to SOPS (private key; and optionally `STORAGEBOX_USER`, `STORAGEBOX_HOST` for the script).
3. Add Ansible tasks: deploy Storage Box SSH key and known_hosts; install backup script; cron.
4. Add backup script and (optionally) restore script and Taskfile tasks as in the outline above.
