#!/usr/bin/env python3
"""
Registry prune: remove old image tags (keep N newest per repo by creation time).
Protects the currently deployed tag per repo (from /opt/deploy/<app>/deploy-info.yml).
Uses crane binary (in worker image); runs registry garbage-collect via docker exec.

Config in this directory (flows/registry_prune/etc/). REGISTRY_URL and DOCKER_CONFIG from env (Ansible).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import yaml

ETC_DIR = Path(__file__).resolve().parent
DEPLOY_ROOT = Path("/opt/deploy")


def _crane_run(args: list[str]) -> subprocess.CompletedProcess:
    """Run crane binary (worker has it; DOCKER_CONFIG is set for registry auth)."""
    return subprocess.run(
        ["crane", *args],
        capture_output=True,
        text=True,
        timeout=120,
        env=os.environ,
    )


def _crane_fail(cmd: str, result: subprocess.CompletedProcess) -> None:
    """Raise on crane failure so the flow run fails (proper visibility in UI)."""
    msg = (result.stderr or result.stdout or "").strip() or "(no output)"
    raise RuntimeError(f"crane {cmd} failed (exit {result.returncode}): {msg}")


def crane_ls(registry_url: str, repo: str) -> list[str]:
    """List tags for registry/repo. Raises on failure (auth, network, etc.)."""
    ref = f"{registry_url}/{repo}"
    result = _crane_run(["ls", ref])
    if result.returncode != 0:
        _crane_fail(f"ls {ref}", result)
    return [t.strip() for t in result.stdout.strip().splitlines() if t.strip()]


def crane_config(ref: str) -> dict:
    """Get image config JSON for ref. Raises on failure."""
    result = _crane_run(["config", ref])
    if result.returncode != 0:
        _crane_fail(f"config {ref}", result)
    if not result.stdout.strip():
        return {}
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return {}


def crane_digest(ref: str) -> str:
    """Return digest for ref (e.g. sha256:...). Raises on failure."""
    result = _crane_run(["digest", ref])
    if result.returncode != 0:
        _crane_fail(f"digest {ref}", result)
    if not result.stdout.strip():
        raise RuntimeError(f"crane digest {ref}: no output")
    d = result.stdout.strip()
    return d if d.startswith("sha256:") else f"sha256:{d}"


def crane_delete(repo_at_digest: str) -> bool:
    """Delete manifest by repo@digest. Raises on failure."""
    result = _crane_run(["delete", repo_at_digest])
    if result.returncode != 0:
        _crane_fail(f"delete {repo_at_digest}", result)
    return True


# OCI label keys set in .github/workflows/_build-and-push.yml (log pruned snapshot)
OCI_LABEL_KEYS = (
    "org.opencontainers.image.description",
    "org.opencontainers.image.revision",
    "org.opencontainers.image.created",
    "org.opencontainers.image.source",
)


def get_created_ts(config: dict) -> str:
    """Extract org.opencontainers.image.created from config Labels."""
    labels = config.get("config", {}).get("Labels", {}) or {}
    raw = labels.get("org.opencontainers.image.created", "")
    return raw.split("+")[0].strip() if raw else ""


def get_oci_labels(config: dict) -> dict[str, str]:
    """Extract org.opencontainers.* labels from image config (for logging)."""
    labels = config.get("config", {}).get("Labels", {}) or {}
    return {k: (labels.get(k) or "") for k in OCI_LABEL_KEYS}


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


def registry_garbage_collect() -> None:
    """Run docker exec registry registry garbage-collect. Raises on failure."""
    result = subprocess.run(
        ["docker", "exec", "registry", "registry", "garbage-collect", "/etc/distribution/config.yml"],
        capture_output=True,
        text=True,
        timeout=300,
    )
    if result.returncode != 0:
        msg = (result.stderr or result.stdout or "").strip() or "(no output)"
        raise RuntimeError(f"registry garbage-collect failed (exit {result.returncode}): {msg}")


def _build_tagged(full_repo: str, tags: list[str]) -> list[tuple[str, str, str, dict]]:
    """List (tag, created_ts, digest, config) for each tag, sorted by created descending."""
    tagged = []
    for tag in tags:
        ref = f"{full_repo}:{tag}"
        cfg = crane_config(ref)
        created = get_created_ts(cfg)
        digest = crane_digest(ref)
        tagged.append((tag, created, digest, cfg))
    tagged.sort(key=lambda x: (x[1] or ""), reverse=True)
    return tagged


def _compute_kept_and_deleted(
    tagged: list[tuple[str, str, str, dict]],
    tags: list[str],
    keep: int,
    protected_tag: str | None,
    protected_digest: str | None,
) -> tuple[set[str], list[str]]:
    """Return (to_keep_tags, to_delete). Keeps protected + N newest by creation."""
    to_keep_tags = set()
    if protected_tag:
        to_keep_tags.add(protected_tag)
    if protected_digest:
        for t, _, d, _ in tagged:
            if d == protected_digest:
                to_keep_tags.add(t)
                break
    for i, (tag, _, _, _) in enumerate(tagged):
        if i < keep:
            to_keep_tags.add(tag)
    to_delete = [t for t in tags if t not in to_keep_tags]
    return to_keep_tags, to_delete


def _prune_repo(registry_url: str, repo: str, keep: int) -> int:
    """Prune one repo: log removed-tag snapshot, delete tags. Returns number deleted."""
    protected_tag, protected_digest = get_protected_tag_and_digest(registry_url, repo)
    full_repo = f"{registry_url}/{repo}"
    tags = crane_ls(registry_url, repo)
    if not tags:
        print(f"{repo}: no tags found, skipping")
        return 0

    print(f"{repo}: {len(tags)} tags, keep={keep}, protected={protected_tag or '(none)'}")
    tagged = _build_tagged(full_repo, tags)
    _, to_delete = _compute_kept_and_deleted(
        tagged, tags, keep, protected_tag, protected_digest
    )

    if to_delete:
        print(f"{repo}: deleting {len(to_delete)} tag(s): {', '.join(to_delete)}")
    tag_to_cfg = {t: cfg for t, _, _, cfg in tagged}
    deleted_count = 0
    for tag in sorted(to_delete):
        oci = get_oci_labels(tag_to_cfg.get(tag) or {})
        print(f"{repo} pruned snapshot (removed) tag={tag}")
        for key in OCI_LABEL_KEYS:
            val = oci.get(key, "")
            if val:
                short_key = key.removeprefix("org.opencontainers.image.")
                print(f"  {short_key}={val}")
        ref = f"{full_repo}:{tag}"
        digest = crane_digest(ref)
        if not digest:
            continue
        repo_at_digest = f"{full_repo}@{digest}"
        if crane_delete(repo_at_digest):
            deleted_count += 1
        else:
            print(f"Failed to delete {repo_at_digest}", file=sys.stderr)
    return deleted_count


def _process_repos(registry_url: str, repos: list) -> int:
    """Run prune for each configured repo. Returns total deleted count."""
    deleted_count = 0
    for repo_cfg in repos:
        name = repo_cfg.get("name") if isinstance(repo_cfg, dict) else None
        keep = repo_cfg.get("keep") if isinstance(repo_cfg, dict) else None
        if not name or keep is None:
            continue
        repo = name.strip()
        keep = int(keep)
        deleted_count += _prune_repo(registry_url, repo, keep)
    return deleted_count


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

    deleted_count = _process_repos(registry_url, repos)

    if deleted_count > 0:
        registry_garbage_collect()
        print("Registry garbage-collect completed")
        print(f"Pruned {deleted_count} tag(s) in total.")
    else:
        print("No tags to delete (all within keep count or protected).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
