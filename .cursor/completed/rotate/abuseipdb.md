# Rotate AbuseIPDB API key (+ restore fail2ban)

Part of [public-secrets](../../plans/public-secrets.md) full rotate. Key minted in sibling; fail2ban restored after Traefik `ignoreregex` fix; API report path verified.

## Decided

| | |
|--|--|
| Key | `abuseipdb_api_key` in `../secrets/infra.yml` |
| Mint | Done — new key in sibling |
| Root cause | `ignoreregex = …<HOST>…\|…<HOST>…` — invalid after `<HOST>` expansion (18 Mar 2026 `#148`) |
| Ignore shape | **C** — `filter.d/traefik-auth.conf` with separate `ignoreregex` lines; jail uses filter by name |
| Second rotate | **B** — skip; sibling key post-dates Sep 24 log dump |
| Live | `fail2ban` active; `abuseipdb` on jails; check+report API smoke HTTP 200 |

## Decide

None.

## Do

### 0. Fix Traefik auth filter in git

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — add `fail2ban-filter-traefik-auth.conf`; deploy from `fail2ban-traefik.yml`; remove inline regex from `[traefik-auth]`.

**Human must:** Review the template/filter diff (no live change yet).

**Done as:** filter file + yml loop; jail uses filter by name.

### 1. Prove each ignoreregex compiles alone

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — `scripts/check-fail2ban-host-regex.py` + `task test:fail2ban-host-regex` in `test:run`.

**Human must:** None beyond review.

**Done as:** checker wired and passing.

### 2. Apply and confirm fail2ban + AbuseIPDB path

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — smoke commands / live verify after apply.

**Human must:** Commit/push → `task platform:configure:apply` → confirm active + actions.

**Done as:** apply ok; fail2ban active; API check+report smoke HTTP 200.

### 3. Key hygiene (no second mint)

- [x] Agent: implemented
- [x] Human: reviewed

**Agent will implement** — none (pick **B**).

**Human must:** Confirm Sep 24 dump was revoked predecessor; optional log truncate.

**Done as:** Human closed rotate (no second mint).
