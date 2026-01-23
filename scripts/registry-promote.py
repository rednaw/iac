#!/usr/bin/env python3
"""
Promote a container image by tagging a SHA-tagged image with a semantic version.

Usage: registry-promote.py <WORKSPACE> <APP_ROOT> <SHA> <SEMVER>

This script:
1. Validates inputs (WORKSPACE, APP_ROOT, SHA, SEMVER)
2. Reads deployment configuration from $APP_ROOT/deploy.yml
3. Decrypts infrastructure secrets to get registry credentials
4. Logs into Docker registry
5. Pulls the SHA-tagged image
6. Tags it with the semantic version
7. Pushes the semantic version tag
8. Adds OCI annotation linking semver back to SHA

Fails if the semantic tag already exists.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("❌ Error: PyYAML is required. Install with: pip install PyYAML", file=sys.stderr)
    sys.exit(1)


def get_iac_root() -> Path:
    """Derive IAC root from this script's location."""
    script_dir = Path(__file__).resolve().parent
    return script_dir.parent


def validate_workspace(workspace: str) -> None:
    """Validate workspace is dev or prod."""
    if workspace not in ('dev', 'prod'):
        print(f"❌ Error: Invalid workspace '{workspace}'. Must be 'dev' or 'prod'", file=sys.stderr)
        sys.exit(1)


def validate_sha(sha: str) -> None:
    """Validate SHA is a short commit SHA (7 hexadecimal characters)."""
    if not re.match(r'^[0-9a-f]{7}$', sha, re.IGNORECASE):
        print(f"❌ Error: Invalid SHA '{sha}'. Must be 7 hexadecimal characters (short SHA)", file=sys.stderr)
        sys.exit(1)


def validate_semver(semver: str) -> None:
    """Validate semantic version format (MAJOR.MINOR.PATCH, no 'v' prefix)."""
    if not re.match(r'^\d+\.\d+\.\d+$', semver):
        print(f"❌ Error: Invalid semver '{semver}'. Must be MAJOR.MINOR.PATCH (e.g. '1.2.3')", file=sys.stderr)
        sys.exit(1)


def validate_app_root(app_root: Path) -> None:
    """Validate app root exists and is a directory."""
    if not app_root.exists():
        print(f"❌ Error: App root does not exist: {app_root}", file=sys.stderr)
        sys.exit(1)
    if not app_root.is_dir():
        print(f"❌ Error: App root is not a directory: {app_root}", file=sys.stderr)
        sys.exit(1)


def read_deploy_config(deploy_yml_path: Path) -> dict:
    """Read and parse deployment configuration from deploy.yml."""
    # Assume deploy.yml is a valid Ansible playbook
    with open(deploy_yml_path, 'r') as f:
        deploy_yml = yaml.safe_load(f)
    
    # Extract vars from the play (first play in the list)
    for doc in deploy_yml:
        if isinstance(doc, dict) and 'hosts' in doc and 'vars' in doc:
            return doc['vars']
    
    raise ValueError("Could not find vars in deploy.yml play")


def decrypt_secrets(iac_root: Path) -> dict:
    """Decrypt infrastructure secrets using SOPS."""
    secrets_file = iac_root / 'secrets' / 'infrastructure-secrets.yml.enc'
    
    if not secrets_file.exists():
        print(f"❌ Error: Secrets file not found: {secrets_file}", file=sys.stderr)
        sys.exit(1)
    
    # Get SOPS key file from environment or default location
    home = Path.home()
    username = os.getenv('USER', os.getenv('USERNAME', 'unknown'))
    sops_key_file = home / '.config' / 'sops' / 'age' / f'keys-{username}.txt'
    
    env = os.environ.copy()
    env['SOPS_AGE_KEY_FILE'] = str(sops_key_file)
    
    try:
        result = subprocess.run(
            ['sops', '-d', '--input-type', 'yaml', '--output-type', 'yaml', str(secrets_file)],
            capture_output=True,
            text=True,
            check=True,
            env=env
        )
    except subprocess.CalledProcessError as e:
        print(f"❌ Error: Failed to decrypt secrets: {e.stderr}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print("❌ Error: 'sops' command not found. Install SOPS first.", file=sys.stderr)
        sys.exit(1)
    
    try:
        secrets = yaml.safe_load(result.stdout)
    except yaml.YAMLError as e:
        print(f"❌ Error: Failed to parse decrypted secrets: {e}", file=sys.stderr)
        sys.exit(1)
    
    if not isinstance(secrets, dict):
        print("❌ Error: Decrypted secrets must be a YAML object", file=sys.stderr)
        sys.exit(1)
    
    required_secrets = ['registry_domain', 'registry_username', 'registry_password']
    missing = [field for field in required_secrets if field not in secrets]
    if missing:
        print(f"❌ Error: Missing required secrets: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)
    
    return secrets


def docker_login(registry_domain: str, username: str, password: str) -> None:
    """Log into Docker registry."""
    try:
        result = subprocess.run(
            ['docker', 'login', '--username', username, '--password-stdin', registry_domain],
            input=password,
            text=True,
            capture_output=True,
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"❌ Error: Docker login failed: {e.stderr}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print("❌ Error: 'docker' command not found. Install Docker first.", file=sys.stderr)
        sys.exit(1)


def docker_pull(image: str) -> None:
    """Pull Docker image."""
    try:
        subprocess.run(['docker', 'pull', image], check=True, capture_output=True)
    except subprocess.CalledProcessError as e:
        print(f"❌ Error: Failed to pull image {image}: {e.stderr.decode() if e.stderr else 'Unknown error'}", file=sys.stderr)
        sys.exit(1)


def docker_tag(source: str, target: str) -> None:
    """Tag Docker image."""
    try:
        subprocess.run(['docker', 'tag', source, target], check=True, capture_output=True)
    except subprocess.CalledProcessError as e:
        print(f"❌ Error: Failed to tag image: {e.stderr.decode() if e.stderr else 'Unknown error'}", file=sys.stderr)
        sys.exit(1)


def docker_push(image: str) -> None:
    """Push Docker image."""
    try:
        subprocess.run(['docker', 'push', image], check=True, capture_output=True)
    except subprocess.CalledProcessError as e:
        print(f"❌ Error: Failed to push image {image}: {e.stderr.decode() if e.stderr else 'Unknown error'}", file=sys.stderr)
        sys.exit(1)


def crane_mutate_add_annotation(image: str, annotation_key: str, annotation_value: str) -> None:
    """Add OCI annotation to an image using crane mutate."""
    try:
        # Use crane mutate to add annotation to the remote image
        # This will pull, mutate, and push the image
        subprocess.run(
            ['crane', 'mutate', image, '--annotation', f'{annotation_key}={annotation_value}'],
            check=True,
            capture_output=True
        )
    except subprocess.CalledProcessError as e:
        print(f"⚠️  Warning: Failed to add annotation: {e.stderr.decode() if e.stderr else 'Unknown error'}", file=sys.stderr)
        # Don't fail - annotation is nice to have but not critical
    except FileNotFoundError:
        print("⚠️  Warning: 'crane' command not found. Annotation not added.", file=sys.stderr)


def read_oci_annotation(image: str, annotation_key: str) -> str:
    """Read OCI annotation from an image manifest using crane."""
    try:
        result = subprocess.run(
            ['crane', 'manifest', image],
            capture_output=True,
            check=True,
            text=True
        )
        manifest = json.loads(result.stdout)
        # Check annotations (usually in .annotations)
        return manifest.get('annotations', {}).get(annotation_key, '')
    except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError):
        # If crane fails, return empty (description is optional)
        return ''


def check_tag_exists(image: str) -> bool:
    """Check if a tag already exists in the registry."""
    # Try to inspect the manifest - if it exists, the tag exists
    try:
        result = subprocess.run(
            ['docker', 'manifest', 'inspect', image],
            capture_output=True,
            check=False
        )
        return result.returncode == 0
    except FileNotFoundError:
        # If docker manifest doesn't exist, we'll try to pull and see if it fails
        # This is a fallback for older Docker versions
        return False


def main():
    """Main entry point."""
    if len(sys.argv) != 5:
        print("❌ Error: Invalid number of arguments", file=sys.stderr)
        print(f"Usage: {sys.argv[0]} <WORKSPACE> <APP_ROOT> <SHA> <SEMVER>", file=sys.stderr)
        sys.exit(1)
    
    workspace = sys.argv[1]
    app_root_str = sys.argv[2]
    sha = sys.argv[3]
    semver = sys.argv[4]
    
    # Validate inputs
    validate_workspace(workspace)
    validate_sha(sha)
    validate_semver(semver)
    
    # Resolve and validate app root
    app_root = Path(app_root_str).resolve()
    validate_app_root(app_root)
    
    # Read deployment configuration from deploy.yml
    deploy_yml_path = app_root / 'deploy.yml'
    config = read_deploy_config(deploy_yml_path)
    registry_name = config['registry_name']
    image_name = config['image_name']
    
    # Derive IAC root
    iac_root = get_iac_root()
    
    # Decrypt secrets
    secrets = decrypt_secrets(iac_root)
    registry_domain = secrets['registry_domain']
    registry_username = secrets['registry_username']
    registry_password = secrets['registry_password']
    
    # Construct image references
    sha_image = f"{registry_name}/{image_name}:{sha}"
    semver_image = f"{registry_name}/{image_name}:{semver}"
    
    # Check if semantic tag already exists
    print(f"🔍 Checking if tag {semver} already exists...")
    if check_tag_exists(semver_image):
        print(f"❌ Error: Semantic tag {semver} already exists for {semver_image}", file=sys.stderr)
        print("   Refusing to overwrite existing semantic tag.", file=sys.stderr)
        sys.exit(1)
    
    # Login to registry
    print(f"🔐 Logging into registry {registry_domain}...")
    docker_login(registry_domain, registry_username, registry_password)
    
    # Pull SHA-tagged image
    print(f"📥 Pulling image {sha_image}...")
    docker_pull(sha_image)
    
    # Tag with semantic version
    print(f"🏷️  Tagging {sha_image} as {semver_image}...")
    docker_tag(sha_image, semver_image)
    
    # Push semantic version tag
    print(f"📤 Pushing {semver_image}...")
    docker_push(semver_image)
    
    # Read description from SHA-tagged image (if available)
    description = read_oci_annotation(sha_image, 'org.rednaw.description')
    
    # Add OCI annotation to store source SHA
    print(f"📝 Adding source SHA annotation...")
    crane_mutate_add_annotation(semver_image, 'org.rednaw.source-sha', sha)
    
    # Copy description annotation to semver-tagged image (if available)
    if description:
        print(f"📝 Adding description annotation...")
        crane_mutate_add_annotation(semver_image, 'org.rednaw.description', description)
    
    print(f"✅ Successfully promoted {sha_image} to {semver_image}")


if __name__ == '__main__':
    main()
