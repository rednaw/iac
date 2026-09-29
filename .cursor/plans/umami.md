[**<---**](../rules/project.mdc)

# Umami (platform analytics)

Self-hosted **Umami** on the platform VPS: Traefik + Docker + SOPS. Portfolio visitor stats alongside (later instead of) Simple Analytics, with a multi-user, multi-site dashboard (free SA blocks API: “upgrade to the Simple plan”). Origin: SA-mirror discussion in the rednaw window; SA free mirror/proxy paths abandoned.

App snippet cutovers are sibling-repo edits — state paths and wait for go per repo.

## Decided

| | |
|--|--|
| Service | Umami `ghcr.io/umami-software/umami:3.4.0` (v3 is Postgres-only; no `postgresql-` tag prefix; `docker.umami.is` is Cloudflare-fronted, so canonical GHCR) + `postgres:16-alpine` `umami-db` (UTC) |
| Why | Free multi-user + multi-site; Postgres only; MIT; same class as OpenObserve / cms-oauth |
| Home | `ansible/roles/platform/tasks/umami.yml` + `import_tasks` from `platform/tasks/main.yml` |
| Hostname | `analytics.{{ base_domain }}` → `analytics.rednaw.nl`; Traefik `websecure` + `letsencrypt` |
| Auth | Native Umami users only (v1). Self-hosted Umami has no OIDC/OAuth RP; `cms-oauth` is Decap/GitHub popup, not an IdP — cannot reuse even refactored without a Traefik gate + dropping app ACLs. No Authelia / forward-auth for Umami v1. |
| Public vs private | Tracker + `/api/send` **world-reachable** (GH Pages must POST). Dashboard is Umami-auth. Do not gate the whole host. |
| Network | `umami` on `traefik` + internal `umami-network`; `umami-db` on `umami-network` only |
| fail2ban | `traefik-auth` ignores 401/403 on router `umami@docker` (expired-session API polls); `/api/auth/login` still covered by `traefik-login-attempts` |
| Data | Docker named volume `umami-db-data` (same idiom as `prefect-db-data`; Postgres owns it, Ansible manages no host dir). Old bind dir `/var/lib/umami` is migrated once, then removed by Human; **no backup in v1** (analytics history disposable; Prefect only covers `/opt/iac/deploy/*/backup.yml`) |
| Secrets | `umami_db_password`, `umami_app_secret` (`APP_SECRET`) via SOPS / `infrastructure_secrets.*`; both unset → Umami containers absent (cms-oauth idiom); optional `umami_two_factor_encryption_key` later |
| Env | `DATABASE_URL`, `APP_SECRET`, `DISABLE_TELEMETRY=1`, `DISABLE_UPDATES=1`, `CLIENT_IP_HEADER=x-real-ip` (Traefik has no trusted forwarders, so it overwrites `X-Real-Ip` with the peer), `SKIP_LOCATION_HEADERS=1` (no CDN, so client-sent `cf-ipcountry` etc. must not override GeoIP) |
| DNS | Terraform `terraform/platform/` record for `analytics` → VPS |
| Memory | App 512m, Postgres 256m; raise if OOM |
| Default login | First boot `admin` / `umami` — **Human changes immediately** |
| Cloaking | None — honest hostname + default `script.js` / `/api/send`; accept blocker undercount |
| GeoIP | Bundled DB only: image bundles `/app/geo/GeoLite2-City.mmdb` (MaxMind GeoLite2 via GitSquared redist, fetched at image build). Lookup on the `x-real-ip` peer. Freshness = Umami tag bumps (Renovate `ansible` manager on `image:` in `umami.yml`). No own download, no `GEOLITE_DB_PATH` |
| Not doing | SA API proxy/export archive, Plausible/ClickHouse, tracker/hostname cloaking, Authelia/cms-oauth SSO for Umami, restic/Prefect backup for Umami |
| Rollout | Platform live. Sites next, order picked per site. **Dual-run:** every site on SA gets Umami **alongside** SA; SA removal is a later, separate per-site call |
| CSP | Sites with a CSP add `https://analytics.rednaw.nl` to `script-src` and `connect-src` next to the SA origins |
| History | No SA import — metrics start at each site’s cutover |
| Audience | Wander (admin). Extra non-admin users scoped to their own site(s) are a Umami UI action, no infra change. |
| Umami “Domain” field | **Hostname only** — no `http(s)://`, no path. Umami rejects e.g. `rednaw.github.io/unicorn` (“Invalid domain”). Name = human label; Domain = `window.location.hostname`. Separate website row + `data-website-id` per site even when several share one host |
| Collection snippet | `<script defer src="https://analytics.rednaw.nl/script.js" data-website-id="…" data-exclude-search="true"></script>` |
| Privacy / collect defaults | **`data-exclude-search="true"`** on every snippet (no URL query). Privacy copy **states geo**: country/region/city from IP via GeoLite2; **IP not stored**. **No** `data-performance` (no Web Vitals). **No** custom `umami.track` payloads with PII. **No** `data-do-not-track` (DNT is dead on the real web; do not claim it). Hash exclusion not required. Dual-run: until SA is removed, privacy must name **both** SA and Umami |
| Docs after live | `rednaw/.cursor/ideas/portfolio/{private-data,sovereign-exit,portfolio-levers}.md`; `rednaw-map` if platform table should list Umami |

### Site inventory (after platform)

All six below load SA today → dual-run. Order picked per site.

When adding a website in Umami: **Domain** = hostname in the table (not the path). GH Pages **project** sites share `rednaw.github.io`; each still gets its own website + snippet id. Page paths (`/unicorn/…`) still appear in that site’s URL stats.

| Site | Repo | Umami Domain | SA today | Umami notes |
|--|--|--|--|--|
| baglio | `anticobagliosiciliano` | `rednaw.github.io` | `src/app.html`; CSP + SA/Umami strip in `vite.config.ts` | **Snippet + CSP + privacy dual-run** (id `fce8ee03-…`); SA left in place |
| unicorn | `unicorn` | `rednaw.github.io` | `src/app.html`; CSP in `svelte.config.js`; SA+Umami stripped in `vite.config.ts` (dev) | **Snippet + CSP** (id `75720b76-…`); SA left in place |
| compleanno | `compleanno` | `rednaw.github.io` | `src/app.html` (`data-collect-dnt="true"`) | No CSP seen |
| tientje-ketama | `tientje-ketama` | `tientjeketama.nl` (confirm live host) | `src/app.html` (nonce); CSP in `svelte.config.js` | Snippet needs `nonce="%sveltekit.nonce%"`; CSP add; ships via iac `app:deploy` |
| marialoni | `marialoni.org` | `marialoni.org` / `www.marialoni.org` as used | `_layouts/default.html`, `_layouts/indefinites.html`, `nomenu.html` | **Live** (id `4a503d4f-…`) + `data-exclude-search`; SA on nomenu too; no CSP |
| simonacella | `simonacella.github.io` | `simonacella.github.io` | `_layouts/default.html` | **Live** (id `53346294-…`) + `data-exclude-search`; all layouts inherit `default`; no CSP |
| newton | `newton` | `rednaw.github.io` if added | none | Not in scope unless Human adds it |

## Decide

None.

## Do

Checkboxes track status only. The agent may change only **Agent** boxes; only the human may change **Human** boxes.

### 0. Platform Umami

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — `ansible/roles/platform/tasks/umami.yml` (+ import in `main.yml`), fail2ban `traefik-auth` ignore, `analytics_a`/`analytics_aaaa` in `terraform/platform/dns.tf`, key names in `tasks/Taskfile.secrets.yml` template + `tasks/Taskfile.app.yml` forbidden list, README lines. Verified: ansible-lint (production), `server.yml` syntax-check, `terraform fmt`. Live smoke: `script.js` 200 JS, `/` 200, `/api/heartbeat` 200. Not verified: `terraform validate` (pinned 1.16.4 not installed in container). `.cursor/rules/{ansible,terraform}.mdc` still omit Umami/`analytics` (files not agent-readable). No site snippets until Human rotates admin password.

**Human must:**
1. `sops ../secrets/infra.yml` → add `umami_db_password` and `umami_app_secret`, each from `openssl rand -hex 32`; commit in secrets.
2. `task platform:provision:plan` → expect 2 adds (`analytics` A/AAAA); apply.
3. `task platform:configure:apply` → `umami-db` then `umami` start.
4. Smoke: `curl -sI https://analytics.rednaw.nl/script.js` → 200 JS; `https://analytics.rednaw.nl` → login page.
5. Log in `admin` / `umami` → Settings → Profile → change password **immediately**.
6. `docker stats --no-stream` on VPS → RAM headroom OK.

### 1. Portfolio sites

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — Per site, after Human names it and says go: state repo + paths; add Umami snippet **alongside** SA per inventory row (CSP, nonce, tests as noted). Do not remove SA.

**Human must:** Pick the next site; add it in Umami using the inventory **Umami Domain** (hostname only — never a `/path`); give agent its `data-website-id`; deploy/merge; confirm hits in both SA and Umami. SA removal later, per site, on your call.

### 2. Idea / map doc sync

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — After the first site is live on Umami: update analytics rows in rednaw ideas + map if needed (sibling edit, go first).

**Human must:** Review those edits.

### 3. GeoIP check

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — Nothing to build (bundled DB). Verified the `3.4.0` image contains `/app/geo/GeoLite2-City.mmdb` (64 MB). Live: sessions carry countries (SG, US, NL, IT; empty ones are IPv6 visitors seen as `172.19.0.1` — fix in `.cursor/plans/ipv6-client-ip.md`). Renovate Dependency Dashboard lists the Umami image.

**Human must:**
1. On the VPS: `docker exec umami-db psql -U umami -d umami -c "select country, count(*) from session group by 1 order by 2 desc limit 10;"` → expect ISO codes (e.g. `IT`, `NL`), not all empty.
2. Renovate Dependency Dashboard issue on `rednaw/iac` → confirm `ghcr.io/umami-software/umami` is listed under **ansible**. If not, tell the agent (needs a Renovate rule).

### 4. Postgres data to a named volume

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — `umami.yml`: drop the `/var/lib/umami` directory task; `umami-db` mounts `umami-db-data:/var/lib/postgresql/data`. The postgres entrypoint re-chowns PGDATA on every start, so copied files need no fixed uid. Verified: ansible-lint.

**Human must** (on the VPS, then from iac):
1. ~~`docker stop umami umami-db`~~ done
2. ~~`docker volume create umami-db-data`~~ Ansible already created empty volume
3. ~~Copy `/var/lib/umami` → `umami-db-data`~~ done (agent, 2026-09-29): 2 websites, 12 sessions restored; both containers healthy; heartbeat 200
4. ~~`task platform:configure:apply`~~ already applied earlier
5. Check: dashboard shows existing visits
6. After a few days OK: `sudo rm -rf /var/lib/umami` (still present as leftover)

## Operator checklist (Human)

- [x] DNS `analytics.rednaw.nl` live
- [x] Admin password rotated **before** any site snippet
- [x] Each site shows hits in Umami while SA keeps running
