# Parallel Gate box (REALITY on 443) in Hetzner Cloud project Gate.
# Trip box stays terraform/vpn + TFC vpn + Default token — do not retarget.
#
# Deliberately absent: DNS, port 80, backups (same posture as vpn root).

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
