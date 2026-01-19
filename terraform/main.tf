# Firewall - allow SSH from specific IPs, HTTP(S) from anywhere
resource "hcloud_firewall" "giftfinder" {
  lifecycle {
    precondition {
      condition     = length(local.ssh_ips_invalid) == 0
      error_message = "Invalid CIDR blocks found. All IP addresses must be valid CIDR format (e.g., 1.2.3.4/32 or 1.2.3.4/24). Please check your infrastructure-secrets.yml file."
    }
  }
  name = "giftfinder-firewall-${local.environment}"

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

  # HTTPS access (port 443) - reserved for future TLS
  rule {
    direction   = "in"
    source_ips  = ["0.0.0.0/0", "::/0"]
    protocol    = "tcp"
    port        = "443"
    description = "HTTPS"
  }
}

# VPS Server
resource "hcloud_server" "giftfinder" {
  lifecycle {
    precondition {
      condition     = length(local.ssh_keys_invalid) == 0
      error_message = "Invalid SSH key IDs found. All SSH key IDs must be numeric. Please check your infrastructure-secrets.yml file."
    }
    precondition {
      condition     = contains(["dev", "prod"], local.env)
      error_message = "Invalid environment '${local.env}'. Use: dev or prod"
    }
  }
  name         = local.server_name
  image        = var.server_image
  server_type  = var.server_type
  location     = var.server_location
  ssh_keys     = local.ssh_keys
  firewall_ids = [hcloud_firewall.giftfinder.id]

  labels = {
    environment = local.environment
    managed_by  = "terraform"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}

# Generate Ansible inventory from Terraform outputs
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.ini.tpl", {
    server_name = local.server_name
    server_ip   = hcloud_server.giftfinder.ipv4_address
    server_user = var.server_user
    environment = local.environment
  })
  filename             = "${path.module}/../ansible/inventory/${local.environment}.ini"
  file_permission      = "0644"
  directory_permission = "0755"
}

