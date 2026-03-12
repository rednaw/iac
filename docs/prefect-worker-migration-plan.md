# Prefect Worker Migration Plan

Replace the host-based Prefect worker with a Docker worker, then implement registry prune and backup flows.

## Background

The host worker was introduced to handle jobs that need "host access" — but most jobs actually need **Docker socket access**, not host. Running the worker in a container with the Docker socket mounted keeps everything in the Docker world, avoiding host/container boundary issues (especially auth for registry operations).

## Phase 1: Docker Worker

Replace the systemd-based host worker with a containerised worker.

**Worker container requirements:**
- Prefect worker process (same version as server)
- Docker socket mounted (`/var/run/docker.sock`)
- Docker CLI available (for `docker exec`, volume operations)
- Crane binary (for registry API operations)
- Registry auth (Docker config with credentials)

**Changes:**
- [x] Create `Dockerfile.worker` with Prefect + Docker CLI + crane
- [x] Add worker container to Ansible (`prefect.yml`)
- [x] Mount Docker socket into worker container
- [x] Mount or copy Docker config for registry auth (`/opt/prefect/.docker` with both `registry.<domain>` and `https://registry.<domain>` for crane)
- [x] Remove systemd unit and host venv install
- [x] Keep work pool type `process` (flows run as subprocesses inside worker container)
- [x] Test: worker connects to server, picks up jobs

**Auth strategy:**
Worker container has `/root/.docker/config.json` with registry credentials (same as deploy user has now, but inside the container). Crane and Docker CLI inside the container use this directly — no host/container boundary.

## Phase 2: Registry Prune Flow

Implement the registry prune job using the Docker worker.

**Flow design:**
- Flow runs in worker container
- Uses crane (installed in worker image) to list/delete tags
- Uses `docker exec registry ...` to run garbage collection
- Logs output to Prefect UI

**Changes:**
- [x] Simplify `registry_prune.py`: call crane directly (not via `docker run`)
- [x] Remove `Dockerfile.crane` (crane is in worker image)
- [x] GC step already uses `docker exec registry registry garbage-collect ...`
- [x] Test: flow lists tags, deletes old ones, runs GC, logs appear in UI

## Phase 3: App Uploads Volume

Refactor app uploads from bind mount to Docker volume.

**Current:**
```yaml
volumes:
  - ./uploads:/app/uploads  # bind mount to /opt/deploy/<app>/uploads
```

**Target:**
```yaml
volumes:
  - uploads_data:/app/uploads  # named volume

volumes:
  uploads_data:
```

**Changes:**
- [ ] Update `docker-compose.yml` template/contract to use named volume
- [ ] Migration script: copy existing uploads from bind mount to new volume
- [ ] Update any direct host-path references in docs/scripts
- [ ] Test: app works with volume, uploads persist

## Phase 4: App Backup Flow

Implement backup job for Postgres + uploads.

**Flow design:**
- Flow runs in worker container
- Postgres: `docker exec <app>-db-1 pg_dump ...` → backup file
- Uploads: `docker run --rm -v <app>_uploads_data:/data ... tar czf ...`
- Store backups (local volume, or upload to S3/B2/etc.)
- Retention policy (keep N backups)

**Changes:**
- [ ] Create backup flow (`prefect/flows/app_backup/`)
- [ ] Config: which apps to back up, retention, storage destination
- [ ] Implement Postgres dump via `docker exec`
- [ ] Implement uploads backup via volume mount
- [ ] Schedule (e.g. daily)
- [ ] Test: backup runs, files created, can restore

## Order of Operations

1. **Phase 1** first — establishes the Docker worker that all subsequent flows depend on
2. **Phase 2** validates the approach with a real flow (registry prune)
3. **Phase 3** can happen independently but is prerequisite for Phase 4
4. **Phase 4** depends on Phase 1 (worker) and Phase 3 (volumes)

## Rollback

If Docker worker has issues:
- Ansible can re-enable host worker (systemd unit, venv)
- Flows still work on host (with the auth workarounds)

Keep host worker code commented/available until Docker worker is proven stable.
