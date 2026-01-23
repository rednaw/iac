# Registry and containers cheat sheet

Quick reference for **Crane** and **Docker** commands used to inspect the private registry and deployed containers. Auth: use `docker login <registry>` (or `crane auth login`) with credentials from `secrets/infrastructure-secrets.yml.enc` before running read/write commands.

---

## Crane (registry)

| Task | Command |
|------|---------|
| List tags for an image | `crane ls <registry>/<image>` e.g. `crane ls registry.rednaw.nl/rednaw/hello-world` |
| Get digest of a tag | `crane digest <registry>/<image>:<tag>` |
| Inspect manifest | `crane manifest <registry>/<image>:<tag>` |
| Delete a tag (e.g. SHA-only, manual prune) | `crane delete <registry>/<image>:<tag>` |

**Filter SHA-like tags** (for prune candidates):  
`crane ls <registry>/<image> | grep -E '^[0-9a-f]{7}$'`

---

## Docker (server / local)

| Task | Command |
|------|---------|
| See which image a container runs | `docker inspect <container> --format '{{.Config.Image}}'` or `docker inspect <container>` and check `Config.Image` |
| Disk usage (images, containers, volumes) | `docker system df` |
| List running containers | `docker ps` |

---

## Registry host (storage)

| Task | Command |
|------|---------|
| Registry data size | `du -sh /var/lib/registry` (or the registry’s `rootdirectory`; path depends on your registry config) |

---

## Example: find SHA-only tags to prune

```bash
# After logging in (docker login registry.rednaw.nl):
crane ls registry.rednaw.nl/rednaw/hello-world | grep -E '^[0-9a-f]{7}$'
# Then delete if safe, e.g.:
# crane delete registry.rednaw.nl/rednaw/hello-world:<sha>
```

---

See **application-deployment.md** for the full deployment workflow.
