# Parallel Gate box (REALITY on 443) in Hetzner Cloud project Gate.
# Legacy shared box only. Dev vpn box is hcloud (vpn:provision:present|absent).
#
# Deliberately absent: DNS, port 80, backups.

locals {
  location = "nbg1"
}

resource "hcloud_primary_ip" "v4" {
  name        = "gate-v4"
  type        = "ipv4"
  location    = local.location
  auto_delete = false

  labels = {
    purpose    = "gate"
    managed_by = "terraform"
  }
}

module "server" {
  source = "../modules/server"

  name            = "gate"
  firewall_name   = "gate-firewall"
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
    purpose    = "gate"
    managed_by = "terraform"
  }

  backups = false
}
