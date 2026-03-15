"""
Registry prune flow: list all repos (crane catalog), prune each to 6 tags,
protect deployed tag per repo, then run registry garbage-collect.

REGISTRY_URL and DOCKER_CONFIG from env (Ansible).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from io import StringIO
from pathlib import Path

import yaml
from prefect import flow
from prefect.logging import get_run_logger

DEPLOY_ROOT = Path("/opt/iac/deploy")
KEEP = 6

OCI_LABEL_KEYS = (
    "org.opencontainers.image.description",
    "org.opencontainers.image.revision",
    "org.opencontainers.image.created",
    "org.opencontainers.image.source",
)


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


def crane_catalog(registry_url: str) -> list[str]:
    """List all repos in the registry (crane catalog). Raises on failure."""
    result = _crane_run(["catalog", registry_url])
    if result.returncode != 0:
        _crane_fail(f"catalog {registry_url}", result)
    return [r.strip() for r in result.stdout.strip().splitlines() if r.strip()]


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


def _process_repos(registry_url: str, repos: list[tuple[str, int]]) -> int:
    """Run prune for each (repo, keep). Returns total deleted count."""
    deleted_count = 0
    for repo, keep in repos:
        deleted_count += _prune_repo(registry_url, repo, keep)
    return deleted_count


def _run_prune() -> int:
    """Run prune logic. Prints to stdout/stderr. Returns exit code (0 = success)."""
    registry_url = os.environ.get("REGISTRY_URL") or ""
    if not registry_url:
        print("REGISTRY_URL required", file=sys.stderr)
        return 1
    repos = crane_catalog(registry_url)
    if not repos:
        print("No repos in registry, nothing to prune.")
        return 0
    deleted_count = _process_repos(registry_url, [(repo, KEEP) for repo in repos])

    if deleted_count > 0:
        registry_garbage_collect()
        print("Registry garbage-collect completed")
        print(f"Pruned {deleted_count} tag(s) in total.")
    else:
        print("No tags to delete (all within keep count or protected).")
    return 0


@flow
def registry_prune():
    """
    List all repos (crane catalog), prune each to 6 tags, protect deployed tag per repo,
    then run registry garbage-collect.
    """
    out = StringIO()
    err = StringIO()
    old_stdout, old_stderr = sys.stdout, sys.stderr
    try:
        sys.stdout = out
        sys.stderr = err
        exit_code = _run_prune()
    finally:
        sys.stdout = old_stdout
        sys.stderr = old_stderr

    logger = get_run_logger()
    if out.getvalue().strip():
        for line in out.getvalue().strip().splitlines():
            logger.info(line)
    if err.getvalue().strip():
        for line in err.getvalue().strip().splitlines():
            logger.warning(line)

    if exit_code != 0:
        raise RuntimeError(
            f"registry prune exited with {exit_code}\nstdout:\n{out.getvalue() or '(none)'}\nstderr:\n{err.getvalue() or '(none)'}"
        )
    return exit_code
