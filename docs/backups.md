# Backups

**Current setup:** Hetzner automated backups. Enabled in Terraform with `backups = true` on `hcloud_server.platform`. Seven image-level restore points; no backup scripts to run. See [Hetzner Cloud: Backups and snapshots](https://docs.hetzner.com/cloud/servers/backups-snapshots/overview) for the official documentation.

## How it works

- **Terraform:** The platform server (`hcloud_server.platform`, name `platform-<env>`) has `backups = true`. After `terraform apply`, Hetzner starts making automatic image backups of that server.
- **Hetzner:** Keeps up to 7 backup images, on a schedule they choose. Billing: 20% of the server’s monthly price.
- **What’s backed up:** Full server image (disk snapshot). Everything on the server at backup time is in the image.

## How to restore

**From the IaC Devcontainer :**

- `task backup:list -- <dev|prod>` — List backup images for the platform server (`platform-dev` or `platform-prod`). Note the `id` of the image you want.
- `task backup:restore -- <dev|prod> <image-id>` — Restore the server from a specific backup (calls `scripts/backup-restore.sh`; prompts for confirmation).
- `task backup:restore-latest -- <dev|prod>` — Restore from the most recent backup (prompts for confirmation).

Both restore commands run `hcloud server rebuild <server-name> --image <image-id>`: the existing server is rebuilt from the backup image in place (same server ID and IP). They are destructive and ask you to type `yes` before proceeding.

**Manually (Hetzner Cloud Console or API):** In the Hetzner Cloud Console, go to your server → Backups (or Images), or use the API/CLI. To restore in place, use `hcloud server rebuild <server-name> --image <image-id>`. To create a new server from a backup image instead, use the image when creating a new server (you get a new IP and ID; point DNS at it and fix Terraform state or import the new server).

**After an in-place restore:** The server reboots with the backup disk. Platform containers (Traefik, registry, OpenObserve) have `restart_policy: unless-stopped` and come back automatically. Deployed apps only restart if their `docker-compose.yml` sets `restart: unless-stopped` for each service — see [Application deployment](application-deployment.md).

## Relation to other docs

- [Application deployment](application-deployment.md) — App compose should set `restart: unless-stopped` so the app survives reboot/restore.
