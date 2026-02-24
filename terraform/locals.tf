locals {
  environment = replace(terraform.workspace, "platform-", "")
  server_name = var.server_name != null ? var.server_name : "platform-${local.environment}"
}
