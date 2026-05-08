module "server" {
  source = "../modules/server"

  name          = local.server_name
  firewall_name = local.firewall_name
  server_type   = var.server_type
  location      = var.server_location
  image         = var.server_image
  ssh_keys      = var.ssh_keys

  allowed_ssh_ips = var.allowed_ssh_ips

  additional_firewall_rules = [
    {
      protocol    = "tcp"
      port        = "80"
      description = "HTTP"
    },
    {
      protocol    = "tcp"
      port        = "443"
      description = "HTTPS"
    },
  ]

  labels = {
    environment = local.environment
    managed_by  = "terraform"
  }

  backups = true
}
