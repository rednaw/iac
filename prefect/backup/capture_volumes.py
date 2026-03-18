# Backup: capture volume tarballs from deploy dir using backup.yml (on server: next to compose files).
# Synced to server with Prefect flow code. Run on server.
# CLI: python -m prefect.backup.capture_volumes <deploy_dir> [--output-dir <dir>]

import subprocess
import sys
import tempfile
from pathlib import Path

import yaml


def capture_volumes(deploy_dir: Path, out_dir: Path | None = None) -> list[Path]:
    """Read backup.yml from deploy dir, tar each volume into out_dir. Returns list of tarball paths."""
    deploy_dir = deploy_dir.resolve()
    backup_yml = deploy_dir / "backup.yml"
    if not backup_yml.exists():
        return []
    config = yaml.safe_load(backup_yml.read_text()) or {}
    volumes = config.get("volumes") or []
    if not volumes:
        return []

    out_dir = out_dir or Path(tempfile.mkdtemp(prefix="backup-capture-"))
    out_dir = out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    # Use --project-directory so we don't pass -f (worker image may have docker CLI only; -f is not a global docker flag).
    result = []
    for v in volumes:
        service, path = v.get("service"), v.get("path")
        if not service or not path:
            continue
        name = path.strip("/").replace("/", "_") or "root"
        tar_path = out_dir / f"{service}_{name}.tar"
        cmd = [
            "docker", "compose",
            "--project-directory", str(deploy_dir),
            "run", "--rm", "-T", service,
            "tar", "cf", "-", "-C", path, ".",
        ]
        with open(tar_path, "wb") as f:
            r = subprocess.run(cmd, cwd=deploy_dir, stdout=f, stderr=subprocess.PIPE)
        if r.returncode != 0:
            raise RuntimeError(r.stderr.decode("utf-8", errors="replace"))
        result.append(tar_path)
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
        paths = capture_volumes(args.deploy_dir, args.output_dir)
        for t in paths:
            print(t)
        return 0
    except Exception as e:
        print(e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
