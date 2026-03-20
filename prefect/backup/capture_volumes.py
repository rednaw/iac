"""Volume tar capture from backup.yml. CLI: python -m prefect.backup.capture_volumes <deploy_dir> [--output-dir <dir>]"""

import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml


def _volume_slug(path: str) -> str:
    """Tar name segment; keep in sync with restore_from_backup._path_slug."""
    return path.strip("/").replace("/", "_") or "root"


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

    # Bind-mount out_dir: compose run stdout must not be piped to a file (stream corruption).
    result = []
    for v in volumes:
        service, path = v.get("service"), v.get("path")
        if not service or not path:
            continue
        tar_name = f"{service}_{_volume_slug(path)}.tar"
        tar_path = out_dir / tar_name
        out_in_container = shlex.quote(f"/backup-out/{tar_name}")
        path_q = shlex.quote(path)
        cmd = [
            "docker", "compose",
            "--project-directory", str(deploy_dir),
            "run", "--rm", "-T",
            "-v", f"{out_dir}:/backup-out:rw",
            service,
            "sh", "-c", f"tar cf {out_in_container} -C {path_q} .",
        ]
        r = subprocess.run(cmd, cwd=deploy_dir, stderr=subprocess.PIPE, text=True)
        if r.returncode != 0:
            raise RuntimeError(r.stderr or "docker compose run failed")
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
