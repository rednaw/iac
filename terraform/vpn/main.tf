# Throwaway VPN box (REALITY on 443). Design: docs/future/vpn-travel-china.md
#
# Deliberately absent:
#   - DNS: no TransIP record — the box has no hostname anywhere; SSH/Ansible
#     use the API IPv4 and client share links embed the IPv4.
#   - Port 80: REALITY needs no ACME and no redirect.
#   - Backups: keys persist in SOPS; burn renews the primary IPv4 (keep disk)
#     or wipes the server if wedged.
#
# Server type / image use the module defaults (cx23, ubuntu-24.04).
# Location is pinned here so the managed primary IPv4 matches the server.

locals {
  location = "nbg1"
}

# Managed IPv4 so Burned IP can replace the address without destroying the disk.
# auto_delete = false: server destroy must not silently drop us back to ephemeral.
resource "hcloud_primary_ip" "v4" {
  name        = "vpn-v4"
  type        = "ipv4"
  location    = local.location
  auto_delete = false

  labels = {
    purpose    = "vpn"
    managed_by = "terraform"
  }
}

module "server" {
  source = "../modules/server"

  name            = "vpn"
  firewall_name   = "vpn-firewall"
  location        = local.location
  ssh_keys        = var.ssh_keys
  primary_ipv4_id = hcloud_primary_ip.v4.id

  allowed_ssh_ips = var.vpn_allowed_ssh_ips

  additional_firewall_rules = [
    {
      protocol    = "tcp"
      port        = "443"
      description = "REALITY (VLESS over TLS)"
    },
  ]

  labels = {
    purpose    = "vpn"
    managed_by = "terraform"
  }

  backups = false
}
