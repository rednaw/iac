[**<---**](../rules/project.mdc)

# IPv6 visitors lose their IP

Traefik publishes `[::]:80` / `[::]:443`, but the `traefik` Docker network was IPv4-only. IPv6 connections went through `docker-proxy`, so Traefik saw the network gateway `172.19.0.1` as the client and forwarded that as `X-Real-Ip` / `X-Forwarded-For`. Affected every router: Umami geo (empty country/region/city), app logs, Traefik access log, fail2ban.

## Decided

| | |
|--|--|
| Evidence | Traefik access log, router `umami@docker`: many requests from `172.19.0.1`; Umami sessions with empty country = IPv6 visitors |
| Scope | Platform-wide (all Traefik routers), not Umami-specific |
| Fix | **Dual-stack `traefik` network** (`enable_ipv6`, ULA `fd4e:6b2a:9c1d:1::/64`) in `roles/platform/tasks/traefik.yml`. Published ports then DNAT over ip6tables and keep the source |
| No daemon.json | Docker ≥ 28 does ip6tables + per-family gateway selection for user-defined networks without daemon config → no Docker restart. Asserted in the play |
| Other networks | Stay IPv4-only (`openobserve-network`, `prefect-network`, `umami-network`, app networks). With Docker ≥ 28 the IPv6 gateway comes from the only IPv6 network, `traefik` |
| Recreate | Enabling IPv6 recreates `traefik`; the task reads attached containers first and reattaches them (`connected` + `appends`), incl. Compose app containers |
| RA guard | Docker turns on IPv6 forwarding; the play asserts the host IPv6 default route is not `proto ra` (Hetzner Cloud is static `fe80::1`) |
| fail2ban | `ignoreip` also gets the server's own IPv6 (`ansible_default_ipv6.address`) |
| Live | Applied: `traefik` network `EnableIPv6=true` |

## Decide

None.

## Do

### 0. Dual-stack Traefik network

- [x] Agent: implemented
- [ ] Human: reviewed

**Agent will implement** — `ansible/roles/platform/tasks/traefik.yml`: Docker version assert (≥ 28), IPv6 default-route assert, `docker_network_info` read, dual-stack `traefik` network with reattach. `ansible/roles/base/templates/fail2ban-base.conf.j2`: server IPv6 in `ignoreip`. Live: network IPv6 enabled.

**Human must:**
1. `docker network inspect traefik --format '{{.EnableIPv6}}'` → `true`; `https://tientjeketama.nl` and `https://analytics.rednaw.nl` load.
2. From an IPv6 client load a page, then `sudo tail -n 200 /var/log/traefik/access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head` → real IPv6 addresses, no new `172.19.0.1`. New Umami sessions from IPv6 get a country.
3. If an app container is missing from the `traefik` network: `task app:deploy -- tientje-ketama <current sha>` (`task app:versions -- tientje-ketama`).
