#!/usr/bin/env python3
import sys
import subprocess
import yaml
import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

# ANSI color codes
BOLD = "\033[1m"
RESET = "\033[0m"

# ------------------------------------------------------------
# Utilities
# ------------------------------------------------------------

def run(cmd: str) -> str:
    """Run a shell command and return stdout (trimmed)."""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip()


def die(message: str):
    print(f"❌ {message}")
    sys.exit(1)


# ------------------------------------------------------------
# Workspace / remote helpers
# ------------------------------------------------------------

def get_platform_ip() -> str:
    ip = run("task hostkeys:ip -- platform")
    if not ip:
        die("Could not resolve platform IPv4 (task hostkeys:ip -- platform)")
    return ip


def read_remote_file(ip: str, path: str) -> str:
    return run(
        f'ssh -4 -o StrictHostKeyChecking=accept-new '
        f'-o ConnectTimeout=5 '
        f'-o BatchMode=yes '
        f'ubuntu@{ip} "cat {path} 2>/dev/null"'
    )


# ------------------------------------------------------------
# Deployment state
# ------------------------------------------------------------

def get_current_deployed_digest(ip: str, app_name: str) -> str:
    """Return the digest of the currently deployed image (last history entry)."""
    path = f"/opt/iac/deploy/{app_name}/deploy-history.yml"
    content = read_remote_file(ip, path)
    if not content:
        return ""

    data = yaml.safe_load(content)
    if not isinstance(data, list) or not data:
        return ""

    latest = data[-1]
    digest = latest.get("image", {}).get("digest", "").strip()

    if digest and not digest.startswith("sha256:"):
        digest = f"sha256:{digest}"

    return digest


# ------------------------------------------------------------
# Registry helpers
# ------------------------------------------------------------

def list_tags(full_repo: str) -> list[str]:
    output = run(f"crane ls {full_repo} 2>/dev/null || true")
    return output.splitlines()


def parse_timestamp(ts: str) -> datetime | None:
    """Parse timestamp string to datetime object for sorting."""
    if not ts:
        return None

    try:
        if "T" in ts:
            return datetime.fromisoformat(ts.replace("Z", "+00:00"))
        # Try parsing as formatted timestamp (naive)
        return datetime.strptime(ts, "%Y-%m-%d %H:%M:%S")
    except (ValueError, AttributeError):
        return None


def _sort_key_timestamp(ts: str) -> tuple[bool, float]:
    """Return (is_empty, comparable_float) so sort never mixes naive/aware datetimes.
    Empty timestamps sort last (reverse=True: newest first, then empty at end)."""
    dt = parse_timestamp(ts)
    if dt is None:
        return True, 0.0  # (True, 0) < (False, ts) so empty last when reverse=True
    # Use timestamp() so newest is largest; naive and aware are comparable
    return False, dt.timestamp()


def get_image_metadata(full_repo: str, tag: str) -> tuple[str, str, str]:
    """Fetch digest and config for one tag. Used sequentially or from a thread."""
    tag_ref = f"{full_repo}:{tag}"

    digest = run(f"crane digest {tag_ref} 2>/dev/null || echo ''").strip()
    if digest and not digest.startswith("sha256:"):
        digest = f"sha256:{digest}"

    config_raw = run(f"crane config {tag_ref} 2>/dev/null || echo ''")

    created = ""
    description = ""

    if config_raw:
        try:
            config = json.loads(config_raw)
            labels = config.get("config", {}).get("Labels", {})
            created = labels.get("org.opencontainers.image.created", "").split("+")[0]
            description = labels.get("org.opencontainers.image.description", "")
        except json.JSONDecodeError:
            pass

    if len(description) > 38:
        description = description[:38]

    return digest, created, description


# ------------------------------------------------------------
# Output
# ------------------------------------------------------------

def print_header():
    print(f"  {'':2} {'CREATED':20} {'TAG':16} {'DESCRIPTION':40}")
    print(f"  {'':2} {'-------':20} {'---':16} {'-----------':40}")


def print_overview(full_repo: str, tags: list[str], deployed_digest: str):
    # Collect all image metadata in parallel (crane digest/config per tag are I/O-bound)
    max_workers = min(20, max(4, len(tags)))
    images = []
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_tag = {
            executor.submit(get_image_metadata, full_repo, tag): tag
            for tag in tags
        }
        for future in as_completed(future_to_tag):
            tag = future_to_tag[future]
            try:
                digest, created, description = future.result()
                images.append({
                    "tag": tag,
                    "digest": digest,
                    "created": created,
                    "description": description,
                    "is_deployed": digest and digest == deployed_digest,
                })
            except Exception:
                images.append({
                    "tag": tag,
                    "digest": "",
                    "created": "",
                    "description": "",
                    "is_deployed": False,
                })
    
    # Sort by timestamp (newest first), images without timestamps go to end
    images.sort(key=lambda x: _sort_key_timestamp(x["created"]), reverse=True)
    
    # print_header()
    
    for img in images:
        tag = img["tag"]
        created = img["created"]
        description = img["description"]
        is_deployed = img["is_deployed"]
        row = f"  {created:20} {description:40} {tag:16}"
        if is_deployed:
            print(f"{BOLD} -> {row}{RESET}")
        else:
            print(f"    {row}")
    
    print("")


# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

def main():
    args = sys.argv[1:]

    if len(args) != 3:
        die(
            "Usage: task app:versions -- <app>\n"
            "Example: task app:versions -- tientje-ketama"
        )

    registry, image_repo, deploy_slug = args
    ip = get_platform_ip()

    full_repo = f"{registry}/{image_repo}"
    app_name = deploy_slug

    print(f"IMAGE: {image_repo}\n")

    deployed_digest = get_current_deployed_digest(ip, app_name)

    tags = list_tags(full_repo)
    if not tags:
        print("  ℹ️  No tags found")
        return

    print_overview(full_repo, tags, deployed_digest)


if __name__ == "__main__":
    main()
