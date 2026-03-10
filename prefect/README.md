# Prefect flow code

This directory is synced to the server and bind-mounted into the Prefect worker container. One Ansible sync deploys both flows and scripts.

- **`flows/`** — Python flow modules. One noop flow (`noop.py`) is included so `prefect deploy --all` succeeds at install time. Add more flows (e.g. `backup.py`, `registry_prune.py`) in follow-ups.
- **`scripts/`** — Scripts that flows run (shell or Python). The worker invokes these; they live next to the flow code so one sync deploys everything.

**`prefect.yaml`** defines the project and one deployment (noop) so the server-role register step runs without error. Use the key **`deployments`** (plural)—that is what `prefect deploy --all` reads. When you add flows, add entries under `deployments` in that file.
