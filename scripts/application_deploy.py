#!/usr/bin/env python3
import sys
import subprocess
import os
import yaml
import json
from pathlib import Path

def run(cmd, capture_output=True, check=False, cwd=None, env=None):
    """Run a shell command and return its stdout."""
    result = subprocess.run(
        cmd, shell=True, capture_output=capture_output, text=True, cwd=cwd, env=env
    )
    if check and result.returncode != 0:
        raise RuntimeError(f"Command failed: {cmd}\n{result.stderr}")
    return result.stdout.strip()


def extract_key(data, key):
    """Recursively search dicts/lists for a key and return its value."""
    if isinstance(data, dict):
        if key in data:
            return str(data[key]).strip()
        for v in data.values():
            val = extract_key(v, key)
            if val:
                return val
    elif isinstance(data, list):
        for item in data:
            val = extract_key(item, key)
            if val:
                return val
    return ""


def load_deploy_yml(app_root: Path):
    """Load deploy.yml and extract registry_name and image_name."""
    deploy_yml = app_root / "deploy.yml"
    if not deploy_yml.exists():
        print(f"❌ Error: deploy.yml not found in {app_root}")
        sys.exit(1)

    with open(deploy_yml) as f:
        data = yaml.safe_load(f)

    registry_name = extract_key(data, "registry_name")
    image_name = extract_key(data, "image_name")

    if not registry_name or not image_name:
        print("❌ Error: Could not extract registry_name and image_name from deploy.yml")
        sys.exit(1)

    return registry_name, image_name


def resolve_digest(image_ref: str):
    """Resolve image digest using crane."""
    print("🔍 Resolving tag → digest...")
    digest = run(f"crane digest {image_ref} 2>&1 || true")
    if not digest.startswith("sha256:"):
        print(f"❌ Error: Could not resolve digest for {image_ref}")
        if digest:
            print(f" {digest}")
        print(f"   Make sure the image exists in the registry and you're logged in")
        sys.exit(1)
    return digest


def get_image_metadata(image_ref: str):
    """Get image description and build date from crane config."""
    print("📋 Extracting image metadata...")
    config_output = run(f"crane config {image_ref} 2>/dev/null || echo ''")
    if not config_output:
        print("⚠️  Warning: Could not read image config, proceeding without metadata")
        return "", ""

    try:
        config = json.loads(config_output)
        description = config.get("config", {}).get("Labels", {}).get(
            "org.opencontainers.image.description", ""
        )
        built_at = config.get("config", {}).get("Labels", {}).get(
            "org.opencontainers.image.created", ""
        )
        return description, built_at
    except json.JSONDecodeError:
        return "", ""


def prepare_known_hosts(workspace: str):
    """Run hostkeys preparation task."""
    print("🔑 Preparing known_hosts...")
    run(f"task hostkeys:prepare -- {workspace}", check=True)


def deploy_with_ansible(
    workspace: str,
    app_root: Path,
    iac_repo: Path,
    deploy_target: str,
    image_digest: str,
    sha: str,
    description: str,
    built_at: str,
):
    """Run the Ansible playbook to deploy the application."""
    ansible_env = os.environ.copy()
    ansible_env["ANSIBLE_CONFIG"] = str(iac_repo / "ansible/ansible.cfg")

    run(
        f"ansible-playbook -i {iac_repo}/ansible/inventory/{workspace}.ini deploy.yml "
        f"-e iac_repo_root={iac_repo} "
        f"-e app_root={app_root} "
        f"-e deploy_target={deploy_target} "
        f"-e workspace={workspace} "
        f"-e image_digest={image_digest} "
        f"-e image_tag={sha} "
        f"-e image_description='{description}' "
        f"-e image_built_at='{built_at}'",
        cwd=str(app_root),
        env=ansible_env,
        check=True,
    )


def print_deploy_info(image_digest: str, sha: str):
    """Print deployment summary."""
    print("🚀 Deploying application...")
    print(f"   Image: {image_digest}")
    print(f"   Tag: {sha}")
    print("")


def main():
    # --- Parse arguments ---
    args = sys.argv[1:]
    if len(args) != 3:
        print("❌ Error: Invalid number of arguments (expected 3)")
        print("Usage: task application:deploy -- <WORKSPACE> <APP_ROOT> <SHA>")
        sys.exit(1)

    workspace, app_root_path, sha = args[:3]

    iac_repo = Path.cwd()
    app_root = Path(app_root_path).resolve()
    app_slug = app_root.name
    deploy_target = f"/opt/giftfinder/{app_slug}"

    # --- Load YAML and extract image info ---
    registry_name, image_name = load_deploy_yml(app_root)
    image_ref = f"{registry_name}/{image_name}:{sha}"
    digest = resolve_digest(image_ref)
    description, built_at = get_image_metadata(image_ref)
    image_digest = f"{registry_name}/{image_name}@{digest}"

    # --- Print info ---
    print_deploy_info(image_digest, sha)

    # --- Prepare and deploy ---
    prepare_known_hosts(workspace)
    deploy_with_ansible(
        workspace, app_root, iac_repo, deploy_target, image_digest, sha, description, built_at
    )

    print("\n✅ Deployment completed successfully!")


if __name__ == "__main__":
    main()
