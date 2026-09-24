#!/usr/bin/env python3
"""
Do a full circle infrastructure recreation: apply, wait for server, bootstrap, run, destroy.

Usage: validate-stack.py
"""

import subprocess
import sys
import time


def run_task(task_name: str, *args: str) -> int:
    """Run a task command with optional CLI args after --. Returns exit code."""
    cmd = ['task', task_name]
    if args:
        cmd.append('--')
        cmd.extend(args)

    result = subprocess.run(cmd, check=False)
    return result.returncode


def wait_for_server(timeout: int = 300, interval: int = 10) -> bool:
    """Wait for the platform server to be ready after terraform apply."""
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
    print("🧪 Testing full stack (platform)")
    print("")

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("1️⃣  Applying Terraform changes...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    exit_code = run_task("platform:provision:apply")
    if exit_code != 0:
        print("\n❌ Step failed: Applying Terraform changes")
        sys.exit(exit_code)
    print("")

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("2️⃣  Waiting for server to be ready...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    if not wait_for_server():
        print("\n❌ Step failed: Server not ready")
        sys.exit(1)
    print("")

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("2️⃣b Accepting new host key (hostkeys:accept)...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    exit_code = run_task("hostkeys:accept", "platform")
    if exit_code != 0:
        print("\n❌ Step failed: Accepting host key")
        sys.exit(exit_code)
    print("")

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("3️⃣  Bootstrapping server (one-time setup as root)...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    exit_code = run_task("platform:configure:bootstrap")
    if exit_code != 0:
        print("\n❌ Step failed: Bootstrapping server")
        sys.exit(exit_code)
    print("")

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("4️⃣  Running full Ansible playbook...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    exit_code = run_task("platform:configure:apply")
    if exit_code != 0:
        print("\n❌ Step failed: Running Ansible playbook")
        sys.exit(exit_code)
    print("")

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("5️⃣  Destroying infrastructure...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    exit_code = run_task("platform:provision:destroy")
    if exit_code != 0:
        print("\n❌ Step failed: Destroying infrastructure")
        sys.exit(exit_code)
    print("")

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("✅ Full stack test completed successfully!")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")


if __name__ == "__main__":
    main()
