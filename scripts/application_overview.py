#!/usr/bin/env python3
import sys
import subprocess
import yaml
import json
from pathlib import Path

REGISTRY = "registry.rednaw.nl"

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

def get_hostname(workspace: str) -> str:
    hostnames = {
        "dev": "dev.rednaw.nl",
        "prod": "prod.rednaw.nl",
    }
    if workspace not in hostnames:
        die(f"Invalid workspace '{workspace}'. Use: dev or prod")
    return hostnames[workspace]


def read_remote_file(hostname: str, path: str) -> str:
    return run(
        f'ssh -o StrictHostKeyChecking=accept-new '
        f'-o ConnectTimeout=5 '
        f'-o BatchMode=yes '
        f'ubuntu@{hostname} "cat {path} 2>/dev/null"'
    )


# ------------------------------------------------------------
# Deployment state
# ------------------------------------------------------------

def get_current_deployed_digest(hostname: str, app_name: str, workspace: str) -> str:
    """
    Return the digest of the *currently deployed* image for the workspace,
    based on the last matching entry in deploy-history.yml.
    """
    path = f"/opt/giftfinder/{app_name}/deploy-history.yml"
    content = read_remote_file(hostname, path)
    if not content:
        return ""

    data = yaml.safe_load(content)
    if not isinstance(data, list):
        return ""

    # Only entries for this workspace
    entries = [
        e for e in data
        if e.get("deployment", {}).get("workspace") == workspace
    ]

    if not entries:
        return ""

    latest = entries[-1]
    digest = latest.get("image", {}).get("digest", "").strip()

    if digest and not digest.startswith("sha256:"):
        digest = f"sha256:{digest}"

    return digest


# ------------------------------------------------------------
# Registry helpers
# ------------------------------------------------------------

def list_tags(full_repo: str) -> list[str]:
    output = run(f"crane ls {full_repo} 2>/dev/null || true")
    return sorted(output.splitlines(), reverse=True)


def get_image_metadata(full_repo: str, tag: str) -> tuple[str, str, str]:
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
    print(f"  {'':2} {'TAG':16} {'CREATED':20} {'DESCRIPTION':40}")
    print(f"  {'':2} {'---':16} {'-------':20} {'-----------':40}")


def print_overview(full_repo: str, tags: list[str], deployed_digest: str):
    print_header()

    for tag in tags:
        digest, created, description = get_image_metadata(full_repo, tag)
        marker = "→" if digest and digest == deployed_digest else ""
        print(f"  {marker:2} {tag:16} {created:20} {description:40}")

    print("")


# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

def main():
    args = sys.argv[1:]

    if len(args) != 2:
        die("Usage: task application:overview -- <WORKSPACE> <IMAGE_REPO>")

    workspace, image_repo = args
    hostname = get_hostname(workspace)

    full_repo = f"{REGISTRY}/{image_repo}"
    app_name = Path(image_repo).name

    print(f"IMAGE: {image_repo}\n")

    deployed_digest = get_current_deployed_digest(
        hostname, app_name, workspace
    )

    tags = list_tags(full_repo)
    if not tags:
        print("  ℹ️  No tags found")
        return

    print_overview(full_repo, tags, deployed_digest)


if __name__ == "__main__":
    main()
