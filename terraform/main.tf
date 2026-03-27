# Firewall - allow SSH from specific IPs, HTTP(S) from anywhere
resource "hcloud_firewall" "platform" {
  lifecycle {
    precondition {
      condition     = length(local.ssh_ips_invalid) == 0
      error_message = "Invalid CIDR blocks found in allowed_ssh_ips. All values must be valid CIDR format (e.g., 1.2.3.4/32 or 1.2.3.4/24)."
    }
  }
  name = "${local.project_slug}-firewall-${local.environment}"

  # SSH access
  rule {
    direction   = "in"
    source_ips  = local.allowed_ssh_ips
    protocol    = "tcp"
    port        = "22"
    description = "SSH (restricted to allowed IPs)"
  }

  # HTTP access (port 80)
  rule {
    direction   = "in"
    source_ips  = ["0.0.0.0/0", "::/0"]
    protocol    = "tcp"
    port        = "80"
    description = "HTTP"
  }

  # HTTPS access (port 443)
  rule {
    direction   = "in"
    source_ips  = ["0.0.0.0/0", "::/0"]
    protocol    = "tcp"
    port        = "443"
    description = "HTTPS"
  }

  # ICMP (ping)
  rule {
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Allow ping from anywhere"
  }
}

# VPS Server
resource "hcloud_server" "platform" {
  lifecycle {
    precondition {
      condition     = length(local.ssh_keys_invalid) == 0
      error_message = "Invalid SSH key IDs found in ssh_keys. All SSH key IDs must be numeric."
    }
    precondition {
      condition     = contains(["dev", "prod"], local.environment)
      error_message = "Invalid environment '${local.environment}'. Use: dev or prod"
    }
  }
  name         = local.server_name
  image        = var.server_image
  server_type  = var.server_type
  location     = var.server_location
  ssh_keys     = local.ssh_keys
  firewall_ids = [hcloud_firewall.platform.id]
  backups      = true

  labels = {
    environment = local.environment
    managed_by  = "terraform"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}

