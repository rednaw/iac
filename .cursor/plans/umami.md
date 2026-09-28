[**<---**](../rules/project.mdc)

# Umami (platform analytics)

Self-hosted **Umami** on the platform VPS: Traefik + Docker + SOPS. Replaces Simple Analytics for portfolio visitor stats. Multi-user dashboard so Wander and Simona both see numbers without a second SA seat (free SA blocks API: “upgrade to the Simple plan”). Origin: SA-mirror discussion in the rednaw window; SA free mirror/proxy paths abandoned.

App snippet cutovers (Simona first, then other sites) are sequenced **after** platform smoke; those edits are sibling repos — state paths and wait for go from the heart window.

## Decided

| | |
|--|--|
| Service | Umami (`docker.umami.is/umami-software/umami:postgresql-<pinned>`) + dedicated Postgres (UTC) |
| Why | Free multi-user + multi-site; Postgres only; MIT; same class as OpenObserve / cms-oauth |
| Home | `ansible/roles/platform/tasks/umami.yml` + `import_tasks` from `platform/tasks/main.yml` |
| Hostname | `analytics.{{ base_domain }}` → `analytics.rednaw.nl`; Traefik `websecure` + `letsencrypt` |
| Auth | Umami login only (v1) — no Authelia in front |
| Public vs private | Tracker + `/api/send` **world-reachable** (GH Pages must POST). Dashboard is Umami-auth. Do not Authelia-gate the whole host. |
| Network | `umami` on `traefik` network; `umami-db` internal only |
| Data | `/var/lib/umami/` (Postgres); include in restic/Prefect backup set |
| Secrets | `umami_db_password`, `umami_app_secret` (`APP_SECRET`) via SOPS / `infrastructure_secrets.*`; optional `umami_two_factor_encryption_key` later |
| Env | `DATABASE_URL`, `APP_SECRET`, `DISABLE_TELEMETRY=1`; `CLIENT_IP_HEADER` for Traefik real IP (confirm header vs current Traefik when implementing) |
| DNS | Terraform `terraform/platform/` record for `analytics` → VPS |
| Memory | Start modest (~256–512m app, ~256–512m Postgres); raise if OOM |
| Default login | First boot `admin` / `umami` — **Human changes immediately** |
| Cloaking | None — honest hostname + default `script.js` / `/api/send`; accept blocker undercount |
| GeoIP v1 | No explicit MaxMind/`GEO_DATABASE_URL`; country may be empty |
| Not doing | SA API proxy/export archive, Plausible/ClickHouse, tracker/hostname cloaking, Authelia in front of collect |
| Rollout | Platform smoke → **Simona first** (dual-run SA+Umami ~1–2 weeks) → remaining portfolio sites |
| History | No SA import — metrics start at each site’s cutover |
| Audience | Wander (admin) + Simona (non-admin, her website only) |
| Collection snippet | `<script defer src="https://analytics.rednaw.nl/script.js" data-website-id="…"></script>` |
| Docs after live | `rednaw/.cursor/ideas/portfolio/{private-data,sovereign-exit,portfolio-levers}.md`; `rednaw-map` if platform table should list Umami |

### Site inventory (after platform)

| Order | Site | Repo | Notes |
|--|--|--|--|
| 1 | Simona | `simonacella/simonacella.github.io` | Dual-run SA; Umami user for Simona |
| 2+ | baglio, unicorn, compleanno, tientje-ketama, marialoni | respective siblings | tientje snippet in app (iac apex), not only Pages |

## Decide

None.

## Do

Checkboxes track status only. The agent may change only **Agent** boxes; only the human may change **Human** boxes.

### 0. Platform Umami — **blocked on explicit go**

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — After go: `umami.yml`, Traefik labels, DNS TF, SOPS key names, backup inclusion; pin image tag; no GeoDB; default tracker paths. Smoke: `https://analytics.rednaw.nl` loads. No site snippets until Human rotates admin password.

**Human must:** Say go; add SOPS values; apply/merge DNS; first login → change `admin` password; confirm VPS RAM headroom.

### 1. Simona cutover (after Do 0)

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — After Do 0 and go: state `simonacella.github.io` paths + intent; wait for go; add Umami snippet **alongside** SA; later remove SA after overlap window.

**Human must:** Add Simona website in Umami; create scoped user; paste `data-website-id`; verify hits; send her `https://analytics.rednaw.nl` + credentials out-of-band; after ~1–2 weeks approve SA removal.

### 2. Remaining portfolio sites

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — After go: same snippet pattern per inventory row; sibling-edit go per repo.

**Human must:** Add each website in Umami; confirm hits; delete SA properties when done.

### 3. Idea / map doc sync

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — After Simona is live on Umami: update analytics rows in rednaw ideas + map if needed.

**Human must:** Review those edits.

## Operator checklist (Human)

- [ ] DNS `analytics.rednaw.nl` live
- [ ] Admin password rotated **before** Simona snippet
- [ ] Simona user scoped to her site(s)
- [ ] SA retired when inventory empty
- [ ] restic path for Umami Postgres known
