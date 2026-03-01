# Observer: read-only server access for the agent

The Cursor agent can run in the **devcontainer** (B1) and talk to the server only via SSH. That keeps the agent off the server and is safer. This document describes **observer mode**: a server-side user and wrapper so that when the agent runs SSH from the devcontainer, it gets full read access and diagnostics but **no** writes or state changes.

**Status:** Implemented. Use **observer@dev** or **observer@prod** for read-only SSH; **ubuntu@dev** / **ubuntu@prod** for admin.

---

## Cursor agent: use observer only for server investigation

**When you (the Cursor agent) need to run commands on the server to inspect logs, status, or config, use only this entry point:**

```bash
task server:observe -- <dev|prod> '<command>'
```

Examples:
- `task server:observe -- dev 'docker ps'`
- `task server:observe -- dev 'journalctl -u traefik -n 50'`
- `task server:observe -- prod 'systemctl status docker'`

**Do not use** `ssh dev`, `ssh prod`, or the ubuntu user for investigation. Use `task server:observe` so all server inspection goes through the read-only observer channel.

---

## Overview

- **Goal:** The agent (in the devcontainer) uses SSH to run commands on the server. Those sessions should be **read-only**: full read and listing/diagnostics, no filesystem writes (except in allowed dirs), no starting/stopping services or containers.
- **Means:** A dedicated **observer** user on the server. It has no direct sudo; it can only run one wrapper, **observer-run**, which runs the command as root inside **bubblewrap (bwrap)** for a read-only filesystem, with an **allowlist** for `docker` and `systemctl` (only read-only subcommands; all other commands allowed).
- **Usage:** Same hosts **dev** and **prod**. **ubuntu@dev** / **ubuntu@prod** = admin. **observer@dev** / **observer@prod** = read-only.

---

## Architecture: agent in devcontainer (B1)

The recommended setup is **B1**: the agent runs only in the devcontainer. It never runs on the server. When it needs server data (logs, status, config), it runs `ssh <host> '...'` from the devcontainer. The server is just a target.

| Where        | What runs                          |
|-------------|-------------------------------------|
| Devcontainer| Cursor, agent, Task, Ansible, repo  |
| Server      | SSH target; observer or ubuntu user|

So observer is a **server-side** user and script. The agent stays in the devcontainer and reaches the server via SSH as observer (read-only) or ubuntu (when you run Ansible/deploys yourself).

---

## Observer on the server

### User and sudo

| User      | Purpose                    | Sudo |
|-----------|----------------------------|------|
| **ubuntu**| Ansible, manual admin      | Full (unchanged) |
| **observer** | Read-only diagnostics  | Only `observer-run` |

- **observer** is a separate system user. Same SSH keys as ubuntu (or a subset), so one key can connect as either user: `ssh ubuntu@dev` or `ssh observer@dev`.
- Single sudo rule: `observer ALL=(ALL) NOPASSWD: /usr/local/bin/observer-run *`. No other sudo.

### observer-run wrapper

A root-owned script `/usr/local/bin/observer-run` that:

1. **Allowlist:** Only entries in **`/etc/observer-allowed-commands`** are allowed. One entry per line; lines starting with `#` and blank lines are ignored. To allow a new command, add a line and redeploy (no script change). Format:
   - **docker:** `docker:ps`, `docker:logs`, …; two-word subcommands as `docker:system:df`, `docker:volume:ls`, etc.
   - **systemctl:** `systemctl:status`, `systemctl:show`, …
   - **Other:** plain basename, e.g. `cat`, `journalctl`, `jq`. The file ships with a default set (docker read-only subcommands, systemctl read-only subcommands, and common read-only CLI tools).
2. **bwrap (bubblewrap):** Runs the command as root inside a bwrap sandbox: **read-only /** (including **/run**, so the Docker socket and D-Bus are visible but not writable) with writable **/home/observer**, **/tmp**, **/home/ubuntu**. Also **/dev**, **/proc**, **/sys**. Must be invoked as **sudo observer-run** (script exits with a clear error if not root). Requires the **bubblewrap** package (installed by Ansible). Keeping /run read-only means e.g. `journalctl --vacuum-*` cannot remove log files.

Result:

- **Allowed:** Read any file, list and inspect (e.g. `sudo observer-run cat /etc/shadow`, `sudo observer-run docker ps`, `sudo observer-run journalctl -u traefik -n 50`). Writes only under `/home/observer`, `/tmp`, `/home/ubuntu`.
- **Blocked:** Any `docker` or `systemctl` subcommand not on the allowlist; any other command whose basename is not in the general allowlist (e.g. `bash`, `curl`, `python3`); writes outside the allowed dirs (bwrap).

### Allowed vs blocked

| Allowed | Blocked |
|---------|---------|
| Read any file (with sudo observer-run) | Write outside `/home/observer`, `/tmp`, `/home/ubuntu` (bwrap) |
| Any entry in `/etc/observer-allowed-commands` (docker/systemctl subcommands + general basenames) | Anything not in the allowlist file |

### How to connect

- **ubuntu@dev**, **ubuntu@prod** — admin (or `ssh dev` / `ssh prod`).
- **observer@dev**, **observer@prod** — read-only. Use **dev-observer** / **prod-observer** in SSH config when the tunnel is up (no port forwards). A wrapper in the observer’s `~/bin` runs `sudo observer-run` so you can run `observer-run docker ps` without typing `sudo`.

Examples: `ssh dev-observer 'observer-run docker ps'`, `ssh dev-observer 'observer-run journalctl -u traefik -n 50'`. A wrapper in `~/bin` runs `sudo observer-run` for you, so you don’t need to type `sudo`; you can still use `sudo observer-run ...` if you prefer.

---

## Implementation (when you add observer)

- **Ansible:** Create user **observer**, copy authorized_keys from ubuntu (or manage keys separately). Install **bubblewrap**, deploy **`/etc/observer-allowed-commands`** (allowlist), install `/usr/local/bin/observer-run`, deploy `/etc/sudoers.d/90-observer`. Install a wrapper at **`/home/observer/bin/observer-run`** that runs `sudo /usr/local/bin/observer-run "$@"`, and add `~/bin` to PATH in observer’s `.profile`, so the observer can run `observer-run …` without typing `sudo`. To allow another command: add a line to the allowlist file in the role and redeploy.
- **observer-run:** Reads allowlist from **`/etc/observer-allowed-commands`**; if the command is allowed, runs it in bwrap. Requires **bubblewrap** package. To extend: add a line to the allowlist file (and redeploy); no need to edit the script.
- **SSH config:** **dev** / **prod** only (User ubuntu). Connect as observer with **observer@dev** / **observer@prod**. Written by `setup-remote-ssh.sh`.

---

## Edge cases and caveats

- **CLI tools that write outside allowed dirs:** Some programs write to `/var/cache` or `~/.cache`. With only `/home/observer`, `/tmp`, and optionally `/home/ubuntu` writable, those writes fail. You can add `--bind /var/cache /var/cache` (and/or `/var/tmp`) to observer-run if acceptable.
- **Docker socket:** `/run` is part of the read-only root, so `/run/docker.sock` is visible and the Docker client can connect (socket connections don’t require write). Only allowlisted docker subcommands run; `docker run`, `docker system prune`, etc. are rejected by the allowlist.
- **Allowlist:** Stored in **`/etc/observer-allowed-commands`**. Add a line to allow a new command (e.g. `jq` or `docker:exec` if you ever need it); no script edit. Keeps the script small and avoids interpreters/network tools by default.

---

## Alternatives considered

- **Restrict sudo for ubuntu:** Would break Ansible (runs as ubuntu with sudo). Not viable.
- **Same user, “observer mode” via sudo:** Sudo can’t express “this session is read-only.” Need a separate user.
- **Agent on the server (Remote-SSH):** Agent runs on the server as ubuntu or observer. Works but puts the agent on the server; B1 keeps it in the devcontainer only.

---

## Summary

- **Observer** = server user + **observer-run** wrapper (bwrap read-only + allowlist for docker/systemctl). Use **observer@dev** / **observer@prod**.
- **B1:** Agent in devcontainer; SSH to server as observer (read-only) or ubuntu (admin).
