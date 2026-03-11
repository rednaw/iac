"""Registry prune flow: runs the registry_prune script (keep N newest tags, protect deployed, then GC)."""

import subprocess
import sys
from pathlib import Path

from prefect import flow
from prefect.logging import get_run_logger


@flow
def registry_prune():
    """
    Run the registry prune script: prune old image tags per registry_prune_config.yml,
    protect the currently deployed tag, then run registry garbage-collect.
    """
    etc_dir = Path(__file__).resolve().parent / "etc"
    script = etc_dir / "registry_prune.py"
    if not script.exists():
        raise FileNotFoundError(f"Script not found: {script}")
    # Run with prefect project root as cwd so script can resolve paths
    prefect_root = Path(__file__).resolve().parent.parent.parent
    result = subprocess.run(
        [sys.executable, str(script)],
        cwd=prefect_root,
        capture_output=True,
        text=True,
        timeout=600,
    )
    if result.returncode != 0:
        out = (result.stdout or "").strip() or "(none)"
        err = (result.stderr or "").strip() or "(none)"
        raise RuntimeError(
            f"registry_prune.py exited with {result.returncode}\nstdout:\n{out}\nstderr:\n{err}"
        )
    # Log script output so it appears in the flow run logs in the UI
    logger = get_run_logger()
    if result.stdout and result.stdout.strip():
        for line in result.stdout.strip().splitlines():
            logger.info(line)
    if result.stderr and result.stderr.strip():
        for line in result.stderr.strip().splitlines():
            logger.warning(line)
    return result.returncode
