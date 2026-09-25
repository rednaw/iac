# Rotate AbuseIPDB API key (+ restore fail2ban)

Part of [public-secrets](../public-secrets.md) full rotate. Key minted in sibling; live fail2ban is down so reporting cannot smoke until the Traefik `ignoreregex` bug is fixed.

## Decided

| | |
|--|--|
| Key | `abuseipdb_api_key` in `../secrets/infra.yml` |
| Mint | Done — new key in sibling (public-secrets rotate) |
| Symptom | AbuseIPDB last reports ~18 Mar 2026; live fail2ban not running |
| Root cause | `ignoreregex = …<HOST>…\|…<HOST>…` in Traefik auth jail — invalid after `<HOST>` expansion |
| Introduced | 18 Mar 2026 (`backup flow` / `#148`) |
| Not the cause | Missing API key — key is rendered into `base.conf` DEFAULT action |
| Live now | Platform `fail2ban.service` **failed**; bad line still in `traefik.conf` |
| Log leak | Failed startups dump the action (including API key) into `/var/log/fail2ban.log` (`640` root:adm) |
| Template | `ansible/roles/platform/templates/fail2ban-traefik.conf.j2` |

## Decide

### How to express the registry ignore without two `<HOST>`s

| | Option |
|--|--------|
| **A** | Single `<HOST>`, then non-capturing alternation: `^<HOST> -.*(?:("/v2/.*" (401\|403) .*)\|(registry@docker.*(401\|403).*))$` |
| **B** | Keep only `/v2/` ignore; drop `registry@docker` |
| **C** | Move ignores into `filter.d` as separate `ignoreregex` lines |

Choice: _unpicked_

### After fix: rotate AbuseIPDB key again?

Sep 24 configure attempts wrote the then-current key into fail2ban’s error dump.

| | Option |
|--|--------|
| **A** | Rotate again after fix + successful start |
| **B** | Skip if sibling key was minted **after** those failures and the logged value is the revoked predecessor |

Choice: _unpicked_

## Do

### 0. Fix Traefik `ignoreregex` in git

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after Decide (ignore shape): edit `fail2ban-traefik.conf.j2` per the pick.

**Human must:** Review the template diff (no live change yet).

### 1. Prove the regex compiles before apply

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — can start now: a check that expands `<HOST>` as fail2ban does and `re.compile`s the pattern; fail if `redefinition of group name`.

**Human must:** None beyond review, unless running the compile check locally first.

### 2. Apply and confirm fail2ban + AbuseIPDB path

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after 0 and explicit go: prepare smoke commands only.

**Human must:**
1. Commit/push template fix (you own git).
2. `task platform:configure:apply`
3. `systemctl is-active fail2ban` → `active`; jails listed; `abuseipdb` in sshd actions.
4. Optional: test ban / dashboard report.

### 3. Key hygiene after failed startups

- [ ] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — after Decide (rotate again?): remind only if **A**; agent does not mint keys.

**Human must:** Per Decide: mint/revoke at AbuseIPDB if needed; SOPS sibling; re-apply; truncate `/var/log/fail2ban.log*` if they still hold a live key. Revoke old key at AbuseIPDB when smoke is green.
