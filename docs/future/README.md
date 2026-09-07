[**<---**](../../README.md)

# Roadmap (open work)

Completed baseline includes platform layout, secrets/mounts, and the Sveltia CMS OAuth proxy (`auth.<base_domain>`). Below is only what is still to do.

```mermaid
flowchart LR
  subgraph servers [New server types]
    vpn[VPN]
    honeypot[Honeypot]
  end
  subgraph enhancements [Platform enhancements]
    grafana[Grafana]
    backup[Backup shape]
  end
```

## New server types

Pattern: `terraform/<purpose>/` composing `modules/server`, Ansible `roles/<purpose>/` + playbook `[base, <purpose>]`, thin Task namespace over `_terraform:*` / `_ansible:*`.

### VPN

Personal VPN VPS (Xray/VLESS+REALITY, WireGuard); destroyable after use.

Design: [vpn-travel-china.md](vpn-travel-china.md)

### Honeypot

Isolated T-Pot style host, strict egress.

Design: [honeypot.md](honeypot.md)

## Platform enhancements

### Grafana

Optional dashboards on top of OpenObserve when built-in UI is not enough. Parked.

Design: [grafana-exploration.md](grafana-exploration.md)

### Smaller open items

| Item | Notes |
|------|--------|
| Backup shape | Standardize `backup:` in `iac.yml` vs `.iac/backup.yml`; align Taskfile + Prefect |
| Platform UX | Docker context naming, registry hostname clarity across envs |

## Done (reference)

- **CMS OAuth proxy** — implemented; contract notes: [oauth-auth-proxy-implementor-brief.md](oauth-auth-proxy-implementor-brief.md)
