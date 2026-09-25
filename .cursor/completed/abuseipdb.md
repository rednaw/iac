# Restore fail2ban AbuseIPDB reporting

Unnoticed outage: from ~18 Mar 2026 fail2ban could not load the Traefik auth jail (`ignoreregex` with two `<HOST>` tokens OR’d on one line — invalid after expansion, `#148`). AbuseIPDB actions were dead until the filter was split and re-applied. Sibling already held a post-Sep-24 key; no second mint. Touches [public-secrets](../plans/public-secrets.md) inventory only as hygiene, not as a rotate-first plan.

## Decided

| | |
|--|--|
| Key | `abuseipdb_api_key` in `../secrets/infra.yml` (already current; no second mint) |
| Outage | fail2ban Traefik auth jail broken ~18 Mar 2026 → no AbuseIPDB reports |
| Root cause | `ignoreregex = …<HOST>…\|…<HOST>…` — invalid after `<HOST>` expansion |
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

**Done as:** No second mint; outage closed.
