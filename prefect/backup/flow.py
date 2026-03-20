"""
Backup flow: for each app with backup.yml, capture volumes and run restic backup.

Repository:
  - If RESTIC_REPOSITORY_BASE is set (e.g. sftp:uXXXXX@uXXXXX.your-storagebox.de): back up to
    Storage Box at {base}:{app_slug}. Requires RESTIC_PASSWORD_FILE and SSH key at
    /opt/iac/prefect/.ssh/storagebox_id_ed25519.
  - Else: use local backend at /opt/iac/prefect/backups/{app_slug} with RESTIC_PASSWORD (default "local").
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import yaml
from prefect import flow
from prefect.logging import get_run_logger

from .capture_postgres import capture_postgres
from .capture_volumes import capture_volumes

DEPLOY_ROOT = Path("/opt/iac/deploy")
PREFECT_ROOT = Path("/opt/iac/prefect")
# Persist under /opt/iac so backups survive worker container restarts (host mount).
LOCAL_BACKUP_ROOT = PREFECT_ROOT / "backups"
SSH_KEY = PREFECT_ROOT / ".ssh" / "storagebox_id_ed25519"


def _restic_env(app_slug: str) -> dict[str, str]:
    env = os.environ.copy()
    base = os.environ.get("RESTIC_REPOSITORY_BASE", "").strip()
    if base:
        env["RESTIC_REPOSITORY"] = f"{base}:{app_slug}"
        env["RESTIC_PASSWORD_FILE"] = os.environ.get("RESTIC_PASSWORD_FILE", str(PREFECT_ROOT / ".restic-password"))
    else:
        repo_dir = LOCAL_BACKUP_ROOT / app_slug
        repo_dir.mkdir(parents=True, exist_ok=True)
        env["RESTIC_REPOSITORY"] = str(repo_dir)
        env["RESTIC_PASSWORD"] = os.environ.get("RESTIC_PASSWORD", "local")
    return env


def _sftp_args() -> list[str]:
    if os.environ.get("RESTIC_REPOSITORY_BASE") and SSH_KEY.exists():
        return ["-o", f"sftp.args=-i {SSH_KEY}"]
    return []


def _restic_run(cmd: list[str], env: dict[str, str], timeout: int = 600) -> subprocess.CompletedProcess:
    full = ["restic"] + _sftp_args() + cmd
    return subprocess.run(full, env=env, capture_output=True, text=True, timeout=timeout)


def _restic_check(r: subprocess.CompletedProcess, what: str) -> None:
    if r.returncode != 0:
        raise RuntimeError(f"{what} failed: {r.stderr or r.stdout}")


def _restic_init_if_needed(env: dict[str, str], log) -> None:
    """Initialize restic repo if it does not exist. Idempotent (no-op if already initialized)."""
    r = _restic_run(["init"], env, timeout=60)
    if r.returncode == 0:
        return
    err = (r.stderr or r.stdout or "").lower()
    if "already exists" in err or "config file already exists" in err:
        return
    raise RuntimeError(f"restic init failed: {r.stderr or r.stdout}")


def _backup_app(app_slug: str, deploy_dir: Path, log) -> None:
    backup_yml = deploy_dir / "backup.yml"
    config = yaml.safe_load(backup_yml.read_text()) or {}
    retention = config.get("retention") or {}
    keep_daily = retention.get("keep_daily", 7)
    keep_weekly = retention.get("keep_weekly", 4)
    keep_monthly = retention.get("keep_monthly", 12)

    log.info("MEASURE: step=backup_start app=%s", app_slug)
    env = _restic_env(app_slug)
    log.info("Restic repo for %s: %s", app_slug, env.get("RESTIC_REPOSITORY", ""))
    staging = PREFECT_ROOT / "backup-staging" / app_slug
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    log.info("MEASURE: step=capture_postgres app=%s", app_slug)
    capture_postgres(deploy_dir, staging)
    log.info("MEASURE: step=capture_volumes app=%s", app_slug)
    capture_volumes(deploy_dir, staging)
    if not list(staging.iterdir()):
        log.info("%s: no postgres dumps or volume tarballs, skipping restic", app_slug)
        return

    _restic_init_if_needed(env, log)
    log.info("MEASURE: step=restic_backup app=%s", app_slug)
    _restic_check(_restic_run(["backup", str(staging)], env), "restic backup")

    log.info("MEASURE: step=restic_forget app=%s", app_slug)
    _restic_check(
        _restic_run(
            [
                "forget",
                "--keep-daily",
                str(keep_daily),
                "--keep-weekly",
                str(keep_weekly),
                "--keep-monthly",
                str(keep_monthly),
            ],
            env,
        ),
        "restic forget",
    )

    log.info("MEASURE: step=restic_prune app=%s", app_slug)
    _restic_check(_restic_run(["prune"], env, timeout=900), "restic prune")
    log.info("MEASURE: step=backup_done app=%s", app_slug)


@flow
def run_backup() -> None:
    """For each app with backup.yml, capture postgres dumps and volumes, then back up via restic (local or Storage Box if configured)."""
    log = get_run_logger()
    if not DEPLOY_ROOT.is_dir():
        log.warning("Deploy root %s not found", DEPLOY_ROOT)
        return

    for deploy_dir in sorted(DEPLOY_ROOT.iterdir()):
        if not deploy_dir.is_dir():
            continue
        if not (deploy_dir / "backup.yml").exists():
            continue
        app_slug = deploy_dir.name
        try:
            _backup_app(app_slug, deploy_dir, log)
        except Exception as e:
            log.exception("Backup failed for %s: %s", app_slug, e)
            raise
