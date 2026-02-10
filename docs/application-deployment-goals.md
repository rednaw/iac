# Application Deployment: Goals and Design Intent

This document records what we are trying to achieve with the application deployment setup and why it is structured this way.

---

## What we are trying to do

**Run all deployment and ops from the IAC devcontainer.** App developers should not need to install Task, Ansible, or other IAC tooling on their workstations. The app repo stays “just code”: Dockerfile, docker-compose, optional secrets, and a small config file for the platform. Deployment and version listing are triggered from inside the IAC devcontainer, where the tools already live.

**Keep a single app per devcontainer (for now).** One host path points to the app clone; the devcontainer mounts it at a fixed location (`/workspaces/iac/app`) so tasks and playbooks can assume a known layout.

**Keep app config in the app repo.** The app remains the source of truth for “which registry and image.” We read that from a single file (`iac.yml`) in the app root. No duplication in IAC; no need for app repos to include IAC Taskfiles or run Ansible.

**Make the app mount explicit and documented.** The host path is provided via a file in the operator's home directory (`~/.config/iac-app-path`) and an OS-specific profile snippet (macOS: `~/.zprofile` + `launchctl setenv`; Linux: `~/.profile`) so that `APP_HOST_PATH` is in the environment of GUI-launched Cursor/VS Code (e.g. after a reboot). A script (`scripts/setup-app-path.sh`) sets the path and ensures the profile snippet is present. We document this in getting-started and in full in the application deployment guide. We add checks so that if the app is not mounted or `iac.yml` is missing, the failure is clear and points to the right docs.

---

## Outcomes

- **Ops:** Open the IAC repo in the devcontainer, set which app to mount (script or manual path file + profile), and run `task app:deploy` / `task app:versions` from there.
- **App developers:** Maintain `iac.yml`, `docker-compose.yml`, and (optionally) `secrets.yml`; no Task or Ansible in the app repo. They do not run deploy from their machine unless they also use the IAC devcontainer.
- **One new file in the app:** `iac.yml` with `REGISTRY_NAME` and `IMAGE_NAME`. Everything else (playbooks, scripts, host keys, registry auth) stays in IAC and runs in the devcontainer.

---

## What we are not doing (by design)

- **Backwards compatibility** with “run deploy from the app directory” or “include IAC Taskfile from the app.” We inverted the flow; the old contract is retired.
- **Special handling** for any particular app (e.g. hello-world). Whatever is mounted at `/workspaces/iac/app` is “the app”; no branching on app name.
- **Auto-loading env files** for the devcontainer mount. The Dev Containers spec does not read `.env` for variable substitution; we use a path file (`~/.config/iac-app-path`) and profile snippets so the session has `APP_HOST_PATH` (macOS/Linux).
- **Multiple apps in one devcontainer** for now. One `APP_HOST_PATH` → one mount. Multi-app could be a later extension.

---

## Reference

- **Getting started:** [getting-started.md](getting-started.md) — reminder to set which app to mount (script) and link to application deployment.
- **Full technical detail:** [application-deployment.md](application-deployment.md) — app mount, commands, `iac.yml`, troubleshooting.
