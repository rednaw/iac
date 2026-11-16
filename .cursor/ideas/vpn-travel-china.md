**Dest roster only** (living). Trip archive: [../completed/vpn-travel-china.md](../completed/vpn-travel-china.md). Living work: [../plans/gate-friend-provision.md](../plans/gate-friend-provision.md); renew ops in sibling `vpn/.cursor/plans/`. Criteria: [../rules/vpn-reality-dest.mdc](../rules/vpn-reality-dest.mdc).

Operator manual / eSIM / routing JSON: under [../completed/](../completed/) (`vpn-travel-china-manual.md`, `china-esim-comparison.md`, `onexray-custom-routing-cn.json`).

# Dest roster (REALITY)

**Dest** (one live at a time; re-check from the CX23). Criteria (must / disqualify / Denit lesson): [../rules/vpn-reality-dest.mdc](../rules/vpn-reality-dest.mdc). Must: TLS 1.3 + h2 + **X25519**, HTTP 200 on the SNI hostname (no 301-to-`www`), looks like the real site from `nbg1` (not CDN 403).

After a burned IP, the GFW blocked **our** Hetzner address, not the dest’s real host. Renewing the primary IPv4 is the fix. Stepping `vpn_dest` is optional. Same shared-host machine for #1 and #2 is **not** self-defeating.

| Rank | Host | Role |
|--|--|--|
| #1 | `amateurkunstamstelveen.nl` | roster |
| #2 | `seapalace.nl` | roster |
| #3 | `jamstudios.nl` | was trip live |

Friend cutover picks a **fresh per-friend** dest from this pool (see `vpn/.cursor/plans/friend1-cutover.md`).
