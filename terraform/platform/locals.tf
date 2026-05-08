locals {
  environment   = replace(terraform.workspace, "platform-", "")
  project_slug  = replace(var.base_domain, ".", "-")
  server_name   = var.server_name != null ? var.server_name : "${local.project_slug}-${local.environment}"
  firewall_name = "${local.project_slug}-firewall-${local.environment}"
  base_domain   = var.base_domain
}
