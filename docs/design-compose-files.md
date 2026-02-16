# Design: Application Deployment and Compose Layout

**Status:** Design decided

One compose file for the full stack. Deploy copies it and runs with `IMAGE=<digest>`. App devs work in a devcontainer that builds the app container from source; local run outside the devcontainer is optional and can be added later.

---

## Chosen design

- **One compose file** (`docker-compose.yml`) defines the full stack: app service with `image: ${IMAGE}`, database, and any other services. Deploy copies this file and `.env` to the server; no multi-file list.
- **App devs work in a devcontainer.** The devcontainer must **build the app container** from source (not rely on a pre-built image). Use the same `docker-compose.yml` via `dockerComposeFile` in devcontainer.json, plus a **minimal** override under `.devcontainer/` that does only what’s needed: override the app service with `build: .` (and an `image:` tag so the built image is named). Nothing more.
- **Local run** (e.g. `docker compose up` on the host) is optional; apps can add a `docker-compose.override.yml` later if they want.

---

## Changes in this project (IaC repo) — done

| Action | Detail |
|--------|--------|
| **Document the contract** | In `docs/application-deployment.md`: single `docker-compose.yml` defines full stack; app service uses `image: ${IMAGE}`; deploy copies only that file (plus `.env`). |
| **Document app dev workflow** | In `docs/application-deployment.md`: app dev is devcontainer-first; devcontainer builds the app via minimal override under `.devcontainer/`; local compose run optional. Design Principles updated. |
| **Deploy logic** | No change. |
| **Devcontainer mount** | No change. |

---

## Changes in the app project — done where possible

| Action | Detail |
|--------|--------|
| **Single full-stack compose file** | One `docker-compose.yml` in the app repo root with app (`image: ${IMAGE}`), database, and any other services. **App repo:** merge `docker-compose.base.yml` into `docker-compose.yml` so the `db` (and other) services are defined in this file; remove or stop using the base file for deploy. |
| **Devcontainer builds the app** | `.devcontainer/docker-compose.yml` added: minimal override (app service only: `build: .`, `image: tientje-ketama:dev`). **App repo:** in `.devcontainer/devcontainer.json`, set `dockerComposeFile` to `["../docker-compose.yml", "docker-compose.yml"]` so this override is used. |
| **Local run (optional)** | If desired later, add `docker-compose.override.yml` in the app repo with `build: .` and `image: myapp:dev` for the app service. |
