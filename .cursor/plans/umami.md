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
| Data | Docker named volume `umami-db-data` (same idiom as `prefect-db-data`). Old bind `/var/lib/umami` migrated and **removed**. **No backup in v1** (analytics history disposable; Prefect only covers `/opt/iac/deploy/*/backup.yml`) |
| Secrets | `umami_db_password`, `umami_app_secret` (`APP_SECRET`) via SOPS / `infrastructure_secrets.*`; both unset → Umami containers absent (cms-oauth idiom); optional `umami_two_factor_encryption_key` later |
| Env | `DATABASE_URL`, `APP_SECRET`, `DISABLE_TELEMETRY=1`, `DISABLE_UPDATES=1`, `CLIENT_IP_HEADER=x-real-ip` (Traefik has no trusted forwarders, so it overwrites `X-Real-Ip` with the peer), `SKIP_LOCATION_HEADERS=1` (no CDN, so client-sent `cf-ipcountry` etc. must not override GeoIP) |
| DNS | Terraform `terraform/platform/` record for `analytics` → VPS |
| Memory | App 512m, Postgres 256m; raise if OOM |
| Default login | First boot `admin` / `umami` — **Human changes immediately** |
| Cloaking | None — honest hostname + default `script.js` / `/api/send`; accept blocker undercount |
| GeoIP | Bundled DB only: image bundles `/app/geo/GeoLite2-City.mmdb` (MaxMind GeoLite2 via GitSquared redist, fetched at image build). Lookup on the `x-real-ip` peer. Freshness = Umami tag bumps (Renovate `ansible` manager on `image:` in `umami.yml`). No own download, no `GEOLITE_DB_PATH`. IPv6 client IP: dual-stack `traefik` network (`.cursor/plans/ipv6-client-ip.md`) |
| Collect extras | **Off:** session replay / heatmaps (`recorder_enabled=false` all sites), Web Vitals (`data-performance`), custom `umami.track` with PII, `data-do-not-track` |
| Not doing | SA API proxy/export archive, Plausible/ClickHouse, tracker/hostname cloaking, Authelia/cms-oauth SSO for Umami, restic/Prefect backup for Umami |
| Rollout | Platform live. **Dual-run:** sites on SA get Umami **alongside** SA; SA removal is a later, separate per-site call |
| CSP | Sites with a CSP add `https://analytics.rednaw.nl` to `script-src` and `connect-src` next to the SA origins |
| History | No SA import — metrics start at each site’s cutover |
| Audience | Wander (admin). Extra non-admin users scoped to their own site(s) are a Umami UI action, no infra change. |
| Umami “Domain” field | **Hostname only** — no `http(s)://`, no path. Umami rejects e.g. `rednaw.github.io/unicorn` (“Invalid domain”). Name = human label; Domain = `window.location.hostname`. Separate website row + `data-website-id` per site even when several share one host |
| Collection snippet | `<script defer src="https://analytics.rednaw.nl/script.js" data-website-id="…" data-exclude-search="true"></script>` |
| Privacy / collect defaults | **`data-exclude-search="true"`** on every snippet (no URL query). Privacy copy **states geo**: country/region/city from IP via GeoLite2; **IP not stored**. Dual-run: until SA is removed, privacy must name **both** SA and Umami |
| Docs after live | `rednaw/.cursor/ideas/portfolio/{private-data,sovereign-exit,portfolio-levers}.md`; `rednaw-map` platform table should list Umami |

### Site inventory

When adding a website in Umami: **Domain** = hostname in the table (not the path). GH Pages **project** sites share `rednaw.github.io`; each still gets its own website + snippet id.

| Site | Repo | Umami Domain | Status |
|--|--|--|--|
| baglio | `anticobagliosiciliano` | `rednaw.github.io` | **Live** id `fce8ee03-…`; snippet + CSP + privacy dual-run; SA kept |
| unicorn | `unicorn` | `rednaw.github.io` | **Live** id `75720b76-…`; snippet + CSP; SA kept; **privacy still SA-only** |
| marialoni | `marialoni.org` | `marialoni.org` | **Live** id `4a503d4f-…`; snippet + `data-exclude-search` (incl. nomenu); SA kept; **no privacy dual-run copy** |
| simonacella | `simonacella.github.io` | `simonacella.github.io` | **Live** id `53346294-…`; snippet + `data-exclude-search`; SA kept; **no privacy dual-run copy** |
| compleanno | `compleanno` | `rednaw.github.io` | SA only (`data-collect-dnt="true"`); **Umami not wired** |
| tientje-ketama | `tientje-ketama` | `tientjeketama.nl` | **Live** id `941c8400-…`; snippet + nonce + CSP + `data-exclude-search`; SA kept; no privacy page in repo |
| newton | `newton` | `rednaw.github.io` if added | Out of scope unless Human adds it |

## Decide

### How long to keep Umami visit data?

Self-hosted Umami today: **no retention policy** (`app_setting` empty). API reports `sessionDeletionEnabled: true` (product can delete sessions). DB is tiny. **No backup** already Decided — history is disposable. OpenObserve (ops logs/metrics) is separate: **7-day** compact retention.

| | Option | Trade-off |
|--|--|--|
| **A** | **Keep forever** (status quo) — no job, no UI schedule | Simplest; disk grows slowly at portfolio traffic; privacy copy can’t claim a short window |
| **B** | **Fixed window (e.g. 90 days)** — delete older sessions/events on a schedule (Umami UI if it covers it, else Prefect/cron SQL) | Matches “stats, not archive”; need to pick N and say it in privacy text |
| **C** | **Short window (e.g. 30 days)** — same mechanism as B | Stronger minimization; year-over-year trends gone |
| **D** | **Align with OpenObserve (7 days)** | One story for “box data”; too short for useful visitor trends for most people |

Also decide (can piggyback on B/C): whether privacy pages **state** the retention period (recommended if not A).

Choice: _unpicked_

## Do

Checkboxes track status only. The agent may change only **Agent** boxes; only the human may change **Human** boxes.

### 0. Platform Umami

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — `ansible/roles/platform/tasks/umami.yml` (+ import in `main.yml`), fail2ban `traefik-auth` ignore, `analytics_a`/`analytics_aaaa` in `terraform/platform/dns.tf`, key names in `tasks/Taskfile.secrets.yml` template + `tasks/Taskfile.app.yml` forbidden list, README lines.

**Human must:** (done) secrets, DNS, configure apply, smoke, admin password rotate, RAM check.

### 1. Portfolio sites (first wave)

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — Snippets (+ CSP where needed) for baglio, unicorn, marialoni, simonacella alongside SA.

**Human must:** (done for those four) website ids, deploy/merge, confirm hits in SA + Umami.

### 2. Idea / map doc sync

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — Sibling go first: update analytics rows in `rednaw/.cursor/ideas/portfolio/{private-data,sovereign-exit,portfolio-levers}.md` and `rednaw-map` platform table to name Umami (dual-run / self-hosted on VPS), not SA-only.

**Human must:** Review those edits.

### 3. GeoIP check

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — Bundled GeoLite2; Renovate lists Umami image. Empty-country sessions from IPv6-as-gateway fixed under `.cursor/plans/ipv6-client-ip.md` (human verify there).

**Human must:** (done) country counts non-empty; Renovate lists umami under ansible.

### 4. Postgres data to a named volume

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — `umami-db` mounts `umami-db-data:/var/lib/postgresql/data`.

**Human must:** (done) migrate + confirm visits; `/var/lib/umami` removed.

### 5. Remaining portfolio sites

- [ ] Agent: implemented
- [ ] Human: reviewed

**can start now** (after Human supplies website id)

**Agent will implement** — State repo + paths; wait for go. Add Umami snippet alongside SA on `compleanno` (`src/app.html`; SA uses `data-collect-dnt="true"` — do not add DNT on Umami). Do not remove SA. (`tientje-ketama` done: id `941c8400-…`, nonce + CSP.)

**Human must:** Create website in Umami (Domain `rednaw.github.io`); give `data-website-id`; deploy; confirm hits in both SA and Umami.

### 6. Privacy copy on dual-run sites

- [ ] Agent: implemented
- [ ] Human: reviewed

**can start now** (per site after Human says go)

**Agent will implement** — Dual-run privacy text naming SA + Umami (geo from IP, IP not stored), matching baglio’s bar: unicorn, simonacella, marialoni (compleanno when wired). `tientje-ketama` has no privacy page today — only if Human wants one added. Sibling paths + go first.

**Human must:** Pick site / approve wording; merge/deploy.

## Operator checklist (Human)

- [x] DNS `analytics.rednaw.nl` live
- [x] Admin password rotated **before** any site snippet
- [x] First-wave sites (baglio, unicorn, marialoni, simonacella) show hits in Umami while SA keeps running
- [x] tientje-ketama on Umami
- [ ] compleanno on Umami
- [ ] Privacy dual-run on unicorn / simonacella / marialoni
- [ ] Idea / map doc sync reviewed
- [ ] Retention Decide (A/B/C/D) picked
