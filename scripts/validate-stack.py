#!/usr/bin/env python3
"""
Do a full circle infrastructure recreation: apply, wait for server, bootstrap, run, destroy.

Usage: validate-stack.py [dev|prod]
"""

import subprocess
import sys
import time
from pathlib import Path


def run_task(task_name: str, workspace: str = None) -> int:
    """Run a task command. Returns exit code."""
    cmd = ['task', task_name]
    if workspace:
        cmd.extend(['--', workspace])
    
    result = subprocess.run(cmd, check=False)
    return result.returncode


def wait_for_server(workspace: str, timeout: int = 300, interval: int = 10) -> bool:
    """
    Wait for server to be ready after terraform apply.
    
    Args:
        workspace: Workspace name (dev or prod)
        timeout: Maximum time to wait in seconds (default: 5 minutes)
        interval: Time between checks in seconds (default: 10 seconds)
    
    Returns:
        True if server is ready, False if timeout exceeded
    """
    print(f"⏳ Waiting for server to be ready (timeout: {timeout}s, check every {interval}s)...")
    print("")
    
    start_time = time.time()
    attempt = 1
    
    while time.time() - start_time < timeout:
        print(f"   Attempt {attempt}: Checking server status...", end='\r')
        
        result = run_task('server:check-status')
        if result == 0:
            print(f"\n✅ Server is ready after {int(time.time() - start_time)}s")
            return True
        
        time.sleep(interval)
        attempt += 1
    
    print(f"\n❌ Timeout: Server not ready after {timeout}s")
    return False


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("❌ Error: Workspace required")
        print(f"Usage: {sys.argv[0]} [dev|prod]")
        sys.exit(1)
    
    workspace = sys.argv[1]
    
    if workspace not in ('dev', 'prod'):
        print(f"❌ Error: Invalid workspace '{workspace}'. Use: dev or prod")
        sys.exit(1)
    
    print(f"🧪 Testing full stack for workspace: {workspace}")
    print("")
    
    # Step 1: Apply
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("1️⃣  Applying Terraform changes...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    exit_code = run_task("terraform:apply", workspace)
    if exit_code != 0:
        print("\n❌ Step failed: Applying Terraform changes")
        sys.exit(exit_code)
    print("")
    
    # Step 2: Wait for server to be ready
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("2️⃣  Waiting for server to be ready...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    if not wait_for_server(workspace):
        print("\n❌ Step failed: Server not ready")
        sys.exit(1)
    print("")
    
    # Step 3: Bootstrap
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("3️⃣  Bootstrapping server (one-time setup as root)...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    exit_code = run_task("ansible:bootstrap", workspace)
    if exit_code != 0:
        print("\n❌ Step failed: Bootstrapping server")
        sys.exit(exit_code)
    print("")
    
    # Step 4: Run
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("4️⃣  Running full Ansible playbook...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    exit_code = run_task("ansible:run", workspace)
    if exit_code != 0:
        print("\n❌ Step failed: Running Ansible playbook")
        sys.exit(exit_code)
    print("")
    
    # Step 5: Destroy
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("5️⃣  Destroying infrastructure...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    exit_code = run_task("terraform:destroy", workspace)
    if exit_code != 0:
        print("\n❌ Step failed: Destroying infrastructure")
        sys.exit(exit_code)
    print("")
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("✅ Full stack test completed successfully!")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")


if __name__ == "__main__":
    main()
