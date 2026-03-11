#!/usr/bin/env python3
"""
Registry prune: remove old image tags (keep N newest per repo by creation time).
Protects the currently deployed tag per repo (from /opt/deploy/<app>/deploy-info.yml).
Runs crane via Docker; runs registry garbage-collect on the host after deletes.

Config and Dockerfile.crane live in this directory (flows/registry_prune/etc/).
REGISTRY_URL from env (set by Ansible on worker).
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

ETC_DIR = Path(__file__).resolve().parent
DEPLOY_ROOT = Path("/opt/deploy")
DOCKER_CONFIG_MOUNT = "/opt/deploy/.docker"


def _crane_image() -> str:
    """Read crane image from Dockerfile.crane in this directory (single source of truth for Renovate)."""
    dockerfile = ETC_DIR / "Dockerfile.crane"
    for line in dockerfile.read_text().splitlines():
        line = line.strip()
        if line.startswith("FROM "):
            return line.split(maxsplit=1)[1].strip()
    raise RuntimeError(f"No FROM line in {dockerfile}")


def _crane_docker_run(args: list[str]) -> subprocess.CompletedProcess:
    """Run crane in a Docker container with registry auth from /opt/deploy/.docker.
    Uses host network so the container can reach the registry on the host.
    Copies config to a temp dir with open perms so the container (root) can read it
    (host /opt/deploy/.docker is 0700 so root in container would get permission denied).
    """
    config_src = Path(DOCKER_CONFIG_MOUNT) / "config.json"
    if not config_src.exists():
        return subprocess.CompletedProcess([], 1, "", "config.json not found")
    with tempfile.TemporaryDirectory(prefix="crane-auth-") as tmp:
        tmp_path = Path(tmp)
        config_dst = tmp_path / "config.json"
        shutil.copy2(config_src, config_dst)
        config_dst.chmod(0o644)
        run_cmd = [
            "docker", "run", "--rm", "--network", "host",
            "-v", f"{tmp_path}:/root/.docker:ro",
            "-e", "DOCKER_CONFIG=/root/.docker",
            _crane_image(),
            *args,
        ]
        return subprocess.run(run_cmd, capture_output=True, text=True, timeout=120)


def crane_ls(registry_url: str, repo: str) -> list[str]:
    """List tags for registry/repo."""
    ref = f"{registry_url}/{repo}"
    result = _crane_docker_run(["ls", ref])
    if result.returncode != 0:
        print(f"crane ls {ref}: {result.stderr or result.stdout}", file=sys.stderr)
        return []
    return [t.strip() for t in result.stdout.strip().splitlines() if t.strip()]


def crane_config(ref: str) -> dict:
    """Get image config JSON for ref; return parsed dict or empty dict."""
    result = _crane_docker_run(["config", ref])
    if result.returncode != 0 or not result.stdout.strip():
        return {}
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return {}


def crane_digest(ref: str) -> str:
    """Return digest for ref (e.g. sha256:...)."""
    result = _crane_docker_run(["digest", ref])
    if result.returncode != 0 or not result.stdout.strip():
        return ""
    d = result.stdout.strip()
    return d if d.startswith("sha256:") else f"sha256:{d}"


def crane_delete(repo_at_digest: str) -> bool:
    """Delete manifest by repo@digest. Returns True on success."""
    result = _crane_docker_run(["delete", repo_at_digest])
    if result.returncode != 0:
        print(f"crane delete {repo_at_digest}: {result.stderr or result.stdout}", file=sys.stderr)
        return False
    return True


def get_created_ts(config: dict) -> str:
    """Extract org.opencontainers.image.created from config Labels."""
    labels = config.get("config", {}).get("Labels", {}) or {}
    raw = labels.get("org.opencontainers.image.created", "")
    return raw.split("+")[0].strip() if raw else ""


def get_protected_tag_and_digest(registry_url: str, repo: str) -> tuple[str | None, str | None]:
    """If deploy-info.yml exists for this repo's app, return (tag, digest) to protect. Else (None, None)."""
    app_slug = repo.split("/")[-1]
    deploy_info = DEPLOY_ROOT / app_slug / "deploy-info.yml"
    if not deploy_info.exists():
        return None, None
    data = yaml.safe_load(deploy_info.read_text()) or {}
    image = data.get("image") or {}
    tag = image.get("tag")
    digest = image.get("digest")
    if digest and not digest.startswith("sha256:"):
        digest = f"sha256:{digest}"
    return tag, digest


def load_config() -> dict:
    """Load registry_prune_config.yml from this directory."""
    path = ETC_DIR / "registry_prune_config.yml"
    with open(path) as f:
        return yaml.safe_load(f) or {}


def registry_garbage_collect() -> bool:
    """Run docker exec registry registry garbage-collect on the host. Returns True on success."""
    result = subprocess.run(
        ["docker", "exec", "registry", "registry", "garbage-collect", "/etc/distribution/config.yml"],
        capture_output=True,
        text=True,
        timeout=300,
    )
    if result.returncode != 0:
        print(f"registry garbage-collect: {result.stderr or result.stdout}", file=sys.stderr)
        return False
    return True


def main() -> int:
    config = load_config()
    registry_url = os.environ.get("REGISTRY_URL") or config.get("registry_url") or ""
    if not registry_url:
        print("REGISTRY_URL or config.registry_url required", file=sys.stderr)
        return 1
    repos = config.get("repos") or []
    if not repos:
        print("No repos in config", file=sys.stderr)
        return 1

    deleted_count = 0
    for repo_cfg in repos:
        name = repo_cfg.get("name") if isinstance(repo_cfg, dict) else None
        keep = repo_cfg.get("keep") if isinstance(repo_cfg, dict) else None
        if not name or keep is None:
            continue
        repo = name.strip()
        keep = int(keep)
        protected_tag, protected_digest = get_protected_tag_and_digest(registry_url, repo)
        full_repo = f"{registry_url}/{repo}"
        tags = crane_ls(registry_url, repo)
        if not tags:
            print(f"{repo}: no tags found, skipping")
            continue
        print(f"{repo}: {len(tags)} tags, keep={keep}, protected={protected_tag or '(none)'}")
        # Build list of (tag, created_ts, digest) and sort by created descending
        tagged = []
        for tag in tags:
            ref = f"{full_repo}:{tag}"
            cfg = crane_config(ref)
            created = get_created_ts(cfg)
            digest = crane_digest(ref)
            tagged.append((tag, created, digest))
        tagged.sort(key=lambda x: (x[1] or ""), reverse=True)
        # Keep: protected (if present) + N newest
        to_keep_tags = set()
        if protected_tag:
            to_keep_tags.add(protected_tag)
        if protected_digest:
            for t, _, d in tagged:
                if d == protected_digest:
                    to_keep_tags.add(t)
                    break
        for i, (tag, _, _) in enumerate(tagged):
            if i < keep:
                to_keep_tags.add(tag)
        to_delete = [t for t in tags if t not in to_keep_tags]
        if to_delete:
            print(f"{repo}: deleting {len(to_delete)} tag(s): {', '.join(to_delete)}")
        for tag in to_delete:
            ref = f"{full_repo}:{tag}"
            digest = crane_digest(ref)
            if not digest:
                continue
            repo_at_digest = f"{full_repo}@{digest}"
            if crane_delete(repo_at_digest):
                deleted_count += 1
                print(f"Deleted {repo_at_digest}")
            else:
                print(f"Failed to delete {repo_at_digest}", file=sys.stderr)

    if deleted_count > 0:
        if not registry_garbage_collect():
            print("Warning: garbage-collect failed", file=sys.stderr)
        else:
            print("Registry garbage-collect completed")
        print(f"Pruned {deleted_count} tag(s) in total.")
    else:
        print("No tags to delete (all within keep count or protected).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
