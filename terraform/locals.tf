locals {
  env = replace(terraform.workspace, "platform-", "")
  environment = local.env
  server_name = var.server_name != null ? var.server_name : "platform-${local.environment}"
}
