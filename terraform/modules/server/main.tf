locals {
  firewall_name = coalesce(var.firewall_name, "${var.name}-firewall")

  ssh_keys_invalid = [
    for key_id in var.ssh_keys :
    key_id if !can(tonumber(key_id))
  ]

  ssh_ips_invalid = [
    for ip in var.allowed_ssh_ips :
    ip if !can(cidrhost(length(regexall("/", ip)) > 0 ? ip : "${ip}/32", 0))
  ]
}

resource "hcloud_firewall" "this" {
  lifecycle {
    precondition {
      condition     = length(local.ssh_ips_invalid) == 0
      error_message = "Invalid CIDR blocks in allowed_ssh_ips. All values must be valid CIDR format (e.g. 1.2.3.4/32 or 1.2.3.4/24)."
    }
  }
  name = local.firewall_name

  rule {
    direction   = "in"
    source_ips  = var.allowed_ssh_ips
    protocol    = "tcp"
    port        = "22"
    description = "SSH (restricted to allowed IPs)"
  }

  rule {
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Allow ping from anywhere"
  }

  dynamic "rule" {
    for_each = var.additional_firewall_rules
    content {
      direction       = rule.value.direction
      protocol        = rule.value.protocol
      port            = rule.value.port
      source_ips      = rule.value.source_ips
      destination_ips = rule.value.destination_ips
      description     = rule.value.description
    }
  }
}

resource "hcloud_server" "this" {
  lifecycle {
    precondition {
      condition     = length(local.ssh_keys_invalid) == 0
      error_message = "Invalid SSH key IDs in ssh_keys. All SSH key IDs must be numeric Hetzner key IDs."
    }
  }
  name         = var.name
  image        = var.image
  server_type  = var.server_type
  location     = var.location
  ssh_keys     = var.ssh_keys
  firewall_ids = [hcloud_firewall.this.id]
  backups      = var.backups
  labels       = var.labels

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}
