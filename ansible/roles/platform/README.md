# Platform role

Composes the app-serving services on top of [`roles/base/`](../base/). Imported by [`playbooks/server.yml`](../../playbooks/server.yml) (after `base`).

Runs in this order so Traefik, registry auth paths, fail2ban log readers, and Prefect stay consistent:

1. fail2ban-traefik (jails reading Traefik logs)
2. traefik (reverse proxy)
3. iac-user (`iac` user, `/opt/iac/` tree)
4. registry (Docker registry behind Traefik)
5. openobserve (logs/metrics)
6. prefect (workflow runner)

## Co-location assumptions

Components are split into separate task files for readability, but they assume **single-host co-location**. Splitting components to different hosts needs explicit interfaces (networking, secrets) — see [`docs/future/restructuring.md`](../../../docs/future/restructuring.md#discipline-for-future-splits).

| Cross-component link | Producer | Consumer(s) |
|---|---|---|
| `traefik` Docker network | [`traefik.yml`](tasks/traefik.yml) | registry, openobserve, prefect, apps |
| `letsencrypt` cert resolver (Traefik) | [`traefik.yml`](tasks/traefik.yml) | registry, openobserve, prefect, apps (via Docker labels) |
| `/etc/traefik/auth/htpasswd` | [`registry.yml`](tasks/registry.yml) | Traefik basic-auth middleware |
| `/var/log/traefik/access.log` | [`traefik.yml`](tasks/traefik.yml) | [`fail2ban-traefik.yml`](tasks/fail2ban-traefik.yml) jails |
| `iac` user (gid: docker, no home) | [`iac-user.yml`](tasks/iac-user.yml) | registry auth, prefect worker |
| `/opt/iac/.docker/config.json` | [`iac-user.yml`](tasks/iac-user.yml) | prefect worker (registry pulls), `app:deploy` task |
| `/opt/iac/prefect/` | [`iac-user.yml`](tasks/iac-user.yml) | [`prefect.yml`](tasks/prefect.yml), `workflow:deploy` |

## fail2ban contract with base

[`fail2ban-traefik.yml`](tasks/fail2ban-traefik.yml) writes to `/etc/fail2ban/jail.d/traefik.conf`. fail2ban merges all `jail.d/*.conf` into one config space, so Traefik jails inherit `[DEFAULT]` (ignoreip, AbuseIPDB action, ban/find times) from base's `/etc/fail2ban/jail.d/base.conf`. Restart is notified to base's `Restart fail2ban` handler.
