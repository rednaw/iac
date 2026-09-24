locals {
  server_name   = var.server_name != null ? var.server_name : "platform"
  firewall_name = "platform-firewall"
  base_domain   = var.base_domain
}
