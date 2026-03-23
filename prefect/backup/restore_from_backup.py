#!/usr/bin/env python3
"""Restore DB/volumes from local Restic (run on server; optional: save-volumes-safety.sh first).

RESTORE_TMP_PARENT (default /opt/iac/prefect/.restore-work) should stay under /opt/iac so
`docker compose cp` paths match the host (worker uses the Docker socket).
"""
import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import yaml
from dotenv import dotenv_values


def _path_slug(path: str) -> str:
    """Volume tarball suffix; must match capture_volumes._volume_slug."""
    return path.strip("/").replace("/", "_") or "root"


def main() -> None:
    p = argparse.ArgumentParser(description="Restore from restic backup")
    p.add_argument("app_slug", help="App slug (e.g. tientje-ketama)")
    p.add_argument("snapshot", nargs="?", default="latest")
    p.add_argument("--postgres-only", action="store_true")
    p.add_argument("--volumes-only", action="store_true")
    p.add_argument("--confirm", action="store_true")
    args = p.parse_args()

    deploy_root = Path(os.environ.get("DEPLOY_ROOT", "/opt/iac/deploy"))
    deploy_dir = deploy_root / args.app_slug
    repo = Path(os.environ.get("REPO", f"/opt/iac/prefect/backups/{args.app_slug}"))
    prefect_parts = [
        p
        for p in os.environ.get("PREFECT_ROOT", "/opt/iac/prefect").strip("/").split("/")
        if p
    ]
    password = os.environ.get("RESTIC_PASSWORD", "local")

    if not deploy_dir.is_dir():
        raise SystemExit(f"Deploy dir not found: {deploy_dir}")
    if not (deploy_dir / "backup.yml").is_file():
        raise SystemExit("No backup.yml")
    if not repo.is_dir():
        raise SystemExit(f"Restic repo not found: {repo}")

    config = yaml.safe_load((deploy_dir / "backup.yml").read_text()) or {}
    env = dict(dotenv_values(deploy_dir / ".env")) if (deploy_dir / ".env").exists() else {}

    do_pg = not args.volumes_only
    do_vol = not args.postgres_only
    print(f"Snapshot: {args.snapshot}\nRestore will: App={args.app_slug} Postgres={do_pg} Volumes={do_vol}")
    if not args.confirm:
        try:
            typed = input("Type 'restore' to confirm: ")
        except EOFError:
            raise SystemExit("Non-interactive: pass --confirm") from None
        if typed != "restore":
            raise SystemExit("Aborted.")

    restore_parent = Path(
        os.environ.get("RESTORE_TMP_PARENT", "/opt/iac/prefect/.restore-work")
    )
    restore_parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=restore_parent) as tmp:
        tmp = Path(tmp)
        restic_env = os.environ.copy()
        restic_env["RESTIC_REPOSITORY"] = str(repo.resolve())
        restic_env["RESTIC_PASSWORD"] = password
        subprocess.run(
            ["restic", "restore", args.snapshot, "--target", str(tmp)],
            env=restic_env,
            check=True,
        )
        staging = tmp.joinpath(*prefect_parts, "backup-staging", args.app_slug)
        if not staging.is_dir():
            raise SystemExit(f"Could not find restore root: {staging}")
        compose = ["docker", "compose", "--project-directory", str(deploy_dir)]

        if do_pg:
            for entry in config.get("postgres") or []:
                service = entry.get("service")
                user = env.get(entry.get("user_env") or "", "")
                db = env.get(entry.get("db_env") or "", "")
                if not service:
                    continue
                dump = staging / f"postgres_{service}.dump"
                if not dump.is_file():
                    print(f"Dump not found: {dump}")
                    continue
                print(f"Restoring DB: {service}")
                container_dump = "/tmp/restore.dump"
                subprocess.run(
                    compose + ["cp", str(dump), f"{service}:{container_dump}"],
                    cwd=deploy_dir, check=True,
                )
                try:
                    subprocess.run(
                        compose + ["exec", "-T", service, "pg_restore", "-U", user, "-d", db,
                                   "--clean", "--if-exists", "--no-owner", "--no-acl", container_dump],
                        cwd=deploy_dir, check=True,
                    )
                finally:
                    subprocess.run(
                        compose + ["exec", "-T", service, "rm", "-f", container_dump],
                        cwd=deploy_dir, check=False,
                    )
        if do_vol:
            for entry in config.get("volumes") or []:
                service, path = entry.get("service"), entry.get("path")
                if not service or not path:
                    continue
                slug = _path_slug(path)
                tar_path = staging / f"{service}_{slug}.tar"
                if not tar_path.is_file():
                    print(f"Volume tar not found: {tar_path}")
                    continue
                print(f"Restoring volume: {service} {path}")
                extract_root = tmp / f"_vextract_{service}_{slug}"
                extract_root.mkdir()
                try:
                    r = subprocess.run(
                        ["tar", "xf", str(tar_path), "-C", str(extract_root)],
                        capture_output=True,
                        text=True,
                    )
                    if r.returncode != 0:
                        raise SystemExit(
                            f"Unreadable volume tar (corrupt or old capture): {tar_path}\n{r.stderr}"
                        )
                    subprocess.run(
                        compose + ["cp", f"{extract_root}/.", f"{service}:{path}/"],
                        cwd=deploy_dir,
                        check=True,
                    )
                finally:
                    shutil.rmtree(extract_root, ignore_errors=True)
    print("Restore complete.")


if __name__ == "__main__":
    main()
