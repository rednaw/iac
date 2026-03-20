"""Postgres dumps from backup.yml (-F c). CLI: python -m prefect.backup.capture_postgres <deploy_dir> [--output-dir <dir>]"""

import subprocess
import sys
import tempfile
from pathlib import Path

import yaml
from dotenv import dotenv_values


def capture_postgres(deploy_dir: Path, out_dir: Path | None = None) -> list[Path]:
    """Run pg_dump per backup.yml postgres entry into out_dir; returns dump paths or []."""
    deploy_dir = deploy_dir.resolve()
    backup_yml = deploy_dir / "backup.yml"
    if not backup_yml.exists():
        return []
    config = yaml.safe_load(backup_yml.read_text()) or {}
    postgres_list = config.get("postgres") or []
    if not postgres_list:
        return []

    if out_dir is None:
        out_dir = Path(tempfile.mkdtemp(prefix="backup-capture-"))
    out_dir = out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    env_path = deploy_dir / ".env"
    env = dict(dotenv_values(env_path)) if env_path.exists() else {}
    result = []
    for entry in postgres_list:
        service = entry.get("service")
        user_key = entry.get("user_env")
        db_key = entry.get("db_env")
        if not service or not user_key or not db_key:
            continue
        user = env.get(user_key)
        db = env.get(db_key)
        if not user or not db:
            raise ValueError(
                f"postgres entry service={service}: missing in .env (need {user_key}=..., {db_key}=...)"
            )
        dump_path = out_dir / f"postgres_{service}.dump"
        dump_in_container = "/tmp/prefect_pgdump.dump"
        cmd = [
            "docker", "compose",
            "--project-directory", str(deploy_dir),
            "exec", "-T", service,
            "sh", "-c",
            "pg_dump -U \"$1\" -d \"$2\" -F c -f " + dump_in_container + " && cat " + dump_in_container,
            "_", user, db,
        ]
        with open(dump_path, "wb") as f:
            r = subprocess.run(cmd, cwd=deploy_dir, stdout=f, stderr=subprocess.PIPE, text=True)
        if r.returncode != 0:
            raise RuntimeError(f"pg_dump failed for {service}: {r.stderr or ''}")
        if dump_path.stat().st_size == 0:
            stderr = r.stderr or ""
            raise RuntimeError(
                f"pg_dump for {service} produced 0 bytes (empty dump). Is the DB running and reachable? stderr: {stderr}"
            )
        result.append(dump_path)
    return result


def main() -> int:
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("deploy_dir", type=Path)
    p.add_argument("--output-dir", type=Path, default=None)
    args = p.parse_args()
    if not args.deploy_dir.resolve().is_dir():
        print("Error: deploy_dir must be a directory", file=sys.stderr)
        return 1
    try:
        paths = capture_postgres(args.deploy_dir, args.output_dir)
        for t in paths:
            print(t)
        return 0
    except Exception as e:
        print(e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
