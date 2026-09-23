[**<---**](../rules/project.mdc)

# Authelia behind Traefik

SSO/forward-auth gate on the platform VPS. Admin UIs first; gated-audience surfaces (jury, seminar, subscribers, private previews) later. €0 on existing infra. Origin: `rednaw/.cursor/ideas/portfolio-levers.md` (top lever).

## Decided

| | |
|--|--|
| Service | Authelia (`authelia/authelia:4`) behind existing Traefik, forward-auth middleware |
| Why | Unlocks every gated-audience idea portfolio-wide (`portfolio-levers.md`) |
| Home | `ansible/roles/platform/tasks/authelia.yml`; container on `traefik` network, certs via existing `letsencrypt` resolver |
| Footprint | ~25–50 MB RAM; authentik (0.5–1.2 GB) / Keycloak (1.5–2.5 GB) rejected by size (`rednaw/.cursor/ideas/sovereign-exit.md`) |
| cms-oauth | Stays at `auth.<base_domain>` — Sveltia needs a GitHub OAuth handoff; Authelia gates browsers, doesn't broker GitHub tokens |
| Registry | Keeps htpasswd basic-auth — `docker push` can't follow SSO redirects |
| Secrets | New `authelia_*` keys via SOPS; private sibling if the `public-secrets` plan has landed |
| Portal | `login.<base_domain>`; no change to existing services |
| Users | File `users_database.yml` (argon2id hashes) rendered from SOPS; self-service password reset disabled |
| Storage | SQLite at `/var/lib/authelia` + in-memory sessions; restart = re-login |
| App domains | Off-`base_domain` apps (e.g. `tientjeketama.nl`) get a `session.cookies` entry (+ portal host on that domain) when first gated |
| Backup | None — config and users come from SOPS; losing SQLite costs TOTP re-enrollment and sessions only |
| Notifier | Filesystem (`/var/lib/authelia/notification.txt`); operator reads TOTP enrollment codes via SSH. SMTP (Scaleway TEM) when non-operator users arrive |
| Second factor | Staged: one-factor everywhere first (admin hosts included, Prefect's only gate); TOTP on admin later — accepted risk |
| Platform | Single environment after `remove-dev.md`. Hosts: `login.`, `traefik.`, `prefect.`, `openobserve.<base_domain>`; one cookie on `base_domain` |
| Gated surfaces | Traefik dashboard (→ `api@internal`), Prefect UI, OpenObserve UI |
| SSH tunnel | Persistent tunnel, aliases and `prod.<base_domain>` are already removed by `remove-dev.md`. SSH (22) stays firewalled to your IP for Ansible/diagnosis; explicit API-IP `ssh -L` remains break-glass |
| Localhost bindings | `127.0.0.1:57800/57801/57802` stay — Ansible health checks and dashboard provisioning use them; one-off `ssh -L` can still target them |
| Prefect | OSS has no auth: Authelia is its only gate. `PREFECT_UI_API_URL` → `https://<prefect host>/api`; Traefik joins `prefect-network`. Workers keep `http://prefect-server:4200/api` internally |
| OpenObserve | OSS has no header/SSO login (enterprise only): its own root login stays behind Authelia (two logins). Traefik already on `openobserve-network` |

## Decide

None.

## Do

Checkboxes track status only. The agent may change only **Agent** boxes; only the human may change **Human** boxes. Task bodies assign the work.

### 0. Secrets scaffold

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — can start now: add Authelia secret-variable wiring to Ansible/templates and provide the exact generation/hash commands.

**Human must:** Run `docker run --rm authelia/authelia:4 authelia crypto rand` three times (session, JWT and storage encryption keys), run `authelia crypto hash generate argon2` for the initial password, and store the resulting `authelia_*` values in the active SOPS secrets repo. Do not paste plaintext secrets into chat.

### 1. DNS

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after `remove-dev.md`: add and validate `transip_dns_record` A/AAAA records in `terraform/platform/dns.tf` for `login`, `traefik`, `prefect` and `openobserve` on `base_domain`, using `for_each`.

**Human must:** Review the Terraform plan, confirm it only adds those eight DNS records, then apply it.

### 2. Role tasks

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after `remove-dev.md`: create `ansible/roles/platform/tasks/authelia.yml` modeled on `cms-oauth.yml`; template `configuration.yml` and users file to `/etc/authelia/` (`0600`, `no_log`); configure SQLite at `/var/lib/authelia`, one cookie for `base_domain`, filesystem notifier, disabled password reset, default-deny + `one_factor`, `traefik` network and `memory: 128m`; import it after Traefik; update the platform dependency README; run Ansible checks.

**Human must:** After reviewing the generated configuration and diff, run `task platform:configure:apply`.

### 3. Forward-auth middleware

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 2: extend `templates/traefik-dynamic-middlewares.yml.j2` with forward-auth to `http://authelia:9091/api/authz/forward-auth`, trusted forwarded headers and the required identity response headers.

**Human must:** Include this in the same reviewed `task platform:configure:apply`; no separate manual configuration.

### 4. Gate admin UIs

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 3:
- `traefik.yml`: router for `traefik.<base_domain>` → `api@internal` with the middleware; join `prefect-network`.
- `prefect.yml`: Traefik labels (host, `websecure`, `letsencrypt`, middleware, port 4200); `PREFECT_UI_API_URL` → public https URL.
- `openobserve.yml`: Traefik labels (host, middleware, port 5080).

**Human must:** Apply the reviewed platform configuration, then open all three public admin URLs and confirm each redirects to Authelia before exposing its UI.

### 5. fail2ban + logrotate

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 2: configure the Authelia log file, a jail following `fail2ban-traefik.yml`, and log rotation; validate all three.

**Human must:** Apply the platform configuration and confirm the Authelia jail is loaded on the server.

### 6. Verify

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 4: run read-only HTTP, container, routing and fail2ban checks; verify unauthenticated admin requests redirect to `login.<base_domain>`.

**Human must:** Log in interactively, verify Traefik returns 200, Prefect loads flow runs through its public API URL, and OpenObserve presents its own login after Authelia; then accept the rollout.
