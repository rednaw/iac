**Promoted.** Living three-list plan: [../plans/vpn-travel-china.md](../plans/vpn-travel-china.md). This file is retained as background / dest roster detail; do not treat it as the active Decide/Do.

Operator manual: [vpn-travel-china-manual.md](vpn-travel-china-manual.md).  
Custom Routing: [onexray-custom-routing-cn.json](onexray-custom-routing-cn.json).

# VPN for China travel (notes)

Dedicated Hetzner VPS for a China trip. Same account as platform (`rednaw.nl`). **Not legal advice.**

See the **plan** for Decided / Decide / Do and live status. Dest roster, spares, and long primers below remain useful reference.

---

## Dest roster

**Dest** (one live at a time; re-check from the CX23). Must: TLS 1.3 + h2 + **X25519**, HTTP 200 on the SNI hostname (no 301-to-`www`), looks like the real site from `nbg1` (not CDN 403).

After a burned IP, the GFW blocked **our** Hetzner address, not the dest’s real host. Renewing the primary IPv4 is the fix. Stepping `vpn_dest` is optional. Same shared-host machine for #1 and #2 is **not** self-defeating.

| Rank | Host | Role |
|--|--|--|
| 1 | `amateurkunstamstelveen.nl` | Start / live. TransIP `77.72.150.234`. Verified from VPN CX23. |
| 2 | `seapalace.nl` | Easy SNI swap after renew. Same TransIP machine as #1. |
| 3 | `jamstudios.nl` | Neighbourhood swap. Denit `80.247.175.21`. |

Spares (finding alternatives only):

- TransIP / #1–#2: `arcadic.nl` `catercompany.eu` `damiro-ontruiming.nl` `fueldesign.nl` `getsalesdone.eu` `jbscleaningservice.nl` `jbsgroep.nl` `lindeman-schuttingen.nl` `lobatto.eu` `nickfalkenberg.com` `puuragenturen.com` `radicalcup.nl` `shirtshop-amsterdam.com` `shirtshop-amsterdam.nl` `svrap.nl` `time2choco.nl` `toffeebreak.com` `toffeebreak.eu` `toffeebreak.net` `xbrands.nl`
- Denit / #3: `autom8-it.nl` `auvimedia.nl` `beertema.nl` `dependans.nl` `elsburgeronland.nl` `haagspreventienetwerk.nl` `idmaker.nl` `inclusiefmedia.nl` `joytofilms.com` `kerkdebron.org` `kippenburg.nl` `lindhout-es.nl` `maartenwoud.nl` `mijderwijk.nl` `mijndenhaag.org` `mirjam-ouwerkerk.nl` `paian.nl` `radiobeurslisse.nl` `robvankan.nl` `sinister.nl` `slampampers.nl` `smartlappenkoor.com` `teletrailer-huren.nl` `thatsmagic.nl` `tradeservice.nl` `trouwautoverhuur.nl` `van-grinsven.nl` `vioolpianolesnijmegen.nl` `waltergoeting.nl`

Out: our names; landlord/GFW-class brands; gov costume; CDN/TLS1.2/geo; apex→`www` only.
