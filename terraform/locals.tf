locals {
  env = replace(terraform.workspace, "giftfinder-", "")
  environment = local.env
  server_name = var.server_name != null ? var.server_name : "giftfinder-${local.environment}"
}
