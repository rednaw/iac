[**<---**](README.md)

# Backlog

- **Better backup** — Service-aware backups (Postgres + uploads) to Hetzner Storage Box. See [backup-storage-box.md](backup-storage-box.md) for the design.
- **Image cleanup automation** — Prune old images from the registry automatically (untagged and older tagged images).
- **App-specific security headers** — Per-app Traefik middleware for `Content-Security-Policy` and related headers, rather than a single shared default.
